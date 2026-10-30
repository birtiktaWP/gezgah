import 'dart:async';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gal/gal.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/api.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import 'skeleton.dart';

/// Instagram paylaşım biçimi. Boyutlar Instagram'ın önerdiği çözünürlüktür.
enum IgFormat {
  story('story', 'Story', '1080 × 1920', 1080, 1920),
  post('post', 'Gönderi', '1080 × 1350', 1080, 1350);

  final String slug; // API'ye giden değer (ROTA_INSTAGRAM_PAYLASIM.md)
  final String label;
  final String sizeLabel;
  final int width;
  final int height;
  const IgFormat(
    this.slug,
    this.label,
    this.sizeLabel,
    this.width,
    this.height,
  );

  double get aspect => width / height;
}

/// Gezi rotasını Instagram'da paylaşma akışı (alttan açılan modallar):
///
/// 1. "Story / Gönderi" seçimi
/// 2. Seçilen biçimde iki şablondan birinin seçimi + "Görseli Kaydet"
/// 3. "Görsel kaydedildi" bilgisi (galeriden Instagram'da paylaşılabilir)
///
/// Tüm modallar kök navigator'da açılır (`useRootNavigator`); alttaki
/// yüzen menü ve sayfa butonlarının üstünde kalır, arkalarında kalmaz.
///
/// Şablonlar ve kaydedilen görsel API'den gelir
/// (ROTA_PAYLASIM_SABLON_API.md). Şablon ucu yoksa / boş dönerse uygulama
/// içinde çizilen iki örnek şablon gösterilir ve görsel cihazda üretilir.
Future<void> showRotaInstagramShare(BuildContext context, GeziRota rota) async {
  final format = await _showSheet<IgFormat>(
    context,
    builder: (_) => const _FormatSheet(),
  );
  if (format == null || !context.mounted) return;

  // Kapak görseli şablonda kullanılıyor: önceden yükle ki önizleme ve
  // kaydedilen görsel boş/gri çıkmasın (en fazla 4 sn beklenir).
  final cover = rota.kapakGorsel.trim();
  if (cover.isNotEmpty) {
    await precacheImage(
      CachedNetworkImageProvider(cover),
      context,
    ).timeout(const Duration(seconds: 4)).catchError((Object _) {});
    if (!context.mounted) return;
  }

  final saved = await _showSheet<bool>(
    context,
    isScrollControlled: true,
    builder: (_) => _TemplateSheet(rota: rota, format: format),
  );
  if (saved != true || !context.mounted) return;

  await _showSheet<void>(context, builder: (_) => const _SavedSheet());
}

Future<T?> _showSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool isScrollControlled = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: isScrollControlled,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: builder,
  );
}

// ---------------------------------------------------------------------------
// Ortak parçalar
// ---------------------------------------------------------------------------

class _Grabber extends StatelessWidget {
  const _Grabber();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 10, bottom: 6),
    child: Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: AppColors.line,
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );
}

class _SheetTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  const _SheetTitle(this.title, {this.subtitle});

  @override
  Widget build(BuildContext context) => Container(
    // Tam genişlik: başlık sola yaslı dursun (dış Column ortalıyor).
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(22, 10, 22, 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: AppColors.muted,
            ),
          ),
        ],
      ],
    ),
  );
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  const _PrimaryButton({
    required this.label,
    required this.onPressed,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: const Color(0xFFD9D9E2),
        disabledForegroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 0,
      ),
      onPressed: busy ? null : onPressed,
      child: busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: Colors.white,
              ),
            )
          : Text(
              label,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
    ),
  );
}

// ---------------------------------------------------------------------------
// 1) Story / Gönderi
// ---------------------------------------------------------------------------

