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
      initialUrun: d.seciliUrun,
    );
    if (res == null || !mounted) return;
    // qr_id: seçili ürün varsa qrId, yoksa 0 (ürünü temizle).
    await _guard(() => RotaRepository.instance.durakGuncelle(
          widget.rotaId,
          durakId: d.durakId,
          yorum: res.yorum,
          qrId: res.urun?.qrId ?? 0,
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

  /// Sağ üst paylaş butonu → alttan modal: Haritada aç + Paylaş
  /// (rota-harita-link.md).
  Future<void> _openShareSheet(GeziRota r) async {
    final harita = r.haritaLink;
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
            const SizedBox(height: 6),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: AppColors.line, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 10),
            if (harita.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.map_outlined,
                    color: AppColors.primary),
                title: const Text('Haritada Aç'),
                subtitle: const Text('Rotayı Google Haritalar\u2019da gör',
                    style: TextStyle(fontSize: 12.5)),
                onTap: () => Navigator.pop(ctx, 'map'),
              ),
            ListTile(
              leading:
                  const Icon(Icons.ios_share, color: AppColors.primary),
              title: const Text('Paylaş'),
              subtitle: const Text('Rota bağlantısını uygulamalarla paylaş',
                  style: TextStyle(fontSize: 12.5)),
              onTap: () => Navigator.pop(ctx, 'share'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    if (action == 'map') {
      await _openMaps(harita);
    } else if (action == 'share') {
      await _shareRoute(r);
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
    final owner = r != null && r.benim;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          PageHeader(
            title: 'Rota Detayı',
            actions: [
              // Paylaş — herkeste görünür.
              if (r != null)
                IconButton(
                  tooltip: 'Paylaş',
                  onPressed: () => _openShareSheet(r),
                  icon: const Icon(Icons.ios_share, color: AppColors.primary),
                ),
              // Kapak/düzenle/sil yalnız sahibe.
              if (owner) ...[
                IconButton(
                  tooltip: 'Kapak görseli',
                  onPressed: _changeCover,
                  icon: const Icon(Icons.image_outlined,
                      color: AppColors.primary),
                ),
                IconButton(
                  onPressed: _editRoute,
                  icon: const Icon(Icons.edit_outlined,
                      color: AppColors.primary),
                ),
                IconButton(
                  onPressed: _deleteRoute,
                  icon: const Icon(Icons.delete_outline,
                      color: AppColors.closing),
                ),
              ],
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
                    // Durağa bağlı QR menü ürünü (PROFIL_VE_ROTA_URUN.md §1.4).
                    if (d.seciliUrun != null) ...[
                      const SizedBox(height: 6),
                      _urunRozet(d.seciliUrun!),
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

/// Durak yorumu giriş dialogu. Kaydedilirse metni (boş olabilir) döner.
/// Durak düzenleme sheet'i: not + (opsiyonel) QR menü ürünü seçimi. Kaydedilirse
/// `(yorum, urun)` döner (urun null → ürün yok/temizlendi); iptalde null.
Future<({String yorum, RotaUrun? urun})?> _showStopSheet(
  BuildContext context, {
  required int postId,
  required String title,
  String initialYorum = '',
  RotaUrun? initialUrun,
}) {
  return showModalBottomSheet<({String yorum, RotaUrun? urun})>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _StopSheet(
      postId: postId,
      title: title,
      initialYorum: initialYorum,
      initialUrun: initialUrun,
    ),
  );
}

class _StopSheet extends StatefulWidget {
  final int postId;
  final String title;
  final String initialYorum;
  final RotaUrun? initialUrun;
  const _StopSheet({
    required this.postId,
    required this.title,
    this.initialYorum = '',
    this.initialUrun,
  });

  @override
  State<_StopSheet> createState() => _StopSheetState();
}

class _StopSheetState extends State<_StopSheet> {
  late final TextEditingController _yorumC =
      TextEditingController(text: widget.initialYorum);
  late RotaUrun? _urun = widget.initialUrun;

  @override
  void dispose() {
    _yorumC.dispose();
    super.dispose();
  }

  Future<void> _pickProduct() async {
    final urun = await _showMenuPicker(context, widget.postId);
    if (urun != null && mounted) setState(() => _urun = urun);
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
            const Text('Menüden ürün (opsiyonel)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            if (_urun != null)
              _selectedProduct(_urun!)
            else
              OutlinedButton.icon(
                onPressed: widget.postId > 0 ? _pickProduct : null,
                icon: const Icon(Icons.restaurant_menu, size: 18),
                label: const Text('Menüden ürün seç'),
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
                onPressed: () => Navigator.pop(
                    context, (yorum: _yorumC.text.trim(), urun: _urun)),
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

  Widget _selectedProduct(RotaUrun u) {
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
            tooltip: 'Değiştir',
            onPressed: widget.postId > 0 ? _pickProduct : null,
            icon: const Icon(Icons.swap_horiz, color: AppColors.primary),
          ),
          IconButton(
            tooltip: 'Kaldır',
            onPressed: () => setState(() => _urun = null),
            icon: const Icon(Icons.close, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

/// Mekanın QR menüsünden ürün seçici (`/uye/rotalar/mekan-menu`). Seçilen
/// ürünü döner; iptalde null.
Future<RotaUrun?> _showMenuPicker(BuildContext context, int postId) {
  return showModalBottomSheet<RotaUrun>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _MenuPickerSheet(postId: postId),
  );
}

class _MenuPickerSheet extends StatefulWidget {
  final int postId;
  const _MenuPickerSheet({required this.postId});

  @override
  State<_MenuPickerSheet> createState() => _MenuPickerSheetState();
}

class _MenuPickerSheetState extends State<_MenuPickerSheet> {
  List<MekanMenuKategori> _menu = const [];
  bool _loading = true;

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

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
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
        ],
      ),
    );
  }

  Widget _urunTile(RotaUrun u) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.pop(context, u),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
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
              if (u.fiyatLabel.isNotEmpty)
                Text(u.fiyatLabel,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.muted)),
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


/// Rotaya eklenmek üzere hazırlanan bir durak (mekan + opsiyonel ürün + not).
class _StagedStop {
  final Place place;
  RotaUrun? urun;
  String yorum;
  _StagedStop({required this.place, this.urun, this.yorum = ''});
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
    setState(() =>
        _staged.add(_StagedStop(place: place, urun: res.urun, yorum: res.yorum)));
  }

  Future<void> _edit(int index) async {
    final s = _staged[index];
    final res = await _showStopSheet(
      context,
      postId: s.place.id,
      title: s.place.name,
      initialYorum: s.yorum,
      initialUrun: s.urun,
    );
    if (res == null || !mounted) return;
    setState(() {
      s.urun = res.urun;
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
            .map((s) =>
                (postId: s.place.id, qrId: s.urun?.qrId, yorum: s.yorum))
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
                  if (s.urun != null || s.yorum.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      [
                        if (s.urun != null)
                          s.urun!.fiyatLabel.isEmpty
                              ? s.urun!.ad
                              : '${s.urun!.ad} · ${s.urun!.fiyatLabel}',
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

  static const List<(String, String)> _tipler = [
    ('restoran', 'Restoran'),
    ('mesire', 'Mesire'),
    ('plaj', 'Plaj'),
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
                    () => setState(() => _tip = _tip == t.$1 ? null : t.$1)),
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int?>(
                  isExpanded: true,
                  value: _ilce,
                  hint: const Text('Tüm ilçeler'),
                  items: [
                    const DropdownMenuItem<int?>(
                        value: null, child: Text('Tüm ilçeler')),
                    for (final i in _ilceler)
                      DropdownMenuItem<int?>(value: i.id, child: Text(i.ad)),
                  ],
                  onChanged: (v) => setState(() {
                    _ilce = v;
                    _ilceAd = v == null
                        ? null
                        : _ilceler
                            .firstWhere((e) => e.id == v,
                                orElse: () => const Ilce(id: 0, ad: ''))
                            .ad;
                  }),
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

  Widget _choice(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
              color: active ? AppColors.primary : AppColors.line),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : AppColors.ink)),
      ),
    );
  }
}

/// Keşfet: herkese açık gezi rotaları akışı (`GET /rotalar`). Tekli, tam
/// genişlikte satırlar — solda kapak görseli, sağda rota adı + sahip + durak
/// sayısı. Sonsuz kaydırmayla sayfalanır (UYELIK_PLUS.md §6.1).
class DiscoverRoutesScreen extends StatelessWidget {
  const DiscoverRoutesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: Column(
          children: [
            const PageHeader(title: 'Gezi Rotaları'),
            Builder(
              builder: (ctx) => _PillTabs(
                controller: DefaultTabController.of(ctx),
                labels: const ['Keşfet', 'Takip'],
              ),
            ),
            const Expanded(
              child: TabBarView(
                children: [
                  _RouteFeed(follow: false),
                  _RouteFeed(follow: true),
                ],
              ),
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
  const _RouteFeed({required this.follow});

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

  // Sıralama + filtre (yalnız Keşfet sekmesi, KESFET_SIRALAMA_FILTRE.md).
  String _sort = 'yeni'; // yeni | begeni | fiyat_artan | fiyat_azalan | mesafe
  String? _tip; // restoran | mesire | plaj
  int? _ilce; // ilçe id
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

  @override
  bool get wantKeepAlive => true;

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

  Future<({List<GeziRota> items, bool hasMore, int? nextPage, int total})>
      _fetch(int page) {
    if (widget.follow) {
      return RotaRepository.instance.takipAkisi(page: page, limit: 20);
    }
    return RotaRepository.instance.kesfet(
      page: page,
      limit: 20,
      sort: _sort,
      tip: _tip,
      ilce: _ilce,
      lat: _sort == 'mesafe' ? _lat : null,
      lng: _sort == 'mesafe' ? _lng : null,
    );
  }

  /// Sıralama/filtre değişince listeyi baştan yükler.
  void _applyChange() {
    setState(() {
      _items.clear();
      _loading = true;
    });
    _load();
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
    final content = _loading
        ? const Center(child: CircularProgressIndicator())
        : (_items.isEmpty ? _empty() : _list());
    if (widget.follow) return content;
    // Keşfet: üstte sıralama + filtre çubuğu.
    return Column(
      children: [
        _controls(),
        Expanded(child: content),
      ],
    );
  }

  // ---- Sıralama + filtre çubuğu ---------------------------------------------

  Widget _controls() {
    final filterCount = (_tip != null ? 1 : 0) + (_ilce != null ? 1 : 0);
    final sortActive = _sort != 'yeni';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
      child: Row(
        children: [
          // Filtre — butonlu; bottom sheet ile seçilir.
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _openFilter,
              icon: const Icon(Icons.tune, size: 18),
              label: Text(
                  filterCount > 0 ? 'Filtrele ($filterCount)' : 'Filtrele',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor:
                    filterCount > 0 ? AppColors.primary : AppColors.ink,
                side: BorderSide(
                    color: filterCount > 0
                        ? AppColors.primary
                        : AppColors.line),
                minimumSize: const Size(0, 44),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Sıralama — sadece ikon.
          GestureDetector(
            onTap: _openSort,
            child: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: sortActive ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: sortActive ? AppColors.primary : AppColors.line),
              ),
              child: Icon(Icons.swap_vert,
                  color: sortActive ? Colors.white : AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openFilter() async {
    final res =
        await showModalBottomSheet<({String? tip, int? ilce, String? ilceAd})>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _FilterSheet(tip: _tip, ilce: _ilce, ilceAd: _ilceAd),
    );
    if (res == null || !mounted) return;
    setState(() {
      _tip = res.tip;
      _ilce = res.ilce;
      _ilceAd = res.ilceAd;
    });
    _applyChange();
  }

  Future<void> _openSort() async {
    final secili = await showModalBottomSheet<String>(
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
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Sırala',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
            for (final e in _sortLabels.entries)
              ListTile(
                title: Text(e.value),
                trailing: _sort == e.key
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () => Navigator.pop(ctx, e.key),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (secili == null || secili == _sort) return;
    // "Mesafe" için konum çöz.
    if (secili == 'mesafe') {
      final loc = await LocationService.resolve();
      if (!mounted) return;
      _lat = loc.lat;
      _lng = loc.lng;
    }
    setState(() => _sort = secili);
    _applyChange();
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
