import 'package:flutter/material.dart';
import '../data/api.dart';
import '../data/models.dart';
import '../navigation/main_nav.dart';
import '../theme/app_theme.dart';
import '../widgets/app_icons.dart';
import '../widgets/common.dart';
import '../widgets/tabbar.dart';
import 'event_detail_screen.dart';

/// Etkinlikler — ayrı (itilerek açılan) sayfa. `GET /etkinlikler?upcoming=true`
/// (yaklaşan etkinlikler). En üstte ERP "Reklam → Öne Çıkan Etkinlikler"
/// (`/reklam/etkinlikler`) büyük kartlarla, kategori listesindeki sabit
/// mekan kartıyla aynı düzende; aynı etkinlik aşağıda tekrar edilmez.
/// Sonuç boşsa ekranın ortasında bilgi gösterir. Kaydırınca sonraki sayfayı
/// yükler. Karta dokununca etkinlik detayı açılır.
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
  // Öne çıkan (reklam) etkinlikler; hata/boş → gösterilmez.
  List<FeaturedEvent> _featured = const [];

  /// Öne çıkanlarda olan etkinlik normal listede tekrar edilmez.
  List<Event> get _visibleEvents {
    final ids = {for (final f in _featured) f.id};
    return ids.isEmpty
        ? _events
        : _events.where((e) => !ids.contains(e.id)).toList();
  }

  void _open(Etkinlik e) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EventDetailScreen(etkinlik: e)),
    );
  }

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
    // Öne çıkanlar paralel; liste hatası onları etkilemez (tersi de).
    final featuredF = HomeRepository.instance.reklamEtkinlikler();
    try {
      final r = await HomeRepository.instance
          .etkinlikler(upcoming: true, limit: 20);
      final featured = await featuredF;
      if (!mounted) return;
      setState(() {
        _featured = featured ?? const [];
        _events = List<Event>.from(r.items);
        _hasMore = r.hasMore;
        _nextPage = r.nextPage;
        _loading = false;
      });
    } catch (_) {
      final featured = await featuredF;
      if (!mounted) return;
      setState(() {
        _featured = featured ?? const [];
        // Öne çıkan varsa liste hatasında da onlar gösterilir.
        _error = _featured.isEmpty;
        _events = [];
        _hasMore = false;
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
              child: FloatingTabBar(
                  activeIndex: 3, onTap: MainNav.instance.select),
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
    final events = _visibleEvents;
    if (events.isEmpty && _featured.isEmpty) {
      return _centered(_info(
        icon: Icons.event_busy_outlined,
        title: 'Şu an bekleyen bir etkinlik yok',
        subtitle: 'Yaklaşan etkinlikler eklendiğinde burada göreceksin.',
      ));
    }

    // Lazy: hero (0) + etkinlik satırları + (varsa) yükleniyor göstergesi.
    // Öğeler ve görselleri yalnızca ekrana geldikçe oluşturulur.
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.only(bottom: 130),
      itemCount: 1 + events.length + (_loadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: _hero(),
              ),
              for (final f in _featured)
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 14),
                  child: _featuredCard(f),
                ),
            ],
          );
        }
        final i = index - 1;
        if (i < events.length) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 14),
            child: _eventRow(events[i]),
          );
        }
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                  strokeWidth: 2.5, color: AppColors.primary),
            ),
          ),
        );
      },
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
                  fontSize: 16, fontWeight: FontWeight.w600)),
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
                        fontWeight: FontWeight.w600,
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
                        fontWeight: FontWeight.w600,
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
    // Etkinlik detayına gider (mekan detayına değil). Eskiden kartın hiç
    // dokunma işlevi yoktu.
    return GestureDetector(
      onTap: () => _open(e.toEtkinlik()),
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
            // Hazır kare küçük görsel varsa o (ETKINLIK_EKSIKLER.md §2).
            SizedBox(
              width: 110,
              height: 110,
              child: NetImage(
                e.thumbSquare.isNotEmpty ? e.thumbSquare : e.image,
              ),
            ),
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
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary)),
                      ),
                      const SizedBox(height: 6),
                    ],
                    Text(e.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
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
      ),
    );
  }

  static const _aylar = [
    'OCA', 'ŞUB', 'MAR', 'NİS', 'MAY', 'HAZ', //
    'TEM', 'AĞU', 'EYL', 'EKİ', 'KAS', 'ARA',
  ];

  /// Öne çıkan etkinlik — kategori listesindeki sabit (sponsorlu) mekan
  /// kartıyla aynı düzen: geniş görsel + "Sponsorlu" etiketi + tarih rozeti;
  /// altta ad, tarih · saat · fiyat, çizginin altında mekan + "İncele".
  Widget _featuredCard(FeaturedEvent f) {
    final e = f.toEtkinlik();
    final d = DateTime.tryParse(f.date);
    return GestureDetector(
      onTap: () => _open(e),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppShadows.listTile,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 176,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  (f.thumbWide.isNotEmpty || f.image.isNotEmpty)
                      ? NetImage(
                          f.thumbWide.isNotEmpty ? f.thumbWide : f.image,
                        )
                      : const ColoredBox(
                          color: AppColors.primarySoft,
                          child: Center(
                            child: Icon(
                              Icons.celebration_outlined,
                              size: 44,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'Sponsorlu',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  if (d != null)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${d.day}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                                height: 1,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _aylar[d.month - 1],
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                                height: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 13, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    f.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    [
                      e.tarihSaat,
                      e.fiyatLabel,
                    ].where((s) => s.isNotEmpty).join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1, thickness: 1, color: AppColors.line),
                  const SizedBox(height: 11),
                  Row(
                    children: [
                      if (f.mekanAd.isNotEmpty) ...[
                        const AppSvgIcon(
                          AppIcons.pin,
                          size: 12,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                        child: Text(
                          f.mekanAd,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'İncele',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: AppColors.primary,
                      ),
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
}
