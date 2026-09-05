import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/api.dart';
import '../data/auth_service.dart';
import '../data/location_service.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/app_icons.dart';
import '../widgets/common.dart';
import '../widgets/onayli_modal.dart';
import 'detail_screen.dart';
import 'login_screen.dart';
import 'member_profile_screen.dart';
import 'plus_screen.dart';
import 'route_map_screen.dart';

/// "Gezi Rotalarım" ekranını açar (UYELIK_PLUS.md §6).
Future<void> openRoutes(BuildContext context) {
  return Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const RoutesScreen()),
  );
}

/// Herkese açık rotaların keşfet akışını açar (`GET /rotalar`,
/// UYELIK_PLUS.md §6.1).
Future<void> openDiscoverRoutes(BuildContext context) {
  return Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const DiscoverRoutesScreen()),
  );
}

/// Ortak Plus/giriş hata yönlendirmesi: giriş gerekiyorsa login, aksi halde
/// paywall açar. Kullanıcı Plus olduysa true döner (çağıran yenilesin).
Future<bool> _handlePlus(BuildContext context, PlusRequiredException e) async {
  if (e.girisGerekli) {
    final ok = await openLogin(context);
    return ok == true && AuthService.instance.isLoggedIn;
  }
  final ok = await openPlus(context);
  return ok == true && (AuthService.instance.user.value?.isPlus ?? false);
}

/// Üyenin gezi rotaları listesi. Okuma serbest; oluşturma Plus ister.
class RoutesScreen extends StatefulWidget {
  const RoutesScreen({super.key});

  @override
  State<RoutesScreen> createState() => _RoutesScreenState();
}

class _RoutesScreenState extends State<RoutesScreen> {
  List<GeziRota> _rotalar = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await RotaRepository.instance.rotalar();
    if (!mounted) return;
    setState(() {
      _rotalar = list;
      _loading = false;
    });
  }

  Future<void> _create() async {
    final data = await _showRouteForm(context);
    if (data == null || !mounted) return;
    try {
      final rota = await RotaRepository.instance.olustur(
        baslik: data.baslik,
        aciklama: data.aciklama,
        gorunurluk: data.gorunurluk,
        yorumlarAcik: data.yorumlarAcik,
      );
      // Kapak ilk adımda seçildiyse oluşturmanın hemen ardından yükle.
      if (data.kapak != null) {
        await RotaRepository.instance.kapakYukle(rota.id,
            'data:image/jpeg;base64,${base64Encode(data.kapak!)}');
      }
      await _load();
    } on PlusRequiredException catch (e) {
      if (!mounted) return;
      final ok = await _handlePlus(context, e);
      if (ok && mounted) _create();
    } on RotaException catch (e) {
      _snack(e.message);
    }
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          const PageHeader(title: 'Gezi Rotalarım'),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : (_rotalar.isEmpty ? _empty() : _list()),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Yeni Rota'),
      ),
    );
  }

  Widget _empty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                  color: AppColors.primarySoft, shape: BoxShape.circle),
              child: const Icon(Icons.route, size: 34, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            const Text('Henüz rotan yok',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            const Text(
              'Favori duraklarını sırala, her yere notunu ekle. Yeni bir '
              'rota oluşturarak başla.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _list() {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        itemCount: _rotalar.length,
        itemBuilder: (_, i) => _card(_rotalar[i]),
      ),
    );
  }

  Widget _card(GeziRota r) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => RouteDetailScreen(rotaId: r.id)),
          );
          _load();
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppShadows.listTile,
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Icons.route, color: AppColors.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.baslik.isEmpty ? 'Adsız rota' : r.baslik,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text('${r.durakSayisi} durak',
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
                        if (r.herkeseAcik) ...[
                          const Text('  ·  ',
                              style: TextStyle(color: AppColors.muted)),
                          const Icon(Icons.public,
                              size: 13, color: AppColors.muted),
                          const SizedBox(width: 3),
                          const Text('Herkese açık',
                              style: TextStyle(
                                  fontSize: 12.5, color: AppColors.muted)),
                        ],
                      ],
                    ),
                    // İstatistik (kendi rotam): görüntülenme + gösterim.
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.visibility_outlined,
                            size: 13, color: AppColors.muted),
                        const SizedBox(width: 4),
                        Text('${r.goruntulenme}',
                            style: const TextStyle(
                                fontSize: 12.5, color: AppColors.muted)),
                        const SizedBox(width: 12),
                        const Icon(Icons.bar_chart,
                            size: 13, color: AppColors.muted),
                        const SizedBox(width: 4),
                        Text('${r.gosterim}',
                            style: const TextStyle(
                                fontSize: 12.5, color: AppColors.muted)),
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

/// Rota detayı: sıralı duraklar, düzenleme/silme, durak ekle/çıkar/sırala.
class RouteDetailScreen extends StatefulWidget {
  final int rotaId;
  const RouteDetailScreen({super.key, required this.rotaId});

  @override
  State<RouteDetailScreen> createState() => _RouteDetailScreenState();
}

