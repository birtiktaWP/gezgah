import 'package:flutter/material.dart';

import '../data/api.dart';
import '../data/home_config.dart';
import '../data/location_service.dart';
import '../data/mock_data.dart';
import '../data/models.dart';
import '../navigation/main_nav.dart';
import '../theme/app_theme.dart';
import '../widgets/app_icons.dart';
import '../widgets/common.dart';
import '../widgets/filter_sheet.dart';
import '../widgets/place_cards.dart';
import '../widgets/search_modal.dart';
import '../widgets/tabbar.dart';
import 'detail_screen.dart';
import 'map_screen.dart';

class CategoryScreen extends StatefulWidget {
  final int? categoryId;

  /// Post type slug'ı (kategori yerine). Verilirse `/mekanlar?type=<type>` ile
  /// listelenir (otopark | muze | mesire | plaj). Alt kategori/pin/filtre yok.
  final String? type;
  final String title;
  const CategoryScreen(
      {super.key, this.categoryId, this.type, this.title = 'Kategori'});

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

/// Çözülmüş konum tipi.
typedef _Loc = ({double lat, double lng, bool real});

/// Sıralama biçimi.
enum _SortMode { yakinlik, tarih }

class _CategoryScreenState extends State<CategoryScreen> {
  final ScrollController _scroll = ScrollController();

  bool _loading = true;
  bool _loadingMore = false;

  Category? _category;
  List<Category> _subs = const [];
  Place? _pinned;
  List<Place> _places = [];
  int _total = 0;
  bool _hasMore = false;
  int? _nextPage;

  _Loc? _loc; // cihaz konumu (bir kez çözülür)
  _SortMode _sort = _SortMode.yakinlik; // varsayılan: yakınlık

