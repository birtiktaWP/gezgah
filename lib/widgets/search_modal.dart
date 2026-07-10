import 'dart:async';
import 'package:flutter/material.dart';
import '../data/api.dart';
import '../data/home_config.dart';
import '../data/mock_data.dart';
import '../data/models.dart';
import '../data/search_history.dart';
import '../data/user_service.dart';
import '../screens/category_screen.dart';
import '../theme/app_theme.dart';
import 'common.dart';
import 'place_cards.dart';

/// Gelişmiş arama — tam ekran açılan modal.
void showSearchModal(BuildContext context, {void Function()? onOpenDetail}) {
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
  final void Function()? onOpenDetail;
  const _SearchModal({this.onOpenDetail});

  @override
  State<_SearchModal> createState() => _SearchModalState();
}

class _SearchModalState extends State<_SearchModal> {
  final TextEditingController _controller = TextEditingController();

  Timer? _debounce;
  String _query = '';
  bool _searching = false;
  List<SearchResult> _results = const [];

  String? _userId; // arama geçmişi kaydı için (varsa gerçek, yoksa anonim)
  List<String> _popular = MockData.popularSearches; // API gelene kadar fallback
  List<String> _history = const [];
  List<Category> _categories = const []; // ana sayfayla aynı kaynak
  List<Place> _sponsored = const []; // search_page_settings sponsorlu

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    final id = await UserService.instance.currentId();
    final pop = await HomeRepository.instance.populerAramalar(limit: 6);
    final hist = await SearchHistory.instance.list();
    // Ana sayfadaki kategorilerle aynı: mekanı olanlar, en çok mekana göre.
    List<Category> cats = const [];
    try {
      final all = await HomeRepository.instance.kategoriler();
      cats = all.where((c) => c.mekanSayisi > 0).toList()
        ..sort((a, b) => b.mekanSayisi.compareTo(a.mekanSayisi));
    } catch (_) {
      cats = const [];
    }

    // Arama sayfası sponsorlu restoranları (search_page_settings).
    List<Place> sponsored = const [];
    try {
      final items = await HomeRepository.instance.aramaSponsorluRestoranlar();
      sponsored = items.map((a) {
        final cd = a.cityDistrict;
        return a.toPlace(subtitle: cd.isNotEmpty ? cd : 'Restoran');
      }).toList();
    } catch (_) {
      sponsored = const [];
    }

    if (!mounted) return;
    setState(() {
      _userId = id;
      if (pop.isNotEmpty) _popular = pop;
      _history = hist;
      _categories = cats;
      _sponsored = sponsored;
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    setState(() => _query = value);
    _debounce?.cancel();
    final term = value.trim();
    if (term.length < 2) {
      setState(() {
        _results = const [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 350), () => _runSearch(term));
  }

  Future<void> _runSearch(String term) async {
    try {
      final r = await HomeRepository.instance.arama(term, userId: _userId);
      if (!mounted || _controller.text.trim() != term) return;
      setState(() {
        _results = r;
        _searching = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _results = const [];
        _searching = false;
      });
    }
  }

  bool get _isSearching => _query.trim().length >= 2;

  void _clear() {
    setState(() {
      _controller.clear();
      _query = '';
      _results = const [];
      _searching = false;
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
                  _sectionTitle('Sponsorlu', link: true),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 188,
                    child: Builder(
                      builder: (_) {
                        final sponsored = _sponsored.isNotEmpty
                            ? _sponsored
                            : MockData.popular;
                        return ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: sponsored.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 14),
                          itemBuilder: (_, i) => PopCard(
                            place: sponsored[i],
                            sponsored: true,
                            onTap: () {
                              Navigator.pop(context);
                              widget.onOpenDetail?.call();
                            },
                          ),
                        );
                      },
                    ),
                  ),
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

  /// Arama sonuçları görünümü (q >= 2 karakter).
  Widget _resultsView() {
    if (_searching) {
      return const Center(
        child: SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(
              strokeWidth: 2.5, color: AppColors.primary),
        ),
      );
    }
    if (_results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.search_off,
                  size: 44, color: AppColors.muted),
              const SizedBox(height: 12),
              Text('"${_query.trim()}" için sonuç bulunamadı',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: AppColors.muted)),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      itemCount: _results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _resultTile(_results[i]),
    );
  }

  Widget _resultTile(SearchResult r) {
    final p = r.place;
    final loc =
        [p.sehir, p.ilce].where((s) => s.trim().isNotEmpty).join(' · ');
    return GestureDetector(
      onTap: () {
        _commitHistory(_query);
        Navigator.pop(context);
        widget.onOpenDetail?.call();
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
                child: p.image.isNotEmpty
                    ? NetImage(p.image)
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
                          fontSize: 14.5, fontWeight: FontWeight.w800)),
                  if (loc.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 13, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(loc,
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
                      TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
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
                fontSize: 16, fontWeight: FontWeight.w700)),
        if (link)
          const Text('Tümü',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary)),
      ],
    );
  }

  Widget _historyHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('Son Aramalar',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        GestureDetector(
          onTap: _clearHistory,
          child: const Text('Temizle',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
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
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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
    (Icons.landscape_outlined, 'Manzaralı kahvaltı'),
    (Icons.pets, 'Evcil hayvan dostu'),
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
                          fontWeight: FontWeight.w700,
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
                    child: Icon(HomeConfig.iconFor(c.id),
                        color: AppColors.primary, size: 24),
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