class _RouteDetailScreenState extends State<RouteDetailScreen> {
  GeziRota? _rota;
  bool _loading = true;
  // Kapak yüklenirken gösterilen yerel önizleme (blob). Yükleme bitince temizlenir.
  Uint8List? _pendingCover;
  // Kaydırıldıkça üst bar başlığı "Rota Detayı" → rota başlığına döner.
  final ScrollController _scroll = ScrollController();
  bool _titleInBar = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load();
  }

  void _onScroll() {
    // Kapak görseli varsa başlık, kapak kayıp gizlenince gelsin (daha geç eşik).
    final hasCover =
        (_rota?.kapakGorsel.isNotEmpty ?? false) || _pendingCover != null;
    final threshold = hasCover ? 200.0 : 56.0;
    final show = _scroll.hasClients && _scroll.offset > threshold;
    if (show != _titleInBar) setState(() => _titleInBar = show);
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final r = await RotaRepository.instance.detay(widget.rotaId);
    if (!mounted) return;
    setState(() {
      _rota = r;
      _loading = false;
    });
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  /// Plus/giriş hatasında yönlendir; düzeldiyse [after] tekrar denenir.
  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
      await _load();
    } on PlusRequiredException catch (e) {
      if (!mounted) return;
      final ok = await _handlePlus(context, e);
      if (ok && mounted) _load();
    } on RotaException catch (e) {
      _snack(e.message);
    }
  }

  Future<void> _editRoute() async {
    final r = _rota;
    if (r == null) return;
    final data = await _showRouteForm(context, initial: r);
    if (data == null) return;
    await _guard(() async {
      await RotaRepository.instance.guncelle(
        r.id,
        baslik: data.baslik,
        aciklama: data.aciklama,
        gorunurluk: data.gorunurluk,
        yorumlarAcik: data.yorumlarAcik,
      );
      // Yeni kapak seçildiyse güncellemeyle birlikte yükle.
      if (data.kapak != null) {
        await RotaRepository.instance.kapakYukle(
            r.id, 'data:image/jpeg;base64,${base64Encode(data.kapak!)}');
      }
    });
  }

  Future<void> _deleteRoute() async {
    final ok = await _confirm('Rotayı sil',
        'Bu rotayı ve tüm duraklarını silmek istediğine emin misin?');
    if (ok != true) return;
    try {
      await RotaRepository.instance.sil(widget.rotaId);
      if (mounted) Navigator.pop(context);
    } on PlusRequiredException catch (e) {
      if (!mounted) return;
      await _handlePlus(context, e);
    } on RotaException catch (e) {
      _snack(e.message);
    }
  }

  Future<void> _addStop() async {
    // Çoklu mekan/ürün ekleme kompozitörü (rota-coklu-mekan-ekleme.md).
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => _AddStopsScreen(rotaId: widget.rotaId)),
    );
    if (added == true && mounted) _load();
  }

  /// Kapak görseli seç/kaldır (`/uye/rotalar/{id}/kapak`, Plus gerekli).
  Future<void> _changeCover() async {
    final hasCover = _rota?.kapakGorsel.isNotEmpty ?? false;
    final action = await _pickImageSource(context, allowRemove: hasCover);
    if (action == null || !mounted) return;
    if (action == 'remove') {
      await _guard(() => RotaRepository.instance.kapakSil(widget.rotaId));
      return;
    }
    final bytes = await _cropCover(
        action == 'camera' ? ImageSource.camera : ImageSource.gallery);
    if (!mounted) return;
    if (bytes == null) {
      _showPickError(context);
      return;
    }
    final b64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
    // Yükleme sırasında kırpılan görseli anında (blob) göster.
    setState(() => _pendingCover = bytes);
    await _guard(() => RotaRepository.instance.kapakYukle(widget.rotaId, b64));
    if (mounted) setState(() => _pendingCover = null);
  }

  Future<void> _editStop(RotaDurak d) async {
    final res = await _showStopSheet(
      context,
      postId: d.mekan?.id ?? 0,
      title: d.mekan?.name ?? 'Durak',
      initialYorum: d.yorum,
      initialUrunler: d.urunler,
    );
    if (res == null || !mounted) return;
    // qr_ids: durağın tüm ürün kümesini seçilenlerle değiştir (boş → temizle).
    await _guard(() => RotaRepository.instance.durakGuncelle(
          widget.rotaId,
          durakId: d.durakId,
          yorum: res.yorum,
          qrIds: res.urunler.map((u) => u.qrId).toList(),
        ));
  }

  Future<void> _deleteStop(RotaDurak d) async {
    final ok = await _confirm(
        'Durağı çıkar', '${d.mekan?.name ?? 'Bu durak'} rotadan çıkarılsın mı?');
    if (ok != true) return;
    await _guard(
        () => RotaRepository.instance.durakSil(widget.rotaId, durakId: d.durakId));
  }

  /// [newIndex] `onReorderItem` tarafından zaten düzeltilmiş gelir (silinen
  /// öğe konumuna göre); ek düzeltme gerekmez.
  Future<void> _reorder(int oldIndex, int newIndex) async {
    final r = _rota;
    if (r == null) return;
    final list = List<RotaDurak>.from(r.duraklar);
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    // İyimser güncelleme (anında yeniden çiz), sonra sunucuya sırayı yolla.
    setState(() => _rota = GeziRota(
          id: r.id,
          baslik: r.baslik,
          aciklama: r.aciklama,
          gorunurluk: r.gorunurluk,
          durakSayisi: r.durakSayisi,
          duraklar: list,
        ));
    try {
      await RotaRepository.instance
          .sirala(r.id, sira: list.map((d) => d.durakId).toList());
    } on PlusRequiredException catch (e) {
      if (!mounted) return;
      final ok = await _handlePlus(context, e);
      if (ok && mounted) return;
      await _load(); // geri al
    } on RotaException catch (e) {
      _snack(e.message);
      await _load();
    }
  }

  /// Rota beğenisini iyimser günceller; hatada geri alır (SOSYAL §1).
  Future<void> _toggleLike() async {
    final r = _rota;
    if (r == null) return;
    if (!AuthService.instance.isLoggedIn) {
      final ok = await openLogin(context);
      if (ok != true || !mounted || !AuthService.instance.isLoggedIn) return;
    }
    final want = !r.begendim;
    setState(() => _rota = r.copyWithBegeni(
          begendim: want,
          begeniSayisi: (r.begeniSayisi + (want ? 1 : -1)).clamp(0, 1 << 30),
        ));
    try {
      final res = want
          ? await RotaRepository.instance.begen(r.id)
          : await RotaRepository.instance.begeniKaldir(r.id);
      if (!mounted) return;
      setState(() => _rota = _rota!
          .copyWithBegeni(begendim: res.begendim, begeniSayisi: res.begeniSayisi));
    } catch (e) {
      if (!mounted) return;
      setState(() => _rota = r); // geri al
      _snack(e is AuthException || e is RotaException
          ? e.toString()
          : 'Beğeni güncellenemedi.');
    }
  }

  /// Rota sahibini takip et/bırak — iyimser güncelleme (SOSYAL §2).
  Future<void> _toggleFollow() async {
    final r = _rota;
    final s = r?.sahip;
    if (r == null || s == null) return;
    if (!AuthService.instance.isLoggedIn) {
      final ok = await openLogin(context);
      if (ok != true || !mounted || !AuthService.instance.isLoggedIn) return;
    }
    final want = !(s.takipEdiyorum ?? false);
    setState(() => _rota = _withFollow(r, want));
    try {
      if (want) {
        await TakipRepository.instance.takipEt(s.uyeId);
      } else {
        await TakipRepository.instance.takipBirak(s.uyeId);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _rota = r); // geri al
      _snack(e is AuthException ? e.toString() : 'Takip güncellenemedi.');
    }
  }

  /// [r]'nin sahip.takip_ediyorum alanını değiştirip yeni rota nesnesi üretir.
  GeziRota _withFollow(GeziRota r, bool follow) {
    final s = r.sahip!;
    return GeziRota(
      id: r.id,
      baslik: r.baslik,
      aciklama: r.aciklama,
      gorunurluk: r.gorunurluk,
      durakSayisi: r.durakSayisi,
      kapakGorsel: r.kapakGorsel,
      benim: r.benim,
      begeniSayisi: r.begeniSayisi,
      begendim: r.begendim,
      goruntulenme: r.goruntulenme,
      gosterim: r.gosterim,
      rotaFiyat: r.rotaFiyat,
      mesafeM: r.mesafeM,
      haritaLink: r.haritaLink,
      koordinatlar: r.koordinatlar,
      polyline: r.polyline,
      toplamMesafeM: r.toplamMesafeM,
      toplamSureSn: r.toplamSureSn,
      duraklar: r.duraklar,
      sahip: RotaSahip(
        uyeId: s.uyeId,
        isim: s.isim,
        soyisim: s.soyisim,
        avatar: s.avatar,
        takipEdiyorum: follow,
      ),
    );
  }

  /// Sağ üst ayar ikonu → alttan menü: Haritada Aç / Google Haritalar /
  /// Paylaş + (sahibe) Kapak Görseli / Düzenle / Sil. Her item altında çizgi.
  Future<void> _openMenu(GeziRota r) async {
    final owner = r.benim;
    final inApp = r.haritadaGosterilebilir;
    final harita = r.haritaLink;

    // (key, svg?, icon, başlık, tehlikeli-mi) — svg varsa SVG, yoksa Material.
    final items = <(String, String?, IconData, String, bool)>[
      if (inApp) ('map_in', AppIcons.mapPins, Icons.map_outlined, 'Haritada Aç', false),
      if (harita.isNotEmpty)
        ('map_ext', AppIcons.mapFolded, Icons.directions_outlined,
            'Google Haritalar\u2019da Aç', false),
      ('share', AppIcons.shareUp, Icons.ios_share, 'Paylaş', false),
      if (owner)
        ('cover', null, Icons.image_outlined, 'Kapak Görseli', false),
      if (owner) ('edit', null, Icons.edit_outlined, 'Rotayı Düzenle', false),
      if (owner) ('delete', null, Icons.delete_outline, 'Rotayı Sil', true),
    ];

    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 6),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.line,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            for (final it in items) ...[
              ListTile(
                leading: it.$2 != null
                    ? AppSvgIcon(it.$2!,
                        size: 20,
                        color: it.$5 ? AppColors.closing : AppColors.primary)
                    : Icon(it.$3,
                        color:
                            it.$5 ? AppColors.closing : AppColors.primary),
                title: Text(it.$4,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: it.$5 ? AppColors.closing : AppColors.ink)),
                onTap: () => Navigator.pop(ctx, it.$1),
              ),
              // Her item altında çizgi.
              const Divider(
                  height: 1, thickness: 1, color: AppColors.line),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    switch (action) {
      case 'map_in':
        await openRouteMap(context, r);
        break;
      case 'map_ext':
        await _openMaps(harita);
        break;
      case 'share':
        await _shareRoute(r);
        break;
      case 'cover':
        await _changeCover();
        break;
      case 'edit':
        await _editRoute();
        break;
      case 'delete':
        await _deleteRoute();
        break;
    }
  }

  Future<void> _openMaps(String url) async {
    if (url.isEmpty) return;
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) _snack('Harita açılamadı.');
    }
  }

  Future<void> _shareRoute(GeziRota r) async {
    final baslik = r.baslik.isEmpty ? 'Gezi rotası' : r.baslik;
    final text = r.haritaLink.isNotEmpty
        ? 'Gezgah\u2019ta "$baslik" rotasına göz at:\n${r.haritaLink}'
        : 'Gezgah\u2019ta "$baslik" rotasına göz at.';
    // iPad'de paylaşım popover'ının konumlanması için origin gerekir.
    final box = context.findRenderObject() as RenderBox?;
    await Share.share(
      text,
      subject: baslik,
      sharePositionOrigin:
          box != null ? box.localToGlobal(Offset.zero) & box.size : null,
    );
  }

  Future<bool?> _confirm(String title, String body) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil',
                style: TextStyle(
                    color: AppColors.closing, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = _rota;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          PageHeader(
            // Kapak kaydırılıp gizlenince üst bara rota başlığı gelir.
            title: (_titleInBar && r != null && r.baslik.isNotEmpty)
                ? r.baslik
                : 'Rota Detayı',
            // Tek ayar ikonu (geri butonu gibi arka planlı); menü bottom
            // sheet'te açılır.
            actions: [
              if (r != null)
                GlassButton(
                  icon: Icons.settings_outlined,
                  svg: AppIcons.gear,
                  flat: true,
                  onTap: () => _openMenu(r),
                ),
            ],
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : r == null
                    ? const Center(
                        child: Text('Rota bulunamadı.',
                            style: TextStyle(color: AppColors.muted)),
                      )
                    : _body(r),
          ),
        ],
      ),
      // Durak ekleme yalnız rota sahibine (UYELIK_PLUS.md §6 — Plus yazma).
      floatingActionButton: (!_loading && r != null && r.benim)
          ? FloatingActionButton.extended(
              onPressed: _addStop,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text('Durak Ekle'),
            )
          : null,
    );
  }

  Widget _body(GeziRota r) {
    final duraklar = r.duraklar;
    return CustomScrollView(
      controller: _scroll,
      slivers: [
        SliverToBoxAdapter(child: _header(r)),
        if (duraklar.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: EdgeInsets.all(40),
              child: Center(
                child: Text(
                  'Bu rotada henüz durak yok.\nAltdaki butonla mekan ekle.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted, fontSize: 14),
                ),
              ),
            ),
          )
        else if (r.benim)
          SliverReorderableList(
            itemCount: duraklar.length,
            itemBuilder: (_, i) => _stopTile(duraklar[i], i,
                key: ValueKey(duraklar[i].durakId), owner: true),
            onReorderItem: _reorder,
          )
        else
          SliverList.builder(
            itemCount: duraklar.length,
            itemBuilder: (_, i) => _stopTile(duraklar[i], i,
                key: ValueKey(duraklar[i].durakId), owner: false),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _header(GeziRota r) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppShadows.listTile,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Kapak görseli (16:10). Yükleme sırasında yerel önizleme (blob),
          // sonrasında sunucudaki görsel gösterilir.
          if (_pendingCover != null)
            AspectRatio(
              aspectRatio: 16 / 10,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.memory(_pendingCover!, fit: BoxFit.cover),
                  Container(
                    color: Colors.black.withValues(alpha: 0.25),
                    child: const Center(
                      child: SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.6, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (r.kapakGorsel.isNotEmpty)
            AspectRatio(
              aspectRatio: 16 / 10,
              child: NetImage(r.kapakGorsel),
            ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
          // Başkasının rotasıysa sahip — başlığın ÜSTÜNDE, sola yaslı,
          // profiline tıklanabilir sade satır.
          if (!r.benim && r.sahip != null) ...[
            GestureDetector(
              onTap: () => openMemberProfile(
                context,
                uyeId: r.sahip!.uyeId,
                isim: r.sahip!.isim,
                soyisim: r.sahip!.soyisim,
                avatar: r.sahip!.avatar,
                takipEdiyorum: r.sahip!.takipEdiyorum,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ownerAvatar(r.sahip!.avatar, 22),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      r.sahip!.adSoyad.isEmpty ? 'Üye' : r.sahip!.adSoyad,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          // Başlık + takip butonu (başkasının rotası) / Gizli rozeti.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(r.baslik.isEmpty ? 'Adsız rota' : r.baslik,
                    style: const TextStyle(
                        fontSize: 19, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 10),
              if (!r.benim && r.sahip != null)
                _followButtonCompact(r.sahip!)
              else if (!r.herkeseAcik)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_outline,
                          size: 13, color: AppColors.primary),
                      SizedBox(width: 4),
                      Text('Gizli',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary)),
                    ],
                  ),
                ),
            ],
          ),
          if (r.aciklama.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(r.aciklama,
                style: const TextStyle(
                    fontSize: 13.5, height: 1.5, color: AppColors.muted)),
          ],
          const SizedBox(height: 12),
          // İstatistikler — sola yaslı; tutar (fiyat) en sonda.
          Wrap(
            spacing: 16,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _stat(null, '${r.duraklar.length} durak', svg: AppIcons.pin),
              // Görüntülenme herkese; gösterim (listeleme) yalnız sahibe.
              _stat(null, '${r.goruntulenme} görüntülenme',
                  svg: AppIcons.eye),
              if (r.benim)
                _stat(Icons.bar_chart_outlined, '${r.gosterim} gösterim'),
              // Tutar en sonda.
              if (r.fiyatLabel.isNotEmpty)
                _stat(null, r.fiyatLabel, primary: true, svg: AppIcons.tag),
            ],
          ),
          const SizedBox(height: 22),
          _actions(r),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// İkon + etiket taşıyan sade istatistik öğesi. [svg] verilirse SVG,
  /// yoksa [icon] Material ikonu kullanılır.
  Widget _stat(IconData? icon, String label,
      {bool primary = false, String? svg}) {
    final color = primary ? AppColors.primary : AppColors.muted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (svg != null)
          AppSvgIcon(svg, size: 14, color: color)
        else
          Icon(icon, size: 15, color: color),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: primary ? FontWeight.w700 : FontWeight.w500,
                color: primary ? AppColors.primary : AppColors.ink)),
      ],
    );
  }

  /// Instagram kartı tarzı aksiyon barı: beğeni · yorum · paylaşım (soldan),
  /// harita (sağda). Yalnız ikon + rakam (etiket yok). rota-paylasim-gorseli.md.
  Widget _actions(GeziRota r) {
    return Row(
      children: [
        _igAction(
          // Beğenince dolu kırmızı kalp; değilse outline SVG.
          icon: r.begendim
              ? const Icon(Icons.favorite, size: 20, color: AppColors.heart)
              : _igSvg(AppIcons.heart),
          count: r.begeniSayisi,
          onTap: _toggleLike,
        ),
        const SizedBox(width: 22),
        _igAction(
          icon: _igSvg(AppIcons.comment),
          count: r.yorumSayisi,
          onTap: () => _openComments(r),
        ),
        const SizedBox(width: 22),
        _igAction(
          icon: _igSvg(AppIcons.share),
          onTap: () => _openShareSheet(r),
        ),
        const Spacer(),
        // Haritada aç (uygulama içi harita) — koordinat varsa.
        if (r.haritadaGosterilebilir)
          _igAction(
            icon: _igSvg(AppIcons.mapPins),
            onTap: () => openRouteMap(context, r),
          ),
      ],
    );
  }

  Widget _igSvg(String svg, {Color color = AppColors.ink, double size = 20}) =>
      AppSvgIcon(svg, size: size, color: color);

  Widget _igAction({
    required Widget icon,
    int? count,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          if (count != null && count > 0) ...[
            const SizedBox(width: 6),
            Text('$count',
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink)),
          ],
        ],
      ),
    );
  }



  /// Paylaşım seçenekleri (alttan sheet): Instagram'da Paylaş / Harita Olarak
  /// Paylaş. Tasarım rota ayar menüsüyle tutarlı.
  Future<void> _openShareSheet(GeziRota r) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 6),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.line,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined,
                  color: AppColors.primary),
              title: const Text('Instagram\u2019da Paylaş',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w500)),
              onTap: () => Navigator.pop(ctx, 'ig'),
            ),
            const Divider(height: 1, thickness: 1, color: AppColors.line),
            ListTile(
              leading: const Icon(Icons.map_outlined, color: AppColors.primary),
              title: const Text('Harita Olarak Paylaş',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w500)),
              onTap: () => Navigator.pop(ctx, 'map'),
            ),
            const Divider(height: 1, thickness: 1, color: AppColors.line),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    if (action == 'ig') {
      await _shareToInstagram(r);
    } else if (action == 'map') {
      await _shareRoute(r);
    }
  }

  /// Rota için paylaşım görsel(ler)ini üretir, indirir ve native paylaşım
  /// sayfasıyla (Instagram vb.) paylaşır.
  Future<void> _shareToInstagram(GeziRota r) async {
    // Hazırlanıyor göstergesi.
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );
    try {
      final urls =
          await RotaRepository.instance.paylasimGorseli(r.id, format: 'story');
      if (urls.isEmpty) {
        if (mounted) Navigator.pop(context); // spinner
        _snack('Paylaşım görseli oluşturulamadı.');
        return;
      }
      final dio = Dio();
      final files = <XFile>[];
      final dir = Directory.systemTemp;
      for (var i = 0; i < urls.length; i++) {
        try {
          final path = '${dir.path}/gezgah_rota_${r.id}_$i.jpg';
          await dio.download(urls[i], path);
          files.add(XFile(path));
        } catch (_) {}
      }
      if (!mounted) return;
      Navigator.pop(context); // spinner
      if (files.isEmpty) {
        _snack('Görseller indirilemedi.');
        return;
      }
      final box = context.findRenderObject() as RenderBox?;
      await Share.shareXFiles(
        files,
        text: 'Gezgah\u2019taki gezi rotama gözat! @gezgah.app',
        sharePositionOrigin:
            box != null ? box.localToGlobal(Offset.zero) & box.size : null,
      );
    } catch (_) {
      if (mounted) Navigator.pop(context); // spinner
      _snack('Paylaşım sırasında bir hata oluştu.');
    }
  }

  /// Başlık satırı için kompakt takip pili (ismin en sağında).
  Widget _followButtonCompact(RotaSahip s) {
    final following = s.takipEdiyorum ?? false;
    return GestureDetector(
      onTap: _toggleFollow,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: following ? Colors.white : AppColors.primary,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.primary),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            following
                ? const Icon(Icons.check, size: 15, color: AppColors.primary)
                : const AppSvgIcon(AppIcons.userPlus,
                    size: 15, color: Colors.white),
            const SizedBox(width: 5),
            Text(following ? 'Takipte' : 'Takip Et',
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: following ? AppColors.primary : Colors.white)),
          ],
        ),
      ),
    );
  }

  /// Yorum sheet'ini açar; yorum eklenince/silinince başlıktaki sayıyı tazeler.
  Future<void> _openComments(GeziRota r) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _YorumSheet(
        rota: r,
        onCount: (c) {
          if (mounted && _rota != null) {
            setState(() => _rota = _rota!.copyWithYorumSayisi(c));
          }
        },
      ),
    );
  }

  /// Durağa bağlı QR menü ürünü rozeti (küçük görsel + ad + fiyat). Kullanıcının
  /// yüklediği yemek fotoğrafı (`foto`) varsa küçük görsel onu gösterir, yoksa
  /// menü görseli. Dokununca: sahip → foto yönetimi, diğerleri → foto varsa
  /// tam ekran (rota-yemek-gorsel.md).
  Widget _urunRozet(RotaDurak d, RotaUrun u, bool owner) {
    final thumb = u.foto.isNotEmpty ? u.foto : u.gorsel;
    final hasFoto = u.foto.isNotEmpty;
    return GestureDetector(
      onTap: () {
        if (owner) {
          _openUrunFoto(d, u);
        } else if (hasFoto) {
          _openFotoViewer([DurakGorsel(id: 0, url: u.foto)], 0);
        }
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 4, 10, 4),
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: thumb.isNotEmpty
                        ? NetImage(thumb)
                        : Container(
                            color: Colors.white,
                            child: const Icon(Icons.restaurant_menu,
                                size: 13, color: AppColors.primary),
                          ),
                  ),
                ),
                // Sahibe: foto ekleme/varlığı ipucu.
                if (owner)
                  Positioned(
                    right: -1,
                    bottom: -1,
                    child: Container(
                      padding: const EdgeInsets.all(1.5),
                      decoration: const BoxDecoration(
                          color: AppColors.primary, shape: BoxShape.circle),
                      child: Icon(
                          hasFoto ? Icons.edit : Icons.add_a_photo,
                          size: 8,
                          color: Colors.white),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                u.fiyatLabel.isEmpty ? u.ad : '${u.ad} · ${u.fiyatLabel}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Sahip için yemek (ürün) fotoğrafı yönetimi (yükle/değiştir/kaldır).
  Future<void> _openUrunFoto(RotaDurak d, RotaUrun u) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _UrunFotoSheet(rotaId: widget.rotaId, durak: d, urun: u),
    );
    if (changed == true && mounted) _load();
  }

  /// Küçük yuvarlak sahip avatarı (yoksa baş harf yerine kişi ikonu).
  Widget _ownerAvatar(String url, double size) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size),
      child: SizedBox(
        width: size,
        height: size,
        child: url.isNotEmpty
            ? NetImage(url)
            : Container(
                color: AppColors.primarySoft,
                alignment: Alignment.center,
                child: AppSvgIcon(AppIcons.user,
                    size: size * 0.5, color: AppColors.primary),
              ),
      ),
    );
  }

  Widget _stopTile(RotaDurak d, int index,
      {required Key key, required bool owner}) {
    final m = d.mekan;
    return Container(
      key: key,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.listTile,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        // Durağa dokununca detay sheet'i açılır (fotoğraflar, not, ürünler).
        onTap: d.silinmis ? null : () => _openStopSheet(d, index),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
              // Sıra numarası rozeti.
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                    color: AppColors.primary, shape: BoxShape.circle),
                child: Text('${index + 1}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 12),
              _stopThumb(d, m),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d.silinmis
                          ? 'Silinmiş mekan'
                          : (m?.name.isNotEmpty == true
                              ? m!.name
                              : (d.isKonum ? 'Konum' : 'Mekan')),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: d.silinmis ? AppColors.muted : AppColors.ink),
                    ),
                    // Konum durağının adresi (varsa).
                    if (d.isKonum && (m?.adres.isNotEmpty ?? false)) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.place_outlined,
                              size: 13, color: AppColors.muted),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(m!.adres,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 12, color: AppColors.muted)),
                          ),
                        ],
                      ),
                    ],
                    if (d.yorum.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(d.yorum,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12.5,
                              height: 1.4,
                              color: AppColors.muted)),
                    ],
                    // Durağa bağlı QR menü ürünleri (çoklu, rota-coklu-yemek.md).
                    if (d.urunler.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final u in d.urunler) _urunRozet(d, u, owner),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              // Durağı haritada aç (koordinatı varsa) — herkeste görünür.
              if (d.haritaLink.isNotEmpty)
                IconButton(
                  tooltip: 'Haritada aç',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _openMaps(d.haritaLink),
                  icon: const Icon(Icons.place_outlined,
                      color: AppColors.primary),
                ),
              if (owner) ...[
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.more_vert, color: AppColors.muted),
                  onPressed: () => _openStopMenu(d),
                ),
                ReorderableDragStartListener(
                  index: index,
                  child: const Padding(
                    padding: EdgeInsets.only(left: 2),
                    child: Icon(Icons.drag_handle,
                        color: AppColors.muted, size: 22),
                  ),
                ),
              ],
                ],
              ),
              // Durak fotoğrafları — yalnız görüntüleme (ekleme üç nokta
              // menüsündeki foto yönetiminde). rota-durak-gorsel.md.
              // Konum duraklarında fotoğraf kare alanda gösterilir → çip yok.
              if (d.gorseller.isNotEmpty && !d.isKonum) ...[
                const SizedBox(height: 10),
                _fotoStrip(d),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Durak kartındaki kare görsel.
  ///
  /// Konum duraklarının kayıtlı mekan fotosu yoktur; kullanıcının yüklediği
  /// durak fotoğrafı varsa pin ikonu yerine **o fotoğraf** gösterilir (birden
  /// fazlaysa köşede adet rozeti). Dokununca görüntüleyici açılır.
  Widget _stopThumb(RotaDurak d, RotaMekan? m) {
    final fotos = d.gorseller;
    final konumFoto = d.isKonum && fotos.isNotEmpty;

    Widget inner;
    if (d.silinmis) {
      inner = Container(
        color: AppColors.primarySoft,
        child: const Icon(Icons.image_not_supported_outlined,
            color: AppColors.muted),
      );
    } else if (konumFoto) {
      inner = NetImage(fotos.first.url);
    } else if (d.isKonum && (m?.image.isEmpty ?? true)) {
      // Fotoğrafı olmayan konum durağı → konum pini.
      inner = Container(
        color: AppColors.primarySoft,
        alignment: Alignment.center,
        child: const AppSvgIcon(AppIcons.pin,
            size: 22, color: AppColors.primary),
      );
    } else {
      inner = NetImage(m?.image ?? '');
    }

    final thumb = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 52,
        height: 52,
        child: konumFoto && fotos.length > 1
            ? Stack(
                fit: StackFit.expand,
                children: [
                  inner,
                  Positioned(
                    right: 3,
                    bottom: 3,
                    child: Container(
                      width: 18,
                      height: 18,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        shape: BoxShape.circle,
                      ),
                      child: Text('${fotos.length}',
                          style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                    ),
                  ),
                ],
              )
            : inner,
      ),
    );

    if (!konumFoto) return thumb;
    return GestureDetector(
      onTap: () => _openFotoViewer(fotos, 0),
      child: thumb,
    );
  }

  /// Durak fotoğrafları — yemek rozeti gibi sade çip: gri zemin, görsel ikonu +
  /// "N resim" (lacivert). Dokununca tüm fotoğrafları gösteren görüntüleyici açılır.
  ///
  /// Konum duraklarında fotoğraf zaten kare alanda gösterildiği için çip
  /// tekrarlanmaz.
  Widget _fotoStrip(RotaDurak d) {
    final fotos = d.gorseller;
    if (fotos.isEmpty || d.isKonum) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        onTap: () => _openFotoViewer(fotos, 0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.image_outlined,
                  size: 15, color: AppColors.primary),
              const SizedBox(width: 6),
              Text('${fotos.length} resim',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary)),
            ],
          ),
        ),
      ),
    );
  }

  void _openFotoViewer(List<DurakGorsel> fotos, int index) {
    showDialog<void>(
      context: context,
      builder: (_) => _FotoViewer(fotos: fotos, index: index),
    );
  }

  /// Durak detayı — alttan açılan panel: fotoğraflar, konum/adres, not ve
  /// seçili ürünler. Mekan durağında "Mekan Detayı" ile işletme sayfasına,
  /// harita bağlantısı varsa yol tarifine gidilebilir.
  void _openStopSheet(RotaDurak d, int index) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _StopDetailSheet(
        durak: d,
        index: index,
        onOpenFotos: (i) => _openFotoViewer(d.gorseller, i),
      ),
    );
  }

  Future<void> _openFotoManager(RotaDurak d) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DurakFotoSheet(rotaId: widget.rotaId, durak: d),
    );
    if (changed == true && mounted) _load();
  }

  /// Durak aksiyon menüsü (sahibe) — tasarıma uygun alttan sheet: Fotoğraf ekle
  /// (en üstte) / Notu düzenle / Durağı çıkar. Her item altında çizgi.
  Future<void> _openStopMenu(RotaDurak d) async {
    // (key, icon, başlık, tehlikeli-mi)
    final items = <(String, IconData, String, bool)>[
      if (!d.silinmis)
        ('foto', Icons.add_a_photo_outlined, 'Fotoğraf ekle', false),
      if (!d.silinmis) ('edit', Icons.edit_outlined, 'Notu düzenle', false),
      ('delete', Icons.delete_outline, 'Durağı çıkar', true),
    ];
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 6),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.line,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            for (final it in items) ...[
              ListTile(
                leading: Icon(it.$2,
                    color: it.$4 ? AppColors.closing : AppColors.primary),
                title: Text(it.$3,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: it.$4 ? AppColors.closing : AppColors.ink)),
                onTap: () => Navigator.pop(ctx, it.$1),
              ),
              const Divider(height: 1, thickness: 1, color: AppColors.line),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    switch (action) {
      case 'foto':
        await _openFotoManager(d);
        break;
      case 'edit':
        _editStop(d);
        break;
      case 'delete':
        _deleteStop(d);
        break;
    }
  }
}

