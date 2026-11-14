import 'package:flutter/material.dart';

import '../data/kampanya.dart';
import '../navigation/main_nav.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/kampanya_widgets.dart';
import '../widgets/tabbar.dart';
import 'campaign_detail_screen.dart';
import 'campaign_qr_screen.dart';
import 'detail_screen.dart';

/// Kampanyalar — aktif kampanyası olan işletmeler (`GET /kampanyalar`,
/// KAMPANYALAR.md §1). Konum izni varsa en yakın önce, yoksa en yüksek
/// indirim önce. Sekme yok (tüm kampanyalar tek listede). Kaydırınca sonraki
/// sayfa yüklenir.
class CampaignsScreen extends StatefulWidget {
  const CampaignsScreen({super.key});

  @override
  State<CampaignsScreen> createState() => _CampaignsScreenState();
}

class _CampaignsScreenState extends State<CampaignsScreen> {
  final ScrollController _scroll = ScrollController();
  int _seq = 0;

  bool _loading = true;
  bool _loadingMore = false;
  bool _error = false;
  List<KampanyaliMekan> _items = [];
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
    final seq = ++_seq;
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final r = await KampanyaRepository.instance.liste();
      if (!mounted || seq != _seq) return;
      setState(() {
        _items = r.items;
        _hasMore = r.hasMore;
        _nextPage = r.nextPage;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || seq != _seq) return;
      setState(() {
        _error = true;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _loading || !_hasMore || _nextPage == null) return;
    final seq = _seq;
    setState(() => _loadingMore = true);
    try {
      final r = await KampanyaRepository.instance.liste(page: _nextPage!);
      if (!mounted || seq != _seq) return;
      final seen = {for (final i in _items) i.mekan.id};
      setState(() {
        _items.addAll(r.items.where((i) => seen.add(i.mekan.id)));
        _hasMore = r.hasMore && r.items.isNotEmpty;
        _nextPage = _hasMore ? r.nextPage : null;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _openKampanya(Kampanya k, KampanyaMekan m) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            CampaignDetailScreen(kampanyaId: k.id, onizleme: k, mekan: m),
      ),
    );
  }

  void _openMekan(KampanyaMekan m) {
    Navigator.push(
      context,
      detailRoute(builder: (_) => DetailScreen(place: m.toPlace())),
    );
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
                activeIndex: 0,
                onTap: MainNav.instance.select,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    Widget centered(Widget child) {
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

    if (_loading) {
      return centered(
        const SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: AppColors.primary,
          ),
        ),
      );
    }
    if (_error) {
      return centered(
        _info(
          icon: Icons.wifi_off_rounded,
          title: 'Kampanyalar yüklenemedi',
          subtitle: 'İnternet bağlantını kontrol edip tekrar dene.',
          action: 'Tekrar dene',
          onAction: _load,
        ),
      );
    }
    if (_items.isEmpty) {
      return centered(
        _info(
          icon: Icons.local_offer_outlined,
          title: 'Şu an aktif kampanya yok',
          subtitle: 'İşletmeler kampanya başlattığında burada göreceksin.',
        ),
      );
    }
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: ListView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 130),
        itemCount: 1 + _items.length + (_loadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: _hero(),
            );
          }
          final i = index - 1;
          if (i < _items.length) {
            final it = _items[i];
            return Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
              child: KampanyaMekanKarti(
                item: it,
                onKampanya: (k) => _openKampanya(k, it.mekan),
                onMekan: () => _openMekan(it.mekan),
              ),
            );
          }
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.primary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _hero() {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
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
                  onTap: () => Navigator.pop(context),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Kampanyalar',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                // İşletmedeyken doğrudan okut (KAMPANYA_QR.md).
                Semantics(
                  button: true,
                  label: 'Kampanya QR okut',
                  child: GestureDetector(
                    onTap: () => openKampanyaQr(context),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.qr_code_scanner_rounded,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'QR okut',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'İndirimi işletmede, kasadaki QR’ı okutarak kullan',
              style: TextStyle(fontSize: 13, color: Colors.white70),
            ),
          ],
        ),
      ),
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
              color: AppColors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 34, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13.5, color: AppColors.muted),
          ),
          if (action != null) ...[
            const SizedBox(height: 18),
            GestureDetector(
              onTap: onAction,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  action,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
