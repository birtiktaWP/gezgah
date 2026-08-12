import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../data/api.dart';
import '../data/location_service.dart';
import '../data/mock_data.dart';
import '../data/models.dart';
import '../data/search_history.dart';
import '../data/user_service.dart';
import '../screens/category_screen.dart';
import '../theme/app_theme.dart';
import 'common.dart';

/// Gelişmiş arama — tam ekran açılan modal.
void showSearchModal(BuildContext context,
    {void Function(Place place)? onOpenDetail}) {
  Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black26,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) => _SearchModal(onOpenDetail: onOpenDetail),
      transitionsBuilder: (_, anim, __, child) {
        return SlideTransition(
          position: Tween<Offset>(
                  begin: const Offset(0, 1), end: Offset.zero)
              .animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
          child: child,
        );
      },
    ),
  );
}

class _SearchModal extends StatefulWidget {
  final void Function(Place place)? onOpenDetail;
  const _SearchModal({this.onOpenDetail});

  @override
  State<_SearchModal> createState() => _SearchModalState();
}

class _SearchModalState extends State<_SearchModal>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  late final TabController _tab;

  Timer? _debounce;
  String _query = '';

  // "Mekanlar" sekmesi (varsayılan, tab=mekan).
  final ScrollController _placeScroll = ScrollController();
  CancelToken? _placeCancel;
  List<SearchResult> _placeItems = const [];
  bool _placeLoading = false;
  bool _placeMoreLoading = false;
  bool _placeHasMore = false;
  int? _placeNextPage;

  // "Yemekler" sekmesi (lazy; sekmeye geçilince tab=yemek ile yüklenir).
  final ScrollController _foodScroll = ScrollController();
  CancelToken? _foodCancel;
  List<FoodResult> _foodItems = const [];
  bool _foodLoading = false;
  bool _foodMoreLoading = false;
  bool _foodHasMore = false;
  int? _foodNextPage;
  String? _foodTerm; // yemekler'in yüklendiği terim (null = yüklenmedi)

  // Konum (mesafe sıralaması) + yemek sekmesi sıralama/filtre durumu.
  double? _lat;
  double? _lng;
  bool _hasCoord = false;
  String _foodSort = 'likes'; // konum gelince 'distance' olur
  final Set<int> _foodFilters = {}; // seçili filtre id'leri (yemek)
  List<Filter> _allFilters = const []; // /filtreler (filtre sheet için)

  String? _userId; // arama geçmişi kaydı için (varsa gerçek, yoksa anonim)
  List<String> _popular = MockData.popularSearches; // API gelene kadar fallback
  List<String> _history = const [];
  List<Category> _categories = const []; // ana sayfayla aynı kaynak

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(_onTabChanged);
    _placeScroll.addListener(() {
      if (_placeScroll.position.pixels >=
          _placeScroll.position.maxScrollExtent - 300) {
        _loadMorePlaces();
      }
    });
    _foodScroll.addListener(() {
      if (_foodScroll.position.pixels >=
          _foodScroll.position.maxScrollExtent - 300) {
        _loadMoreFoods();
      }
    });
    _loadInitial();
    _resolveLoc();
  }

  /// Konumu (mesafe sıralaması için) çözer. Gerçek konum varsa mekan/yemek
  /// varsayılanı mesafeye döner; aktif bir sorgu varsa yeniden çalıştırılır.
  Future<void> _resolveLoc() async {
    final loc = await LocationService.resolve();
    if (!mounted || !loc.real) return;
    setState(() {
      _lat = loc.lat;
      _lng = loc.lng;
      _hasCoord = true;
      // Kullanıcı elle bir sıralama seçmediyse mesafeyi varsayılan yap.
      if (_foodSort == 'likes') _foodSort = 'distance';
    });
    // Konum geç geldiyse ve arama aktifse mesafeye göre yenile.
    final term = _query.trim();
    if (term.length >= 2) {
      _runMekan(term);
      if (_tab.index == 1) _runFood(term);
    }
  }

  /// Mekan sekmesi için etkin sıralama (konum varsa mesafe, yoksa alaka).
  String? get _mekanSort => _hasCoord ? 'distance' : null;

  /// Metre → "1.2 km" (yoksa boş).
  String _km(int? m) => m == null ? '' : LocationService.format(m.toDouble());

  /// Yemekler sekmesine geçilince aynı terimle bir kez yükler (tab=yemek).
  void _onTabChanged() {
    if (_tab.index == 1) {
      final term = _query.trim();
      if (term.length >= 2 && _foodTerm != term && !_foodLoading) {
        _runFood(term);
      }
    }
  }

  Future<void> _loadInitial() async {
    final id = await UserService.instance.currentId();
    final pop = await HomeRepository.instance.populerAramalar(limit: 6);
    final hist = await SearchHistory.instance.list();
    // Ana sayfadaki kategorilerle aynı: mekanı olanlar, en çok mekana göre.
    List<Category> cats = const [];
    try {
      final all = await HomeRepository.instance.kategoriler();
      // one_cikan_kategoriler'de mekan_sayisi yok (hepsi 0); bu durumda
      // curated sırayı koru. Aksi halde (fallback /kategoriler) mekanı
      // olanları mekan sayısına göre sırala.
      final hasCounts = all.any((c) => c.mekanSayisi > 0);
      cats = hasCounts
          ? (all.where((c) => c.mekanSayisi > 0).toList()
            ..sort((a, b) => b.mekanSayisi.compareTo(a.mekanSayisi)))
          : all;
    } catch (_) {
      cats = const [];
    }

    if (!mounted) return;
    setState(() {
      _userId = id;
      if (pop.isNotEmpty) _popular = pop;
      _history = hist;
      _categories = cats;
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _placeCancel?.cancel('modal kapandı');
    _foodCancel?.cancel('modal kapandı');
    _tab.removeListener(_onTabChanged);
    _tab.dispose();
    _placeScroll.dispose();
    _foodScroll.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    setState(() => _query = value);
    _debounce?.cancel();
    final term = value.trim();
    if (term.length < 2) {
      _placeCancel?.cancel('kısa sorgu');
      _foodCancel?.cancel('kısa sorgu');
      setState(() {
        _placeItems = const [];
        _foodItems = const [];
        _placeLoading = false;
        _foodLoading = false;
        _foodTerm = null;
        _placeHasMore = false;
        _foodHasMore = false;
      });
      return;
    }
    setState(() {
      _placeLoading = true;
      _foodTerm = null; // yeni terim → yemekler tekrar yüklenecek
    });
    _debounce = Timer(const Duration(milliseconds: 250), () {
      _runMekan(term);
      if (_tab.index == 1) _runFood(term); // yemekler sekmesindeyken de yükle
    });
  }

  /// Mekanlar sekmesi (tab=mekan). Önceki isteği iptal eder.
  Future<void> _runMekan(String term) async {
    _placeCancel?.cancel('yeni arama');
    final token = CancelToken();
    _placeCancel = token;
    if (mounted) setState(() => _placeLoading = true);
    try {
      final r = await HomeRepository.instance.aramaMekan(
        term,
        userId: _userId,
        limit: 20,
        cancelToken: token,
        lat: _lat,
        lng: _lng,
        sort: _mekanSort,
      );
      if (!mounted || _controller.text.trim() != term) return;
      setState(() {
        _placeItems = r.items;
        _placeHasMore = r.hasMore;
        _placeNextPage = r.nextPage;
        _placeLoading = false;
      });
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) return;
      if (!mounted) return;
      setState(() {
        _placeItems = const [];
        _placeLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _placeItems = const [];
        _placeLoading = false;
      });
    }
  }

  /// Yemekler sekmesi (tab=yemek). Önceki isteği iptal eder.
  Future<void> _runFood(String term) async {
    _foodCancel?.cancel('yeni arama');
    final token = CancelToken();
    _foodCancel = token;
    if (mounted) setState(() => _foodLoading = true);
    try {
      final r = await HomeRepository.instance.aramaYemek(
        term,
        userId: _userId,
        limit: 20,
        cancelToken: token,
        lat: _lat,
        lng: _lng,
        sort: _foodSort,
        filtreler: _foodFilters.toList(),
      );
      if (!mounted || _controller.text.trim() != term) return;
      setState(() {
        _foodItems = r.items;
        _foodHasMore = r.hasMore;
        _foodNextPage = r.nextPage;
        _foodTerm = term;
        _foodLoading = false;
      });
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) return;
      if (!mounted) return;
      setState(() {
        _foodItems = const [];
        _foodTerm = term;
        _foodLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _foodItems = const [];
        _foodTerm = term;
        _foodLoading = false;
      });
    }
  }

  Future<void> _loadMorePlaces() async {
    if (_placeMoreLoading || !_placeHasMore || _placeNextPage == null) return;
    final term = _query.trim();
    if (term.length < 2) return;
    setState(() => _placeMoreLoading = true);
    try {
      final r = await HomeRepository.instance.aramaMekan(
        term,
        userId: _userId,
        page: _placeNextPage!,
        limit: 20,
        lat: _lat,
        lng: _lng,
        sort: _mekanSort,
      );
      if (!mounted) return;
      setState(() {
        _placeItems = [..._placeItems, ...r.items];
        _placeHasMore = r.hasMore;
        _placeNextPage = r.nextPage;
        _placeMoreLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _placeMoreLoading = false);
    }
  }

  Future<void> _loadMoreFoods() async {
    if (_foodMoreLoading || !_foodHasMore || _foodNextPage == null) return;
    final term = _query.trim();
    if (term.length < 2) return;
    setState(() => _foodMoreLoading = true);
    try {
      final r = await HomeRepository.instance.aramaYemek(
        term,
        userId: _userId,
        page: _foodNextPage!,
        limit: 20,
        lat: _lat,
        lng: _lng,
        sort: _foodSort,
        filtreler: _foodFilters.toList(),
      );
      if (!mounted) return;
      setState(() {
        _foodItems = [..._foodItems, ...r.items];
        _foodHasMore = r.hasMore;
        _foodNextPage = r.nextPage;
        _foodMoreLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _foodMoreLoading = false);
    }
  }

  bool get _isSearching => _query.trim().length >= 2;

  void _clear() {
    _placeCancel?.cancel('temizlendi');
    _foodCancel?.cancel('temizlendi');
    setState(() {
      _controller.clear();
      _query = '';
      _placeItems = const [];
      _foodItems = const [];
      _placeLoading = false;
      _foodLoading = false;
      _foodTerm = null;
      _placeHasMore = false;
      _foodHasMore = false;
    });
  }

  /// Bir terimi arama kutusuna yazıp aramayı tetikler (çip/öneri dokunuşları).
  void _applyTerm(String term) {
    _controller.text = term;
    _controller.selection =
        TextSelection.collapsed(offset: term.length);
    _onQueryChanged(term);
  }

  /// Terimi yerel "Son Aramalar" listesine ekler (kullanıcı aramayı onayladı).
  Future<void> _commitHistory(String term) async {
    final t = term.trim();
    if (t.length < 2) return;
    final hist = await SearchHistory.instance.add(t);
    if (!mounted) return;
    setState(() => _history = hist);
  }

  Future<void> _removeHistory(String term) async {
    final hist = await SearchHistory.instance.remove(term);
    if (!mounted) return;
    setState(() => _history = hist);
  }

  Future<void> _clearHistory() async {
    await SearchHistory.instance.clear();
    if (!mounted) return;
    setState(() => _history = const []);
  }

  /// Yemekler sekmesi sıralama seçimi (bottom sheet).
  void _openFoodSort() {
    final options = <(String, String)>[
      if (_hasCoord) ('distance', 'Yakınlığa göre'),
      ('price_asc', 'Fiyat: Artan'),
      ('price_desc', 'Fiyat: Azalan'),
      ('likes', 'Beğeniye göre'),
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(22, 18, 22, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Sırala',
                    style: TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w600)),
              ),
            ),
            for (final o in options)
              InkWell(
                onTap: () {
                  Navigator.pop(ctx);
                  _applyFoodSort(o.$1);
                },
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(o.$2,
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: _foodSort == o.$1
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                color: _foodSort == o.$1
                                    ? AppColors.primary
                                    : AppColors.ink)),
                      ),
                      if (_foodSort == o.$1)
                        const Icon(Icons.check, color: AppColors.primary),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _applyFoodSort(String s) {
    if (s == _foodSort) return;
    setState(() => _foodSort = s);
    final term = _query.trim();
    if (term.length >= 2) _runFood(term);
  }

  /// Yemekler sekmesi filtre seçimi (bottom sheet, /filtreler).
  Future<void> _openFoodFilter() async {
    if (_allFilters.isEmpty) {
      _allFilters = await HomeRepository.instance.filtreler(type: 'restoran');
    }
    if (!mounted) return;
    if (_allFilters.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Filtre bulunamadı')),
      );
      return;
    }
    final temp = Set<int>.from(_foodFilters);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 8),
                child: Row(
                  children: [
                    const Text('Filtrele',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => setSheet(temp.clear),
                      child: const Text('Temizle',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary)),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    for (final f in _allFilters)
                      InkWell(
                        onTap: () => setSheet(() {
                          if (temp.contains(f.id)) {
                            temp.remove(f.id);
                          } else {
                            temp.add(f.id);
                          }
                        }),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(f.name,
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: temp.contains(f.id)
                                            ? FontWeight.w600
                                            : FontWeight.w500,
                                        color: temp.contains(f.id)
                                            ? AppColors.primary
                                            : AppColors.ink)),
                              ),
                              Icon(
                                temp.contains(f.id)
                                    ? Icons.check_box
                                    : Icons.check_box_outline_blank,
                                color: temp.contains(f.id)
                                    ? AppColors.primary
                                    : AppColors.muted,
                                size: 22,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                    20, 8, 20, 16 + MediaQuery.of(ctx).padding.bottom),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Uygula',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ).then((applied) {
      if (applied == true && mounted) {
        setState(() {
          _foodFilters
            ..clear()
            ..addAll(temp);
        });
        final term = _query.trim();
        if (term.length >= 2) _runFood(term);
      }
    });
  }

  /// Kategoriye dokununca arama modalını kapatıp kategori detayını açar.
  void _openCategory(Category c) {
    final nav = Navigator.of(context);
    nav.pop();
    nav.push(MaterialPageRoute(
        builder: (_) => CategoryScreen(categoryId: c.id, title: c.name)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: GestureDetector(
        // Boş bir yere dokununca klavyeyi kapat.
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: SafeArea(
          child: Column(
            children: [
              _header(),
              Expanded(
                child: _isSearching
                    ? _resultsView()
                    : ListView(
                  // Kaydırınca da klavye kapansın.
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                  if (_history.isNotEmpty) ...[
                    _historyHeader(),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _history
                          .take(3) // yalnızca son 3 arama
                          .map((s) => _chip(s, Icons.history,
                              onRemove: () => _removeHistory(s)))
                          .toList(),
                    ),
                    const SizedBox(height: 26),
                  ],
                  _sectionTitle('Popüler Aramalar'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _popular
                        .map((s) => _chip(s, Icons.trending_up))
                        .toList(),
                  ),
                  const SizedBox(height: 26),
                  _kedyHeader(),
                  const SizedBox(height: 12),
                  _kedyGrid(),
                  const SizedBox(height: 26),
                  _sectionTitle('Kategoriler'),
                  const SizedBox(height: 14),
                  _categoryRow(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Arama sonuçları görünümü (q >= 2): iki sekme — Mekanlar / Yemekler.
  Widget _resultsView() {
    return Column(
      children: [
        _searchTabs(),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [_placesTab(), _foodsTab()],
          ),
        ),
      ],
    );
  }

  /// Segment tarzı sekme çubuğu (kaymalı TabBarView ile senkron).
  Widget _searchTabs() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 4, 20, 6),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tab,
        indicator: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(9),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        splashBorderRadius: BorderRadius.circular(9),
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.ink,
        labelStyle:
            const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
        unselectedLabelStyle:
            const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
        tabs: const [Tab(text: 'Mekanlar'), Tab(text: 'Yemekler')],
      ),
    );
  }

  Widget _searchSpinner() => const Center(
        child: SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(
              strokeWidth: 2.5, color: AppColors.primary),
        ),
      );

  Widget _emptyResults() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.search_off, size: 44, color: AppColors.muted),
              const SizedBox(height: 12),
              Text('"${_query.trim()}" için sonuç bulunamadı',
                  textAlign: TextAlign.center,
                  style:
                      const TextStyle(fontSize: 14, color: AppColors.muted)),
            ],
          ),
        ),
      );

  Widget _moreSpinner() => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
                strokeWidth: 2.2, color: AppColors.primary),
          ),
        ),
      );

  Widget _placesTab() {
    if (_placeLoading) return _searchSpinner();
    if (_placeItems.isEmpty) return _emptyResults();
    return ListView.separated(
      controller: _placeScroll,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      itemCount: _placeItems.length + (_placeMoreLoading ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) =>
          i >= _placeItems.length ? _moreSpinner() : _resultTile(_placeItems[i]),
    );
  }

  Widget _foodsTab() {
    // Toolbar (sırala + filtrele) her durumda üstte kalsın; içerik altında.
    return Column(
      children: [
        _foodToolbar(),
        Expanded(child: _foodsContent()),
      ],
    );
  }

  Widget _foodsContent() {
    final term = _query.trim();
    // Bu terim için yemekler henüz yüklenmediyse (sekmeye yeni geçildi) veya
    // yükleniyorsa spinner göster — yanlış "sonuç yok" göstermemek için.
    if (_foodLoading || (_foodTerm != term && term.length >= 2)) {
      return _searchSpinner();
    }
    if (_foodItems.isEmpty) return _emptyResults();
    return ListView.separated(
      controller: _foodScroll,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      itemCount: _foodItems.length + (_foodMoreLoading ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) =>
          i >= _foodItems.length ? _moreSpinner() : _foodTile(_foodItems[i]),
    );
  }

  String get _foodSortLabel => switch (_foodSort) {
        'distance' => 'Yakınlığa göre',
        'price_asc' => 'Fiyat: Artan',
        'price_desc' => 'Fiyat: Azalan',
        _ => 'Beğeniye göre',
      };

  Widget _foodToolbar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(_foodSortLabel,
                style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.muted)),
          ),
          GestureDetector(onTap: _openFoodSort, child: _sfBtn(Icons.swap_vert)),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _openFoodFilter,
            child: _sfBtn(Icons.filter_list, active: _foodFilters.isNotEmpty),
          ),
        ],
      ),
    );
  }

  Widget _sfBtn(IconData icon, {bool active = false}) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: active ? AppColors.primary : Colors.white,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: active ? AppColors.primary : AppColors.line),
      ),
      child: Icon(icon,
          size: 18, color: active ? Colors.white : AppColors.primary),
    );
  }

  /// Yemek sonucu satırı — ürün görseli + ad + fiyat/beğeni + ait olduğu mekan.
  /// Dokununca mekan detayına gider.
  Widget _foodTile(FoodResult f) {
    final p = f.mekan;
    final loc = p.subtitle;
    // Ürünün kendi görseli varsa onu, yoksa mekanın kare thumbnail'ını kullan.
    final foodImg = f.gorsel.isNotEmpty ? f.gorsel : p.thumb(ThumbSize.square);
    return GestureDetector(
      onTap: () {
        _commitHistory(_query);
        Navigator.pop(context);
        widget.onOpenDetail?.call(p);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: SizedBox(
                width: 56,
                height: 56,
                child: foodImg.isNotEmpty
                    ? NetImage(foodImg)
                    : Container(
                        color: AppColors.primarySoft,
                        child: const Icon(Icons.restaurant_menu,
                            color: AppColors.primary, size: 22),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(f.urun,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14.5, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.storefront_outlined,
                          size: 13, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                            [
                              p.name,
                              _km(f.mesafeM),
                              loc
                            ].where((s) => s.isNotEmpty).join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.muted)),
                      ),
                    ],
                  ),
                  if (f.fiyat.isNotEmpty || f.begeni > 0) ...[
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        if (f.fiyat.isNotEmpty)
                          Text('₺${f.fiyat}',
                              style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary)),
                        if (f.begeni > 0) ...[
                          if (f.fiyat.isNotEmpty) const SizedBox(width: 10),
                          const Icon(Icons.favorite,
                              size: 12, color: AppColors.heart),
                          const SizedBox(width: 3),
                          Text('${f.begeni}',
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.muted)),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.muted),
          ],
        ),
      ),
    );
  }

  Widget _resultTile(SearchResult r) {
    final p = r.place;
    final loc =
        [p.sehir, p.ilce].where((s) => s.trim().isNotEmpty).join(' · ');
    // Konum verildiyse mesafe alt yazının başına eklenir.
    final metaText =
        [_km(r.mesafeM), loc].where((s) => s.isNotEmpty).join(' · ');
    return GestureDetector(
      onTap: () {
        _commitHistory(_query);
        Navigator.pop(context);
        widget.onOpenDetail
            ?.call(p.toPlace(subtitle: loc.isNotEmpty ? loc : 'Restoran'));
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: SizedBox(
                width: 56,
                height: 56,
                child: p.thumb(ThumbSize.square).isNotEmpty
                    ? NetImage(p.thumb(ThumbSize.square))
                    : Container(
                        color: AppColors.primarySoft,
                        child: const Icon(Icons.restaurant_outlined,
                            color: AppColors.primary, size: 22),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(p.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14.5, fontWeight: FontWeight.w600)),
                  if (metaText.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 13, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(metaText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.muted)),
                        ),
                      ],
                    ),
                  ],
                  if (r.matchedProducts.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('Menü: ${r.matchedProducts.take(3).join(', ')}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary)),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.muted),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
      child: Column(
        children: [
          Row(
            children: [
              const Text('Ara',
                  style:
                      TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F0F5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.close, color: AppColors.ink, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primary, width: 1.5),
            ),
            child: Row(
              children: [
                const Icon(Icons.search, color: AppColors.primary, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    autofocus: true,
                    textInputAction: TextInputAction.search,
                    onChanged: _onQueryChanged,
                    onSubmitted: _commitHistory,
                    decoration: const InputDecoration(
                      hintText: 'Mekan ve yemek ara…',
                      hintStyle: TextStyle(color: AppColors.muted),
                      border: InputBorder.none,
                      isCollapsed: true,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _clear,
                  child: const Icon(Icons.cancel,
                      color: AppColors.muted, size: 20),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String t, {bool link = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(t,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w600)),
        if (link)
          const Text('Tümü',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary)),
      ],
    );
  }

  Widget _historyHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('Son Aramalar',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        GestureDetector(
          onTap: _clearHistory,
          child: const Text('Temizle',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary)),
        ),
      ],
    );
  }

  Widget _chip(String label, IconData icon, {VoidCallback? onRemove}) {
    return GestureDetector(
      onTap: () => _applyTerm(label),
      child: Container(
        padding: EdgeInsets.only(
            left: 13, right: onRemove != null ? 8 : 13, top: 9, bottom: 9),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: AppColors.primary),
            const SizedBox(width: 7),
            Text(label,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
            if (onRemove != null) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onRemove,
                child: const Icon(Icons.close, size: 15, color: AppColors.muted),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _kedyHeader() {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
              color: AppColors.primary, shape: BoxShape.circle),
          child: const Center(child: KedyIcon(size: 18, color: Colors.white)),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('Kedy Tavsiyeleri',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            Text('Sana özel akıllı öneriler',
                style: TextStyle(fontSize: 12, color: AppColors.muted)),
          ],
        ),
      ],
    );
  }

  /// Kedy tavsiyeleri — 2 sütunlu kart ızgarası, her öneride kendi ikonu.
  static const List<(IconData, String)> _kedyTips = [
    (Icons.work_outline, 'Sessiz çalışma kafeleri'),
    (Icons.umbrella, 'Yağmurlu güne uygun'),
    (Icons.favorite_border, 'İlk buluşma için'),
    (Icons.attach_money, 'Bütçe dostu lezzetler'),
  ];

  Widget _kedyGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        mainAxisExtent: 66,
      ),
      itemCount: _kedyTips.length,
      itemBuilder: (_, i) {
        final tip = _kedyTips[i];
        return GestureDetector(
          onTap: () => _applyTerm(tip.$2),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(11)),
                  child: Icon(tip.$1, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(tip.$2,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.2)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _categoryRow() {
    // Ana sayfayla aynı kaynak: /kategoriler.
    if (_categories.isEmpty) return const SizedBox(height: 86);
    return SizedBox(
      height: 86,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (_, i) {
          final c = _categories[i];
          return GestureDetector(
            onTap: () => _openCategory(c),
            child: SizedBox(
              width: 64,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(12)),
                    child: Center(
                      child: CategoryIcon(
                          icon: c.icon,
                          id: c.id,
                          color: AppColors.primary,
                          size: 24),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(c.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
