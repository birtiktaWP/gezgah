import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Favoriye eklerken küçük konfeti patlaması + hafif titreşim.
void celebrateFavorite(BuildContext context) {
  HapticFeedback.mediumImpact();
  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return;
  final size = MediaQuery.of(context).size;
  final origin = Offset(size.width / 2, size.height * 0.4);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _ConfettiBurst(origin: origin, onDone: () => entry.remove()),
  );
  overlay.insert(entry);
}

class _ConfettiBurst extends StatefulWidget {
  final Offset origin;
  final VoidCallback onDone;
  const _ConfettiBurst({required this.origin, required this.onDone});

  @override
  State<_ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<_ConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 950),
  );
  late final List<_Particle> _particles;

  static const _colors = [
    Color(0xFF120C63),
    Color(0xFFFF3D6E),
    Color(0xFFFFC24B),
    Color(0xFF35C77B),
    Color(0xFF4B9BFF),
  ];

  @override
  void initState() {
    super.initState();
    final r = Random();
    _particles = List.generate(26, (_) {
      final angle = -pi / 2 + (r.nextDouble() - 0.5) * pi * 1.1;
      return _Particle(
        angle: angle,
        speed: 120 + r.nextDouble() * 190,
        color: _colors[r.nextInt(_colors.length)],
        size: 5 + r.nextDouble() * 6,
        rot: r.nextDouble() * pi,
        rotSpeed: (r.nextDouble() - 0.5) * 12,
      );
    });
    _c.forward().whenComplete(widget.onDone);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => CustomPaint(
          size: Size.infinite,
          painter: _ConfettiPainter(_c.value, _particles, widget.origin),
        ),
      ),
    );
  }
}

class _Particle {
  final double angle;
  final double speed;
  final Color color;
  final double size;
  final double rot;
  final double rotSpeed;
  const _Particle({
    required this.angle,
    required this.speed,
    required this.color,
    required this.size,
    required this.rot,
    required this.rotSpeed,
  });
}

class _ConfettiPainter extends CustomPainter {
  final double t; // 0..1
  final List<_Particle> particles;
  final Offset origin;
  const _ConfettiPainter(this.t, this.particles, this.origin);

  @override
  void paint(Canvas canvas, Size size) {
    const gravity = 520.0;
    final paint = Paint();
    for (final p in particles) {
      final dx = cos(p.angle) * p.speed * t;
      final dy = sin(p.angle) * p.speed * t + 0.5 * gravity * t * t;
      final pos = origin + Offset(dx, dy);
      final opacity = (1 - t).clamp(0.0, 1.0);
      paint.color = p.color.withValues(alpha: opacity);
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(p.rot + p.rotSpeed * t);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6),
          const Radius.circular(1.5),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
