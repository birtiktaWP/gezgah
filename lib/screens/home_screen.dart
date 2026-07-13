import 'package:flutter/material.dart';
import '../data/api.dart';
import '../data/home_config.dart';
import '../data/location_service.dart';
import '../data/mock_data.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/place_cards.dart';
import '../widgets/typewriter.dart';
import 'category_screen.dart';
import 'detail_screen.dart';
import 'map_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback onOpenSearch;
  final VoidCallback onOpenNotifications;

  const HomeScreen({
    super.key,
    required this.onOpenSearch,
    required this.onOpenNotifications,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

/// Çözülmüş konum tipi kısaltması.
typedef _Loc = ({double lat, double lng, bool real});

class _HomeScreenState extends State<HomeScreen> {
  int _activeShortcut = -1; // başlangıçta hiçbir kısayol seçili değil

  // Konum bir kez çözülür, tüm mesafe hesaplarında paylaşılır.
  late final Future<_Loc> _loc;

  // Hero'daki konum etiketi (gerçek konumdan; gelene kadar varsayılan).
  String _locationLabel = 'Konum alınıyor…';

  late final Future<List<Category>> _categoriesFuture;
  late final Future<List<Place>> _sponsoredFuture;
  late final Future<List<Place>> _nearbyFuture;
  late final Future<List<Place>> _newestFuture;
  late final Future<List<FeaturedEvent>> _eventsFuture;

  @override
  void initState() {
    super.initState();
    _loc = LocationService.resolve();
    _resolveLocationLabel();
    // Kategori alanı: API'deki tüm kategoriler (mekanı olanlar), en çok
    // mekana sahip olandan başlayarak.
    _categoriesFuture = HomeRepository.instance.kategoriler().then((all) {
      final list = all.where((c) => c.mekanSayisi > 0).toList()
        ..sort((a, b) => b.mekanSayisi.compareTo(a.mekanSayisi));
      return list;
    });
    _sponsoredFuture = _loadSponsored();
    _nearbyFuture = _loadNearby();
    _newestFuture = _loadNewest();
    _eventsFuture = HomeRepository.instance.sponsorluEtkinlikler();
  }

  /// Gerçek konumdan "İl, İlçe" etiketini çözer ve hero'ya yazar.
  Future<void> _resolveLocationLabel() async {
    final loc = await _loc;
    final label = await LocationService.cityDistrict(loc.lat, loc.lng);
    if (!mounted) return;
    setState(() => _locationLabel = label ?? 'Konum bulunamadı');
  }

  // --- Veri yükleyiciler ------------------------------------------------------

  /// ApiPlace listesini Place kartlarına çevirir.
  ///
  /// Koordinat varsa mesafe hesaplanır ve `place.distance`e yazılır.
  /// Alt yazı (`subtitle`):
  ///  - [preferDistance] true ve mesafe varsa → mesafe (Yakındakiler).
  ///  - aksi halde "İl · İlçe" (yoksa mesafe, o da yoksa "Restoran").
  List<Place> _toPlaces(List<ApiPlace> items, _Loc loc,
      {bool preferDistance = false}) {
    return items.map((a) {
      String distance = '';
      if (a.hasCoord) {
        final m =
            LocationService.distanceMeters(loc.lat, loc.lng, a.lat!, a.lng!);
        distance = LocationService.format(m);
      }
      final cd = a.cityDistrict;
      final String sub;
      if (preferDistance && distance.isNotEmpty) {
        sub = distance;
      } else if (cd.isNotEmpty) {
        sub = cd;
      } else if (distance.isNotEmpty) {
        sub = distance;
      } else {
        sub = 'Restoran';
      }
      return a.toPlace(subtitle: sub, distance: distance);
    }).toList();
  }

  /// Sponsorlu restoranlar (home_page_settings → sponsorlu_restoranlar).
  Future<List<Place>> _loadSponsored() async {
    final loc = await _loc;
    try {
      final items = await HomeRepository.instance
          .sponsorluRestoranlar(HomeConfig.sponsorluRestoranlar);
      return _toPlaces(items, loc);
    } catch (_) {
      return const [];
    }
  }

  /// Yakındakiler: havuzu çekip cihaz konumuna göre en yakın 10'u seçer.
  Future<List<Place>> _loadNearby() async {
    final loc = await _loc;
    List<ApiPlace> pool;
    try {
      pool = await HomeRepository.instance.yakindakiler();
    } catch (_) {
      return MockData.nearby;
    }

    final withCoord = pool.where((p) => p.hasCoord).toList();

    // Koordinatlı kayıt yoksa (API havuzunda kordinat boş olabilir) ilk 10'u
    // mesafesiz göster; o da boşsa mock vitrine düş.
    if (withCoord.isEmpty) {
      final list = _toPlaces(pool.take(10).toList(), loc, preferDistance: true);
      return list.isEmpty ? MockData.nearby : list;
    }

    double dist(ApiPlace p) =>
        LocationService.distanceMeters(loc.lat, loc.lng, p.lat!, p.lng!);
    withCoord.sort((a, b) => dist(a).compareTo(dist(b)));
    return _toPlaces(withCoord.take(10).toList(), loc, preferDistance: true);
  }

  /// Yeni eklenenler (date DESC).
  Future<List<Place>> _loadNewest() async {
    final loc = await _loc;
    try {
      final items = await HomeRepository.instance.yeniEklenenler(limit: 10);
      return _toPlaces(items, loc);
    } catch (_) {
      return const [];
    }
  }

  // --- Navigasyon -------------------------------------------------------------

  void _openDetail(Place p) {
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => DetailScreen(place: p)));
  }

  void _openMap() {
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => const MapScreen()));
  }

  void _openCategory(int id, String title) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => CategoryScreen(categoryId: id, title: title)));
  }

  // --- Build ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 130),
      children: [
        _heroWithSearch(),
        const SizedBox(height: 14),
        _shortcuts(), // Tümü (home_page_settings → tumu)
        const SizedBox(height: 18),
        _categorySection(), // Kategori (kahvalti_sokak_tatli)
        const SizedBox(height: 22),
        _sponsoredSection(), // Sponsorlu Restoranlar (etkinlik kartı tasarımı)
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Marquee(items: MockData.promos),
        ),
        const SizedBox(height: 22),
        _placeRail('Yakındakiler', _nearbyFuture, fallback: MockData.nearby),
        const SizedBox(height: 18),
        _placeRail('Yeni Eklenenler', _newestFuture),
        const SizedBox(height: 26),
        _featuredEventsSection(), // Öne Çıkan Etkinlikler (sponsorlu kart tasarımı)
        const SizedBox(height: 50),
      ],
    );
  }

  Widget _hero() {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 46),
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0.7, -1.1),
          radius: 1.2,
          colors: [AppColors.primary2, AppColors.primary],
          stops: [0.0, 0.55],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const GezgahWordmark(),
                Row(
                  children: [
                    GlassButton(
                        icon: Icons.location_on_outlined, onTap: _openMap),
                    const SizedBox(width: 10),
                    GlassButton(
                      icon: Icons.notifications_none,
                      showDot: true,
                      onTap: widget.onOpenNotifications,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                const Icon(Icons.location_on_outlined,
                    size: 15, color: Colors.white70),
                const SizedBox(width: 6),
                Text('Konum · ',
                    style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.white.withValues(alpha: 0.78))),
                Flexible(
                  child: Text(_locationLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ),
              ],
            ),
            const SizedBox(height: 15),
            const Text('Şehrin en iyi',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                    letterSpacing: -0.5,
                    color: Colors.white)),
            SizedBox(
              height: 34,
              child: Typewriter(
                phrases: MockData.typedPhrases,
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroWithSearch() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 46),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          _hero(),
          Positioned(
            left: 22,
            right: 22,
            bottom: -34,
            child: _searchBox(),
          ),
        ],
      ),
    );
  }

  Widget _searchBox() {
    return GestureDetector(
      onTap: widget.onOpenSearch,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: AppShadows.search,
        ),
        child: Row(
          children: [
            const Icon(Icons.search, color: AppColors.primary),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Mekan ve yemek ara…',
                  style: TextStyle(fontSize: 15, color: AppColors.muted)),
            ),
            Container(width: 1, height: 24, color: AppColors.line),
            const SizedBox(width: 12),
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.mic_none, color: Colors.white, size: 18),
            ),
          ],
        ),
      ),
    );
  }

  /// "Tümü" kısayol satırı (home_page_settings → section_key `tumu`).
  /// İkonlu hap butonlar (CategoryPill) — emoji kullanılmaz.
  Widget _shortcuts() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        itemCount: HomeConfig.tumu.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final s = HomeConfig.tumu[i];
          return CategoryPill(
            icon: HomeConfig.iconFor(s.id),
            label: s.name,
            active: _activeShortcut == i,
            onTap: () {
              setState(() => _activeShortcut = i);
              _openCategory(s.id, s.name);
            },
          );
        },
      ),
    );
  }

  /// Kategori vitrini (home_page_settings → kahvalti_sokak_tatli).
  /// İçerik `GET /kategoriler`den seçili id'lerle çekilir.
  Widget _categorySection() {
    return SizedBox(
      height: 86,
      child: FutureBuilder<List<Category>>(
        future: _categoriesFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: AppColors.primary),
              ),
            );
          }
          final cats = snap.data ?? const <Category>[];
          if (cats.isEmpty) return const SizedBox.shrink();
          return ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 22),
            itemCount: cats.length,
            separatorBuilder: (_, __) => const SizedBox(width: 5),
            itemBuilder: (_, i) {
              final c = cats[i];
              return GestureDetector(
                onTap: () => _openCategory(c.id, c.name),
                child: SizedBox(
                  width: 72,
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
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// Sponsorlu Restoranlar — silinen "Yaklaşan Etkinlikler" büyük kart
  /// tasarımı burada kullanılır (görsel + karartma + sponsor rozeti + isim).
  Widget _sponsoredSection() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: SectionHead('Sponsorlu Restoranlar', onAll: () {}),
        ),
        SizedBox(
          height: 150,
          child: FutureBuilder<List<Place>>(
            future: _sponsoredFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: AppColors.primary),
                  ),
                );
              }
              final places = snapshot.data ?? const <Place>[];
              if (places.isEmpty) {
                return const Center(
                  child: Text('Şu an sponsorlu restoran yok',
                      style: TextStyle(fontSize: 13, color: AppColors.muted)),
                );
              }
              return ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 22),
                itemCount: places.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (_, i) => _sponsoredCard(places[i]),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Öne Çıkan Etkinlikler — sponsorlu restoranlarla aynı büyük kart tasarımı.
  /// (home_page_settings → sponsorlu_etkinlikler)
  Widget _featuredEventsSection() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: SectionHead('Öne Çıkan Etkinlikler', onAll: () {}),
        ),
        SizedBox(
          height: 150,
          child: FutureBuilder<List<FeaturedEvent>>(
            future: _eventsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: AppColors.primary),
                  ),
                );
              }
              final events = snapshot.data ?? const <FeaturedEvent>[];
              if (events.isEmpty) {
                return const Center(
                  child: Text('Şu an öne çıkan etkinlik yok',
                      style: TextStyle(fontSize: 13, color: AppColors.muted)),
                );
              }
              return ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 22),
                itemCount: events.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (_, i) => _eventCardBig(events[i]),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Sponsorlu restoran büyük kartı.
  Widget _sponsoredCard(Place p) => _bigCard(
        image: p.image,
        badgeIcon: Icons.verified,
        badgeText: 'SPONSORLU',
        title: p.name,
        metaIcon: Icons.location_on_outlined,
        metaText: p.subtitle, // il · ilçe (koordinat yoksa)
        trailing: p.distance, // koordinat varsa mesafe (sağda)
        onTap: () => _openDetail(p),
      );

  /// Öne çıkan etkinlik kartı — HTML'deki "Yaklaşan Etkinlikler" tasarımı:
  /// sol üstte tarih rozeti (gün + ay), altta tag çipi, başlık ve saat.
  Widget _eventCardBig(FeaturedEvent e) {
    final d = DateTime.tryParse(e.date);
    const months = [
      'OCA', 'ŞUB', 'MAR', 'NİS', 'MAY', 'HAZ', //
      'TEM', 'AĞU', 'EYL', 'EKİ', 'KAS', 'ARA'
    ];
    final day = d != null ? d.day.toString() : '';
    final month = d != null ? months[d.month - 1] : '';

    return GestureDetector(
      onTap: () {},
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.84,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Stack(
            fit: StackFit.expand,
            children: [
              NetImage(e.image),
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xD1080526),
                      Color(0x59080526),
                      Color(0x1A080526),
                    ],
                    stops: [0.12, 0.6, 1.0],
                  ),
                ),
              ),
              // Tarih rozeti (sol üst)
              if (day.isNotEmpty)
                Positioned(
                  top: 14,
                  left: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(day,
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                                height: 1)),
                        const SizedBox(height: 3),
                        Text(month,
                            style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                                height: 1)),
                      ],
                    ),
                  ),
                ),
              // Gövde (sol alt)
              Positioned(
                left: 14,
                right: 14,
                bottom: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.music_note, size: 12, color: Colors.white),
                          SizedBox(width: 5),
                          Text('Etkinlik',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(e.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Colors.white)),
                    if (e.time.trim().isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          const Icon(Icons.access_time,
                              size: 13, color: Colors.white),
                          const SizedBox(width: 5),
                          Text(e.time,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.9))),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Sponsorlu restoranlar ve öne çıkan etkinliklerde kullanılan büyük kart.
  Widget _bigCard({
    required String image,
    required IconData badgeIcon,
    required String badgeText,
    required String title,
    required IconData metaIcon,
    required String metaText,
    String trailing = '',
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.84,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Stack(
            fit: StackFit.expand,
            children: [
              NetImage(image),
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [Color(0xD1080526), Color(0x1A080526)],
                  ),
                ),
              ),
              // Rozet (sol üst)
              Positioned(
                top: 14,
                left: 14,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(badgeIcon, size: 14, color: AppColors.primary),
                      const SizedBox(width: 5),
                      Text(badgeText,
                          style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                              color: AppColors.primary)),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 14,
                right: 14,
                bottom: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Colors.white)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(metaIcon, size: 13, color: Colors.white),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(metaText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.9))),
                        ),
                        if (trailing.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.3)),
                            ),
                            child: Text(trailing,
                                style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white)),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Yatay kaydırmalı kompakt mekan rayı (PopCard).
  Widget _placeRail(
    String title,
    Future<List<Place>> future, {
    List<Place> fallback = const [],
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: SectionHead(title, onAll: () {}),
        ),
        SizedBox(
          height: 186,
          child: FutureBuilder<List<Place>>(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: AppColors.primary),
                  ),
                );
              }
              final data = snapshot.data;
              final places = (data == null || data.isEmpty) ? fallback : data;
              if (places.isEmpty) {
                return const Center(
                  child: Text('Şu an gösterilecek mekan yok',
                      style: TextStyle(fontSize: 13, color: AppColors.muted)),
                );
              }
              return ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 22),
                itemCount: places.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (_, i) {
                  final p = places[i];
                  return PopCard(
                    place: p,
                    onTap: () => _openDetail(p),
                    onFav: () => setState(() => p.favorite = !p.favorite),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
