
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

  /// API'den gelen SVG'yi çizilebilir hale getirir.
  ///
  /// Bazı kayıtlarda (ör. Meyhane) `</svg>` kapanışından **sonra** başka bir
  /// ikonun parçası yapıştırılmış geliyor. Bu, XML'i geçersiz kıldığı için
  /// flutter_svg hiç çizemiyor ve ikon kayboluyor. Burada kök `<svg>` bloğu
  /// dışındaki artıklar atılır; kaynak veri düzeltilene kadar ikon görünür.
  static String? sanitizeSvg(String raw) {
    final start = raw.indexOf('<svg');
    if (start < 0) return null;
    final end = raw.indexOf('</svg>', start);
    if (end < 0) return null;
    return raw.substring(start, end + '</svg>'.length);
  }

  @override
  Widget build(BuildContext context) {
    final ic = icon;
    if (ic != null && ic.isNotEmpty) {
      if (ic.contains('<svg')) {
        final svg = sanitizeSvg(ic);
        if (svg != null) {
          return SvgPicture.string(
            svg,
            width: size,
            height: size,
            colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
          );
        }
        // Bozuk/eksik SVG → yedek ikona düş.
        return Icon(HomeConfig.iconFor(id), size: size, color: color);
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
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512"><path d="M452.1 164.2c-11.7 18.7-25 36.5-36.1 50.4-11.1-13.9-24.4-31.7-36.1-50.4-17.8-28.5-27.9-52.9-27.9-68.2 0-35.3 28.7-64 64-64s64 28.7 64 64c0 15.2-10.1 39.7-27.9 68.2zM427.4 251c25.4-29.9 84.6-104.8 84.6-155 0-53-43-96-96-96s-96 43-96 96c0 38.7 35 91.9 62.7 128L336 224c-44.2 0-80 35.8-80 80s35.8 80 80 80l96 0c26.5 0 48 21.5 48 48s-21.5 48-48 48l-266 0c-9.4 12.3-18.6 23.2-26.4 32L432 512c44.2 0 80-35.8 80-80s-35.8-80-80-80l-96 0c-26.5 0-48-21.5-48-48s21.5-48 48-48l76.9 0c5.1 1.1 10.7-.6 14.5-5zM132.2 417.2C120.5 435 107.1 451.7 96 464.6 84.9 451.7 71.5 435 59.8 417.2 41.9 390.3 32 367 32 352 32 316.7 60.7 288 96 288s64 28.7 64 64c0 15-9.9 38.3-27.8 65.2zm-7.6 63.1c28.3-33.6 67.4-87.5 67.4-128.4 0-53-43-96-96-96S0 299 0 352c0 50.5 59.8 121 85 148.4 6 6.5 16 6.5 21.9 0 3.1-3.4 6.8-7.5 10.9-12.2 2.2-2.5 4.4-5.1 6.7-7.9zM440 96a24 24 0 1 0 -48 0 24 24 0 1 0 48 0zM96 376a24 24 0 1 0 0-48 24 24 0 1 0 0 48z"/></svg>';

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
