import 'package:flutter/material.dart';

import '../data/api.dart';
import '../data/auth_service.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'follow_screen.dart';
import 'login_screen.dart';
import 'routes_screen.dart';

/// Bir üyenin herkese açık profilini açar (`GET /uye/profil/{id}`,
/// PROFIL_VE_ROTA_URUN.md §2): avatar, ad, sayaçlar, takip et + rotaları.
Future<void> openMemberProfile(
  BuildContext context, {
  required int uyeId,
  String isim = '',
  String soyisim = '',
  String avatar = '',
  bool? takipEdiyorum,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => MemberProfileScreen(
        uyeId: uyeId,
        isim: isim,
        soyisim: soyisim,
        avatar: avatar,
        takipEdiyorum: takipEdiyorum,
      ),
    ),
  );
}

class MemberProfileScreen extends StatefulWidget {
  final int uyeId;
  final String isim;
  final String soyisim;
  final String avatar;
  final bool? takipEdiyorum;
  const MemberProfileScreen({
    super.key,
    required this.uyeId,
    this.isim = '',
    this.soyisim = '',
    this.avatar = '',
    this.takipEdiyorum,
  });

  @override
  State<MemberProfileScreen> createState() => _MemberProfileScreenState();
}

class _MemberProfileScreenState extends State<MemberProfileScreen> {
  final ScrollController _scroll = ScrollController();
  UyeProfil? _profil;
  final List<GeziRota> _rotalar = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  int _nextPage = 2;

