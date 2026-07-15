import 'package:flutter/material.dart';
import '../data/api.dart';
import '../data/favorites_service.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/fav_heart.dart';
import '../widgets/kedy_chat.dart';
import '../widgets/search_modal.dart';
import '../widgets/tabbar.dart';
import 'detail_screen.dart';
import 'events_screen.dart';

/// Favorilerim — Hesabım'dan itilerek açılan ayrı sayfa. Yapı, Etkinlikler
/// listesiyle aynıdır (hero + kart listesi + boş/hata/yükleniyor + "daha fazla
/// yükle"). Favori mekanlar `GET /uye/favoriler` ile gelir (FAVORILER.md).
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final ScrollController _scroll = ScrollController();

  bool _loading = true;
  bool _loadingMore = false;
  bool _error = false;
  List<Place> _favorites = [];
  bool _hasMore = false;
  int? _nextPage;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) {
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

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final r = await FavRepository.instance.favoriler(page: 1, limit: 20);
      if (!mounted) return;
      setState(() {
        _favorites = List<Place>.from(r.items);
        _hasMore = r.hasMore;
        _nextPage = r.nextPage;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = true;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _loading || !_hasMore || _nextPage == null) return;
    setState(() => _loadingMore = true);
    try {
      final r =
          await FavRepository.instance.favoriler(page: _nextPage!, limit: 20);
      if (!mounted) return;
      setState(() {
        _favorites.addAll(r.items);
        _hasMore = r.hasMore;
        _nextPage = r.nextPage;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _openDetail(Place p) {
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => DetailScreen(place: p)));
  }

  void _onTab(int i) {
    switch (i) {
      case 0:
        Navigator.popUntil(context, (r) => r.isFirst);
        break;
      case 1:
        showSearchModal(context, onOpenDetail: _openDetail);
        break;
      case 2:
        showKedyChat(context);
        break;
      case 3:
        Navigator.push(
            context, MaterialPageRoute(builder: (_) => const EventsScreen()));
        break;
      case 4:
        Navigator.pop(context); // Hesabım'a geri dön
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          _body(),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: FloatingTabBar(activeIndex: 4, onTap: _onTab),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return _centered(const SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(
            strokeWidth: 2.5, color: AppColors.primary),
      ));
    }
    if (_error) {
      return _centered(_info(
        icon: Icons.wifi_off_rounded,
        title: 'Favoriler yüklenemedi',
        subtitle: 'İnternet bağlantını kontrol edip tekrar dene.',
        action: 'Tekrar dene',
        onAction: _load,
      ));
    }

    // Favori kümesi değişince (kalpten çıkarınca) liste anında güncellensin.
    return ValueListenableBuilder<Set<int>>(
      valueListenable: FavoritesService.instance.ids,
      builder: (context, ids, _) {
        final visible =
            _favorites.where((p) => ids.contains(p.id)).toList();
        if (visible.isEmpty) {
          return _centered(_info(
            icon: Icons.favorite_border,
            title: 'Henüz favorin yok',
            subtitle:
                'Beğendiğin mekanları kalbe dokunarak favorilerine ekleyebilirsin.',
          ));
        }
        return ListView(
          controller: _scroll,
          padding: const EdgeInsets.only(bottom: 130),
          children: [
            _hero(),
            const SizedBox(height: 20),
            ...visible.map((p) => Padding(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 14),
                  child: _favoriteRow(p),
                )),
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
    );
  }

  Widget _centered(Widget child) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Column(
      children: [
        _hero(),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: 85 + bottomInset),
            child: Center(child: child),
          ),
        ),
      ],
    );
  }

  Widget _info({
    required IconData icon,
    required String title,
    required String subtitle,
    String? action,
    VoidCallback? onAction,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
                color: AppColors.primarySoft, shape: BoxShape.circle),
            child: Icon(icon, size: 34, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          Text(title,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13.5, color: AppColors.muted)),
          if (action != null) ...[
            const SizedBox(height: 18),
            GestureDetector(
              onTap: onAction,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
                decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12)),
                child: Text(action,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _hero() {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 26),
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
              children: [
                GlassButton(
                    icon: Icons.chevron_left,
                    onTap: () => Navigator.pop(context)),
                const SizedBox(width: 12),
                const Text('Favorilerim',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
              ],
            ),
            const SizedBox(height: 14),
            const Text('Kaydettiğin mekanlar',
                style: TextStyle(fontSize: 13, color: Colors.white70)),
          ],
        ),
      ),
    );
  }

  Widget _favoriteRow(Place p) {
    final location = p.distance.isNotEmpty ? p.distance : p.subtitle;
    return GestureDetector(
      onTap: () => _openDetail(p),
      child: Container(
        height: 110,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: AppShadows.listTile,
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            SizedBox(width: 110, height: 110, child: NetImage(p.image)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w800)),
                    if (location.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined,
                              size: 13, color: AppColors.primary),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(location,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 12, color: AppColors.muted)),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: FavHeart(postId: p.id, circle: false, size: 22),
            ),
          ],
        ),
      ),
    );
  }
}