// ===========================================================================
// Ortak formlar / seçiciler
// ===========================================================================

/// Görsel seçer ve kırpıcıya vermeden önce boyutunu makul sınıra çeker.
///
/// Kamerayla çekilen ham fotoğraf 10-12 MP olabiliyor; bu boyutta
/// [ImageCropper] bellek yüzünden başarısız olup `null` dönebiliyor ve önizleme
/// boş kalıyordu (galeriden seçilenler genelde daha küçük olduğu için sorun
/// çıkmıyordu). `maxWidth/maxHeight` verildiğinde image_picker görüntüyü
/// yeniden kodlar; bu ayrıca EXIF yön bilgisini de düzleştirir.
Future<XFile?> _pickImage(ImageSource source) {
  return ImagePicker().pickImage(
    source: source,
    maxWidth: 2400,
    maxHeight: 2400,
    imageQuality: 92,
    requestFullMetadata: false, // konum/EXIF meta izni gerekmesin
  );
}

/// Görsel seçme/kırpma sırasında oluşan son hata (teşhis için). Bu akıştaki
/// hatalar eskiden sessizce yutuluyordu; artık kullanıcıya gösterilir ki
/// "fotoğraf eklenmiyor" durumunun nedeni belli olsun.
String? _lastPickError;

/// Son hatayı (varsa) kullanıcıya gösterir ve temizler.
void _showPickError(BuildContext context) {
  final err = _lastPickError;
  _lastPickError = null;
  if (err == null || !context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text('Fotoğraf alınamadı: $err'),
    duration: const Duration(seconds: 6),
  ));
}

/// Görsel seçip verilen orana göre kırpar; JPEG bytes döner.
///
/// - Kullanıcı görsel seçmezse ya da kırpmayı iptal ederse `null`.
/// - Kırpıcı bir hata verirse (ör. kameradan gelen dosyayı işleyemezse) görsel
///   **kırpılmadan** kullanılır; akış sessizce durup önizleme boş kalmaz.
Future<Uint8List?> _pickAndCrop(
  ImageSource source, {
  required double ratioX,
  required double ratioY,
  required String title,
  required int maxWidth,
  required int maxHeight,
}) async {
  XFile? file;
  try {
    file = await _pickImage(source);
  } catch (e) {
    // Kamera/galeri açılamadı ya da sonuç alınamadı (izin, bellek, platform).
    _lastPickError = e.toString();
    return null;
  }
  if (file == null) return null; // seçim yapılmadı
  try {
    final cropped = await ImageCropper().cropImage(
      sourcePath: file.path,
      aspectRatio: CropAspectRatio(ratioX: ratioX, ratioY: ratioY),
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 88,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: title,
          toolbarColor: AppColors.primary,
          toolbarWidgetColor: Colors.white,
          backgroundColor: Colors.black,
          activeControlsWidgetColor: AppColors.primary,
          lockAspectRatio: true,
          hideBottomControls: true, // alttaki taşan kontrol çubuğunu gizle
        ),
        IOSUiSettings(
          title: title,
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
          aspectRatioPickerButtonHidden: true,
          rotateButtonsHidden: false, // gerekirse elle döndürme
        ),
      ],
    );
    if (cropped == null) return null; // kullanıcı kırpmayı iptal etti
    return cropped.readAsBytes();
  } catch (e) {
    // Kırpıcı çalışmadı → ham (küçültülmüş) görselle devam et; hatayı not al.
    _lastPickError = 'kırpma: $e';
    try {
      return await file.readAsBytes();
    } catch (e2) {
      _lastPickError = 'okuma: $e2';
      return null;
    }
  }
}

/// Kapak görseli: **16:10** kırpma.
Future<Uint8List?> _cropCover(ImageSource source) => _pickAndCrop(
      source,
      ratioX: 16,
      ratioY: 10,
      title: 'Kapağı Kırp',
      maxWidth: 1200,
      maxHeight: 750,
    );

/// Durak/ürün fotoğrafı: **1:1 kare** kırpma (rota-yemek-gorsel.md).
Future<Uint8List?> _cropSquare(ImageSource source) => _pickAndCrop(
      source,
      ratioX: 1,
      ratioY: 1,
      title: 'Fotoğrafı Kırp',
      maxWidth: 1080,
      maxHeight: 1080,
    );

