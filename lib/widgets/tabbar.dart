import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    return FloatingTabBarShell(
      barHeight: _barHeight,
      circle: _circle,
      onKedyTap: () => onTap(2),
      items: [
        TabItemData(Icons.home_outlined, 'Keşfet', activeIndex == 0,
            () => onTap(0)),
        TabItemData(Icons.search, 'Arama', activeIndex == 1, () => onTap(1)),
        null, // Kedy yuvası (boş; daire üstte konumlanır)
        TabItemData(Icons.calendar_today_outlined, 'Etkinlikler',
            activeIndex == 3, () => onTap(3)),
        TabItemData(Icons.person_outline, 'Hesabım', activeIndex == 4,
            () => onTap(4)),
      ],
    );
  }
}

class TabItemData {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const TabItemData(this.icon, this.label, this.active, this.onTap);
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
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
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
          Icon(data.icon, size: 22, color: color),
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
