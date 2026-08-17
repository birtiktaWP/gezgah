import 'dart:convert';
import 'dart:typed_data';

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
import '../widgets/common.dart';
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
      await RotaRepository.instance.olustur(
        baslik: data.$1,
        aciklama: data.$2,
        gorunurluk: data.$3,
      );
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

  @override
  void initState() {
    super.initState();
    _load();
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
    await _guard(() => RotaRepository.instance.guncelle(
          r.id,
          baslik: data.$1,
          aciklama: data.$2,
          gorunurluk: data.$3,
        ));
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
    final action = await showModalBottomSheet<String>(
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
              leading: const Icon(Icons.camera_alt_outlined,
                  color: AppColors.primary),
              title: const Text('Fotoğraf çek'),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            if (hasCover)
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
    if (action == null || !mounted) return;

    if (action == 'remove') {
      await _guard(() => RotaRepository.instance.kapakSil(widget.rotaId));
      return;
    }
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: action == 'camera' ? ImageSource.camera : ImageSource.gallery,
    );
    if (file == null || !mounted) return;

    // 16:10 yatay çerçevede kullanıcı kırpma alanını kendisi seçer
    // (SOSYAL/UYELIK_PLUS §6.2 — kapak 1200×750).
    final cropped = await ImageCropper().cropImage(
      sourcePath: file.path,
      aspectRatio: const CropAspectRatio(ratioX: 16, ratioY: 10),
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 88,
      maxWidth: 1200,
      maxHeight: 750,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Kapağı Kırp',
          toolbarColor: AppColors.primary,
          toolbarWidgetColor: Colors.white,
          backgroundColor: Colors.black,
          activeControlsWidgetColor: AppColors.primary,
          lockAspectRatio: true,
          hideBottomControls: false,
        ),
        IOSUiSettings(
          title: 'Kapağı Kırp',
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
          aspectRatioPickerButtonHidden: true,
          rotateButtonsHidden: false,
        ),
      ],
    );
    if (cropped == null || !mounted) return;

    final bytes = await cropped.readAsBytes();
    final b64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
    // Yükleme sırasında kırpılan görseli anında (blob) göster.
    setState(() => _pendingCover = bytes);
    await _guard(
        () => RotaRepository.instance.kapakYukle(widget.rotaId, b64));
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

    // (key, icon, başlık, tehlikeli-mi)
    final items = <(String, IconData, String, bool)>[
      if (inApp) ('map_in', Icons.map_outlined, 'Haritada Aç', false),
      if (harita.isNotEmpty)
        ('map_ext', Icons.directions_outlined, 'Google Haritalar\u2019da Aç',
            false),
      ('share', Icons.ios_share, 'Paylaş', false),
      if (owner) ('cover', Icons.image_outlined, 'Kapak Görseli', false),
      if (owner) ('edit', Icons.edit_outlined, 'Rotayı Düzenle', false),
      if (owner) ('delete', Icons.delete_outline, 'Rotayı Sil', true),
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
            title: 'Rota Detayı',
            // Tek ayar ikonu (geri butonu gibi arka planlı); menü bottom
            // sheet'te açılır.
            actions: [
              if (r != null)
                GlassButton(
                  icon: Icons.settings_outlined,
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
          Row(
            children: [
              Expanded(
                child: Text(r.baslik.isEmpty ? 'Adsız rota' : r.baslik,
                    style: const TextStyle(
                        fontSize: 19, fontWeight: FontWeight.w600)),
              ),
              // Yalnız "Gizli" rozeti gösterilir; herkese açık rozetine gerek yok.
              if (!r.herkeseAcik)
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
          const SizedBox(height: 10),
          Row(
            children: [
              Text('${r.duraklar.length} durak',
                  style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink)),
              // Rota toplam fiyatı (seçili ürünler) — varsa göster.
              if (r.fiyatLabel.isNotEmpty) ...[
                const Text('  ·  ', style: TextStyle(color: AppColors.muted)),
                Text(r.fiyatLabel,
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary)),
              ],
              // Başkasının rotasıysa sahip bilgisi — profiline tıklanabilir.
              if (!r.benim && r.sahip != null) ...[
                const Text('  ·  ', style: TextStyle(color: AppColors.muted)),
                Flexible(
                  child: GestureDetector(
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
                        _ownerAvatar(r.sahip!.avatar, 18),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            r.sahip!.adSoyad.isEmpty ? 'Üye' : r.sahip!.adSoyad,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          _actions(r),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Beğen + (başkasının rotasıysa) Takip Et aksiyonları (SOSYAL §1–2).
  Widget _actions(GeziRota r) {
    final followable = !r.benim && r.sahip != null;
    return Row(
      children: [
        // Beğen butonu — dokununca toggle (giriş gerekir).
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _toggleLike,
            icon: Icon(
                r.begendim ? Icons.favorite : Icons.favorite_border,
                size: 18,
                color: r.begendim ? AppColors.heart : AppColors.primary),
            label: Text(
              r.begeniSayisi > 0 ? 'Beğen · ${r.begeniSayisi}' : 'Beğen',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.ink,
              side: const BorderSide(color: AppColors.line),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        if (followable) ...[
          const SizedBox(width: 10),
          Expanded(child: _followButton(r.sahip!)),
        ],
      ],
    );
  }

  Widget _followButton(RotaSahip s) {
    final following = s.takipEdiyorum ?? false;
    return following
        ? OutlinedButton.icon(
            onPressed: _toggleFollow,
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Takipte',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          );
  }

  /// Durağa bağlı QR menü ürünü rozeti (küçük görsel + ad + fiyat).
  Widget _urunRozet(RotaUrun u) {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 4, 10, 4),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              width: 22,
              height: 22,
              child: u.gorsel.isNotEmpty
                  ? NetImage(u.gorsel)
                  : Container(
                      color: Colors.white,
                      child: const Icon(Icons.restaurant_menu,
                          size: 13, color: AppColors.primary),
                    ),
            ),
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
    );
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
                child: const Icon(Icons.person,
                    size: 12, color: AppColors.primary),
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
        onTap: (m != null && !d.silinmis)
            ? () => Navigator.push(
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
                )
            : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
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
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: d.silinmis
                      ? Container(
                          color: AppColors.primarySoft,
                          child: const Icon(Icons.image_not_supported_outlined,
                              color: AppColors.muted),
                        )
                      : NetImage(m?.image ?? ''),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d.silinmis
                          ? 'Silinmiş mekan'
                          : (m?.name.isNotEmpty == true ? m!.name : 'Mekan'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: d.silinmis ? AppColors.muted : AppColors.ink),
                    ),
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
                          for (final u in d.urunler) _urunRozet(u),
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
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: AppColors.muted),
                  onSelected: (v) {
                    if (v == 'edit') _editStop(d);
                    if (v == 'delete') _deleteStop(d);
                  },
                  itemBuilder: (_) => [
                    if (!d.silinmis)
                      const PopupMenuItem(
                          value: 'edit', child: Text('Notu düzenle')),
                    const PopupMenuItem(
                        value: 'delete', child: Text('Durağı çıkar')),
                  ],
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
        ),
      ),
    );
  }
}

// ===========================================================================
// Ortak formlar / seçiciler
// ===========================================================================

/// Rota oluştur/düzenle formu. `(baslik, aciklama, gorunurluk)` döner; iptalde
/// null.
Future<(String, String, String)?> _showRouteForm(BuildContext context,
    {GeziRota? initial}) {
  final baslikC = TextEditingController(text: initial?.baslik ?? '');
  final aciklamaC = TextEditingController(text: initial?.aciklama ?? '');
  var herkeseAcik = initial?.herkeseAcik ?? false;

  return showModalBottomSheet<(String, String, String)>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
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
              const SizedBox(height: 18),
              Text(initial == null ? 'Yeni Rota' : 'Rotayı Düzenle',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 18),
              _field(baslikC, 'Rota başlığı', 'Örn. Kadıköy Turu'),
              const SizedBox(height: 14),
              _field(aciklamaC, 'Açıklama (opsiyonel)', 'Kısa bir açıklama',
                  maxLines: 3),
              const SizedBox(height: 14),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Herkese açık',
                    style: TextStyle(
                        fontSize: 14.5, fontWeight: FontWeight.w600)),
                subtitle: const Text('Diğer üyeler bu rotayı görebilir',
                    style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
                value: herkeseAcik,
                activeThumbColor: Colors.white,
                activeTrackColor: AppColors.primary,
                onChanged: (v) => setSheet(() => herkeseAcik = v),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    if (baslikC.text.trim().isEmpty) return;
                    Navigator.pop(ctx, (
                      baslikC.text.trim(),
                      aciklamaC.text.trim(),
                      herkeseAcik ? 'herkese_acik' : 'gizli',
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

/// Mekan arama seçici (durak eklemek için). Seçilen mekanı döner.
Future<Place?> _showPlacePicker(BuildContext context) {
  return showModalBottomSheet<Place>(
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
  bool _loading = false;
  int _seq = 0;

  Future<void> _search(String q) async {
    final term = q.trim();
    final mySeq = ++_seq;
    if (term.length < 2) {
      setState(() {
        _results = const [];
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    final r = await HomeRepository.instance.aramaMekan(term, limit: 20);
    if (!mounted || mySeq != _seq) return;
    setState(() {
      _results = r.items;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
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
                  const Text('Mekan Ekle',
                      style: TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w600)),
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
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _results.isEmpty
                      ? const Center(
                          child: Text('En az 2 karakter yaz ve mekan ara.',
                              style: TextStyle(color: AppColors.muted)),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                          itemCount: _results.length,
                          itemBuilder: (_, i) {
                            final p = _results[i].place;
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
                                  style: const TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w600)),
                              subtitle: p.cityDistrict.isNotEmpty
                                  ? Text(p.cityDistrict,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12.5))
                                  : null,
                              onTap: () => Navigator.pop(
                                  context, p.toPlace(subtitle: p.cityDistrict)),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}


/// Rotaya eklenmek üzere hazırlanan bir durak (mekan + çoklu ürün + not).
class _StagedStop {
  final Place place;
  List<RotaUrun> urunler;
  String yorum;
  _StagedStop({required this.place, this.urunler = const [], this.yorum = ''});
}

/// Çoklu mekan/ürün ekleme ekranı (rota-coklu-mekan-ekleme.md). Kullanıcı
/// birden çok durağı hazırlar, tek istekte `duraklar` dizisiyle gönderir.
class _AddStopsScreen extends StatefulWidget {
  final int rotaId;
  const _AddStopsScreen({required this.rotaId});

  @override
  State<_AddStopsScreen> createState() => _AddStopsScreenState();
}

class _AddStopsScreenState extends State<_AddStopsScreen> {
  final List<_StagedStop> _staged = [];
  bool _busy = false;

  Future<void> _pickAndAdd() async {
    final place = await _showPlacePicker(context);
    if (place == null || !mounted) return;
    final res =
        await _showStopSheet(context, postId: place.id, title: place.name);
    if (res == null || !mounted) return;
    setState(() => _staged.add(
        _StagedStop(place: place, urunler: res.urunler, yorum: res.yorum)));
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
      final res = await RotaRepository.instance.mekanlarEkle(
        widget.rotaId,
        _staged
            .map((s) => (
                  postId: s.place.id,
                  qrIds: s.urunler.map((u) => u.qrId).toList(),
                  yorum: s.yorum,
                ))
            .toList(),
      );
      if (!mounted) return;
      if (res.atlanan.isNotEmpty) {
        await _showAtlanan(res.eklenen, res.atlanan);
      }
      if (mounted) Navigator.pop(context, res.eklenen > 0);
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
          const PageHeader(title: 'Mekan Ekle'),
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
                child: NetImage(s.place.thumb(ThumbSize.square)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.place.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14.5, fontWeight: FontWeight.w600)),
                  if (s.urunler.isNotEmpty || s.yorum.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      [
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
    if (mounted) setState(() {}); // sekme değişince header ikonlarını güncelle
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
                    _headerAction(Icons.tune, filterCount > 0, _openFilter),
                    _headerAction(
                        Icons.swap_vert, _sort != 'yeni', _openSort),
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
                ),
                const _RouteFeed(follow: true),
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
        baslik: data.$1,
        aciklama: data.$2,
        gorunurluk: data.$3,
      );
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => RouteDetailScreen(rotaId: rota.id)),
      );
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
  Widget _headerAction(IconData icon, bool active, VoidCallback onTap) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          onPressed: onTap,
          icon: Icon(icon,
              color: active ? AppColors.primary : AppColors.ink),
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
  const _RouteFeed({
    required this.follow,
    this.sort = 'yeni',
    this.tip,
    this.ilce,
    this.lat,
    this.lng,
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
    // Header'dan sıralama/filtre değişince listeyi baştan yükle.
    if (old.sort != widget.sort ||
        old.tip != widget.tip ||
        old.ilce != widget.ilce ||
        old.lat != widget.lat ||
        old.lng != widget.lng) {
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
                            _badge(Icons.payments_outlined, r.fiyatLabel),
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

  Widget _badge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.primary),
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
                child:
                    const Icon(Icons.person, size: 12, color: AppColors.primary),
              ),
      ),
    );
  }
}