/// Görsel kaynağı seçici (galeri/kamera[/kaldır]) — `'gallery'|'camera'|'remove'`.
Future<String?> _pickImageSource(BuildContext context,
    {bool allowRemove = false}) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_library_outlined,
                color: AppColors.primary),
            title: const Text('Galeriden seç'),
            onTap: () => Navigator.pop(ctx, 'gallery'),
          ),
          ListTile(
            leading:
                const Icon(Icons.camera_alt_outlined, color: AppColors.primary),
            title: const Text('Fotoğraf çek'),
            onTap: () => Navigator.pop(ctx, 'camera'),
          ),
          if (allowRemove)
            ListTile(
              leading:
                  const Icon(Icons.delete_outline, color: AppColors.closing),
              title: const Text('Kapağı kaldır',
                  style: TextStyle(color: AppColors.closing)),
              onTap: () => Navigator.pop(ctx, 'remove'),
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

/// Rota oluştur/düzenle formu (kapak görseli **ilk adımda**). Kaydedilirse
/// `(baslik, aciklama, gorunurluk, yorumlarAcik, kapak-bytes?)` döner; iptalde null.
Future<
        ({
          String baslik,
          String aciklama,
          String gorunurluk,
          bool yorumlarAcik,
          Uint8List? kapak
        })?>
    _showRouteForm(BuildContext context, {GeziRota? initial}) {
  final baslikC = TextEditingController(text: initial?.baslik ?? '');
  final aciklamaC = TextEditingController(text: initial?.aciklama ?? '');
  var herkeseAcik = initial?.herkeseAcik ?? false;
  var yorumlarAcik = initial?.yorumlarAcik ?? true;
  final initialKapak = initial?.kapakGorsel ?? '';
  Uint8List? kapak;

  return showModalBottomSheet<
      ({
        String baslik,
        String aciklama,
        String gorunurluk,
        bool yorumlarAcik,
        Uint8List? kapak
      })>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) {
        Future<void> pickCover() async {
          final src = await _pickImageSource(ctx);
          if (src == null || src == 'remove') return;
          final b = await _cropCover(
              src == 'camera' ? ImageSource.camera : ImageSource.gallery);
          if (!ctx.mounted) return;
          if (b == null) {
            _showPickError(ctx);
            return;
          }
          setSheet(() => kapak = b);
        }

        return Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: AppColors.line,
                          borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(initial == null ? 'Yeni Rota' : 'Rotayı Düzenle',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),
                  // Kapak görseli — ilk adımda seçilir/kırpılır.
                  const Text('Kapak görseli (opsiyonel)',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: pickCover,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: AspectRatio(
                        aspectRatio: 16 / 10,
                        child: kapak != null
                            ? Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.memory(kapak!, fit: BoxFit.cover),
                                  _coverEditHint(),
                                ],
                              )
                            : initialKapak.isNotEmpty
                                ? Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      NetImage(initialKapak),
                                      _coverEditHint(),
                                    ],
                                  )
                                : Container(
                                    color: AppColors.primarySoft,
                                    child: const Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.add_photo_alternate_outlined,
                                              size: 30,
                                              color: AppColors.primary),
                                          SizedBox(height: 6),
                                          Text('Kapak Ekle',
                                              style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.primary)),
                                        ],
                                      ),
                                    ),
                                  ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _field(baslikC, 'Rota başlığı', 'Örn. Kadıköy Turu'),
                  const SizedBox(height: 14),
                  _field(aciklamaC, 'Açıklama (opsiyonel)',
                      'Kısa bir açıklama',
                      maxLines: 3),
                  const SizedBox(height: 14),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Herkese açık',
                        style: TextStyle(
                            fontSize: 14.5, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Diğer üyeler bu rotayı görebilir',
                        style:
                            TextStyle(fontSize: 12.5, color: AppColors.muted)),
                    value: herkeseAcik,
                    activeThumbColor: Colors.white,
                    activeTrackColor: AppColors.primary,
                    onChanged: (v) => setSheet(() => herkeseAcik = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Yoruma izin ver',
                        style: TextStyle(
                            fontSize: 14.5, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Diğer üyeler bu rotaya yorum yapabilir',
                        style:
                            TextStyle(fontSize: 12.5, color: AppColors.muted)),
                    value: yorumlarAcik,
                    activeThumbColor: Colors.white,
                    activeTrackColor: AppColors.primary,
                    onChanged: (v) => setSheet(() => yorumlarAcik = v),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        if (baslikC.text.trim().isEmpty) return;
                        Navigator.pop(ctx, (
                          baslik: baslikC.text.trim(),
                          aciklama: aciklamaC.text.trim(),
                          gorunurluk: herkeseAcik ? 'herkese_acik' : 'gizli',
                          yorumlarAcik: yorumlarAcik,
                          kapak: kapak,
                        ));
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(initial == null ? 'Oluştur' : 'Kaydet',
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

/// Kapak önizlemesi üstünde "değiştir" ipucu.
Widget _coverEditHint() {
  return Container(
    alignment: Alignment.bottomRight,
    padding: const EdgeInsets.all(8),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.edit, size: 13, color: Colors.white),
          SizedBox(width: 4),
          Text('Değiştir',
              style: TextStyle(fontSize: 11.5, color: Colors.white)),
        ],
      ),
    ),
  );
}

Widget _field(TextEditingController c, String label, String hint,
    {int maxLines = 1}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      TextField(
        controller: c,
        maxLines: maxLines,
        decoration: InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: AppColors.primarySoft,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    ],
  );
}

/// Durak düzenleme sheet'i: not + (opsiyonel) çoklu QR menü ürünü seçimi.
/// Kaydedilirse `(yorum, urunler)` döner; iptalde null (rota-coklu-yemek.md).
Future<({String yorum, List<RotaUrun> urunler})?> _showStopSheet(
  BuildContext context, {
  required int postId,
  required String title,
  String initialYorum = '',
  List<RotaUrun> initialUrunler = const [],
}) {
  return showModalBottomSheet<({String yorum, List<RotaUrun> urunler})>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _StopSheet(
      postId: postId,
      title: title,
      initialYorum: initialYorum,
      initialUrunler: initialUrunler,
    ),
  );
}

class _StopSheet extends StatefulWidget {
  final int postId;
  final String title;
  final String initialYorum;
  final List<RotaUrun> initialUrunler;
  const _StopSheet({
    required this.postId,
    required this.title,
    this.initialYorum = '',
    this.initialUrunler = const [],
  });

  @override
  State<_StopSheet> createState() => _StopSheetState();
}

class _StopSheetState extends State<_StopSheet> {
  late final TextEditingController _yorumC =
      TextEditingController(text: widget.initialYorum);
  late List<RotaUrun> _urunler = List.of(widget.initialUrunler);

  @override
  void dispose() {
    _yorumC.dispose();
    super.dispose();
  }

  Future<void> _pickProducts() async {
    final res = await _showMenuPicker(
      context,
      widget.postId,
      initial: _urunler.map((u) => u.qrId).toSet(),
    );
    if (res != null && mounted) setState(() => _urunler = res);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.line,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text(widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            _field(_yorumC, 'Not (opsiyonel)', 'Bu durak için notun',
                maxLines: 3),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Menü ürünleri (opsiyonel)',
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const Spacer(),
                if (_urunler.isNotEmpty)
                  Text('${_urunler.length} ürün',
                      style: const TextStyle(
                          fontSize: 12.5, color: AppColors.muted)),
              ],
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < _urunler.length; i++) ...[
              _selectedProduct(_urunler[i],
                  () => setState(() => _urunler.removeAt(i))),
              const SizedBox(height: 8),
            ],
            OutlinedButton.icon(
              onPressed: widget.postId > 0 ? _pickProducts : null,
              icon: Icon(_urunler.isEmpty ? Icons.restaurant_menu : Icons.edit,
                  size: 18),
              label: Text(_urunler.isEmpty
                  ? 'Menüden ürün seç'
                  : 'Ürünleri düzenle'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.line),
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context,
                    (yorum: _yorumC.text.trim(), urunler: _urunler)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Kaydet',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _selectedProduct(RotaUrun u, VoidCallback onRemove) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 44,
              height: 44,
              child: u.gorsel.isNotEmpty
                  ? NetImage(u.gorsel)
                  : Container(
                      color: Colors.white,
                      child: const Icon(Icons.restaurant_menu,
                          color: AppColors.primary)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(u.ad,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                if (u.fiyatLabel.isNotEmpty)
                  Text(u.fiyatLabel,
                      style: const TextStyle(
                          fontSize: 12.5, color: AppColors.muted)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Kaldır',
            onPressed: onRemove,
            icon: const Icon(Icons.close, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

/// Mekanın QR menüsünden **çoklu** ürün seçici (`/uye/rotalar/mekan-menu`).
/// [initial] önceden seçili qr_id'ler. "Uygula" ile seçilen ürün listesini
/// döner (boş olabilir → temizle); iptalde null.
Future<List<RotaUrun>?> _showMenuPicker(BuildContext context, int postId,
    {Set<int> initial = const {}}) {
  return showModalBottomSheet<List<RotaUrun>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _MenuPickerSheet(postId: postId, initial: initial),
  );
}

class _MenuPickerSheet extends StatefulWidget {
  final int postId;
  final Set<int> initial;
  const _MenuPickerSheet({required this.postId, this.initial = const {}});

  @override
  State<_MenuPickerSheet> createState() => _MenuPickerSheetState();
}

class _MenuPickerSheetState extends State<_MenuPickerSheet> {
  List<MekanMenuKategori> _menu = const [];
  bool _loading = true;
  late final Set<int> _selected = {...widget.initial};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final m = await RotaRepository.instance.mekanMenu(widget.postId);
    if (!mounted) return;
    setState(() {
      _menu = m;
      _loading = false;
    });
  }

  void _apply() {
    // Menü sırasına göre seçili ürünleri topla.
    final result = <RotaUrun>[
      for (final k in _menu)
        for (final u in k.urunler)
          if (_selected.contains(u.qrId)) u,
    ];
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Text('Menüden Ürün Seç',
                    style:
                        TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: AppColors.ink),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _menu.isEmpty
                    ? const Center(
                        child: Text('Bu mekanın menüsü yok.',
                            style: TextStyle(color: AppColors.muted)),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        children: [
                          for (final k in _menu) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
                              child: Text(k.kategori,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.ink)),
                            ),
                            for (final u in k.urunler) _urunTile(u),
                          ],
                        ],
                      ),
          ),
          if (!_loading && _menu.isNotEmpty)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _apply,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                        _selected.isEmpty
                            ? 'Uygula'
                            : 'Uygula (${_selected.length})',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _urunTile(RotaUrun u) {
    final sel = _selected.contains(u.qrId);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() {
          if (sel) {
            _selected.remove(u.qrId);
          } else {
            _selected.add(u.qrId);
          }
        }),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: sel ? AppColors.primary : Colors.transparent,
                width: 1.5),
            boxShadow: AppShadows.listTile,
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: u.gorsel.isNotEmpty
                      ? NetImage(u.gorsel)
                      : Container(
                          color: AppColors.primarySoft,
                          child: const Icon(Icons.restaurant_menu,
                              color: AppColors.primary)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(u.ad,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
              ),
              if (u.fiyatLabel.isNotEmpty) ...[
                Text(u.fiyatLabel,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.muted)),
                const SizedBox(width: 10),
              ],
              Icon(
                sel ? Icons.check_circle : Icons.circle_outlined,
                color: sel ? AppColors.primary : AppColors.line,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mekan seçici sonucu: Gezgah mekanı ([place]) **veya** Google yeri ([konum],
/// konum durağı olarak eklenir — rota-place-arama.md).
class _PickResult {
  final Place? place;
  final PlaceDetay? konum;
  const _PickResult.mekan(Place p)
      : place = p,
        konum = null;
  const _PickResult.konum(PlaceDetay k)
      : konum = k,
        place = null;
}

/// Mekan arama seçici (durak eklemek için). Seçilen sonucu döner.
Future<_PickResult?> _showPlacePicker(BuildContext context) {
  return showModalBottomSheet<_PickResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _PlacePickerSheet(),
  );
}

class _PlacePickerSheet extends StatefulWidget {
  const _PlacePickerSheet();

  @override
  State<_PlacePickerSheet> createState() => _PlacePickerSheetState();
}

class _PlacePickerSheetState extends State<_PlacePickerSheet> {
  final TextEditingController _c = TextEditingController();
  List<SearchResult> _results = const [];
  List<PlaceTahmin> _gResults = const []; // Google Places tahminleri
  bool _loading = false;
  bool _gLoading = false;
  int _seq = 0;
  String? _resolving; // detayı çözülen Google place_id
  // Google faturalamasını ucuzlatan arama oturumu token'ı (autocomplete+detay).
  final String _session = 's${DateTime.now().microsecondsSinceEpoch}';

  Future<void> _search(String q) async {
    final term = q.trim();
    final mySeq = ++_seq;
    if (term.length < 2) {
      setState(() {
        _results = const [];
        _gResults = const [];
        _loading = false;
        _gLoading = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _gLoading = true;
    });
    // Gezgah mekan araması.
    HomeRepository.instance.aramaMekan(term, limit: 20).then((r) {
      if (!mounted || mySeq != _seq) return;
      setState(() {
        _results = r.items;
        _loading = false;
      });
    });
    // Google Places (Gezgah dışı yerler) — paralel.
    RotaRepository.instance.placeAutocomplete(term, session: _session).then((g) {
      if (!mounted || mySeq != _seq) return;
      setState(() {
        _gResults = g;
        _gLoading = false;
      });
    });
  }

  /// Google tahminini seç → detayını çöz → konum sonucu olarak döndür.
  Future<void> _pickGoogle(PlaceTahmin t) async {
    setState(() => _resolving = t.placeId);
    final d = await RotaRepository.instance.placeDetay(t.placeId, session: _session);
    if (!mounted) return;
    setState(() => _resolving = null);
    if (d == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Yer bilgisi alınamadı.')));
      return;
    }
    Navigator.pop(context, _PickResult.konum(d));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Klavye yüksekliği; sheet'in ÜSTÜNÜ ekran dışına taşırmamak için padding'i
    // dışarıya değil, içerideki listenin altına ekliyoruz.
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag handle (diğer sheet'lerle tutarlı).
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 6),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 12, 4),
            child: Row(
              children: [
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: AppColors.ink),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: TextField(
                controller: _c,
                autofocus: true,
                onChanged: _search,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Mekan ara…',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: AppColors.primarySoft,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(child: _resultsView()),
          ],
        ),
      );
  }

  Widget _resultsView() {
    final term = _c.text.trim();
    final busy = _loading || _gLoading;
    if (term.length < 2) {
      return const Center(
        child: Text('En az 2 karakter yaz ve mekan ara.',
            style: TextStyle(color: AppColors.muted)),
      );
    }
    if (busy && _results.isEmpty && _gResults.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!busy && _results.isEmpty && _gResults.isEmpty) {
      return const Center(
        child: Text('Sonuç bulunamadı.',
            style: TextStyle(color: AppColors.muted)),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      children: [
        if (_results.isNotEmpty) ...[
          _sectionLabel('Gezgah\u2019ta'),
          for (final r in _results) _gezgahTile(r.place),
        ],
        if (_gResults.isNotEmpty) ...[
          _sectionLabel('Haritadan (Google)'),
          for (final t in _gResults) _googleTile(t),
        ],
      ],
    );
  }

  Widget _sectionLabel(String s) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 10, 0, 4),
      child: Text(s,
          style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppColors.muted)),
    );
  }

  Widget _gezgahTile(ApiPlace p) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 48,
          height: 48,
          child: NetImage(p.thumb(ThumbSize.square)),
        ),
      ),
      title: Text(p.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
      subtitle: p.cityDistrict.isNotEmpty
          ? Text(p.cityDistrict,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5))
          : null,
      onTap: () => Navigator.pop(
          context, _PickResult.mekan(p.toPlace(subtitle: p.cityDistrict))),
    );
  }

  Widget _googleTile(PlaceTahmin t) {
    final resolving = _resolving == t.placeId;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.place_outlined, color: AppColors.primary),
      ),
      title: Text(t.ad.isEmpty ? t.aciklama : t.ad,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
      subtitle: t.altBilgi.isNotEmpty
          ? Text(t.altBilgi,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5))
          : null,
      trailing: resolving
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2.2))
          : const Icon(Icons.add, color: AppColors.primary),
      onTap: resolving ? null : () => _pickGoogle(t),
    );
  }
}


