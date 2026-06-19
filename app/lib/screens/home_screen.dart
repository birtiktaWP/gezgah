import 'package:flutter/material.dart';
import '../data/api.dart';
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

class _HomeScreenState extends State<HomeScreen> {
  int _activeCat = 0;
  late Future<List<Place>> _popularFuture;

  @override
  void initState() {
    super.initState();
    _popularFuture = _loadPopular();
  }

  /// Öne çıkan firmaları API'den çeker; hata/boş gelirse mock vitrine düşer
  /// (vitrin asla boş görünmesin). Ardından konum iznini isteyip kullanıcıya
  /// olan mesafeyi hesaplar ve kart alt yazısına ("Restoran · 3.2 km") ekler.
  Future<List<Place>> _loadPopular() async {
    List<Place> list;
    try {
      list = await PlacesRepository.instance.oneCikanFirmalar(limit: 10);
      if (list.isEmpty) list = MockData.popular;
    } catch (_) {
      list = MockData.popular;
    }

    // Konum izni iste ve mesafeleri hesapla (gerçek konum yoksa varsayılan
    // merkeze düşülür; böylece km her zaman görünür).
    final loc = await LocationService.resolve();
    for (final p in list) {
      final meters = LocationService.distanceMeters(
          loc.lat, loc.lng, p.lat, p.lng);
      p.distance = LocationService.format(meters);
      p.subtitle = p.distance; // sadece mesafe (tür adı gösterilmez)
    }
    return list;
  }

  void _openDetail() {
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => const DetailScreen()));
  }

  void _openMap() {
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => const MapScreen()));
  }

  void _openCategory(String title) {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => CategoryScreen(title: title)));
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 130),
      children: [
        _heroWithSearch(),
        const SizedBox(height: 14),
        _categories(),
        const SizedBox(height: 18),
        _quickCats(),
        const SizedBox(height: 14),
        _eventsSection(),
        const SizedBox(height: 15),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Marquee(items: MockData.promos),
        ),
        const SizedBox(height: 26),
        _popularSection(),
        const SizedBox(height: 12),
        _nearbySection(),
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
                const Text('İstanbul, Kadıköy',
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
                const Icon(Icons.keyboard_arrow_down,
                    size: 16, color: Colors.white70),
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

  /// Hero + üzerine binen arama kutusu. Arama, hero'nun alt kenarına
  /// oturur (28px içeri taşar) ve 34px aşağı çıkar; Padding bu çıkıntıyı
  /// rezerve eder, böylece altında yalnızca ~12px boşluk kalır.
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
              child: Text('Restoran, kafe, mekan ara…',
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

  Widget _categories() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        itemCount: MockData.categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final c = MockData.categories[i];
          return CategoryPill(
            icon: c.icon,
            label: c.label,
            active: _activeCat == i,
            onTap: () => setState(() => _activeCat = i),
          );
        },
      ),
    );
  }

  Widget _quickCats() {
    return SizedBox(
      height: 86,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        itemCount: MockData.quickCategories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 5),
        itemBuilder: (_, i) {
          final q = MockData.quickCategories[i];
          return GestureDetector(
            onTap: () => _openCategory(q.label),
            child: SizedBox(
              width: 68,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(12)),
                    child: Icon(q.icon, color: AppColors.primary, size: 24),
                  ),
                  const SizedBox(height: 8),
                  Text(q.label,
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

  Widget _eventsSection() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: SectionHead('Yaklaşan Etkinlikler', onAll: () {}),
        ),
        SizedBox(
          height: 150,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 22),
            itemCount: MockData.events.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (_, i) => _eventCard(MockData.events[i]),
          ),
        ),
      ],
    );
  }

  Widget _eventCard(EventItem e) {
    return SizedBox(
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
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Color(0xD1080526), Color(0x1A080526)],
                ),
              ),
            ),
            Positioned(
              top: 14,
              left: 14,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12)),
                child: Column(
                  children: [
                    Text(e.day,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                            height: 1)),
                    const SizedBox(height: 3),
                    Text(e.month.toUpperCase(),
                        style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                            height: 1)),
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
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    child: Text(e.tag,
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  ),
                  const SizedBox(height: 7),
                  Text(e.title,
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Colors.white)),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined,
                          size: 13, color: Colors.white),
                      const SizedBox(width: 5),
                      Text(e.location,
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.9))),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _popularSection() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: SectionHead('Popüler Mekanlar', onAll: () {}),
        ),
        SizedBox(
          height: 186,
          child: FutureBuilder<List<Place>>(
            future: _popularFuture,
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
              final places = snapshot.data ?? MockData.popular;
              return ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 22),
                itemCount: places.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (_, i) {
                  final p = places[i];
                  return PopCard(
                    place: p,
                    onTap: _openDetail,
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

  Widget _nearbySection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Column(
        children: [
          SectionHead('Yakınındakiler', onAll: () {}),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              mainAxisExtent: 210,
            ),
            itemCount: MockData.nearby.length,
            itemBuilder: (_, i) {
              final p = MockData.nearby[i];
              return GridTile2(
                place: p,
                onTap: _openDetail,
                onFav: () => setState(() => p.favorite = !p.favorite),
              );
            },
          ),
        ],
      ),
    );
  }
}
