import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../data/api.dart';
import '../data/home_config.dart';
import '../data/location_service.dart';
import '../data/mock_data.dart';
import '../data/models.dart';
import '../navigation/main_nav.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/place_cards.dart';
import '../widgets/tabbar.dart';
import 'detail_screen.dart';
import 'map_screen.dart';

class CategoryScreen extends StatefulWidget {
  final int? categoryId;
  final String title;
  const CategoryScreen({super.key, this.categoryId, this.title = 'Kategori'});

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

  List<Filter> _filters = const []; // /filtreler
  final Set<int> _selectedFilters = {}; // seçili filtre id'leri

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
    if (id == null) {
      _useFallback();
      return;
    }
    try {
      final loc = await _ensureLoc();
      final results = await Future.wait([
        HomeRepository.instance.kategoriDetay(id, limit: 20),
        HomeRepository.instance.filtreler(type: 'restoran'),
      ]);
      final d = results[0] as CategoryDetail;
      final filters = results[1] as List<Filter>;
      if (!mounted) return;
      _applyDistances(d.places, loc);
      if (d.pinned != null) _applyDistances([d.pinned!], loc);
      setState(() {
        _loading = false;
        _filters = filters;
        _category = d.category;
        _subs = d.subCategories;
        _pinned = d.pinned;
        _places = List<Place>.from(d.places);
        _total = d.total;
        _hasMore = d.hasMore;
        _nextPage = d.nextPage;
        _sortPlaces();
      });
    } catch (_) {
      // Endpoint yoksa/hata olursa mock vitrine düş (tasarım bozulmasın).
      _useFallback();
    }
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
    if (id == null ||
        _loadingMore ||
        _loading ||
        !_hasMore ||
        _nextPage == null) {
      return;
    }
    setState(() => _loadingMore = true);
    try {
      final loc = await _ensureLoc();
      final d = await HomeRepository.instance
          .kategoriDetay(id, page: _nextPage!, limit: 20);
      if (!mounted) return;
      _applyDistances(d.places, loc);
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

  bool _matchesFilters(Place p) {
    if (_selectedFilters.isEmpty) return true;
    return _selectedFilters.every((id) => p.filterIds.contains(id));
  }

  /// Seçili filtrelere göre görünecek mekanlar.
  List<Place> get _visiblePlaces =>
      _selectedFilters.isEmpty ? _places : _places.where(_matchesFilters).toList();

  Place? get _visiblePinned {
    final p = _pinned;
    if (p == null) return null;
    return _matchesFilters(p) ? p : null;
  }

  /// Filtre bottom sheet'i — çoklu seçim.
  void _openFilterSheet() {
    if (_filters.isEmpty) return;
    final temp = Set<int>.from(_selectedFilters);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            return SafeArea(
              child: ConstrainedBox(
                // Modal yarım ekrandan kısa; uzun liste kendi içinde kayar.
                constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(ctx).size.height * 0.45),
                child: Padding(
                  padding: EdgeInsets.only(
                      bottom: MediaQuery.of(ctx).viewInsets.bottom),
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
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Filtrele',
                              style: TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.w800)),
                          GestureDetector(
                            onTap: () => setSheet(() => temp.clear()),
                            child: const Text('Temizle',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary)),
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                        child: Column(
                          children: [
                            for (final f in _filters)
                              _FilterRow(
                                filter: f,
                                selected: temp.contains(f.id),
                                onToggle: () => setSheet(() {
                                  if (temp.contains(f.id)) {
                                    temp.remove(f.id);
                                  } else {
                                    temp.add(f.id);
                                  }
                                }),
                              ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          onPressed: () {
                            Navigator.pop(sheetCtx);
                            setState(() {
                              _selectedFilters
                                ..clear()
                                ..addAll(temp);
                            });
                          },
                          child: const Text('Uygula',
                              style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w800)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
          },
        );
      },
    );
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
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
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
                          fontSize: 17, fontWeight: FontWeight.w800)),
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

  void _openDetail(Place p) {
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => DetailScreen(place: p)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          ListView(
            controller: _scroll,
            padding: const EdgeInsets.only(bottom: 120),
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
                if (_visiblePinned != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 0, 22, 14),
                    child: ListTileCard(
                      place: _visiblePinned!,
                      onTap: () => _openDetail(_visiblePinned!),
                    ),
                  ),
                ...List.generate(_visiblePlaces.length, (i) {
                  final p = _visiblePlaces[i];
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(22, 0, 22, 14),
                    child: ListTileCard(
                      place: p,
                      onTap: () => _openDetail(p),
                    ),
                  );
                }),
                if (_visiblePlaces.isEmpty && _visiblePinned == null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 30, 22, 30),
                    child: Center(
                      child: Text(
                          _selectedFilters.isEmpty
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
            ],
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
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary)),
              ),
            ),
            GlassButton(
              icon: Icons.location_on_outlined,
              flat: true,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MapScreen(
                    initialCategoryId: _category?.id ?? widget.categoryId,
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
              _selectedFilters.isEmpty
                  ? '$_total mekan bulundu'
                  : '${_visiblePlaces.length} mekan (filtreli)',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.muted)),
          Row(
            children: [
              GestureDetector(
                  onTap: _openSortSheet, child: _actBtn(Icons.swap_vert)),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _openFilterSheet,
                child: _actBtn(Icons.filter_list,
                    active: _selectedFilters.isNotEmpty),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actBtn(IconData icon, {bool active = false}) {
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
}

/// Filtre satırı — solda ikon (API'den gelen SVG; yoksa isme göre Material
/// ikon), ortada ad, sağda özel on/off switch. Tüm satıra dokununca toggle.
class _FilterRow extends StatelessWidget {
  final Filter filter;
  final bool selected;
  final VoidCallback onToggle;
  const _FilterRow({
    required this.filter,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.line)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Center(child: _icon()),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(filter.name,
                  style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink)),
            ),
            _CustomSwitch(value: selected),
          ],
        ),
      ),
    );
  }

  Widget _icon() {
    final svg = filter.icon;
    if (svg != null && svg.trim().isNotEmpty) {
      return SvgPicture.string(
        svg,
        width: 20,
        height: 20,
        colorFilter:
            const ColorFilter.mode(AppColors.primary, BlendMode.srcIn),
      );
    }
    return Icon(_filterFallbackIcon(filter), size: 20, color: AppColors.primary);
  }
}

