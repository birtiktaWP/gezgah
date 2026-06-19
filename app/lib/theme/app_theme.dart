import 'package:flutter/material.dart';

/// Gezgah tasarım sistemi — HTML/CSS mockup'larındaki :root değişkenlerinden türetildi.
class AppColors {
  static const Color primary = Color(0xFF120C63); // rgb(18,12,99)
  static const Color primary2 = Color(0xFF281E96); // rgb(40,30,150)
  static const Color primarySoft = Color(0x12120C63); // rgba(18,12,99,0.07)
  static const Color primarySoft2 = Color(0x1F120C63); // rgba(18,12,99,0.12)

  static const Color bg = Color(0xFFFFFFFF);
  static const Color pageBg = Color(0xFFE9EAF2);
  static const Color ink = Color(0xFF14132B);
  static const Color muted = Color(0xFF7A7A8C);
  static const Color line = Color(0xFFECECF3);
  static const Color star = Color(0xFFFFC24B);

  static const Color open = Color(0xFF16A34A);
  static const Color closing = Color(0xFFE0533D);
  static const Color heart = Color(0xFFFF3D6E);
}

class AppRadius {
  static const double card = 22;
  static const double tile = 18;
  static const double pill = 999;
}

class AppTheme {
  static ThemeData get light {
    const family = 'gez_gah';
    const fallback = ['gez_gah_ext', 'gez_gah_viet'];

    final base = ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.pageBg,
      fontFamily: family,
      fontFamilyFallback: fallback,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        surface: AppColors.bg,
      ),
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.ink,
        displayColor: AppColors.ink,
      ),
      splashFactory: InkRipple.splashFactory,
    );
  }
}

/// Ortak gölge tanımları
class AppShadows {
  static const List<BoxShadow> search = [
    BoxShadow(
      color: Color(0x29120C63), // rgba(18,12,99,.16)
      blurRadius: 30,
      offset: Offset(0, 14),
    ),
  ];

  static const List<BoxShadow> tabbar = [
    BoxShadow(
      color: Color(0x66120C63), // rgba(18,12,99,.4)
      blurRadius: 34,
      offset: Offset(0, 16),
    ),
  ];

  static const List<BoxShadow> listTile = [
    BoxShadow(
      color: Color(0x12120C63), // rgba(18,12,99,.07)
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> soft = [
    BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 14,
      offset: Offset(0, 4),
    ),
  ];
}
