import 'package:flutter/material.dart';
import '../data/api.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/kedy_chat.dart';
import '../widgets/search_modal.dart';
import '../widgets/tabbar.dart';
import 'detail_screen.dart';

/// Etkinlikler — ayrı (itilerek açılan) sayfa. `GET /etkinlikler?upcoming=1`
/// (yaklaşan etkinlikler). Sonuç boşsa ekranın ortasında bilgi gösterir.
/// Kaydırınca sonraki sayfayı yükler.
class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  final ScrollController _scroll = ScrollController();

  bool _loading = true;
  bool _loadingMore = false;
  bool _error = false;
  List<Event> _events = [];
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
      final r = await HomeRepository.instance
          .etkinlikler(upcoming: true, limit: 20);
      if (!mounted) return;
      setState(() {
        _events = List<Event>.from(r.items);
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
      final r = await HomeRepository.instance
          .etkinlikler(upcoming: true, page: _nextPage!, limit: 20);
      if (!mounted) return;
      setState(() {
        _events.addAll(r.items);
        _hasMore = r.hasMore;
        _nextPage = r.nextPage;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  // Aramadan bir mekan seçilince detayını açar (etkinlik listesi için değil).
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
      case 4:
        Navigator.popUntil(context, (r) => r.isFirst);
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
              child: FloatingTabBar(activeIndex: 3, onTap: _onTab),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    // Yükleniyor / hata / boş durumlarında hero altında kalan alanı doldurup
    // mesajı ekranın ortasında gösterir.
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
        title: 'Etkinlikler yüklenemedi',
        subtitle: 'İnternet bağlantını kontrol edip tekrar dene.',
        action: 'Tekrar dene',
        onAction: _load,
      ));
    }
    if (_events.isEmpty) {
      return _centered(_info(
        icon: Icons.event_busy_outlined,
        title: 'Şu an bekleyen bir etkinlik yok',
        subtitle: 'Yaklaşan etkinlikler eklendiğinde burada göreceksin.',
      ));
    }

    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.only(bottom: 130),
      children: [
        _hero(),
        const SizedBox(height: 20),
        ..._events.map((e) => Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 14),
              child: _eventRow(e),
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
  }

  /// Hero'yu üstte tutar, kalan alanı ortalayarak [child]'ı yerleştirir.
  /// Alttaki yüzen tab bar'ın kapladığı yükseklik kadar alt boşluk bırakılır
  /// ki mesaj hero ile tab bar arasında gerçekten ortalansın.
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
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w800)),
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
                const Text('Etkinlikler',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
              ],
            ),
            const SizedBox(height: 14),
            const Text('Yakınındaki etkinlikleri keşfet',
                style: TextStyle(fontSize: 13, color: Colors.white70)),
          ],
        ),
      ),
    );
  }

  Widget _eventRow(Event e) {
    final dm = [e.day, e.month].where((s) => s.isNotEmpty).join(' ');
    final subtitle = [dm, e.place].where((s) => s.isNotEmpty).join(' · ');
    // Etkinlikler mekan değildir; kartın mekan detayına yönlendirmesi kaldırıldı.
    return Container(
        height: 110,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: AppShadows.listTile,
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            SizedBox(width: 110, height: 110, child: NetImage(e.image)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (e.tag.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(999)),
                        child: Text(e.tag,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary)),
                      ),
                      const SizedBox(height: 6),
                    ],
                    Text(e.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w800)),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined,
                              size: 13, color: AppColors.primary),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(subtitle,
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
          ],
        ),
      );
  }
}