class _FormatSheet extends StatelessWidget {
  const _FormatSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _Grabber(),
          const _SheetTitle(
            'Instagram\u2019da Paylaş',
            subtitle: 'Nerede paylaşmak istersin?',
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
            child: Row(
              children: [
                for (final f in IgFormat.values) ...[
                  if (f != IgFormat.values.first) const SizedBox(width: 12),
                  Expanded(
                    child: _FormatTile(
                      format: f,
                      onTap: () => Navigator.pop(context, f),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FormatTile extends StatelessWidget {
  final IgFormat format;
  final VoidCallback onTap;
  const _FormatTile({required this.format, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${format.label}, ${format.sizeLabel}',
      excludeSemantics: true,
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Column(
              children: [
                // Biçimin oranını gösteren küçük çerçeve.
                SizedBox(
                  height: 64,
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: format.aspect,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(7),
                          border: Border.all(
                            color: AppColors.primary,
                            width: 1.6,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  format.label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  format.sizeLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 2) Şablon seçimi + kaydet
// ---------------------------------------------------------------------------

class _TemplateSheet extends StatefulWidget {
  final GeziRota rota;
  final IgFormat format;
  const _TemplateSheet({required this.rota, required this.format});

  @override
  State<_TemplateSheet> createState() => _TemplateSheetState();
}

/// Şablon seçeneği: sunucudan ([remote] dolu) ya da yerel örnek.
typedef _Option = ({int id, String ad, PaylasimSablon? remote});

class _TemplateSheetState extends State<_TemplateSheet> {
  // Sunucu şablonu yoksa gösterilen yerel örnekler (uygulama içinde çizilir).
  static const List<_Option> _localOptions = [
    (id: 1, ad: 'Kapak', remote: null),
    (id: 2, ad: 'Kart', remote: null),
  ];

  /// null = şablonlar yükleniyor.
  List<_Option>? _options;
  final Map<int, GlobalKey> _keys = {};
  int? _selected;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  /// Şablonlar `GET /rotalar/paylasim-sablonlari?format=`'ten gelir
  /// (ROTA_PAYLASIM_SABLON_API.md). Uç yoksa / hata / boş / 5 sn'de
  /// yanıt yoksa yerel örnek şablonlar gösterilir.
  Future<void> _loadTemplates() async {
    final list = await RotaRepository.instance
        .paylasimSablonlari(widget.format.slug)
        .timeout(const Duration(seconds: 5), onTimeout: () => const []);
    if (!mounted) return;
    setState(() {
      _options = list.isEmpty
          ? _localOptions
          : [for (final s in list) (id: s.id, ad: s.ad, remote: s)];
    });
  }

  _Option? get _selectedOption =>
      _options?.where((o) => o.id == _selected).firstOrNull;

  /// Seçili şablonun kaydedilecek görseli.
  ///
  /// - Sunucu şablonu: `GET /uye/rotalar/{id}/paylasim?format=&sablon=`
  ///   ile rotaya özel görsel üretilir ve indirilir.
  /// - Yerel örnek: ekrandaki önizleme biçimin tam çözünürlüğünde
  ///   (ör. 1080×1920) yeniden çizilir.
  Future<Uint8List> _buildImage(_Option o) async {
    if (o.remote != null) {
      final urls = await RotaRepository.instance.paylasimGorseli(
        widget.rota.id,
        format: widget.format.slug,
        sablon: o.id,
      );
      if (urls.isEmpty) throw const _NoImage();
      final res = await Dio().get<List<int>>(
        urls.first,
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 30),
        ),
      );
      final data = res.data;
      if (data == null || data.isEmpty) throw const _NoImage();
      return Uint8List.fromList(data);
    }
    final ctx = _keys[o.id]!.currentContext!;
    final boundary = ctx.findRenderObject()! as RenderRepaintBoundary;
    final ratio = widget.format.width / boundary.size.width;
    final image = await boundary.toImage(pixelRatio: ratio);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data!.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  Future<void> _save() async {
    final o = _selectedOption;
    if (o == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (!await Gal.hasAccess() && !await Gal.requestAccess()) {
        throw const _NoAccess();
      }
      final bytes = await _buildImage(o);
      await Gal.putImageBytes(
        bytes,
        name: 'gezgah_rota_${widget.rota.id}_${widget.format.slug}_${o.id}',
      );
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error =
            (e is _NoAccess ||
                (e is GalException && e.type == GalExceptionType.accessDenied))
            ? 'Görseli kaydetmek için fotoğraflarına erişim izni gerekiyor. '
                  'Ayarlar\u2019dan izin verip tekrar dene.'
            : (e is _NoImage || e is DioException)
            ? 'Görsel oluşturulamadı. Biraz sonra tekrar dene.'
            : 'Görsel kaydedilemedi. Tekrar dene.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.format;
    final maxH = MediaQuery.sizeOf(context).height * 0.86;
    final options = _options;
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _Grabber(),
            _SheetTitle('Şablon seç', subtitle: '${f.label} · ${f.sizeLabel}'),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(top: 16, bottom: 4),
                child: LayoutBuilder(
                  builder: (context, c) {
                    // Ekranda yan yana 2 şablon; fazlası yatay kaydırılır.
                    final w = (c.maxWidth - 44 - 12) / 2;
                    final h = w / f.aspect + 6 + 8 + 22;
                    final count = options?.length ?? 2;
                    return SizedBox(
                      height: h,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 22),
                        physics: count > 2
                            ? null
                            : const NeverScrollableScrollPhysics(),
                        itemCount: count,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (_, i) => SizedBox(
                          width: w,
                          child: options == null
                              ? _skeletonOption()
                              : _templateOption(options[i]),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 8, 22, 0),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.closing,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 14),
              child: _PrimaryButton(
                label: _selected == null ? 'Bir şablon seç' : 'Görseli Kaydet',
                busy: _saving,
                onPressed: _selected == null ? null : _save,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Şablonlar yüklenirken gri yer tutucu.
  Widget _skeletonOption() {
    return SkeletonPulse(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(3),
            child: AspectRatio(
              aspectRatio: widget.format.aspect,
              child: const SkeletonBox(height: double.infinity, radius: 10),
            ),
          ),
          const SizedBox(height: 10),
          const SkeletonBox(width: 56, height: 12),
        ],
      ),
    );
  }

  Widget _preview(_Option o) {
    final remote = o.remote;
    if (remote != null) {
      return Image(
        image: CachedNetworkImageProvider(remote.onizleme),
        fit: BoxFit.cover,
        frameBuilder: (_, child, frame, sync) => (sync || frame != null)
            ? child
            : const ColoredBox(color: SkeletonBox.color),
        errorBuilder: (_, __, ___) => const ColoredBox(
          color: SkeletonBox.color,
          child: Center(
            child: Icon(
              Icons.image_not_supported_outlined,
              color: AppColors.muted,
            ),
          ),
        ),
      );
    }
    return RepaintBoundary(
      key: _keys.putIfAbsent(o.id, GlobalKey.new),
      child: _RotaTemplate(
        sablon: o.id,
        rota: widget.rota,
        format: widget.format,
      ),
    );
  }

  Widget _templateOption(_Option o) {
    final selected = _selected == o.id;
    final ad = o.ad.isEmpty ? 'Şablon ${o.id}' : o.ad;
    return Semantics(
      button: true,
      selected: selected,
      label: '$ad şablonu',
      child: GestureDetector(
        onTap: _saving
            ? null
            : () {
                HapticFeedback.selectionClick();
                setState(() {
                  _selected = o.id;
                  _error = null;
                });
              },
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected ? AppColors.primary : AppColors.line,
                  width: selected ? 2.4 : 1.2,
                ),
              ),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: AspectRatio(
                      aspectRatio: widget.format.aspect,
                      child: _preview(o),
                    ),
                  ),
                  if (selected)
                    const Positioned(
                      top: 8,
                      right: 8,
                      child: CircleAvatar(
                        radius: 12,
                        backgroundColor: AppColors.primary,
                        child: Icon(Icons.check, size: 15, color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              ad,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: selected ? AppColors.primary : AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoImage implements Exception {
  const _NoImage();
}

class _NoAccess implements Exception {
  const _NoAccess();
}

/// Örnek paylaşım şablonu. Sabit mantıksal tuvale (360 genişlik) çizilip
/// [FittedBox] ile ölçeklenir; böylece önizleme ve kaydedilen tam çözünürlük
/// görsel birebir aynı yerleşimi taşır.
///
/// - 1 "Kapak": kapak görseli tam ekran, altta koyu geçiş + başlık.
/// - 2 "Kart": marka zemini üzerinde beyaz kart, kapak + ilk duraklar.
class _RotaTemplate extends StatelessWidget {
  final int sablon;
  final GeziRota rota;
  final IgFormat format;
  const _RotaTemplate({
    required this.sablon,
    required this.rota,
    required this.format,
  });

  static const double _w = 360;

  String get _baslik =>
      rota.baslik.trim().isEmpty ? 'Gezi Rotam' : rota.baslik.trim();

  String get _sahip {
    final s = rota.sahip;
    if (s == null) return '';
    return [s.isim, s.soyisim].where((e) => e.trim().isNotEmpty).join(' ');
  }

  String get _alt {
    final parts = <String>[
      if (rota.durakSayisi > 0) '${rota.durakSayisi} durak',
      if (_sahip.isNotEmpty) _sahip,
    ];
    return parts.join(' · ');
  }

  List<String> get _duraklar => [
    for (final d in rota.duraklar)
      if (!d.silinmis && (d.mekan?.name.trim().isNotEmpty ?? false))
        d.mekan!.name.trim(),
  ];

  Widget _cover() {
    final url = rota.kapakGorsel.trim();
    // Kapak yoksa marka geçişi + rota ikonu (alanı tam doldurur; çocuksuz
    // DecoratedBox 0 boyut alıp kartta beyaz boşluk bırakıyordu).
    const fallback = SizedBox.expand(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primary2, AppColors.primary],
          ),
        ),
        child: Center(
          child: Icon(Icons.route_outlined, size: 54, color: Color(0x40FFFFFF)),
        ),
      ),
    );
    if (url.isEmpty) return fallback;
    return Image(
      image: CachedNetworkImageProvider(url),
      fit: BoxFit.cover,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => fallback,
    );
  }

  Widget _logo(Color color, double h) => SvgPicture.asset(
    'assets/logo.svg',
    height: h,
    colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
  );

  @override
  Widget build(BuildContext context) {
    final h = _w / format.aspect;
    return FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(
        width: _w,
        height: h,
        child: MediaQuery.withNoTextScaling(
          child: sablon == 1 ? _kapak() : _kart(h),
        ),
      ),
    );
  }

  Widget _kapak() {
    return Stack(
      fit: StackFit.expand,
      children: [
        _cover(),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0.35, 1],
              colors: [Color(0x00000000), Color(0xD9080526)],
            ),
          ),
        ),
        Positioned(
          left: 26,
          right: 26,
          bottom: format == IgFormat.story ? 96 : 34,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'GEZİ ROTASI',
                  style: TextStyle(
                    fontSize: 10.5,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _baslik,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 30,
                  height: 1.1,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              if (_alt.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  _alt,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xE6FFFFFF),
                  ),
                ),
              ],
              const SizedBox(height: 22),
              _logo(Colors.white, 20),
            ],
          ),
        ),
      ],
    );
  }

  Widget _kart(double h) {
    final story = format == IgFormat.story;
    final duraklar = _duraklar.take(story ? 4 : 2).toList();
    return ColoredBox(
      color: AppColors.primary,
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, story ? 70 : 28, 24, story ? 70 : 24),
        child: Column(
          children: [
            _logo(Colors.white, 18),
            SizedBox(height: story ? 26 : 16),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: story ? 5 : 6, child: _cover()),
                    Expanded(
                      flex: story ? 6 : 5,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _baslik,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 22,
                                height: 1.15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                            if (_alt.isNotEmpty) ...[
                              const SizedBox(height: 5),
                              Text(
                                _alt,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            for (var i = 0; i < duraklar.length; i++)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 10,
                                      backgroundColor: AppColors.primary,
                                      child: Text(
                                        '${i + 1}',
                                        style: const TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 9),
                                    Expanded(
                                      child: Text(
                                        duraklar[i],
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.ink,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: story ? 22 : 14),
            const Text(
              'Rotanın tamamı Gezgah\u2019ta',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xCCFFFFFF),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 3) Kaydedildi
// ---------------------------------------------------------------------------

class _SavedSheet extends StatelessWidget {
  const _SavedSheet();

  Future<void> _openInstagram(BuildContext context) async {
    Navigator.pop(context);
    final app = Uri.parse('instagram://app');
    try {
      if (await launchUrl(app, mode: LaunchMode.externalApplication)) return;
    } catch (_) {}
    await launchUrl(
      Uri.parse('https://www.instagram.com/'),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _Grabber(),
          const SizedBox(height: 14),
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: Color(0x1A16A34A),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              size: 36,
              color: AppColors.open,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Görsel kaydedildi',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(32, 8, 32, 0),
            child: Text(
              'Galerinizdeki görseli Instagram\u2019da paylaşabilirsiniz.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                fontWeight: FontWeight.w500,
                color: AppColors.muted,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 4),
            child: _PrimaryButton(
              label: 'Instagram\u2019ı Aç',
              onPressed: () => _openInstagram(context),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
                foregroundColor: AppColors.primary,
              ),
              child: const Text(
                'Tamam',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