/// Rotaya eklenmek üzere hazırlanan bir durak. [isKonum] true ise Google/serbest
/// konum durağıdır (ürünsüz; `konumEkle` ile eklenir), [place] lat/lng taşır.
class _StagedStop {
  final Place place;
  List<RotaUrun> urunler;
  String yorum;
  final bool isKonum;
  final String adres;
  _StagedStop({
    required this.place,
    this.urunler = const [],
    this.yorum = '',
    this.isKonum = false,
    this.adres = '',
  });
}

/// Çoklu mekan/ürün ekleme ekranı (rota-coklu-mekan-ekleme.md). Kullanıcı
/// birden çok durağı hazırlar, tek istekte `duraklar` dizisiyle gönderir.
class _AddStopsScreen extends StatefulWidget {
  final int rotaId;
  const _AddStopsScreen({required this.rotaId});

  @override
  State<_AddStopsScreen> createState() => _AddStopsScreenState();
}

class _AddStopsScreenState extends State<_AddStopsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this)
    ..addListener(_onTab);
  final List<_StagedStop> _staged = [];
  bool _busy = false;

  // Konum sekmesi durumu (rota-konum-durak.md).
  final TextEditingController _konumAdC = TextEditingController();
  final TextEditingController _konumAdresC = TextEditingController();
  final TextEditingController _konumYorumC = TextEditingController();
  double? _konumLat;
  double? _konumLng;
  bool _konumReal = false;
  bool _konumLoading = false;
  bool _konumBusy = false;
  bool _konumFetched = false;
  Uint8List? _konumFoto;

  void _onTab() {
    // Konum sekmesine ilk geçişte konumu çöz.
    if (_tab.index == 1 && !_konumFetched) _resolveKonum();
  }

  @override
  void dispose() {
    _tab
      ..removeListener(_onTab)
      ..dispose();
    _konumAdC.dispose();
    _konumAdresC.dispose();
    _konumYorumC.dispose();
    super.dispose();
  }

  Future<void> _pickAndAdd() async {
    final picked = await _showPlacePicker(context);
    if (picked == null || !mounted) return;
    // Gezgah mekanı → ürün seçimi + not; sonra durağa ekle.
    if (picked.place != null) {
      final p = picked.place!;
      final res =
          await _showStopSheet(context, postId: p.id, title: p.name);
      if (res == null || !mounted) return;
      setState(() => _staged
          .add(_StagedStop(place: p, urunler: res.urunler, yorum: res.yorum)));
      return;
    }
    // Google yeri → konum durağı (ürünsüz, yalnız not).
    final k = picked.konum!;
    final ad = k.ad.isEmpty ? 'Konum' : k.ad;
    final res = await _showStopSheet(context, postId: 0, title: ad);
    if (res == null || !mounted) return;
    final place = Place(
      id: 0,
      name: ad,
      category: '',
      subtitle: k.adres,
      rating: 0,
      distance: '',
      price: '',
      image: '',
      lat: k.lat,
      lng: k.lng,
    );
    setState(() => _staged.add(_StagedStop(
        place: place, yorum: res.yorum, isKonum: true, adres: k.adres)));
  }

  Future<void> _edit(int index) async {
    final s = _staged[index];
    final res = await _showStopSheet(
      context,
      postId: s.place.id,
      title: s.place.name,
      initialYorum: s.yorum,
      initialUrunler: s.urunler,
    );
    if (res == null || !mounted) return;
    setState(() {
      s.urunler = res.urunler;
      s.yorum = res.yorum;
    });
  }

  Future<void> _submit() async {
    if (_staged.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      final mekanlar = _staged.where((s) => !s.isKonum).toList();
      final konumlar = _staged.where((s) => s.isKonum).toList();
      var eklenen = 0;
      var atlanan = <Map<String, dynamic>>[];
      // Konum durakları tek tek (kendi ucuyla).
      for (final s in konumlar) {
        try {
          await RotaRepository.instance.konumEkle(
            widget.rotaId,
            lat: s.place.lat,
            lng: s.place.lng,
            ad: s.place.name,
            adres: s.adres,
            yorum: s.yorum,
          );
          eklenen++;
        } on PlusRequiredException {
          rethrow;
        } on RotaException catch (e) {
          atlanan.add({'neden': '${s.place.name}: ${e.message}'});
        } catch (_) {
          atlanan.add({'neden': '${s.place.name}: konum eklenemedi'});
        }
      }
      // Mekan durakları toplu.
      if (mekanlar.isNotEmpty) {
        final res = await RotaRepository.instance.mekanlarEkle(
          widget.rotaId,
          mekanlar
              .map((s) => (
                    postId: s.place.id,
                    qrIds: s.urunler.map((u) => u.qrId).toList(),
                    yorum: s.yorum,
                  ))
              .toList(),
        );
        eklenen += res.eklenen;
        atlanan = [...atlanan, ...res.atlanan];
      }
      if (!mounted) return;
      if (atlanan.isNotEmpty) {
        await _showAtlanan(eklenen, atlanan);
      }
      if (mounted) Navigator.pop(context, eklenen > 0);
    } on PlusRequiredException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      await _handlePlus(context, e);
    } on RotaException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _showAtlanan(int eklenen, List<Map<String, dynamic>> atlanan) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(eklenen > 0
            ? '$eklenen durak eklendi'
            : 'Durak eklenemedi'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Şunlar eklenemedi:',
                style: TextStyle(fontSize: 13.5)),
            const SizedBox(height: 8),
            for (final a in atlanan)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                    '• ${a['neden'] ?? 'eklenemedi'}',
                    style:
                        const TextStyle(fontSize: 13, color: AppColors.muted)),
              ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Tamam')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          const PageHeader(title: 'Durak Ekle'),
          _PillTabs(controller: _tab, labels: const ['Mekan', 'Konum']),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _mekanTab(),
                _konumTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mekanTab() {
    return Column(
      children: [
        Expanded(
          child: _staged.isEmpty
              ? _empty()
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  itemCount: _staged.length,
                  itemBuilder: (_, i) => _stagedTile(i),
                ),
        ),
        _bottomBar(),
      ],
    );
  }

  Widget _empty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add_location_alt_outlined,
                size: 56, color: AppColors.muted),
            const SizedBox(height: 14),
            const Text('Rotaya mekan ekle',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            const Text(
              'Birden çok mekan ve ürün ekleyebilirsin. Aşağıdaki butonla '
              'mekan aramaya başla.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stagedTile(int i) {
    final s = _staged[i];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: AppShadows.listTile,
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 52,
                height: 52,
                // Konum durağı: görsel yok → konum pini.
                child: s.isKonum
                    ? Container(
                        color: AppColors.primarySoft,
                        alignment: Alignment.center,
                        child: const AppSvgIcon(AppIcons.pin,
                            size: 22, color: AppColors.primary),
                      )
                    : NetImage(s.place.thumb(ThumbSize.square)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (s.isKonum) ...[
                        const Icon(Icons.near_me,
                            size: 13, color: AppColors.primary),
                        const SizedBox(width: 4),
                      ],
                      Flexible(
                        child: Text(s.place.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 14.5, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  if (s.isKonum && s.adres.isNotEmpty ||
                      s.urunler.isNotEmpty ||
                      s.yorum.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      [
                        if (s.isKonum && s.adres.isNotEmpty) s.adres,
                        if (s.urunler.isNotEmpty)
                          s.urunler.map((u) => u.ad).join(', '),
                        if (s.yorum.isNotEmpty) s.yorum,
                      ].join('  ·  '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12.5, color: AppColors.muted),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              tooltip: 'Düzenle',
              visualDensity: VisualDensity.compact,
              onPressed: () => _edit(i),
              icon: const Icon(Icons.edit_outlined,
                  size: 19, color: AppColors.primary),
            ),
            IconButton(
              tooltip: 'Çıkar',
              visualDensity: VisualDensity.compact,
              onPressed: () => setState(() => _staged.removeAt(i)),
              icon: const Icon(Icons.close, size: 19, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, 12 + MediaQuery.of(context).viewPadding.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _busy ? null : _pickAndAdd,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Mekan Ekle',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                minimumSize: const Size(0, 50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: (_staged.isEmpty || _busy) ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                minimumSize: const Size(0, 50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.4, color: Colors.white),
                    )
                  : Text(
                      _staged.isEmpty
                          ? 'Rotaya Ekle'
                          : 'Rotaya Ekle (${_staged.length})',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  // --- Konum sekmesi (rota-konum-durak.md) ---------------------------------

  Future<void> _resolveKonum() async {
    setState(() {
      _konumLoading = true;
      _konumFetched = true;
    });
    final loc = await LocationService.resolve(forceRefresh: true);
    String? adres;
    try {
      adres =
          await LocationService.cityDistrict(loc.lat, loc.lng, districtFirst: true);
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _konumLat = loc.lat;
      _konumLng = loc.lng;
      _konumReal = loc.real;
      if (adres != null && adres.isNotEmpty && _konumAdresC.text.trim().isEmpty) {
        _konumAdresC.text = adres;
      }
      _konumLoading = false;
    });
  }

  Future<void> _pickKonumFoto() async {
    final src = await _pickImageSource(context, allowRemove: _konumFoto != null);
    if (src == null) return;
    if (src == 'remove') {
      setState(() => _konumFoto = null);
      return;
    }
    final bytes = await _cropSquare(
        src == 'camera' ? ImageSource.camera : ImageSource.gallery);
    if (!mounted) return;
    if (bytes == null) {
      _showPickError(context); // sebebi göster (izin/bellek/platform hatası)
      return;
    }
    setState(() => _konumFoto = bytes);
  }

  Future<void> _submitKonum() async {
    if (_konumLat == null || _konumLng == null || _konumBusy) return;
    setState(() => _konumBusy = true);
    try {
      await RotaRepository.instance.konumEkle(
        widget.rotaId,
        lat: _konumLat!,
        lng: _konumLng!,
        ad: _konumAdC.text,
        adres: _konumAdresC.text,
        yorum: _konumYorumC.text,
        gorselBase64: _konumFoto != null
            ? 'data:image/jpeg;base64,${base64Encode(_konumFoto!)}'
            : null,
      );
      if (mounted) Navigator.pop(context, true);
    } on PlusRequiredException catch (e) {
      if (!mounted) return;
      setState(() => _konumBusy = false);
      await _handlePlus(context, e);
    } on RotaException catch (e) {
      if (!mounted) return;
      setState(() => _konumBusy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Widget _konumTab() {
    final hasLoc = _konumLat != null && _konumLng != null;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Konum kartı.
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: AppShadows.listTile,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                            color: AppColors.primarySoft,
                            shape: BoxShape.circle),
                        child: const Icon(Icons.my_location,
                            color: AppColors.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Bulunduğun konum',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text(
                              _konumLoading
                                  ? 'Konum alınıyor…'
                                  : hasLoc
                                      ? '${_konumLat!.toStringAsFixed(5)}, ${_konumLng!.toStringAsFixed(5)}'
                                      : 'Konum alınamadı',
                              style: const TextStyle(
                                  fontSize: 12.5, color: AppColors.muted),
                            ),
                            if (!_konumLoading && hasLoc && !_konumReal)
                              const Padding(
                                padding: EdgeInsets.only(top: 2),
                                child: Text('Yaklaşık konum (GPS kapalı olabilir)',
                                    style: TextStyle(
                                        fontSize: 11.5,
                                        color: AppColors.closing)),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Yenile',
                        onPressed: _konumLoading ? null : _resolveKonum,
                        icon: _konumLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.2))
                            : const Icon(Icons.refresh,
                                color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                // Fotoğraf (opsiyonel, kare).
                const Text('Fotoğraf (opsiyonel)',
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _pickKonumFoto,
                  child: SizedBox(
                    width: 110,
                    height: 110,
                    child: _konumFoto != null
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child:
                                    Image.memory(_konumFoto!, fit: BoxFit.cover),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () =>
                                      setState(() => _konumFoto = null),
                                  child: Container(
                                    width: 26,
                                    height: 26,
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.black.withValues(alpha: 0.55),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.close,
                                        color: Colors.white, size: 16),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Container(
                            decoration: BoxDecoration(
                              color: AppColors.primarySoft,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.line),
                            ),
                            child: const Icon(Icons.add_a_photo_outlined,
                                color: AppColors.primary, size: 26),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                _field(_konumAdC, 'Konum adı (opsiyonel)',
                    'Örn. Sultanahmet Meydanı'),
                const SizedBox(height: 14),
                _field(_konumAdresC, 'Adres (opsiyonel)', 'Örn. Fatih/İstanbul'),
                const SizedBox(height: 14),
                _field(_konumYorumC, 'Yorum (opsiyonel)', 'Kısa bir not',
                    maxLines: 3),
              ],
            ),
          ),
        ),
        Container(
          padding: EdgeInsets.fromLTRB(
              16, 12, 16, 12 + MediaQuery.of(context).viewPadding.bottom),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppColors.line)),
          ),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: (!hasLoc || _konumBusy) ? null : _submitKonum,
              icon: _konumBusy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.4, color: Colors.white))
                  : const Icon(Icons.add_location_alt_outlined, size: 20),
              label: Text(_konumBusy ? 'Ekleniyor…' : 'Konumu Rotaya Ekle',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Keşfet filtre sheet'i: tür (restoran/mesire/plaj) + ilçe. "Uygula" veya
/// "Temizle" ile `(tip, ilce, ilceAd)` döner; iptalde null (KESFET_SIRALAMA).
class _FilterSheet extends StatefulWidget {
  final String? tip;
  final int? ilce;
  final String? ilceAd;
  const _FilterSheet({this.tip, this.ilce, this.ilceAd});

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  String? _tip;
  int? _ilce;
  String? _ilceAd;
  List<Ilce> _ilceler = const [];
  bool _loadingIlce = true;

  static const List<(String, String, IconData)> _tipler = [
    ('restoran', 'Restoran', Icons.restaurant_outlined),
    ('mesire', 'Mesire', Icons.park_outlined),
    ('plaj', 'Plaj', Icons.beach_access_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _tip = widget.tip;
    _ilce = widget.ilce;
    _ilceAd = widget.ilceAd;
    _loadIlce();
  }

  Future<void> _loadIlce() async {
    final list = await UyeRepository.instance.ilceler();
    if (!mounted) return;
    setState(() {
      _ilceler = list;
      _loadingIlce = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Filtrele',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 18),
          const Text('Tür',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in _tipler)
                _choice(t.$2, _tip == t.$1,
                    () => setState(() => _tip = _tip == t.$1 ? null : t.$1),
                    icon: t.$3),
            ],
          ),
          const SizedBox(height: 20),
          const Text('İlçe',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          if (_loadingIlce)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4)),
            )
          else
            // Tasarım: dokununca alttan yarım modal (ilçe listesi) açılır.
            GestureDetector(
              onTap: _pickIlce,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.place_outlined,
                        size: 19, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(_ilceAd ?? 'Tüm ilçeler',
                          style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: _ilceAd == null
                                  ? FontWeight.w400
                                  : FontWeight.w600,
                              color: _ilceAd == null
                                  ? AppColors.muted
                                  : AppColors.ink)),
                    ),
                    const Icon(Icons.keyboard_arrow_down,
                        color: AppColors.muted),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(
                      context, (tip: null, ilce: null, ilceAd: null)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.ink,
                    side: const BorderSide(color: AppColors.line),
                    minimumSize: const Size(0, 50),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Temizle',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context,
                      (tip: _tip, ilce: _ilce, ilceAd: _ilceAd)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    minimumSize: const Size(0, 50),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Uygula',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _choice(String label, bool active, VoidCallback onTap,
      {IconData? icon}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.fromLTRB(icon != null ? 12 : 16, 10, 16, 10),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
              color: active ? AppColors.primary : AppColors.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon,
                  size: 16,
                  color: active ? Colors.white : AppColors.primary),
              const SizedBox(width: 6),
            ],
            Text(label,
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: active ? Colors.white : AppColors.ink)),
          ],
        ),
      ),
    );
  }

  /// İlçe seçimi — üstü açık renk çizgili (drag handle) yarım bottom sheet.
  /// Dönüş: `0` → Tüm ilçeler (temizle), `>0` → ilçe id, null → iptal.
  Future<void> _pickIlce() async {
    final res = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.7,
        child: Column(
          children: [
            // Açık renk tutamak çizgisi.
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 6),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.line,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 6, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('İlçe seç',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
            const Divider(height: 1, color: AppColors.line),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _ilceRow(ctx, id: 0, ad: 'Tüm ilçeler', selected: _ilce == null),
                  for (final i in _ilceler)
                    _ilceRow(ctx, id: i.id, ad: i.ad, selected: _ilce == i.id),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (res == null || !mounted) return;
    setState(() {
      if (res == 0) {
        _ilce = null;
        _ilceAd = null;
      } else {
        _ilce = res;
        _ilceAd = _ilceler
            .firstWhere((e) => e.id == res,
                orElse: () => const Ilce(id: 0, ad: ''))
            .ad;
      }
    });
  }

  Widget _ilceRow(BuildContext ctx,
      {required int id, required String ad, required bool selected}) {
    return InkWell(
      onTap: () => Navigator.pop(ctx, id),
      child: Container(
        color: selected ? AppColors.primarySoft : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        child: Row(
          children: [
            Expanded(
              child: Text(ad,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.w400,
                      color: AppColors.ink)),
            ),
            if (selected)
              const Icon(Icons.check, size: 18, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}

/// Keşfet: herkese açık gezi rotaları akışı (`GET /rotalar`). Tekli, tam
/// genişlikte satırlar — solda kapak görseli, sağda rota adı + sahip + durak
/// sayısı. Sonsuz kaydırmayla sayfalanır (UYELIK_PLUS.md §6.1).
class DiscoverRoutesScreen extends StatefulWidget {
  const DiscoverRoutesScreen({super.key});

  @override
  State<DiscoverRoutesScreen> createState() => _DiscoverRoutesScreenState();
}

class _DiscoverRoutesScreenState extends State<DiscoverRoutesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab =
      TabController(length: 2, vsync: this)..addListener(_onTab);

  // Keşfet sıralama + filtre (header ikonlarından yönetilir).
  String _sort = 'yeni';
  String? _tip;
  int? _ilce;
  String? _ilceAd;
  double? _lat;
  double? _lng;

  /// Akış yenileme sayacı — artınca sekmelerdeki listeler baştan yüklenir.
  /// Yeni rota oluşturma, detaydan dönüş ve sekme değişiminde artırılır.
  int _tick = 0;

  static const Map<String, String> _sortLabels = {
    'yeni': 'En yeni',
    'begeni': 'En beğenilen',
    'fiyat_artan': 'Fiyat (artan)',
    'fiyat_azalan': 'Fiyat (azalan)',
    'mesafe': 'Bana en yakın',
  };

  static const Map<String, IconData> _sortIcons = {
    'yeni': Icons.schedule,
    'begeni': Icons.favorite_border,
    'fiyat_artan': Icons.arrow_upward,
    'fiyat_azalan': Icons.arrow_downward,
    'mesafe': Icons.near_me_outlined,
  };

  void _onTab() {
    if (!mounted) return;
    // Sekme değişince header ikonları güncellenir ve açılan sekme tazelenir
    // (aradaki değişiklikler — yeni rota, beğeni — hemen görünsün).
    setState(() {
      if (!_tab.indexIsChanging) _tick++;
    });
  }

  @override
  void dispose() {
    _tab
      ..removeListener(_onTab)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onKesfet = _tab.index == 0;
    final filterCount = (_tip != null ? 1 : 0) + (_ilce != null ? 1 : 0);
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          PageHeader(
            title: 'Gezi Rotaları',
            // Filtre + sıralama yalnız Keşfet sekmesinde, sağ üstte, ikonlu.
            actions: onKesfet
                ? [
                    _headerAction(AppIcons.filter, filterCount > 0, _openFilter),
                    _headerAction(AppIcons.sort, _sort != 'yeni', _openSort),
                  ]
                : const [],
          ),
          _PillTabs(controller: _tab, labels: const ['Keşfet', 'Takip']),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _RouteFeed(
                  follow: false,
                  sort: _sort,
                  tip: _tip,
                  ilce: _ilce,
                  lat: _lat,
                  lng: _lng,
                  refreshTick: _tick,
                ),
                _RouteFeed(follow: true, refreshTick: _tick),
              ],
            ),
          ),
        ],
      ),
      // Plus üyelere: sağ altta rota oluşturma butonu.
      floatingActionButton: ValueListenableBuilder<AppUser?>(
        valueListenable: AuthService.instance.user,
        builder: (_, user, __) {
          if (!(user?.isPlus ?? false)) return const SizedBox.shrink();
          return FloatingActionButton(
            onPressed: _createRoute,
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: const CircleBorder(),
            tooltip: 'Yeni Rota',
            child: const Icon(Icons.add),
          );
        },
      ),
    );
  }

  /// Yeni rota oluştur (Plus) → oluşunca detayını aç.
  Future<void> _createRoute() async {
    final data = await _showRouteForm(context);
    if (data == null || !mounted) return;
    try {
      final rota = await RotaRepository.instance.olustur(
        baslik: data.baslik,
        aciklama: data.aciklama,
        gorunurluk: data.gorunurluk,
        yorumlarAcik: data.yorumlarAcik,
      );
      if (data.kapak != null) {
        await RotaRepository.instance.kapakYukle(rota.id,
            'data:image/jpeg;base64,${base64Encode(data.kapak!)}');
      }
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => RouteDetailScreen(rotaId: rota.id)),
      );
      // Detaydan dönünce akışlar tazelensin; yeni rota listede görünsün.
      if (mounted) setState(() => _tick++);
    } on PlusRequiredException catch (e) {
      if (!mounted) return;
      await _handlePlus(context, e);
    } on RotaException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  /// Header'daki ikon aksiyonu; aktifse primary + küçük nokta rozeti.
  Widget _headerAction(String svg, bool active, VoidCallback onTap) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          onPressed: onTap,
          icon: AppSvgIcon(svg,
              size: 21, color: active ? AppColors.primary : AppColors.ink),
        ),
        if (active)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                  color: AppColors.primary, shape: BoxShape.circle),
            ),
          ),
      ],
    );
  }

  Future<void> _openFilter() async {
    final res =
        await showModalBottomSheet<({String? tip, int? ilce, String? ilceAd})>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FilterSheet(tip: _tip, ilce: _ilce, ilceAd: _ilceAd),
    );
    if (res == null || !mounted) return;
    setState(() {
      _tip = res.tip;
      _ilce = res.ilce;
      _ilceAd = res.ilceAd;
    });
  }

  Future<void> _openSort() async {
    final entries = _sortLabels.entries.toList();
    final secili = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Açık renk tutamak çizgisi.
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 6),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.line,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 6, 20, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Sırala',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink)),
              ),
            ),
            const Divider(height: 1, color: AppColors.line),
            for (var i = 0; i < entries.length; i++) ...[
              _sortRow(
                ctx,
                value: entries[i].key,
                label: entries[i].value,
                icon: _sortIcons[entries[i].key] ?? Icons.sort,
                selected: _sort == entries[i].key,
              ),
              if (i < entries.length - 1)
                const Divider(
                    height: 1,
                    thickness: 1,
                    indent: 68,
                    endIndent: 20,
                    color: AppColors.line),
            ],
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (secili == null || secili == _sort) return;
    if (secili == 'mesafe') {
      final loc = await LocationService.resolve();
      if (!mounted) return;
      _lat = loc.lat;
      _lng = loc.lng;
    }
    setState(() => _sort = secili);
  }

  Widget _sortRow(
    BuildContext ctx, {
    required String value,
    required String label,
    required IconData icon,
    required bool selected,
  }) {
    return InkWell(
      onTap: () => Navigator.pop(ctx, value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : AppColors.primarySoft,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon,
                  size: 19,
                  color: selected ? Colors.white : AppColors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.w500,
                      color: AppColors.ink)),
            ),
            // Aktif badge — en sağda.
            if (selected)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text('Seçili',
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white)),
              ),
          ],
        ),
      ),
    );
  }
}

