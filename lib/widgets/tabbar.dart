import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/app_theme.dart';
import 'common.dart';

/// Yüzen alt navigasyon — ortada öne çıkan "Kedy" yuvarlak butonu.
/// Tüm öğeler eşit genişlikte (5 Expanded) ve yatayda tam ortalanmış;
/// Kedy dairesi yatayda tam merkezde, dengeli şekilde bar'ın üstüne taşar.
class FloatingTabBar extends StatelessWidget {
  final int activeIndex; // 0 Keşfet, 1 Ara, 3 Etkinlik, 4 Hesabım (2 = Kedy)
  final ValueChanged<int> onTap;

  const FloatingTabBar({
    super.key,
    required this.activeIndex,
    required this.onTap,
  });

  static const double _barHeight = 67;
  static const double _circle = 52;

  // Footer sekme ikonları (Font Awesome). currentColor yerine renk,
  // _TabItem'da colorFilter ile uygulanır.
  static const String _svgHome =
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512"><path d="M245.6 4.3c6.1-5.7 15.7-5.7 21.8 0l240 224c6.5 6 6.8 16.2 .8 22.6s-16.2 6.8-22.6 .8l-21.1-19.7 0 216c0 35.3-28.7 64-64 64l-288 0c-35.3 0-64-28.7-64-64l0-216-21.1 19.7c-6.5 6-16.6 5.7-22.6-.8s-5.7-16.6 .8-22.6l240-224zm10.9 33.6l-176 164.3 0 245.8c0 17.7 14.3 32 32 32l64 0 0-112c0-35.3 28.7-64 64-64l32 0c35.3 0 64 28.7 64 64l0 112 64 0c17.7 0 32-14.3 32-32l0-245.8-176-164.3zM208.5 480l96 0 0-112c0-17.7-14.3-32-32-32l-32 0c-17.7 0-32 14.3-32 32l0 112z"/></svg>';
  static const String _svgSearch =
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512"><path d="M384 208a176 176 0 1 0 -352 0 176 176 0 1 0 352 0zM343.3 366C307 397.2 259.7 416 208 416 93.1 416 0 322.9 0 208S93.1 0 208 0 416 93.1 416 208c0 51.7-18.8 99-50 135.3L507.3 484.7c6.2 6.2 6.2 16.4 0 22.6s-16.4 6.2-22.6 0L343.3 366z"/></svg>';
  /// Etkinlik ikonu (Font Awesome). Detay sayfası footer'ı da aynı ikonu
  /// kullanabilsin diye herkese açık.
  static const String svgEvent =
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512"><path d="M40.5 32a24 24 0 1 1 48 0 24 24 0 1 1 -48 0zm416 128a24 24 0 1 1 48 0 24 24 0 1 1 -48 0zm24 264a24 24 0 1 1 0 48 24 24 0 1 1 0-48zM475.8 36.7c6.2 6.2 6.2 16.4 0 22.6l-19 19C445.5 89.6 430.1 96 414.1 96l-11 0c-14 0-23.8 13.7-19.4 26.9 11.3 34-14 69.1-49.8 69.1l-11 0c-7.5 0-14.8 3-20.1 8.3l-19 19c-6.2 6.2-16.4 6.2-22.6 0s-6.2-16.4 0-22.6l19-19c11.3-11.3 26.7-17.7 42.7-17.7l11 0c14 0 23.8-13.7 19.4-26.9-11.3-34 14-69.1 49.8-69.1l11 0c7.5 0 14.8-3 20.1-8.3l19-19c6.2-6.2 16.4-6.2 22.6 0zM240.5 32l0 24.2c0 29.7-11.8 58.2-32.8 79.2l-19.9 19.9c-6.2 6.2-16.4 6.2-22.6 0s-6.2-16.4 0-22.6l19.9-19.9c15-15 23.4-35.4 23.4-56.6l0-24.2c0-8.8 7.2-16 16-16s16 7.2 16 16zM89.3 212.3c7.2-22.9 36.2-30 53.1-13L313.2 370.1c17 17 9.9 45.9-13 53.1L50.7 502c-24.7 7.8-48-15.4-40.2-40.2L89.3 212.3zM290.5 392.7l-170.7-170.7-16 50.7 4 4 128 128 4 4 50.7-16zm-85.1 26.9l-112.5-112.5-19.9 62.9 2.7 2.7 64 64 2.7 2.7 62.9-19.9zM41 471.5l67.1-21.2-45.9-45.9-21.2 67.1zM496.5 288c0 8.8-7.2 16-16 16l-24.2 0c-21.2 0-41.6 8.4-56.6 23.4l-19.9 19.9c-6.2 6.2-16.4 6.2-22.6 0s-6.2-16.4 0-22.6l19.9-19.9c21-21 49.5-32.8 79.2-32.8l24.2 0c8.8 0 16 7.2 16 16z"/></svg>';
  static const String _svgAccount =
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 448 512"><path d="M128 128a96 96 0 1 1 192 0 96 96 0 1 1 -192 0zm224 0a128 128 0 1 0 -256 0 128 128 0 1 0 256 0zM32 480c0-79.5 64.5-144 144-144l96 0c79.5 0 144 64.5 144 144l0 16c0 8.8 7.2 16 16 16s16-7.2 16-16l0-16c0-97.2-78.8-176-176-176l-96 0C78.8 304 0 382.8 0 480l0 16c0 8.8 7.2 16 16 16s16-7.2 16-16l0-16z"/></svg>';