/// Tasarıma uygun özel on/off anahtarı (Material Switch yerine).
class _CustomSwitch extends StatelessWidget {
  final bool value;
  const _CustomSwitch({required this.value});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      width: 46,
      height: 28,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: value ? AppColors.primary : const Color(0xFFD9D9E2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 22,
          height: 22,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 3,
                  offset: Offset(0, 1)),
            ],
          ),
        ),
      ),
    );
  }
}

/// API ikonu (SVG) gelmezse filtre adına/slug'ına göre yedek Material ikon.
IconData _filterFallbackIcon(Filter f) {
  final s = '${f.slug} ${f.name}'.toLowerCase();
  bool has(String k) => s.contains(k);
  if (has('otopark') || has('park')) return Icons.local_parking_outlined;
  if (has('wifi') || has('internet')) return Icons.wifi;
  if (has('alkolsüz') || has('alkolsuz')) return Icons.no_drinks;
  if (has('alkol') || has('bar')) return Icons.local_bar_outlined;
  if (has('vale')) return Icons.directions_car_outlined;
  if (has('rezerv')) return Icons.event_available_outlined;
  if (has('dijital') || has('menü') || has('menu')) return Icons.qr_code_2;
  if (has('çocuk') || has('cocuk')) return Icons.child_friendly;
  if (has('çalışma') || has('calisma')) return Icons.work_outline;
  if (has('toplu') || has('etkinlik')) return Icons.celebration_outlined;
  if (has('soğutucu') || has('sogutucu') || has('klima')) return Icons.ac_unit;
  if (has('ısıtıcı') || has('isitici')) {
    return Icons.local_fire_department_outlined;
  }
  if (has('sigarasız') || has('sigarasiz')) return Icons.smoke_free;
  if (has('sigara')) return Icons.smoking_rooms;
  if (has('evcil') || has('hayvan') || has('pet')) return Icons.pets;
  if (has('yabancı') || has('dil')) return Icons.translate;
  if (has('nargile')) return Icons.air;
  if (has('engelsiz') || has('engelli')) return Icons.accessible;
  if (has('mescit') || has('ibadet')) return Icons.mosque_outlined;
  return Icons.tune;
}