  List<Filter> _filters = const []; // /filtreler → data
  final Set<int> _selectedFilters = {}; // seçili filtre id'leri
  List<Filter> _ozellikler = const []; // /filtreler → meta.ozellikler
  final Set<int> _selectedOzellikler = {}; // seçili özellik id'leri

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels >=
          _scroll.position.maxScrollExtent - 300) {
        _loadMore();
      }
    });
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<_Loc> _ensureLoc() async {
    final cached = _loc;
    if (cached != null) return cached;
    final r = await LocationService.resolve();
    _loc = r;
    return r;
  }

  /// Koordinatı olanların alt yazısına km, olmayanların İl·İlçe yazılır.
  void _applyDistances(List<Place> list, _Loc loc) {
    for (final p in list) {
      if (!p.lat.isNaN && !p.lng.isNaN) {
        final m =
            LocationService.distanceMeters(loc.lat, loc.lng, p.lat, p.lng);
        p.subtitle = LocationService.format(m);
      } else {
        p.subtitle = p.distance.isNotEmpty ? p.distance : 'Konum bilgisi yok';
      }
    }
  }

  double _distMeters(Place p, _Loc loc) {
    if (p.lat.isNaN || p.lng.isNaN) return double.infinity;
    return LocationService.distanceMeters(loc.lat, loc.lng, p.lat, p.lng);
  }

  void _sortPlaces() {
    final loc = _loc;
    switch (_sort) {
      case _SortMode.yakinlik:
        if (loc != null) {
          _places.sort(
              (a, b) => _distMeters(a, loc).compareTo(_distMeters(b, loc)));
        }
        break;
      case _SortMode.tarih:
        _places.sort((a, b) => b.date.compareTo(a.date)); // yeni → eski
        break;
    }
  }

  Future<void> _load() async {
    final id = widget.categoryId;
    final type = widget.type;
    if (id == null && type == null) {
      _useFallback();
      return;
    }
    // Konumu PARALEL çöz — veri yüklemeyi bloklamasın. Gerçek cihazda GPS
    // fix'i saniyeler sürebildiğinden, önce konumu beklemek ekranı gereksiz
    // yere 4-5 sn döndürüyordu. Veri gelir gelmez gösterilir; konum gelince
    // mesafe + sıralama uygulanır.
    final locFuture = _ensureLoc();

    // Type modu: kategori değil post type listesi (GET /yerler?type=).
    if (type != null) {
      try {
        // Tipe ait filtreler paralel çekilir (FILTRELER_TIP_BAZLI.md).
        // Not: `meta.ozellikler` tipe göre süzülmediği ve restoran odaklı
        // olduğu için otopark/plaj/mesire'de özellik grubu gösterilmez.
        final results = await Future.wait([
          HomeRepository.instance.yerler(type, limit: 20),
          HomeRepository.instance.filtreler(type: type),
        ]);
        final r = results[0]
            as ({List<Place> items, bool hasMore, int? nextPage, int total});
        final f =
            results[1] as ({List<Filter> filtreler, List<Filter> ozellikler});
        if (!mounted) return;
        setState(() {
          _loading = false;
          _filters = f.filtreler;
          _ozellikler = const [];
          _places = List<Place>.from(r.items);
          _total = r.total;
          _hasMore = r.hasMore;
          _nextPage = r.nextPage;
        });
        _applyLocationWhenReady(locFuture);
      } catch (_) {
        _useFallback();
      }
      return;
    }

    try {
      final results = await Future.wait([
        HomeRepository.instance.kategoriDetay(id!, limit: 20),
        HomeRepository.instance.filtreler(type: 'restoran'),
      ]);
      final d = results[0] as CategoryDetail;
      final f = results[1] as ({List<Filter> filtreler, List<Filter> ozellikler});
      if (!mounted) return;
      setState(() {
        _loading = false;
        _filters = f.filtreler;
        _ozellikler = f.ozellikler;
        _category = d.category;
        _subs = d.subCategories;
        _pinned = d.pinned;
        _places = List<Place>.from(d.places);
        _total = d.total;
        _hasMore = d.hasMore;
        _nextPage = d.nextPage;
      });
      _applyLocationWhenReady(locFuture);
    } catch (_) {
      // Endpoint yoksa/hata olursa mock vitrine düş (tasarım bozulmasın).
      _useFallback();
    }
  }

  /// Konum (paralel) çözülünce mesafeleri uygular ve listeyi yeniden sıralar.
  /// Konum gelene kadar liste İl·İlçe alt yazısıyla ve sunucu sırasıyla görünür.
  Future<void> _applyLocationWhenReady(Future<_Loc> locFuture) async {
    final loc = await locFuture;
    if (!mounted) return;
    setState(() {
      _applyDistances(_places, loc);
      if (_pinned != null) _applyDistances([_pinned!], loc);
      _sortPlaces();
    });
  }

  void _useFallback() {
    if (!mounted) return;
    setState(() {
      _loading = false;
      _places = List<Place>.from(MockData.categoryList);
      _total = _places.length;
      _hasMore = false;
      _nextPage = null;
    });
  }

  /// Kaydırma sonuna gelince otomatik olarak sonraki 20 kaydı yükler.
  Future<void> _loadMore() async {
    final id = widget.categoryId;
    final type = widget.type;
    if ((id == null && type == null) ||
        _loadingMore ||
        _loading ||
        !_hasMore ||
        _nextPage == null) {
      return;
    }
    setState(() => _loadingMore = true);

    // Type modu: sonraki sayfayı GET /yerler?type= ile çek.
    if (type != null) {
      try {
        final r = await HomeRepository.instance
            .yerler(type, page: _nextPage!, limit: 20);
        if (!mounted) return;
        final loc = _loc;
        if (loc != null) _applyDistances(r.items, loc);
        setState(() {
          _places.addAll(r.items);
          _hasMore = r.hasMore;
          _nextPage = r.nextPage;
          _loadingMore = false;
          _sortPlaces();
        });
      } catch (_) {
        if (mounted) setState(() => _loadingMore = false);
      }
      return;
    }

    try {
      final d = await HomeRepository.instance
          .kategoriDetay(id!, page: _nextPage!, limit: 20);
      if (!mounted) return;
      // Konum çözülmüşse mesafeleri uygula; değilse İl·İlçe kalır (bloklama).
      final loc = _loc;
      if (loc != null) _applyDistances(d.places, loc);
      setState(() {
        _places.addAll(d.places);
        _total = d.total;
        _hasMore = d.hasMore;
        _nextPage = d.nextPage;
        _loadingMore = false;
        _sortPlaces();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  bool get _hasActiveFilter =>
      _selectedFilters.isNotEmpty || _selectedOzellikler.isNotEmpty;

  /// Süzme istemci tarafında yalnız yüklenmiş kayıtlara uygulandığı için,
  /// filtreli sonuç ekranı doldurmuyorsa sonraki sayfalar otomatik çekilir.
  /// Aksi halde liste kaydırılamaz ve `_loadMore` hiç tetiklenmez.
  Future<void> _fillFilteredResults() async {
    var guard = 0; // en fazla 5 ek sayfa (100 kayıt) — istek yağmuru olmasın
    while (mounted &&
        _hasActiveFilter &&
        _hasMore &&
        _visiblePlaces.length < 10 &&
        guard < 5) {
      guard++;
      final before = _places.length;
      await _loadMore();
      if (!mounted || _places.length == before) break; // ilerleme yoksa dur
    }
  }

  bool _matchesFilters(Place p) {
    if (!_hasActiveFilter) return true;
    // AND mantığı: tüm seçili filtre + tüm seçili özellik id'leri mekanda olmalı.
    return _selectedFilters.every((id) => p.filterIds.contains(id)) &&
        _selectedOzellikler.every((id) => p.ozellikIds.contains(id));
  }

  /// Seçili filtre/özelliklere göre görünecek mekanlar.
  List<Place> get _visiblePlaces =>
      !_hasActiveFilter ? _places : _places.where(_matchesFilters).toList();

  Place? get _visiblePinned {
    final p = _pinned;
    if (p == null) return null;
    return _matchesFilters(p) ? p : null;
  }

  /// Filtre bottom sheet'i (ortak `showFilterSheet`) — çoklu seçim.
  Future<void> _openFilterSheet() async {
    if (_filters.isEmpty && _ozellikler.isEmpty) return;
    final result = await showFilterSheet(
      context,
      filters: _filters,
      selected: _selectedFilters,
      ozellikler: _ozellikler,
      selectedOzellikler: _selectedOzellikler,
    );
    if (result != null && mounted) {
      setState(() {
        _selectedFilters
          ..clear()
          ..addAll(result.filters);
        _selectedOzellikler
          ..clear()
          ..addAll(result.ozellikler);
      });
      _fillFilteredResults();
    }
  }

  /// Sıralama bottom sheet'i.
  void _openSortSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetCtx) {
        Widget option(_SortMode mode, IconData icon, String label) {
          final selected = _sort == mode;
          return ListTile(
            leading: Icon(icon,
                color: selected ? AppColors.primary : AppColors.muted),
            title: Text(label,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w600,
                    color: selected ? AppColors.primary : AppColors.ink)),
            trailing: selected
                ? const Icon(Icons.check, color: AppColors.primary)
                : null,
            onTap: () {
              Navigator.pop(sheetCtx);
              if (_sort != mode) {
                setState(() {
                  _sort = mode;
                  _sortPlaces();
                });
              }
            },
          );
        }

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.line,
                    borderRadius: BorderRadius.circular(999)),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 14, 20, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Sırala',
                      style: TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w600)),
                ),
              ),
              option(_SortMode.yakinlik, Icons.near_me_outlined,
                  'Yakınlığa göre'),
              option(_SortMode.tarih, Icons.schedule,
                  'Eklenme tarihine göre'),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  String get _title => _category?.name ?? widget.title;

  void _openDetail(Place p, {Object? heroTag}) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => DetailScreen(
                place: p, heroTag: heroTag, type: widget.type)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.only(bottom: 120),
            // Lazy: 0 = başlık (+ alt kategori/pin), sonra mekan kartları, en
            // sonda durum/footer. Mekan kartları ve görselleri yalnızca ekrana
            // geldikçe oluşturulur.
            itemCount: _loading ? 1 : 2 + _visiblePlaces.length,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _header(),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.only(top: 90),
                        child: Center(
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: AppColors.primary),
                          ),
                        ),
                      )
                    else ...[
                      const SizedBox(height: 16),
                      if (_subs.isNotEmpty) ...[
                        _categoryPills(),
                        const SizedBox(height: 18),
                      ],
                      _listHead(),
                      if (_hasActiveFilter) _selectedChips(),
                      if (_visiblePinned != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(22, 0, 22, 14),
                          child: ListTileCard(
                            place: _visiblePinned!,
                            heroTag: _visiblePinned!.id > 0
                                ? 'cat-pin-${_visiblePinned!.id}'
                                : null,
                            onTap: () => _openDetail(_visiblePinned!,
                                heroTag: _visiblePinned!.id > 0
                                    ? 'cat-pin-${_visiblePinned!.id}'
                                    : null),
                          ),
                        ),
                    ],
                  ],
                );
              }

              final i = index - 1;
              if (i < _visiblePlaces.length) {
                final p = _visiblePlaces[i];
                final tag = p.id > 0 ? 'cat-${p.id}' : null;
                return Padding(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 14),
                  child: ListTileCard(
                    place: p,
                    heroTag: tag,
                    hideImage: widget.type == 'otopark',
                    onTap: () => _openDetail(p, heroTag: tag),
                  ),
                );
              }

              // Son slot: boş durum mesajı ve/veya "daha fazla yükleniyor".
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_visiblePlaces.isEmpty && _visiblePinned == null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 30, 22, 30),
                      child: Center(
                        child: Text(
                            !_hasActiveFilter
                                ? 'Bu kategoride mekan bulunamadı'
                                : 'Seçili filtrelere uygun mekan bulunamadı',
                            style: const TextStyle(
                                fontSize: 13, color: AppColors.muted)),
                      ),
                    ),
                  if (_loadingMore)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: AppColors.primary),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: FloatingTabBar(
                  activeIndex: -1, onTap: MainNav.instance.select),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
      decoration: const BoxDecoration(
        color: AppColors.bg,
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            GlassButton(
              icon: Icons.chevron_left,
              flat: true,
              onTap: () => Navigator.pop(context),
            ),
            Expanded(
              child: Center(
                child: Text(_title,
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary)),
              ),
            ),
            GlassButton(
              icon: Icons.search,
              flat: true,
              onTap: () =>
                  showSearchModal(context, onOpenDetail: _openDetail),
            ),
            const SizedBox(width: 4),
            GlassButton(
              icon: Icons.location_on_outlined,
              svg: AppIcons.pin,
              flat: true,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MapScreen(
                    initialCategoryId: _category?.id ?? widget.categoryId,
                    // Otopark/mesire/plaj listesinden geçilirse haritada da
                    // aynı tip seçili gelsin.
                    initialType: widget.type,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Kategori hapları — ilk hap mevcut kategori (aktif), sonrakiler alt
  /// kategoriler. Tasarım (CategoryPill) korunur; veri API'den gelir.
  Widget _categoryPills() {
    final items = <Category>[
      ?_category,
      ..._subs,
    ];
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final c = items[i];
          return CategoryPill(
            icon: HomeConfig.iconFor(c.id),
            label: c.name,
            active: i == 0,
            onTap: () {
              if (i == 0) return; // mevcut kategori
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      CategoryScreen(categoryId: c.id, title: c.name),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _listHead() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
              !_hasActiveFilter
                  ? '$_total mekan bulundu'
                  : '${_visiblePlaces.length} mekan (filtreli)',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.muted)),
          Row(
            children: [
              GestureDetector(
                  onTap: _openSortSheet,
                  child: _actBtn(Icons.swap_vert, svg: AppIcons.sort)),
              // Bu liste için hiç filtre/özellik yoksa butonu gizle.
              if (_filters.isNotEmpty || _ozellikler.isNotEmpty) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _openFilterSheet,
                  child: _actBtn(Icons.filter_list,
                      active: _hasActiveFilter,
                      svg: AppIcons.filter),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// Seçili filtre/özellikleri liste başlığının altında ikonsuz badge olarak
  /// gösterir; her badge'deki × ile o filtre/özellik kaldırılır.
  Widget _selectedChips() {
    // Seçili id'leri (filtre + özellik) ad + kaynak kümesiyle eşle.
    final chips = <({int id, String name, bool ozellik})>[];
    for (final f in _filters) {
      if (_selectedFilters.contains(f.id)) {
        chips.add((id: f.id, name: f.name, ozellik: false));
      }
    }
    for (final f in _ozellikler) {
      if (_selectedOzellikler.contains(f.id)) {
        chips.add((id: f.id, name: f.name, ozellik: true));
      }
    }
    if (chips.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 14),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final c in chips)
            GestureDetector(
              onTap: () {
                setState(() {
                  if (c.ozellik) {
                    _selectedOzellikler.remove(c.id);
                  } else {
                    _selectedFilters.remove(c.id);
                  }
                });
                _fillFilteredResults();
              },
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 7, 9, 7),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(c.name,
                        style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary)),
                    const SizedBox(width: 6),
                    const AppSvgIcon(AppIcons.xmark,
                        size: 10, color: AppColors.primary),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _actBtn(IconData icon, {bool active = false, String? svg}) {
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active ? AppColors.primary : Colors.white,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: active ? AppColors.primary : AppColors.line),
      ),
      child: svg != null
          ? AppSvgIcon(svg,
              size: 17, color: active ? Colors.white : AppColors.primary)
          : Icon(icon,
              size: 18, color: active ? Colors.white : AppColors.primary),
    );
  }
}