  @override
  Widget build(BuildContext context) {
    return FloatingTabBarShell(
      barHeight: _barHeight,
      circle: _circle,
      onKedyTap: () => onTap(2),
      items: [
        TabItemData(Icons.home_outlined, 'Ana Sayfa', activeIndex == 0,
            () => onTap(0),
            svg: _svgHome),
        TabItemData(Icons.search, 'Arama', activeIndex == 1, () => onTap(1),
            svg: _svgSearch),
        null, // Kedy yuvası (boş; daire üstte konumlanır)
        TabItemData(Icons.calendar_today_outlined, 'Etkinlikler',
            activeIndex == 3, () => onTap(3),
            svg: svgEvent),
        TabItemData(Icons.person_outline, 'Hesabım', activeIndex == 4,
            () => onTap(4),
            svg: _svgAccount),
      ],
    );
  }
}

class TabItemData {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final double iconSize;
  final String? svg; // verilirse ikon yerine bu SVG çizilir
  const TabItemData(this.icon, this.label, this.active, this.onTap,
      {this.iconSize = 22, this.svg});
}

/// Tab bar iskeleti — hem ana hem detay bar'ında ortak kullanılır.
class FloatingTabBarShell extends StatelessWidget {
  final List<TabItemData?> items; // 5 öğe; ortadaki (index 2) null = Kedy
  final VoidCallback onKedyTap;
  final double barHeight;
  final double circle;

  const FloatingTabBarShell({
    super.key,
    required this.items,
    required this.onKedyTap,
    this.barHeight = 67,
    this.circle = 52,
  });

  @override
  Widget build(BuildContext context) {
    // Dış yükseklik: bar + dairenin yarısı (üste taşan kısım)
    final outerHeight = barHeight + circle / 2;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 404),
        child: SizedBox(
          height: outerHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Navy bar (alt kısım)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: barHeight,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: AppShadows.tabbar,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: items
                        .map((it) => Expanded(
                              child: it == null
                                  ? const _KedyLabelSlot()
                                  : _TabItem(data: it),
                            ))
                        .toList(),
                  ),
                ),
              ),
              // Kedy dairesi — yatayda tam merkez, dikeyde dengeli taşma
              Positioned(
                top: 9,
                left: 0,
                right: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: onKedyTap,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: circle,
                      height: circle,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: AppColors.primary, width: 4),
                        boxShadow: const [
                          BoxShadow(
                              color: Color(0x47000000),
                              blurRadius: 18,
                              offset: Offset(0, 8)),
                        ],
                      ),
                      child: const Center(child: KedyIcon(size: 26)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Normal sekme: ikon + etiket + aktif noktası (hepsi eşit yükseklikte).
class _TabItem extends StatelessWidget {
  final TabItemData data;
  const _TabItem({required this.data});

  @override
  Widget build(BuildContext context) {
    final color =
        data.active ? Colors.white : Colors.white.withValues(alpha: 0.6);
    return GestureDetector(
      onTap: data.onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          data.svg != null
              ? SvgPicture.string(
                  data.svg!,
                  width: data.iconSize,
                  height: data.iconSize,
                  colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
                )
              : Icon(data.icon, size: data.iconSize, color: color),
          const SizedBox(height: 4),
          Text(data.label,
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

/// Kedy yuvası: dairenin altında, diğer etiketlerle aynı hizada "Kedy" yazısı.
class _KedyLabelSlot extends StatelessWidget {
  const _KedyLabelSlot();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        SizedBox(height: 22), // ikon alanı (daire üstte konumlanıyor)
        SizedBox(height: 4),
        Text('Kedy',
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Colors.white)),
      ],
    );
  }
}