/// Segment (pill) sekme seçici — TabController'ı sürer, içerik TabBarView ile
/// kayar. Aktif sekme beyaz-yuvarlak, pasif gri (tasarım referansı).
class _PillTabs extends StatelessWidget {
  final TabController controller;
  final List<String> labels;
  const _PillTabs({required this.controller, required this.labels});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final active = controller.index;
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F1F5),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              for (var i = 0; i < labels.length; i++)
                Expanded(
                  child: GestureDetector(
                    onTap: () => controller.animateTo(i),
                    behavior: HitTestBehavior.opaque,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: active == i ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: active == i
                            ? const [
                                BoxShadow(
                                    color: Color(0x14000000),
                                    blurRadius: 6,
                                    offset: Offset(0, 2))
                              ]
                            : null,
                      ),
                      child: Text(labels[i],
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: active == i
                                  ? AppColors.ink
                                  : AppColors.muted)),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Tek bir rota akışı: Keşfet (herkese açık) ya da Takip (takip edilenler).
/// Kaymalı sekmeler (TabBarView) içinde kullanılır; kendi durumunu korur.
class _RouteFeed extends StatefulWidget {
  final bool follow;
  // Keşfet sıralama/filtre (üstteki header ikonlarından gelir).
  final String sort;
  final String? tip;
  final int? ilce;
  final double? lat;
  final double? lng;

  /// Dışarıdan yenileme tetikleyicisi: değeri değişince liste baştan yüklenir
  /// (yeni rota oluşturma, rota detayından dönüş, sekme değişimi).
  final int refreshTick;

  const _RouteFeed({
    required this.follow,
    this.sort = 'yeni',
    this.tip,
    this.ilce,
    this.lat,
    this.lng,
    this.refreshTick = 0,
  });

  @override
  State<_RouteFeed> createState() => _RouteFeedState();
}

