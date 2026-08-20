
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../data/home_config.dart';
import '../theme/app_theme.dart';

/// Ağ görseli için tutarlı placeholder/error davranışı olan sarmalayıcı.
class NetImage extends StatelessWidget {
  final String url;
  final BoxFit fit;
  const NetImage(this.url, {super.key, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    // Boş/geçersiz URL (API'de image: null olabilir) → doğrudan placeholder.
    if (url.trim().isEmpty) {
      return Container(
        color: const Color(0xFFEDEDF3),
        child: const Icon(Icons.image_not_supported_outlined,
            color: AppColors.muted),
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      fadeInDuration: const Duration(milliseconds: 250),
      placeholder: (c, _) => Container(color: const Color(0xFFEDEDF3)),
      errorWidget: (c, _, __) => Container(
        color: const Color(0xFFEDEDF3),
        child: const Icon(Icons.image_not_supported_outlined,
            color: AppColors.muted),
      ),
    );
  }
}

/// [url] görselini `NetImage` ile gösterir; [tag] verildiyse liste→detay
/// geçişinde akıcı büyüme için `Hero` ile sarmalar. [tag] null ise düz görsel
/// döner (Hero yok → aynı ekranda tag çakışması riski olmaz).
Widget heroImage(Object? tag, String url, {BoxFit fit = BoxFit.cover}) {
  // Hero (liste→detay) uçuş animasyonu iptal edildi: her zaman düz görsel.
  return NetImage(url, fit: fit);
}

/// "Gezgah" markası — HTML'deki orijinal SVG logo.
class GezgahWordmark extends StatelessWidget {
  final Color color;
  final double size; // logo yüksekliği (px)
  const GezgahWordmark({super.key, this.color = Colors.white, this.size = 30});

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/logo.svg',
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      semanticsLabel: 'Gezgah',
    );
  }
}

/// Kedy asistanı kedi ikonu — HTML'deki orijinal SVG.
class KedyIcon extends StatelessWidget {
  final double size;
  final Color color;
  const KedyIcon({super.key, this.size = 24, this.color = AppColors.primary});

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/kedy.svg',
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      semanticsLabel: 'Kedy',
    );
  }
}

/// Hero/flat header'lardaki cam efektli yuvarlak buton.
class GlassButton extends StatelessWidget {
  final IconData icon;
  final String? svg; // verilirse ikon yerine bu SVG çizilir
  final VoidCallback? onTap;
  final bool showDot;
  final bool flat; // beyaz zeminli (hero-flat) varyant

  const GlassButton({
    super.key,
    required this.icon,
    this.svg,
    this.onTap,
    this.showDot = false,
    this.flat = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: flat ? AppColors.primarySoft : Colors.white.withValues(alpha: 0.12),
              border: Border.all(
                color: flat ? Colors.transparent : Colors.white.withValues(alpha: 0.22),
              ),
            ),
            alignment: Alignment.center,
            child: svg != null
                ? SvgPicture.string(
                    svg!,
                    width: 19,
                    height: 19,
                    colorFilter: ColorFilter.mode(
                        flat ? AppColors.primary : Colors.white,
                        BlendMode.srcIn),
                  )
                : Icon(icon,
                    size: 19,
                    color: flat ? AppColors.primary : Colors.white),
          ),
          if (showDot)
            Positioned(
              top: 8,
              right: 9,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF5E7E),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: flat ? Colors.white : AppColors.primary, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// İkincil sayfa başlığı — kategori/favoriler sayfalarıyla aynı stil: beyaz
/// zemin, alt çizgi, SafeArea içeride (üstte gereksiz boşluk olmaz), geri
/// butonu + ortalı başlık + sağda aksiyonlar.
class PageHeader extends StatelessWidget {
  final String title;
  final List<Widget> actions;
  final VoidCallback? onBack;
  const PageHeader({
    super.key,
    required this.title,
    this.actions = const [],
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: const BoxDecoration(
        color: AppColors.bg,
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            GlassButton(
              icon: Icons.chevron_left,
              flat: true,
              onTap: onBack ?? () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: Center(
                child: Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary)),
              ),
            ),
            // Başlığı ortalı tutmak için: aksiyon yoksa sol butona denk boşluk.
            if (actions.isEmpty)
              const SizedBox(width: 40)
            else
              ...actions,
          ],
        ),
      ),
    );
  }
}

