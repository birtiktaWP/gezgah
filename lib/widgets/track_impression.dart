import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../data/view_tracker.dart';

/// Çocuğu (mekan kartı) ekranda en az [minFraction] oranında, kesintisiz
/// [minDuration] boyunca görünürse [scope] üzerinden bir kez `liste`
/// görüntülenmesi kaydeder (GORUNTULENME.md §2). Kart hızlı kaydırılıp
/// geçilirse ya da üstüne başka sayfa açılırsa sayılmaz.
class TrackImpression extends StatefulWidget {
  final ImpressionScope scope;
  final int placeId;
  final int? position;
  final bool featured;
  final Widget child;

  static const double minFraction = 0.5;
  static const Duration minDuration = Duration(seconds: 1);

  const TrackImpression({
    super.key,
    required this.scope,
    required this.placeId,
    required this.child,
    this.position,
    this.featured = false,
  });

  @override
  State<TrackImpression> createState() => _TrackImpressionState();
}

class _TrackImpressionState extends State<TrackImpression> {
  Timer? _timer;

  void _onVisibility(VisibilityInfo info) {
    if (!mounted || widget.scope.hasSeen(widget.placeId)) return;
    if (info.visibleFraction >= TrackImpression.minFraction) {
      _timer ??= Timer(TrackImpression.minDuration, () {
        _timer = null;
        if (!mounted) return;
        widget.scope.seen(
          widget.placeId,
          sira: widget.position,
          oneCikan: widget.featured,
        );
      });
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.placeId <= 0) return widget.child;
    return VisibilityDetector(
      key: ValueKey(
        'imp:${identityHashCode(widget.scope)}:${widget.placeId}:${widget.featured}',
      ),
      onVisibilityChanged: _onVisibility,
      child: widget.child,
    );
  }
}
