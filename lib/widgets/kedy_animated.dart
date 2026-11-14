import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Hareketli Kedy kedisi — `kedi-animasyon.svg`'nin (proje kökü) Flutter
/// karşılığı. flutter_svg SMIL (`<animate>`) ve CSS `@keyframes`
/// animasyonlarını oynatmadığı için aynı yollar, anahtar kareler ve
/// yumuşatma eğrileri burada birebir çizilir:
///
/// - kuyruk sallanır (5 sn), sırt nefes alır (3,6 sn),
/// - ön pati ağza kalkar, kedi patisini yalar (18 sn döngü; dil görünür,
///   gözler keyifle kısılır, baş eğilir),
/// - kulak seğirir (7 sn), gözler kırpılır (5,2 sn) ve yana bakar (11 sn).
///
/// Çizgi rengi [color] (SVG'de #1E3256); dil pembe kalır. Sistemde
/// "animasyonları azalt" açıksa ilk kare durağan çizilir.
class AnimatedKedy extends StatefulWidget {
  final double size;
  final Color color;
  final bool animate;

  const AnimatedKedy({
    super.key,
    required this.size,
    required this.color,
    this.animate = true,
  });

  @override
  State<AnimatedKedy> createState() => _AnimatedKedyState();
}

class _AnimatedKedyState extends State<AnimatedKedy>
    with SingleTickerProviderStateMixin {
  final ValueNotifier<double> _seconds = ValueNotifier<double>(0);
  late final Ticker _ticker = createTicker(
    (elapsed) => _seconds.value = elapsed.inMicroseconds / 1e6,
  );

  bool get _shouldRun =>
      widget.animate && !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(AnimatedKedy oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (_shouldRun) {
      if (!_ticker.isActive) _ticker.start();
    } else {
      if (_ticker.isActive) _ticker.stop();
      _seconds.value = 0;
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _seconds.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Kedy',
      image: true,
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.square(widget.size),
          painter: _KedyPainter(_seconds, widget.color),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Anahtar kare izleri (SVG'deki dur / keyTimes / values / keySplines)
// ---------------------------------------------------------------------------

/// SVG `keySplines=".4 0 .6 1"` ve `.45 0 .55 1`.
const Curve _s46 = Cubic(.4, 0, .6, 1);
const Curve _s4555 = Cubic(.45, 0, .55, 1);

/// Bir sayı dizisini (yol koordinatları, açı…) zamana göre ara değerler.
/// [curves] null ise doğrusal (SVG varsayılanı `calcMode="linear"`); tek eğri
/// verilirse tüm aralıklarda o kullanılır.
class _Track {
  final double dur;
  final List<double> keyTimes;
  final List<List<double>> values;
  final Curve? curve;

  const _Track(this.dur, this.keyTimes, this.values, {this.curve});

  List<double> at(double seconds) {
    final t = (seconds % dur) / dur;
    var i = 0;
    while (i < keyTimes.length - 2 && t >= keyTimes[i + 1]) {
      i++;
    }
    final a = values[i];
    final b = values[i + 1];
    final span = keyTimes[i + 1] - keyTimes[i];
    var f = span <= 0 ? 1.0 : ((t - keyTimes[i]) / span).clamp(0.0, 1.0);
    if (curve != null) f = curve!.transform(f);
    return [for (var k = 0; k < a.length; k++) a[k] + (b[k] - a[k]) * f];
  }
}

/// SVG yol metnindeki sayılar (komut yapısı her karede aynı).
List<double> _n(String d) => RegExp(r'-?\d*\.?\d+')
    .allMatches(d)
    .map((m) => double.parse(m.group(0)!))
    .toList();

// Kuyruk: "M x y C x y x y x y C x y x y x y".
final _tail = _Track(
  5,
  const [0, .22, .45, .72, 1],
  [
    _n('M112 470 C112 400 112 300 112 245 C112 205 85 177 45 177'),
    _n('M112 470 C112 400 117 310 123 250 C129 205 110 166 70 160'),
    _n('M112 470 C112 400 112 300 112 245 C112 205 85 177 45 177'),
    _n('M112 470 C112 400 108 300 100 250 C92 210 62 196 32 206'),
    _n('M112 470 C112 400 112 300 112 245 C112 205 85 177 45 177'),
  ],
  curve: _s46,
);

// Sırt: "M x y C x y x y x y".
final _back = _Track(
  3.6,
  const [0, .5, 1],
  [
    _n('M112 400 C112 300 220 237 338 237'),
    _n('M112 400 C109 292 216 229 338 236'),
    _n('M112 400 C112 300 220 237 338 237'),
  ],
  curve: _s4555,
);

// Karın çizgisi + ön bacak: "M L L L A(rx ry rot large sweep x y) L L".
final _legA = _n(
  'M296 494 L441 395 L441 450 L441 528 A28 28 0 0 0 497 528 L497 400 L497 300',
);
final _legB = _n(
  'M296 494 L450 410 L497 425 L583 351 A28 28 0 0 0 546 308 L474 372 L497 300',
);
final _legC = _n(
  'M296 494 L450 410 L497 427 L577 359 A28 28 0 0 0 540 316 L473 374 L497 300',
);
final _leg = _Track(
  18,
  const [
    0, .5722, .6111, .6389, .6611, .6833, .7056, //
    .7278, .75, .7722, .8, .8389, 1,
  ],
  [
    _legA, _legA, _legB, _legC, _legB, _legC, _legB, //
    _legC, _legB, _legC, _legB, _legA, _legA,
  ],
  curve: _s46,
);

// Baş: (448, 300) etrafında dönüş (derece).
const _headRotate = _Track(
  18,
  [
    0, .1111, .1444, .2444, .2778, .3333, .3667, .4556, .4889, .5833, .6167, //
    .6389, .6611, .6833, .7056, .7278, .75, .7722, .7944, .8278, 1,
  ],
  [
    [0], [0], [-4], [-4], [0], [0], [3], [3], [0], [0], [10], //
    [12], [8], [12], [8], [12], [8], [12], [10], [0], [0],
  ],
  curve: _s46,
);

// Baş çizgisi (kulak seğirmesi): "M L L L L A(...) Z", doğrusal.
final _headBase = _n(
  'M336 45 L415 110 L482 110 L560 45 L560 195 A112 112 0 0 1 336 195 Z',
);
final _head = _Track(
  7,
  const [0, .30, .32, .34, .36, .38, .74, .76, .78, 1],
  [
    _headBase,
    _headBase,
    _n('M336 45 L415 110 L482 110 L574 58 L560 195 A112 112 0 0 1 336 195 Z'),
    _headBase,
    _n('M336 45 L415 110 L482 110 L572 56 L560 195 A112 112 0 0 1 336 195 Z'),
    _headBase,
    _headBase,
    _n('M322 58 L415 110 L482 110 L560 45 L560 195 A112 112 0 0 1 336 195 Z'),
    _headBase,
    _headBase,
  ],
);

// Dil: yalnız yalanırken görünür (doğrusal) ve hızlıca gidip gelir.
const _tongueOpacity = _Track(
  18,
  [0, .6167, .625, .7861, .7944, 1],
  [[0], [0], [1], [1], [0], [0]],
);
const _tongueShift = _Track(
  .8,
  [0, .5, 1],
  [[-4, -5], [4, 5], [-4, -5]],
  curve: _s46,
);

// Yalanırken gözler kısılır: translate(0, ty) + scale(1, sy).
const _squint = _Track(
  18,
  [0, .6056, .6222, .7889, .8111, 1],
  [[0, 1], [0, 1], [148.2, .22], [148.2, .22], [0, 1], [0, 1]],
  curve: _s46,
);

/// CSS `@keyframes`: her aralıkta ayrı zamanlama eğrisi uygulanır.
/// `look` (11 sn, ease-in-out): gözler sola kayıp döner.
const _look = _Track(
  11,
  [0, .52, .56, .68, .72, 1],
  [[0], [0], [-9], [-9], [0], [0]],
  curve: Curves.easeInOut,
);

/// `blink` (5,2 sn, varsayılan `ease`): göz merkezinde dikey ölçek.
const _blink = _Track(
  5.2,
  [0, .43, .45, .47, .88, .892, .905, .918, .93, 1],
  [[1], [1], [.08], [1], [1], [.08], [1], [.08], [1], [1]],
  curve: Curves.ease,
);

// ---------------------------------------------------------------------------

class _KedyPainter extends CustomPainter {
  final ValueNotifier<double> seconds;
  final Color color;

  _KedyPainter(this.seconds, this.color) : super(repaint: seconds);

  static const double _box = 640; // SVG viewBox 0 0 640 640
  static const double _stroke = 28;
  static const Color _tongue = Color(0xFFEE8FA0);

  @override
  void paint(Canvas canvas, Size size) {
    final s = seconds.value;
    final scale = math.min(size.width, size.height) / _box;
    canvas.save();
    canvas.translate(
      (size.width - _box * scale) / 2,
      (size.height - _box * scale) / 2,
    );
    canvas.scale(scale);

    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      // Küçük boyutlarda (sekme çubuğu, sohbet avatarı) çizgi 1,4 px'in
      // altına inmesin; büyükte SVG'deki kalınlık.
      ..strokeWidth = math.max(_stroke, 1.4 / scale)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    // Kuyruk.
    final t = _tail.at(s);
    canvas.drawPath(
      Path()
        ..moveTo(t[0], t[1])
        ..cubicTo(t[2], t[3], t[4], t[5], t[6], t[7])
        ..cubicTo(t[8], t[9], t[10], t[11], t[12], t[13]),
      line,
    );

    // Sırt.
    final b = _back.at(s);
    canvas.drawPath(
      Path()
        ..moveTo(b[0], b[1])
        ..cubicTo(b[2], b[3], b[4], b[5], b[6], b[7]),
      line,
    );

    // Gövde altı ve arka bacak (durağan):
    // M112 380 V490 A70 70 0 0 0 182 560 H348 A31.5 31.5 0 0 0 348 497
    // H285 V455 A55 55 0 0 0 230 400 H222
    canvas.drawPath(
      Path()
        ..moveTo(112, 380)
        ..lineTo(112, 490)
        ..arcToPoint(
          const Offset(182, 560),
          radius: const Radius.circular(70),
          clockwise: false,
        )
        ..lineTo(348, 560)
        ..arcToPoint(
          const Offset(348, 497),
          radius: const Radius.circular(31.5),
          clockwise: false,
        )
        ..lineTo(285, 497)
        ..lineTo(285, 455)
        ..arcToPoint(
          const Offset(230, 400),
          radius: const Radius.circular(55),
          clockwise: false,
        )
        ..lineTo(222, 400),
      line,
    );

    // Karın + ön bacak (pati ağza kalkar).
    final l = _leg.at(s);
    canvas.drawPath(
      Path()
        ..moveTo(l[0], l[1])
        ..lineTo(l[2], l[3])
        ..lineTo(l[4], l[5])
        ..lineTo(l[6], l[7])
        ..arcToPoint(
          Offset(l[13], l[14]),
          radius: Radius.elliptical(l[8], l[9]),
          rotation: l[10],
          largeArc: l[11] > .5,
          clockwise: l[12] > .5,
        )
        ..lineTo(l[15], l[16])
        ..lineTo(l[17], l[18]),
      line,
    );

    // Baş grubu: (448, 300) etrafında döner.
    canvas.save();
    canvas.translate(448, 300);
    canvas.rotate(_headRotate.at(s)[0] * math.pi / 180);
    canvas.translate(-448, -300);

    // Dil (başın arkasında, yalnız yalanırken).
    final op = _tongueOpacity.at(s)[0];
    if (op > 0.001) {
      final sh = _tongueShift.at(s);
      canvas.save();
      canvas.translate(sh[0], sh[1]);
      canvas.translate(529, 291.5);
      canvas.rotate(50 * math.pi / 180);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 40, height: 22),
        Paint()..color = _tongue.withValues(alpha: op),
      );
      canvas.restore();
    }

    // Baş çizgisi (kulak seğirir).
    final h = _head.at(s);
    canvas.drawPath(
      Path()
        ..moveTo(h[0], h[1])
        ..lineTo(h[2], h[3])
        ..lineTo(h[4], h[5])
        ..lineTo(h[6], h[7])
        ..lineTo(h[8], h[9])
        ..arcToPoint(
          Offset(h[15], h[16]),
          radius: Radius.elliptical(h[10], h[11]),
          rotation: h[12],
          largeArc: h[13] > .5,
          clockwise: h[14] > .5,
        )
        ..close(),
      line,
    );

    // Gözler: kısılma (translate + scale) → yana bakma → kırpma.
    final q = _squint.at(s);
    final lookX = _look.at(s)[0];
    final blink = _blink.at(s)[0];
    final eye = Paint()..color = color;
    canvas.save();
    canvas.translate(0, q[0]);
    canvas.scale(1, q[1]);
    canvas.translate(lookX, 0);
    for (final cx in const [408.0, 490.0]) {
      canvas.save();
      canvas.translate(cx, 190);
      canvas.scale(1, blink);
      canvas.drawCircle(Offset.zero, 20, eye);
      canvas.restore();
    }
    canvas.restore();

    canvas.restore(); // baş
    canvas.restore(); // viewBox
  }

  @override
  bool shouldRepaint(_KedyPainter old) =>
      old.color != color || old.seconds != seconds;
}
