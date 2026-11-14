import 'package:flutter/material.dart';

import '../navigation/main_nav.dart';
import '../theme/app_theme.dart';
import 'common.dart';
import 'tabbar.dart';

/// Hesabım altındaki liste sayfaları (Favorilerim tasarımı): üstte lacivert
/// başlık alanı, altta içerik, en altta yüzen footer.
class AccountPage extends StatelessWidget {
  final Widget body;
  const AccountPage({super.key, required this.body});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          body,
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: FloatingTabBar(
                activeIndex: 4,
                onTap: MainNav.instance.select,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Lacivert başlık alanı (geri + başlık + alt yazı) — [bottom] ile altına
/// sekme vb. eklenebilir.
class AccountHero extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? bottom;
  const AccountHero({
    super.key,
    required this.title,
    required this.subtitle,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 26),
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
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 13, color: Colors.white70),
            ),
            if (bottom != null) ...[const SizedBox(height: 16), bottom!],
          ],
        ),
      ),
    );
  }
}

/// Ortalanmış bilgi (boş / hata / yakında) kutusu.
class AccountInfo extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? action;
  final VoidCallback? onAction;
  const AccountInfo({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
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
                  action!,
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

/// Başlığın altında, içeriğin ortasında bilgi/yükleniyor gösterir.
class AccountCentered extends StatelessWidget {
  final Widget hero;
  final Widget child;
  const AccountCentered({super.key, required this.hero, required this.child});

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Column(
      children: [
        hero,
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: 85 + bottomInset),
            child: Center(child: child),
          ),
        ),
      ],
    );
  }
}

/// Küçük renkli durum rozeti.
class StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  const StatusChip(this.label, this.color, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

/// Alttan açılan panellerin üst tutamacı.
class SheetGrabber extends StatelessWidget {
  const SheetGrabber({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      margin: const EdgeInsets.only(top: 10, bottom: 8),
      width: 42,
      height: 4,
      decoration: BoxDecoration(
        color: AppColors.line,
        borderRadius: BorderRadius.circular(999),
      ),
    ),
  );
}

/// "14 Kas 2026" / "Cuma, 14 Kas · 20:00" biçimleri.
class TrTarih {
  static const _ay = [
    '', 'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz', //
    'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara',
  ];
  static const _gun = [
    '',
    'Pazartesi',
    'Salı',
    'Çarşamba',
    'Perşembe',
    'Cuma',
    'Cumartesi',
    'Pazar',
  ];

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String kisa(DateTime d) => '${d.day} ${_ay[d.month]} ${d.year}';

  static String saat(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

  static String uzun(DateTime d) =>
      '${_gun[d.weekday]}, ${d.day} ${_ay[d.month]} · ${saat(d)}';

  /// API biçimi "YYYY-MM-DDTHH:MM" (yerel saat).
  static String api(DateTime d) =>
      '${d.year}-${_two(d.month)}-${_two(d.day)}T${saat(d)}';
}