  /// Yükleme öncesi/başarısızlıkta gösterilecek ad (kart açılışında hazır).
  String get _adSoyad {
    final p = _profil;
    if (p != null) return p.adSoyad;
    final n = [widget.isim, widget.soyisim]
        .where((s) => s.trim().isNotEmpty)
        .join(' ')
        .trim();
    return n.isEmpty ? 'Üye' : n;
  }

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final r = await RotaRepository.instance.profil(widget.uyeId, page: 1);
    if (!mounted) return;
    setState(() {
      _profil = r?.profil;
      _rotalar
        ..clear()
        ..addAll(r?.rotalar ?? const []);
      _hasMore = r?.hasMore ?? false;
      _nextPage = r?.nextPage ?? 2;
      _loading = false;
    });
  }

  void _onScroll() {
    if (!_hasMore || _loadingMore) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 400) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    final r = await RotaRepository.instance.profil(widget.uyeId, page: _nextPage);
    if (!mounted) return;
    setState(() {
      _rotalar.addAll(r?.rotalar ?? const []);
      _hasMore = r?.hasMore ?? false;
      _nextPage = r?.nextPage ?? (_nextPage + 1);
      _loadingMore = false;
    });
  }

  Future<void> _toggleFollow() async {
    final p = _profil;
    if (p == null) return;
    if (!AuthService.instance.isLoggedIn) {
      final ok = await openLogin(context);
      if (ok != true || !mounted || !AuthService.instance.isLoggedIn) return;
    }
    final want = !(p.takipEdiyorum ?? false);
    setState(() => _profil = p.copyWith(
        takipEdiyorum: want,
        takipciSayisi: (p.takipciSayisi + (want ? 1 : -1)).clamp(0, 1 << 30)));
    try {
      final res = want
          ? await TakipRepository.instance.takipEt(widget.uyeId)
          : await TakipRepository.instance.takipBirak(widget.uyeId);
      if (!mounted) return;
      setState(() => _profil = _profil!.copyWith(
          takipEdiyorum: res.takipEdiyorum,
          takipciSayisi: res.takipciSayisi));
    } catch (e) {
      if (!mounted) return;
      setState(() => _profil = p);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e is AuthException ? e.message : 'İşlem yapılamadı.')));
    }
  }

  bool get _self => _profil?.benim ?? false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          PageHeader(title: _adSoyad),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                      itemCount: 2 +
                          (_rotalar.isEmpty
                              ? 1
                              : _rotalar.length + (_hasMore ? 1 : 0)),
                      itemBuilder: (_, i) {
                        if (i == 0) return _profileCard();
                        if (i == 1) {
                          return const Padding(
                            padding: EdgeInsets.fromLTRB(2, 18, 2, 10),
                            child: Text('Paylaşılan Rotalar',
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600)),
                          );
                        }
                        if (_rotalar.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 30),
                            child: Center(
                              child: Text('Henüz herkese açık rota yok.',
                                  style: TextStyle(color: AppColors.muted)),
                            ),
                          );
                        }
                        final idx = i - 2;
                        if (idx >= _rotalar.length) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(
                              child: SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2.4)),
                            ),
                          );
                        }
                        return _routeRow(_rotalar[idx]);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _profileCard() {
    final p = _profil;
    final avatar = p?.avatar.isNotEmpty == true ? p!.avatar : widget.avatar;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppShadows.listTile,
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(40),
            child: SizedBox(
              width: 76,
              height: 76,
              child: avatar.isNotEmpty
                  ? NetImage(avatar)
                  : Container(
                      color: AppColors.primarySoft,
                      child: const Icon(Icons.person,
                          size: 38, color: AppColors.primary),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Text(_adSoyad,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          Row(
            children: [
              _stat(p?.rotaSayisi ?? 0, 'Rota', null),
              _divider(),
              _stat(p?.takipciSayisi ?? 0, 'Takipçi',
                  () => openFollows(context, uyeId: widget.uyeId, initialTab: 0)),
              _divider(),
              _stat(p?.takipEdilenSayisi ?? 0, 'Takip',
                  () => openFollows(context, uyeId: widget.uyeId, initialTab: 1)),
              _divider(),
              _stat(p?.toplamBegeni ?? 0, 'Beğeni', null),
            ],
          ),
          if (p != null && !_self) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: (p.takipEdiyorum ?? false)
                  ? OutlinedButton.icon(
                      onPressed: _toggleFollow,
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Takipte',
                          maxLines: 1,
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    )
                  : ElevatedButton.icon(
                      onPressed: _toggleFollow,
                      icon: const Icon(Icons.person_add_alt, size: 18),
                      label: const Text('Takip Et',
                          maxLines: 1,
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _stat(int value, String label, VoidCallback? onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          children: [
            Text('$value',
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
          ],
        ),
      ),
    );
  }

  Widget _divider() =>
      Container(width: 1, height: 30, color: AppColors.line);

  Widget _routeRow(GeziRota r) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => RouteDetailScreen(rotaId: r.id)),
        ),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppShadows.listTile,
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: r.kapakGorsel.isNotEmpty
                      ? NetImage(r.kapakGorsel)
                      : Container(
                          color: AppColors.primarySoft,
                          child: const Center(child: ShipWheelIcon(size: 26)),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.baslik.isEmpty ? 'Adsız rota' : r.baslik,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14.5, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Text('${r.durakSayisi} durak',
                            style: const TextStyle(
                                fontSize: 12.5, color: AppColors.muted)),
                        const Text('  ·  ',
                            style: TextStyle(color: AppColors.muted)),
                        Icon(
                            r.begendim
                                ? Icons.favorite
                                : Icons.favorite_border,
                            size: 14,
                            color: r.begendim
                                ? AppColors.heart
                                : AppColors.muted),
                        const SizedBox(width: 3),
                        Text('${r.begeniSayisi}',
                            style: const TextStyle(
                                fontSize: 12.5, color: AppColors.muted)),
                        if (r.fiyatLabel.isNotEmpty) ...[
                          const Text('  ·  ',
                              style: TextStyle(color: AppColors.muted)),
                          Text(r.fiyatLabel,
                              style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary)),
                        ],
                        if (!r.herkeseAcik) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.lock_outline,
                              size: 13, color: AppColors.muted),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right,
                  size: 20, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}
