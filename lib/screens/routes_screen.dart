import 'package:flutter/material.dart';

import '../data/api.dart';
import '../data/auth_service.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'detail_screen.dart';
import 'login_screen.dart';
import 'plus_screen.dart';

/// "Gezi Rotalarım" ekranını açar (UYELIK_PLUS.md §6).
Future<void> openRoutes(BuildContext context) {
  return Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const RoutesScreen()),
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
      backgroundColor: AppColors.pageBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _topBar(),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : (_rotalar.isEmpty ? _empty() : _list()),
            ),
          ],
        ),
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

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 16, 6),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.chevron_left, color: AppColors.ink),
          ),
          const Text('Gezi Rotalarım',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
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
    final picked = await _showPlacePicker(context);
    if (picked == null || !mounted) return;
    final yorum = await _showCommentDialog(context, title: picked.name);
    if (!mounted) return;
    await _guard(() => RotaRepository.instance
        .mekanEkle(widget.rotaId, postId: picked.id, yorum: yorum));
  }

  Future<void> _editStop(RotaDurak d) async {
    final yorum = await _showCommentDialog(context,
        title: d.mekan?.name ?? 'Durak', initial: d.yorum);
    if (yorum == null || !mounted) return;
    await _guard(() => RotaRepository.instance
        .durakGuncelle(widget.rotaId, durakId: d.durakId, yorum: yorum));
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
      backgroundColor: AppColors.pageBg,
      body: SafeArea(
        bottom: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : r == null
                ? _notFound()
                : Column(
                    children: [
                      _topBar(r),
                      Expanded(child: _body(r)),
                    ],
                  ),
      ),
      floatingActionButton: (!_loading && r != null)
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

  Widget _notFound() {
    return Column(
      children: [
        _topBar(null),
        const Expanded(
          child: Center(
            child: Text('Rota bulunamadı.',
                style: TextStyle(color: AppColors.muted)),
          ),
        ),
      ],
    );
  }

  Widget _topBar(GeziRota? r) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.chevron_left, color: AppColors.ink),
          ),
          const Expanded(
            child: Text('Rota Detayı',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          ),
          if (r != null) ...[
            IconButton(
              onPressed: _editRoute,
              icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
            ),
            IconButton(
              onPressed: _deleteRoute,
              icon: const Icon(Icons.delete_outline, color: AppColors.closing),
            ),
          ],
        ],
      ),
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
        else
          SliverReorderableList(
            itemCount: duraklar.length,
            itemBuilder: (_, i) => _stopTile(duraklar[i], i,
                key: ValueKey(duraklar[i].durakId)),
            onReorderItem: _reorder,
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _header(GeziRota r) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppShadows.listTile,
      ),
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
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(r.herkeseAcik ? Icons.public : Icons.lock_outline,
                        size: 13, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(r.herkeseAcik ? 'Herkese açık' : 'Gizli',
                        style: const TextStyle(
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
          Text('${r.duraklar.length} durak',
              style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink)),
        ],
      ),
    );
  }

  Widget _stopTile(RotaDurak d, int index, {required Key key}) {
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
                  ],
                ),
              ),
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
                  child:
                      Icon(Icons.drag_handle, color: AppColors.muted, size: 22),
                ),
              ),
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
Future<String?> _showCommentDialog(BuildContext context,
    {required String title, String? initial}) {
  final c = TextEditingController(text: initial ?? '');
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      content: TextField(
        controller: c,
        maxLines: 3,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'Bu durak için notun (opsiyonel)',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, c.text.trim()),
          child: const Text('Kaydet',
              style: TextStyle(fontWeight: FontWeight.w600)),
        ),
      ],
    ),
  );
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