/// Bölüm başlığı + "Tümü >" bağlantısı.
class SectionHead extends StatelessWidget {
  final String title;
  final VoidCallback? onAll;
  const SectionHead(this.title, {super.key, this.onAll});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.3,
                    color: AppColors.ink)),
          ),
          if (onAll != null)
            GestureDetector(
              onTap: onAll,
              child: const Row(
                children: [
                  Text('Tümü',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary)),
                  Icon(Icons.chevron_right, size: 18, color: AppColors.primary),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Yatay kaydırılan kategori hapı.
class CategoryPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  /// Verilirse [icon] yerine bu widget çizilir (ör. özel gemi dümeni ikonu).
  /// Renk, [active] durumuna göre çağıran tarafından ayarlanmalıdır.
  final Widget? iconWidget;

  /// Verilirse [icon] yerine bu SVG çizilir (renk [active]'e göre uygulanır).
  final String? svg;

  const CategoryPill({
    super.key,
    required this.icon,
    required this.label,
    this.active = false,
    this.onTap,
    this.iconWidget,
    this.svg,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.fromLTRB(9, 8, 14, 8),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
              color: active ? AppColors.primary : AppColors.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: active
                    ? Colors.white.withValues(alpha: 0.2)
                    : AppColors.primarySoft,
              ),
              alignment: Alignment.center,
              child: iconWidget ??
                  (svg != null
                      ? SvgPicture.string(
                          svg!,
                          width: 15,
                          height: 15,
                          colorFilter: ColorFilter.mode(
                              active ? Colors.white : AppColors.primary,
                              BlendMode.srcIn),
                        )
                      : Icon(icon,
                          size: 15,
                          color: active ? Colors.white : AppColors.primary)),
            ),
            const SizedBox(width: 7),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: active ? Colors.white : AppColors.ink)),
          ],
        ),
      ),
    );
  }
}

/// Puan rozeti (yıldız + değer).
class RatingBadge extends StatelessWidget {
  final double rating;
  const RatingBadge(this.rating, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 13, color: AppColors.star),
          const SizedBox(width: 3),
          Text(rating.toStringAsFixed(1),
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink)),
        ],
      ),
    );
  }
}

/// Açık / Kapanıyor rozeti.
class OpenDot extends StatelessWidget {
  final bool open;
  const OpenDot({super.key, required this.open});

  @override
  Widget build(BuildContext context) {
    final color = open ? AppColors.open : AppColors.closing;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('● ',
              style: TextStyle(fontSize: 8, color: color)),
          Text(open ? 'Açık' : 'Kapanıyor',
              style: TextStyle(
                  fontSize: 10.5, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

/// Yuvarlak favori (kalp) butonu — kart görselleri üstünde.
class FavButton extends StatelessWidget {
  final bool active;
  final VoidCallback? onTap;
  final double size;
  const FavButton({super.key, required this.active, this.onTap, this.size = 30});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.92),
        ),
        child: Icon(
          active ? Icons.favorite : Icons.favorite_border,
          size: size * 0.5,
          color: active ? AppColors.heart : AppColors.primary,
        ),
      ),
    );
  }
}

// ===========================================================================
// Ortak giriş yardımcıları: telefon formatlayıcı + native seçiciler
// ===========================================================================

/// Türkiye cep telefonu formatlayıcı: yalnızca rakam kabul eder, en fazla 10
/// hane tutar ve otomatik olarak "532 123 45 67" biçiminde boşluk ekler.
class TrPhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    // Rakam dışını temizle ve 10 hane ile sınırla.
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 10) digits = digits.substring(0, 10);

    // 3-3-2-2 gruplama: 532 123 45 67
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i == 3 || i == 6 || i == 8) buf.write(' ');
      buf.write(digits[i]);
    }
    final text = buf.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// Picker sonucu — `null` (kullanıcı vazgeçti) ile `value == null`
/// (bilerek "belirtilmemiş" seçti) durumlarını ayırt etmek için sarmalar.
class PickerResult<T> {
  final T value;
  const PickerResult(this.value);
}

