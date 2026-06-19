import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../theme/app_theme.dart';

/// Hero başlığındaki daktilo (typewriter) efekti.
class Typewriter extends StatefulWidget {
  final List<String> phrases;
  final TextStyle style;
  const Typewriter({super.key, required this.phrases, required this.style});

  @override
  State<Typewriter> createState() => _TypewriterState();
}

class _TypewriterState extends State<Typewriter> {
  String _text = '';
  int _phrase = 0;
  int _char = 0;
  bool _deleting = false;
  Timer? _timer;
  bool _caretOn = true;
  Timer? _caretTimer;

  @override
  void initState() {
    super.initState();
    _tick();
    _caretTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() => _caretOn = !_caretOn);
    });
  }

  void _tick() {
    final current = widget.phrases[_phrase];
    Duration next;
    if (!_deleting) {
      _char++;
      _text = current.substring(0, _char);
      if (_char == current.length) {
        _deleting = true;
        next = const Duration(milliseconds: 1400);
      } else {
        next = const Duration(milliseconds: 90);
      }
    } else {
      _char--;
      _text = current.substring(0, _char);
      if (_char == 0) {
        _deleting = false;
        _phrase = (_phrase + 1) % widget.phrases.length;
        next = const Duration(milliseconds: 350);
      } else {
        next = const Duration(milliseconds: 45);
      }
    }
    if (mounted) setState(() {});
    _timer = Timer(next, _tick);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _caretTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: widget.style,
        children: [
          TextSpan(text: _text),
          TextSpan(
            text: '▏',
            style: widget.style.copyWith(
              color: _caretOn ? Colors.white : Colors.transparent,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

/// Sonsuz kayan kampanya şeridi (marquee).
class Marquee extends StatefulWidget {
  final List<String> items;
  const Marquee({super.key, required this.items});

  @override
  State<Marquee> createState() => _MarqueeState();
}

class _MarqueeState extends State<Marquee>
    with SingleTickerProviderStateMixin {
  late final ScrollController _controller = ScrollController();
  late final Ticker _ticker;
  double _offset = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    if (!_controller.hasClients) return;
    _offset += 0.5;
    final max = _controller.position.maxScrollExtent;
    if (_offset >= max) _offset = 0;
    _controller.jumpTo(_offset);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loop = [...widget.items, ...widget.items];
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: ListView.builder(
          controller: _controller,
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: loop.length,
          itemBuilder: (_, i) {
            return Row(
              children: [
                if (i == 0) const SizedBox(width: 16),
                Center(
                  child: Text(loop[i],
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text('•', style: TextStyle(color: AppColors.muted)),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
