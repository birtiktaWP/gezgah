import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Instagram tarzı yükleme iskeleti: altındaki [SkeletonBox]'lar tek bir
/// animasyonla birlikte yavaşça "nefes alır" (açık ↔ koyu gri). Spinner
/// yerine sayfa düzeninin taslağını gösterir; veri gelince yerini gerçek
/// içerik alır.
///
/// Erişilebilirlik: ekran okuyucuya tek bir "Yükleniyor" etiketi verilir,
/// iç kutular okunmaz.
class SkeletonPulse extends StatefulWidget {
  final Widget child;
  const SkeletonPulse({super.key, required this.child});

  @override
  State<SkeletonPulse> createState() => _SkeletonPulseState();
}

class _SkeletonPulseState extends State<SkeletonPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 850),
  )..repeat(reverse: true);

  late final Animation<double> _opacity = Tween<double>(
    begin: 1,
    end: 0.45,
  ).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Yükleniyor',
      excludeSemantics: true,
      child: FadeTransition(opacity: _opacity, child: widget.child),
    );
  }
}

/// Gri yer tutucu kutu. [width] verilmezse bulunduğu genişliği doldurur.
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;
  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.radius = 8,
  });

  static const Color color = Color(0xFFE9E9F0);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// İçi boş, kenarlıklı kart iskeleti (detaydaki beyaz kartların taslağı).
class SkeletonCard extends StatelessWidget {
  final double height;
  const SkeletonCard({super.key, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
    );
  }
}