/// Cihazın kendi tarih seçicisini tetikler: iOS'ta CupertinoDatePicker
/// (tekerlek), diğer platformlarda Material [showDatePicker].
Future<DateTime?> showNativeDatePicker(
  BuildContext context, {
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  String? helpText,
}) {
  final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
  if (!isIOS) {
    return showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: helpText,
    );
  }

  var temp = initialDate;
  return showModalBottomSheet<DateTime>(
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
          _NativeSheetHeader(
            title: helpText ?? 'Tarih seç',
            onDone: () => Navigator.pop(ctx, temp),
          ),
          SizedBox(
            height: 220,
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.date,
              initialDateTime: initialDate,
              minimumDate: firstDate,
              maximumDate: lastDate,
              onDateTimeChanged: (d) => temp = d,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Cihazın kendi seçim tekerleğini/listesini tetikler: iOS'ta CupertinoPicker,
/// diğer platformlarda modal liste. Vazgeçilirse `null`, seçim yapılırsa
/// [PickerResult] döner.
Future<PickerResult<T>?> showNativePicker<T>(
  BuildContext context, {
  required String title,
  required List<(T, String)> options,
  T? selected,
}) {
  final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
  var index = options.indexWhere((o) => o.$1 == selected);
  if (index < 0) index = 0;

  if (isIOS) {
    var temp = index;
    return showModalBottomSheet<PickerResult<T>>(
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
            _NativeSheetHeader(
              title: title,
              onDone: () =>
                  Navigator.pop(ctx, PickerResult<T>(options[temp].$1)),
            ),
            SizedBox(
              height: 220,
              child: CupertinoPicker(
                scrollController:
                    FixedExtentScrollController(initialItem: index),
                itemExtent: 38,
                onSelectedItemChanged: (i) => temp = i,
                children: [
                  for (final o in options)
                    Center(
                      child: Text(o.$2,
                          style: const TextStyle(
                              fontSize: 17, color: AppColors.ink)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Android / diğer: modal liste (Material native davranış).
  return showModalBottomSheet<PickerResult<T>>(
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
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink)),
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final o in options)
                  ListTile(
                    title: Text(o.$2),
                    trailing: o.$1 == selected
                        ? const Icon(Icons.check, color: AppColors.primary)
                        : null,
                    onTap: () =>
                        Navigator.pop(ctx, PickerResult<T>(o.$1)),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// Native alt sayfa (bottom sheet) başlığı: Vazgeç / başlık / Tamam.
class _NativeSheetHeader extends StatelessWidget {
  final String title;
  final VoidCallback onDone;
  const _NativeSheetHeader({required this.title, required this.onDone});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Vazgeç',
                style: TextStyle(color: AppColors.muted)),
          ),
          Text(title,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink)),
          TextButton(
            onPressed: onDone,
            child: const Text('Tamam',
                style: TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

/// Kategori ikonu: API'den gelen [icon] (SVG markup veya emoji/metin) varsa
/// onu kullanır; yoksa id'ye göre [HomeConfig.iconFor] varsayılanına düşer.
class CategoryIcon extends StatelessWidget {
  final String? icon; // API: kategori_svg_icon (SVG markup ya da emoji)
  final int id; // yedek ikon için kategori id'si
  final double size;
  final Color color;
  const CategoryIcon({
    super.key,
    required this.icon,
    required this.id,
    this.size = 24,
    this.color = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    final ic = icon;
    if (ic != null && ic.isNotEmpty) {
      if (ic.contains('<svg')) {
        return SvgPicture.string(
          ic,
          width: size,
          height: size,
          colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
        );
      }
      // Emoji / metin ikon
      return Text(ic, style: TextStyle(fontSize: size * 0.9));
    }
    return Icon(HomeConfig.iconFor(id), size: size, color: color);
  }
}

/// Gemi dümeni (ship's wheel) ikonu — Material'da karşılığı olmadığı için
/// verilen rota (harita pinleri) SVG'siyle çizilir. Gezi Rotaları kısayolunda
/// kullanılır.
class ShipWheelIcon extends StatelessWidget {
  final double size;
  final Color color;
  const ShipWheelIcon(
      {super.key, this.size = 18, this.color = AppColors.primary});

  static const String _svg =
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 640 640"><path d="M516.1 228.2C504.4 246.9 491.1 264.7 480 278.6C468.9 264.7 455.6 246.9 443.9 228.2C426.1 199.7 416 175.3 416 160C416 124.7 444.7 96 480 96C515.3 96 544 124.7 544 160C544 175.2 533.9 199.7 516.1 228.2zM491.4 315C516.8 285.1 576 210.2 576 160C576 107 533 64 480 64C427 64 384 107 384 160C384 198.7 419 251.9 446.7 288L400 288C355.8 288 320 323.8 320 368C320 412.2 355.8 448 400 448L496 448C522.5 448 544 469.5 544 496C544 522.5 522.5 544 496 544L230 544C220.6 556.3 211.4 567.2 203.6 576L496 576C540.2 576 576 540.2 576 496C576 451.8 540.2 416 496 416L400 416C373.5 416 352 394.5 352 368C352 341.5 373.5 320 400 320L476.9 320C482 321.1 487.6 319.4 491.4 315zM196.2 481.2C184.5 499 171.1 515.7 160 528.6C148.9 515.7 135.5 499 123.8 481.2C105.9 454.3 96 431 96 416C96 380.7 124.7 352 160 352C195.3 352 224 380.7 224 416C224 431 214.1 454.3 196.2 481.2zM188.6 544.3C216.9 510.7 256 456.8 256 415.9C256 362.9 213 319.9 160 319.9C107 319.9 64 363 64 416C64 466.5 123.8 537 149 564.4C155 570.9 165 570.9 170.9 564.4C174 561 177.7 556.9 181.8 552.2C184 549.7 186.2 547.1 188.5 544.3zM504 160C504 146.7 493.3 136 480 136C466.7 136 456 146.7 456 160C456 173.3 466.7 184 480 184C493.3 184 504 173.3 504 160zM160 440C173.3 440 184 429.3 184 416C184 402.7 173.3 392 160 392C146.7 392 136 402.7 136 416C136 429.3 146.7 440 160 440z"/></svg>';

  @override
  Widget build(BuildContext context) {
    return SvgPicture.string(
      _svg,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}