class _RouteFeedState extends State<_RouteFeed>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scroll = ScrollController();
  final List<GeziRota> _items = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  int _nextPage = 2;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load();
  }

  @override
  void didUpdateWidget(covariant _RouteFeed old) {
    super.didUpdateWidget(old);
    // Header'dan sıralama/filtre değişince ya da dışarıdan yenileme
    // istendiğinde (yeni rota / detaydan dönüş / sekme değişimi) baştan yükle.
    if (old.sort != widget.sort ||
        old.tip != widget.tip ||
        old.ilce != widget.ilce ||
        old.lat != widget.lat ||
        old.lng != widget.lng ||
        old.refreshTick != widget.refreshTick) {
      _load();
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<({List<GeziRota> items, bool hasMore, int? nextPage, int total})>
      _fetch(int page) {
    if (widget.follow) {
      return RotaRepository.instance.takipAkisi(page: page, limit: 20);
    }
    return RotaRepository.instance.kesfet(
      page: page,
      limit: 20,
      sort: widget.sort,
      tip: widget.tip,
      ilce: widget.ilce,
      lat: widget.sort == 'mesafe' ? widget.lat : null,
      lng: widget.sort == 'mesafe' ? widget.lng : null,
    );
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final r = await _fetch(1);
    if (!mounted) return;
    setState(() {
      _items
        ..clear()
        ..addAll(r.items);
      _hasMore = r.hasMore;
      _nextPage = r.nextPage ?? 2;
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
    final r = await _fetch(_nextPage);
    if (!mounted) return;
    setState(() {
      _items.addAll(r.items);
      _hasMore = r.hasMore;
      _nextPage = r.nextPage ?? (_nextPage + 1);
      _loadingMore = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (widget.follow && !AuthService.instance.isLoggedIn) return _loginGate();
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_items.isEmpty) return _empty();
    return _list();
  }

  Widget _loginGate() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.group_outlined, size: 60, color: AppColors.muted),
            const SizedBox(height: 14),
            const Text('Takip akışı için giriş yap',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            const Text(
              'Takip ettiğin kişilerin paylaştığı rotaları burada görürsün.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, color: AppColors.muted),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 200,
              height: 48,
              child: ElevatedButton(
                onPressed: () async {
                  final ok = await openLogin(context);
                  if (ok == true && mounted) _load();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Üye Girişi Yap',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _empty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                  color: AppColors.primarySoft, shape: BoxShape.circle),
              child: const Center(child: ShipWheelIcon(size: 34)),
            ),
            const SizedBox(height: 16),
            const Text('Henüz paylaşılan rota yok',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            const Text(
              'Üyelerin herkese açık gezi rotaları burada listelenir.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _list() {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        itemCount: _items.length + (_hasMore ? 1 : 0),
        itemBuilder: (_, i) {
          if (i >= _items.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
              ),
            );
          }
          return _row(_items[i]);
        },
      ),
    );
  }

  Widget _row(GeziRota r) {
    final sahip = r.sahip;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        // Detaydan dönünce listeyi tazele (beğeni/yorum sayısı, silme vb.).
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => RouteDetailScreen(rotaId: r.id)),
          );
          if (mounted) _load();
        },
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppShadows.listTile,
          ),
          child: Row(
            children: [
              // Solda ufak kapak görseli (kare).
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: r.kapakGorsel.isNotEmpty
                      ? NetImage(r.kapakGorsel)
                      : Container(
                          color: AppColors.primarySoft,
                          child: const Center(child: ShipWheelIcon(size: 30)),
                        ),
                ),
              ),
              const SizedBox(width: 14),
              // Sağda rota adı + sahip + durak sayısı.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.baslik.isEmpty ? 'Adsız rota' : r.baslik,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (sahip != null) ...[
                          _avatar(sahip.avatar, 18),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              sahip.adSoyad.isEmpty ? 'Üye' : sahip.adSoyad,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 12.5, color: AppColors.muted),
                            ),
                          ),
                          const Text('  ·  ',
                              style: TextStyle(color: AppColors.muted)),
                        ],
                        Text('${r.durakSayisi} durak',
                            style: const TextStyle(
                                fontSize: 12.5, color: AppColors.muted)),
                        // Beğeni sayısı (statik gösterim; beğenme rota
                        // detayında yapılır — SOSYAL §1).
                        const Text('  ·  ',
                            style: TextStyle(color: AppColors.muted)),
                        r.begendim
                            ? const Icon(Icons.favorite,
                                size: 14, color: AppColors.heart)
                            : const AppSvgIcon(AppIcons.heart,
                                size: 13, color: AppColors.muted),
                        const SizedBox(width: 3),
                        Text('${r.begeniSayisi}',
                            style: const TextStyle(
                                fontSize: 12.5, color: AppColors.muted)),
                        // Yorum sayısı (beğeninin yanında, ikonuyla).
                        const SizedBox(width: 10),
                        const AppSvgIcon(AppIcons.comment,
                            size: 13, color: AppColors.muted),
                        const SizedBox(width: 3),
                        Text('${r.yorumSayisi}',
                            style: const TextStyle(
                                fontSize: 12.5, color: AppColors.muted)),
                      ],
                    ),
                    // Fiyat / mesafe rozetleri (varsa) — sıralamaya göre dolar.
                    if (r.fiyatLabel.isNotEmpty || r.mesafeLabel.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (r.fiyatLabel.isNotEmpty)
                            _badge(Icons.payments_outlined, r.fiyatLabel,
                                svg: AppIcons.tag),
                          if (r.mesafeLabel.isNotEmpty)
                            _badge(Icons.near_me_outlined, r.mesafeLabel),
                        ],
                      ),
                    ],
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

  Widget _badge(IconData icon, String label, {String? svg}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          svg != null
              ? AppSvgIcon(svg, size: 12, color: AppColors.primary)
              : Icon(icon, size: 13, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary)),
        ],
      ),
    );
  }

  Widget _avatar(String url, double size) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size),
      child: SizedBox(
        width: size,
        height: size,
        child: url.isNotEmpty
            ? NetImage(url)
            : Container(
                color: AppColors.primarySoft,
                alignment: Alignment.center,
                child: AppSvgIcon(AppIcons.user,
                    size: size * 0.5, color: AppColors.primary),
              ),
      ),
    );
  }
}


/// Durak fotoğrafları tam ekran görüntüleyici (kaydırmalı + yakınlaştırma).
class _FotoViewer extends StatelessWidget {
  final List<DurakGorsel> fotos;
  final int index;
  const _FotoViewer({required this.fotos, required this.index});

  @override
  Widget build(BuildContext context) {
    final controller = PageController(initialPage: index);
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        children: [
          PageView(
            controller: controller,
            children: [
              for (final f in fotos)
                InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Center(child: NetImage(f.url, fit: BoxFit.contain)),
                ),
            ],
          ),
          Positioned(
            top: 0,
            right: 0,
            child: SafeArea(
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Durak fotoğraf yönetimi (sahibe): ekle/sil. Değişiklik olduysa `true` döner.
class _DurakFotoSheet extends StatefulWidget {
  final int rotaId;
  final RotaDurak durak;
  const _DurakFotoSheet({required this.rotaId, required this.durak});

  @override
  State<_DurakFotoSheet> createState() => _DurakFotoSheetState();
}

class _DurakFotoSheetState extends State<_DurakFotoSheet> {
  static const int _max = 10;
  late final List<DurakGorsel> _fotos = List.of(widget.durak.gorseller);
  bool _busy = false;
  bool _changed = false;

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _add() async {
    if (_fotos.length >= _max) {
      _snack('En fazla $_max fotoğraf ekleyebilirsin.');
      return;
    }
    // Boyut sınırı: büyük ham dosyalar bellek/yükleme sorununa yol açıyor.
    final files = await ImagePicker().pickMultiImage(
      imageQuality: 90,
      maxWidth: 2400,
      maxHeight: 2400,
      requestFullMetadata: false,
    );
    if (files.isEmpty || !mounted) return;
    setState(() => _busy = true);
    for (final f in files) {
      if (_fotos.length >= _max) break;
      try {
        final bytes = await f.readAsBytes();
        final b64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        final g = await RotaRepository.instance.durakGorselYukle(
            widget.rotaId,
            durakId: widget.durak.durakId,
            base64: b64);
        if (!mounted) return;
        setState(() {
          _fotos.add(g);
          _changed = true;
        });
      } on PlusRequiredException catch (e) {
        _snack(e.message);
        break;
      } on RotaException catch (e) {
        _snack(e.message);
        break;
      } catch (_) {
        _snack('Fotoğraf yüklenemedi.');
        break;
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _remove(DurakGorsel g) async {
    try {
      await RotaRepository.instance.durakGorselSil(widget.rotaId,
          durakId: widget.durak.durakId, gorselId: g.id);
      if (!mounted) return;
      setState(() {
        _fotos.removeWhere((e) => e.id == g.id);
        _changed = true;
      });
    } on PlusRequiredException catch (e) {
      _snack(e.message);
    } on RotaException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('Fotoğraf silinemedi.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
            child: Row(
              children: [
                const Text('Durak Fotoğrafları',
                    style:
                        TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                Text('(${_fotos.length}/$_max)',
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.muted)),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context, _changed),
                  icon: const Icon(Icons.close, color: AppColors.ink),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.line),
          Expanded(
            child: _fotos.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.photo_library_outlined,
                              size: 48, color: AppColors.muted),
                          const SizedBox(height: 12),
                          const Text('Bu durağa henüz fotoğraf eklenmedi.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.muted)),
                        ],
                      ),
                    ),
                  )
                : GridView.count(
                    crossAxisCount: 3,
                    padding: const EdgeInsets.all(16),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    children: [
                      for (final g in _fotos)
                        Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: NetImage(g.url),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () => _remove(g),
                                child: Container(
                                  width: 26,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.55),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close,
                                      color: Colors.white, size: 16),
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: (_busy || _fotos.length >= _max) ? null : _add,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.2, color: Colors.white))
                      : const Icon(Icons.add_a_photo_outlined, size: 18),
                  label: Text(_busy ? 'Yükleniyor…' : 'Fotoğraf Ekle',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Yemek (ürün) fotoğrafı yönetimi (sahibe): tek foto yükle/değiştir/kaldır
/// (rota-yemek-gorsel.md). Değişiklik olduysa `true` döner.
class _UrunFotoSheet extends StatefulWidget {
  final int rotaId;
  final RotaDurak durak;
  final RotaUrun urun;
  const _UrunFotoSheet(
      {required this.rotaId, required this.durak, required this.urun});

  @override
  State<_UrunFotoSheet> createState() => _UrunFotoSheetState();
}

class _UrunFotoSheetState extends State<_UrunFotoSheet> {
  late String _foto = widget.urun.foto;
  bool _busy = false;
  bool _changed = false;

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _upload() async {
    final src = await _pickImageSource(context, allowRemove: _foto.isNotEmpty);
    if (src == null) return;
    if (src == 'remove') {
      await _remove();
      return;
    }
    final bytes = await _cropSquare(
        src == 'camera' ? ImageSource.camera : ImageSource.gallery);
    if (!mounted) return;
    if (bytes == null) {
      _showPickError(context);
      return;
    }
    setState(() => _busy = true);
    try {
      final b64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      final url = await RotaRepository.instance.urunGorselYukle(
        widget.rotaId,
        durakId: widget.durak.durakId,
        qrId: widget.urun.qrId,
        base64: b64,
      );
      if (!mounted) return;
      setState(() {
        _foto = url;
        _changed = true;
      });
    } on PlusRequiredException catch (e) {
      _snack(e.message);
    } on RotaException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('Fotoğraf yüklenemedi.');
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _remove() async {
    setState(() => _busy = true);
    try {
      await RotaRepository.instance.urunGorselSil(widget.rotaId,
          durakId: widget.durak.durakId, qrId: widget.urun.qrId);
      if (!mounted) return;
      setState(() {
        _foto = '';
        _changed = true;
      });
    } on PlusRequiredException catch (e) {
      _snack(e.message);
    } on RotaException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('Fotoğraf silinemedi.');
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.urun;
    // Önizlemede kullanıcı fotoğrafı öncelikli, yoksa menü görseli.
    final preview = _foto.isNotEmpty ? _foto : u.gorsel;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 4),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.line,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      u.ad.isEmpty ? 'Yemek Fotoğrafı' : u.ad,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context, _changed),
                    icon: const Icon(Icons.close, color: AppColors.ink),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: preview.isNotEmpty
                      ? NetImage(preview)
                      : Container(
                          color: AppColors.primarySoft,
                          child: const Center(
                            child: Icon(Icons.restaurant_menu,
                                size: 48, color: AppColors.primary),
                          ),
                        ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Text(
                _foto.isNotEmpty
                    ? 'Bu yemek için yüklediğin fotoğraf.'
                    : 'Bu yemek için bir fotoğraf yükleyebilirsin (kare).',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _busy ? null : _upload,
                        icon: _busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.2, color: Colors.white))
                            : Icon(
                                _foto.isEmpty
                                    ? Icons.add_a_photo_outlined
                                    : Icons.swap_horiz,
                                size: 18),
                        label: Text(
                            _busy
                                ? 'Yükleniyor…'
                                : (_foto.isEmpty
                                    ? 'Fotoğraf Yükle'
                                    : 'Değiştir'),
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ),
                  if (_foto.isNotEmpty) ...[
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 50,
                      width: 50,
                      child: OutlinedButton(
                        onPressed: _busy ? null : _remove,
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          side: const BorderSide(color: AppColors.closing),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Icon(Icons.delete_outline,
                            color: AppColors.closing),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Göreli zaman etiketi ("az önce", "5 dk", "3 sa", "2 gün", tarih).
String _yorumZaman(DateTime? d) {
  if (d == null) return '';
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 1) return 'az önce';
  if (diff.inMinutes < 60) return '${diff.inMinutes} dk';
  if (diff.inHours < 24) return '${diff.inHours} sa';
  if (diff.inDays < 7) return '${diff.inDays} gün';
  return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
}

/// Rota yorumları sheet'i (rota-yorumlar.md): listeleme + ekleme + silme.
/// [onCount] her değişiklikte güncel toplam yorum sayısını üst ekrana bildirir.
class _YorumSheet extends StatefulWidget {
  final GeziRota rota;
  final ValueChanged<int> onCount;
  const _YorumSheet({required this.rota, required this.onCount});

  @override
  State<_YorumSheet> createState() => _YorumSheetState();
}

class _YorumSheetState extends State<_YorumSheet> {
  final TextEditingController _c = TextEditingController();
  final ScrollController _scroll = ScrollController();
  List<RotaYorum> _yorumlar = const [];
  bool _loading = true;
  bool _sending = false;
  bool _hasMore = false;
  int _page = 1;
  late bool _yorumlarAcik = widget.rota.yorumlarAcik;
  late int _total = widget.rota.yorumSayisi;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _c.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _load() async {
    final res = await RotaRepository.instance.yorumlar(widget.rota.id, page: 1);
    if (!mounted) return;
    setState(() {
      _yorumlar = res.items;
      _hasMore = res.hasMore;
      _page = 1;
      _yorumlarAcik = res.yorumlarAcik;
      _total = res.total;
      _loading = false;
    });
    widget.onCount(_total);
  }

  Future<void> _loadMore() async {
    final res = await RotaRepository.instance
        .yorumlar(widget.rota.id, page: _page + 1);
    if (!mounted) return;
    setState(() {
      _yorumlar = [..._yorumlar, ...res.items];
      _hasMore = res.hasMore;
      _page += 1;
    });
  }

  Future<void> _send() async {
    final text = _c.text.trim();
    if (text.isEmpty || _sending) return;
    if (!AuthService.instance.isLoggedIn) {
      final ok = await openLogin(context);
      if (ok != true || !mounted || !AuthService.instance.isLoggedIn) return;
    }
    setState(() => _sending = true);
    try {
      final res = await RotaRepository.instance.yorumEkle(widget.rota.id, text);
      if (!mounted) return;
      setState(() {
        _yorumlar = [res.yorum, ..._yorumlar];
        _total = res.yorumSayisi;
        _c.clear();
        _sending = false;
      });
      widget.onCount(_total);
      FocusScope.of(context).unfocus();
    } on PlusRequiredException catch (e) {
      if (mounted) setState(() => _sending = false);
      _snack(e.message);
    } on RotaException catch (e) {
      if (mounted) setState(() => _sending = false);
      _snack(e.message);
    } catch (_) {
      if (mounted) setState(() => _sending = false);
      _snack('Yorum eklenemedi.');
    }
  }

  Future<void> _delete(RotaYorum y) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yorumu sil'),
        content: const Text('Bu yorumu silmek istediğine emin misin?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil',
                style: TextStyle(
                    color: AppColors.closing, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final count = await RotaRepository.instance.yorumSil(widget.rota.id, y.id);
      if (!mounted) return;
      setState(() {
        _yorumlar = _yorumlar.where((e) => e.id != y.id).toList();
        _total = count;
      });
      widget.onCount(_total);
    } on RotaException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('Yorum silinemedi.');
    }
  }

  /// Yorum beğeni/beğenmeme tepkisi (rota-yorum-begeni.md) — iyimser güncelleme,
  /// yanıtla senkron; hatada geri al. Aktif tepkiye tekrar dokunmak kaldırır.
  Future<void> _react(RotaYorum y, {required bool like}) async {
    if (!AuthService.instance.isLoggedIn) {
      final ok = await openLogin(context);
      if (ok != true || !mounted || !AuthService.instance.isLoggedIn) return;
    }
    final idx = _yorumlar.indexWhere((e) => e.id == y.id);
    if (idx < 0) return;
    final cur = _yorumlar[idx];
    RotaYorum optimistic;
    Future<YorumTepki> Function() call;
    if (like) {
      if (cur.begendim) {
        optimistic = cur.copyWith(
            begendim: false,
            begeniSayisi: (cur.begeniSayisi - 1).clamp(0, 1 << 30));
        call = () => RotaRepository.instance.yorumBegenKaldir(widget.rota.id, y.id);
      } else {
        optimistic = cur.copyWith(
            begendim: true,
            begenmedim: false,
            begeniSayisi: cur.begeniSayisi + 1,
            begenmemeSayisi: cur.begenmedim
                ? (cur.begenmemeSayisi - 1).clamp(0, 1 << 30)
                : cur.begenmemeSayisi);
        call = () => RotaRepository.instance.yorumBegen(widget.rota.id, y.id);
      }
    } else {
      if (cur.begenmedim) {
        optimistic = cur.copyWith(
            begenmedim: false,
            begenmemeSayisi: (cur.begenmemeSayisi - 1).clamp(0, 1 << 30));
        call =
            () => RotaRepository.instance.yorumBegenmeKaldir(widget.rota.id, y.id);
      } else {
        optimistic = cur.copyWith(
            begenmedim: true,
            begendim: false,
            begenmemeSayisi: cur.begenmemeSayisi + 1,
            begeniSayisi: cur.begendim
                ? (cur.begeniSayisi - 1).clamp(0, 1 << 30)
                : cur.begeniSayisi);
        call = () => RotaRepository.instance.yorumBegenme(widget.rota.id, y.id);
      }
    }
    setState(() => _yorumlar[idx] = optimistic);
    try {
      final r = await call();
      if (!mounted) return;
      final i2 = _yorumlar.indexWhere((e) => e.id == y.id);
      if (i2 >= 0) {
        setState(() => _yorumlar[i2] = _yorumlar[i2].copyWith(
              begendim: r.begendim,
              begenmedim: r.begenmedim,
              begeniSayisi: r.begeniSayisi,
              begenmemeSayisi: r.begenmemeSayisi,
            ));
      }
    } catch (e) {
      if (!mounted) return;
      final i3 = _yorumlar.indexWhere((e) => e.id == y.id);
      if (i3 >= 0) setState(() => _yorumlar[i3] = cur); // geri al
      _snack(e is RotaException ? e.message : 'İşlem yapılamadı.');
    }
  }

  Widget _reactBtn({
    required IconData icon,
    required bool active,
    required int count,
    required VoidCallback onTap,
  }) {
    final color = active ? AppColors.primary : AppColors.muted;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: color),
          if (count > 0) ...[
            const SizedBox(width: 4),
            Text('$count',
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600, color: color)),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 6),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 2, 12, 8),
            child: Row(
              children: [
                Text(_total > 0 ? 'Yorumlar ($_total)' : 'Yorumlar',
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink)),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: AppColors.ink),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.line),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _yorumlar.isEmpty
                    ? _empty()
                    : ListView.separated(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                        itemCount: _yorumlar.length + (_hasMore ? 1 : 0),
                        separatorBuilder: (_, i) => i < _yorumlar.length - 1
                            ? const Divider(
                                height: 26,
                                thickness: 1,
                                indent: 50,
                                color: AppColors.line)
                            : const SizedBox(height: 12),
                        itemBuilder: (_, i) {
                          if (i >= _yorumlar.length) {
                            return Center(
                              child: TextButton(
                                onPressed: _loadMore,
                                child: const Text('Daha fazla göster'),
                              ),
                            );
                          }
                          return _yorumTile(_yorumlar[i]);
                        },
                      ),
          ),
          _composer(insets),
        ],
      ),
    );
  }

  Widget _empty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.mode_comment_outlined,
                size: 46, color: AppColors.muted),
            const SizedBox(height: 12),
            Text(
              _yorumlarAcik
                  ? 'Henüz yorum yok. İlk yorumu sen yaz.'
                  : 'Bu rotada yorumlar kapalı.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _yorumTile(RotaYorum y) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Avatar. İşletme yorumunda dokununca mekan detayına gider.
        GestureDetector(
          onTap: (y.isletme && y.postId > 0)
              ? () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DetailScreen(
                        place: Place(
                          id: y.postId,
                          name: y.uye.adSoyad,
                          category: '',
                          subtitle: '',
                          rating: 0,
                          distance: '',
                          price: '',
                          image: y.uye.avatar,
                        ),
                      ),
                    ),
                  )
              : null,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(y.isletme ? 12 : 999),
            child: SizedBox(
              width: 38,
              height: 38,
              child: y.uye.avatar.isNotEmpty
                  ? NetImage(y.uye.avatar)
                  : Container(
                      color: AppColors.primarySoft,
                      alignment: Alignment.center,
                      child: const AppSvgIcon(AppIcons.user,
                          size: 18, color: AppColors.primary),
                    ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      y.uye.adSoyad.isEmpty ? 'Üye' : y.uye.adSoyad,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w700),
                    ),
                  ),
                  // İşletme yorumu → mavi tik (dokununca Onaylı İşletme modalı).
                  if (y.isletme) ...[
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => showOnayliIsletmeModal(context),
                      child: const Icon(Icons.verified,
                          size: 15, color: kOnayliMavi),
                    ),
                  ],
                  const SizedBox(width: 8),
                  Text(_yorumZaman(y.createdAt),
                      style: const TextStyle(
                          fontSize: 11.5, color: AppColors.muted)),
                ],
              ),
              const SizedBox(height: 3),
              Text(y.yorum,
                  style: const TextStyle(
                      fontSize: 13.5, height: 1.4, color: AppColors.ink)),
              const SizedBox(height: 8),
              // Beğeni / beğenmeme (rota-yorum-begeni.md).
              Row(
                children: [
                  _reactBtn(
                    icon: y.begendim
                        ? Icons.thumb_up_alt
                        : Icons.thumb_up_alt_outlined,
                    active: y.begendim,
                    count: y.begeniSayisi,
                    onTap: () => _react(y, like: true),
                  ),
                  const SizedBox(width: 20),
                  _reactBtn(
                    icon: y.begenmedim
                        ? Icons.thumb_down_alt
                        : Icons.thumb_down_alt_outlined,
                    active: y.begenmedim,
                    count: y.begenmemeSayisi,
                    onTap: () => _react(y, like: false),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Silme — satırın en sağına sabit (yalnız yetkiliye).
        if (y.silebilir)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: GestureDetector(
              onTap: () => _delete(y),
              child: const Icon(Icons.delete_outline,
                  size: 19, color: AppColors.muted),
            ),
          ),
      ],
    );
  }

  Widget _composer(double insets) {
    if (!_yorumlarAcik) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(bottom: insets),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.line)),
            ),
            alignment: Alignment.center,
            child: const Text('Bu rotada yorumlar kapalı.',
                style: TextStyle(color: AppColors.muted, fontSize: 13)),
          ),
        ),
      );
    }
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: insets),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppColors.line)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _c,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: 1000,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText: 'Yorum yaz…',
                    counterText: '',
                    filled: true,
                    fillColor: AppColors.primarySoft,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: _sending ? null : _send,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                      color: AppColors.primary, shape: BoxShape.circle),
                  child: _sending
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(
                              strokeWidth: 2.2, color: Colors.white),
                        )
                      : const Icon(Icons.send, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Durak detay paneli — rota detayında bir durağa dokununca açılır.
/// İçerik duraktan geliyor: fotoğraflar, ad/adres, not ve seçili ürünler.
class _StopDetailSheet extends StatelessWidget {
  final RotaDurak durak;
  final int index; // 0 tabanlı sıra
  final void Function(int index) onOpenFotos;

  const _StopDetailSheet({
    required this.durak,
    required this.index,
    required this.onOpenFotos,
  });

  @override
  Widget build(BuildContext context) {
    final d = durak;
    final m = d.mekan;
    final fotos = d.gorseller;
    final baslik = m?.name.isNotEmpty == true
        ? m!.name
        : (d.isKonum ? 'Konum' : 'Mekan');
    final konum = m?.cityDistrict ?? '';
    final bottom = MediaQuery.of(context).padding.bottom;

    return Container(
      constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 8),
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(999)),
            ),
          ),
          Flexible(
            child: ListView(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 16 + bottom),
              children: [
                // Başlık: sıra rozeti + ad + tip etiketi.
                Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                          color: AppColors.primary, shape: BoxShape.circle),
                      child: Text('${index + 1}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(baslik,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink)),
                    ),
                    const SizedBox(width: 8),
                    _tag(d.isKonum ? 'Konum' : 'Mekan'),
                  ],
                ),
                if (konum.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AppSvgIcon(AppIcons.pin,
                          size: 13, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(konum,
                            style: const TextStyle(
                                fontSize: 13,
                                height: 1.4,
                                color: AppColors.muted)),
                      ),
                    ],
                  ),
                ],

                // Fotoğraflar — tek foto tam genişlik, çok foto yatay galeri.
                if (fotos.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  if (fotos.length == 1)
                    GestureDetector(
                      onTap: () => onOpenFotos(0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: AspectRatio(
                          aspectRatio: 16 / 10,
                          child: NetImage(fotos.first.url),
                        ),
                      ),
                    )
                  else
                    SizedBox(
                      height: 150,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: fotos.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (_, i) => GestureDetector(
                          onTap: () => onOpenFotos(i),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: SizedBox(
                              width: 150,
                              child: NetImage(fotos[i].url),
                            ),
                          ),
                        ),
                      ),
                    ),
                ] else if (!d.isKonum && (m?.image.isNotEmpty ?? false)) ...[
                  // Fotoğraf yoksa mekanın kendi görseli.
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: AspectRatio(
                      aspectRatio: 16 / 10,
                      child: NetImage(m!.image),
                    ),
                  ),
                ],

                // Not / açıklama.
                if (d.yorum.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('Not',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink)),
                  const SizedBox(height: 6),
                  Text(d.yorum,
                      style: const TextStyle(
                          fontSize: 13.5, height: 1.5, color: AppColors.muted)),
                ],

                // Seçili ürünler (QR menüden).
                if (d.urunler.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  const Text('Seçilen ürünler',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink)),
                  const SizedBox(height: 8),
                  for (final u in d.urunler) _urunRow(u),
                ],

                // Adres metni (konum durağında serbest adres).
                if (d.isKonum &&
                    (m?.adres.isNotEmpty ?? false) &&
                    m!.adres != konum) ...[
                  const SizedBox(height: 16),
                  const Text('Adres',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink)),
                  const SizedBox(height: 6),
                  Text(m.adres,
                      style: const TextStyle(
                          fontSize: 13.5, height: 1.5, color: AppColors.muted)),
                ],

                const SizedBox(height: 18),
                // Aksiyonlar.
                if (!d.isKonum && m != null && m.id > 0)
                  _primaryButton(
                    label: 'Mekan Detayı',
                    icon: Icons.storefront_outlined,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DetailScreen(
                            place: Place(
                              id: m.id,
                              name: m.name,
                              category: '',
                              subtitle: m.cityDistrict,
                              rating: 0,
                              distance: '',
                              price: '',
                              image: m.image,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                if (d.haritaLink.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _secondaryButton(
                    label: 'Yol Tarifi',
                    icon: Icons.directions_outlined,
                    onTap: () async {
                      try {
                        await launchUrl(Uri.parse(d.haritaLink),
                            mode: LaunchMode.externalApplication);
                      } catch (_) {
                        // sessizce yut: harita açılamazsa panel açık kalır
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tag(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(text,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.primary)),
      );

  Widget _urunRow(RotaUrun u) {
    final img = u.foto.isNotEmpty ? u.foto : u.gorsel;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          if (img.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(width: 44, height: 44, child: NetImage(img)),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(u.ad,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink)),
          ),
          if (u.fiyatLabel.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(u.fiyatLabel,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary)),
          ],
        ],
      ),
    );
  }

  Widget _primaryButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        label: Text(label,
            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _secondaryButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18, color: AppColors.primary),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.line),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        label: Text(label,
            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
