import 'package:flutter/material.dart';
import '../data/mock_data.dart';
import 'common.dart';

/// Kedy yapay zeka asistanı — alttan açılan tam yükseklikli sohbet paneli.
/// Tasarım: tasarim/index.html içindeki koyu (siyah) temalı chatbot paneli.
Future<void> showKedyChat(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (_) => const _KedyChatSheet(),
  );
}

/// Chatbot paneline özel koyu tema renkleri (CSS'teki .chatbot değerleri).
class _K {
  static const Color bg = Color(0xFF000000);
  static const Color headLine = Color(0xFF1C1C1C);
  static const Color muted = Color(0xFF9A9A9A);
  static const Color dot = Color(0xFF16A34A);
  static const Color closeBg = Color(0xFF161616);
  static const Color botText = Color(0xFFF2F2F2);
  static const Color meBubble = Color(0xFF2B2B2B);
  static const Color chip = Color(0xFF232323);
  static const Color placeholder = Color(0xFF8A8A8A);

  // Input gradyan kenarlığı (CSS: #7db7ff, #2f7bff, #0a2a8c, #1e57d6, #7db7ff)
  static const List<Color> inputGradient = [
    Color(0xFF7DB7FF),
    Color(0xFF2F7BFF),
    Color(0xFF0A2A8C),
    Color(0xFF1E57D6),
    Color(0xFF7DB7FF),
  ];
}

class _KedyChatSheet extends StatefulWidget {
  const _KedyChatSheet();

  @override
  State<_KedyChatSheet> createState() => _KedyChatSheetState();
}

class _Message {
  final String text;
  final bool me;
  _Message(this.text, this.me);
}

class _KedyChatSheetState extends State<_KedyChatSheet> {
  final List<_Message> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scroll = ScrollController();

  void _send(String text) {
    final value = text.trim();
    if (value.isEmpty) return;
    setState(() {
      _messages.add(_Message(value, true));
      _controller.clear();
    });
    _scrollDown();
    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      setState(() {
        _messages.add(_Message(
            'Hemen bakıyorum… Yakınında 3 harika seçenek buldum! İstersen listeyi açayım.',
            false));
      });
      _scrollDown();
    });
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    // Klavye açıkken klavye zaten gezinme çubuğunu kaplar; kapalıyken sistem
    // gezinme çubuğu (safe area) kadar boşluk bırak. Çift saymamak için max.
    final bottomInset =
        mq.viewInsets.bottom > mq.viewPadding.bottom
            ? mq.viewInsets.bottom
            : mq.viewPadding.bottom;
    final started = _messages.isNotEmpty;
    return Container(
      height: MediaQuery.of(context).size.height * 0.94,
      decoration: const BoxDecoration(
        color: _K.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: Column(
          children: [
            _header(context),
            Expanded(
              child: started
                  ? ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                      itemCount: _messages.length,
                      itemBuilder: (_, i) => _bubble(_messages[i]),
                    )
                  : _welcome(),
            ),
            if (!started) _suggests(),
            _inputBar(bottomInset),
          ],
        ),
      ),
    );
  }

  // ---- Header ---------------------------------------------------------------
  Widget _header(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 12, 18),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _K.headLine)),
      ),
      child: Row(
        children: [
          const KedyIcon(size: 30, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Kedy',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                          color: _K.dot, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    const Text('Yapay Zeka Asistanı',
                        style: TextStyle(fontSize: 12, color: _K.muted)),
                  ],
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                  color: _K.closeBg, shape: BoxShape.circle),
              child: const Icon(Icons.close, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  // ---- Karşılama (boş durum) ------------------------------------------------
  Widget _welcome() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const KedyIcon(size: 88, color: Colors.white),
            const SizedBox(height: 16),
            const Text("Kedy'e sor!",
                style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w600,
                    color: Colors.white)),
            const SizedBox(height: 4),
            const SizedBox(
              width: 240,
              child: Text(
                'Yakınındaki en iyi mekanları bulmana yardım edeyim.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13.5, height: 1.5, color: _K.muted),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- Mesaj balonu ---------------------------------------------------------
  Widget _bubble(_Message m) {
    if (m.me) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Flexible(
              child: Container(
                constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: const BoxDecoration(
                  color: _K.meBubble,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(4),
                  ),
                ),
                child: Text(m.text,
                    style: const TextStyle(
                        fontSize: 14, height: 1.5, color: Colors.white)),
              ),
            ),
          ],
        ),
      );
    }

    // Bot cevabı — baloncuksuz düz metin, solda kedi ikonu.
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(
            width: 30,
            height: 30,
            child: Center(child: KedyIcon(size: 22, color: Colors.white)),
          ),
          const SizedBox(width: 9),
          Flexible(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(m.text,
                  style: const TextStyle(
                      fontSize: 14, height: 1.5, color: _K.botText)),
            ),
          ),
        ],
      ),
    );
  }

  // ---- Hazır mesaj çipleri --------------------------------------------------
  Widget _suggests() {
    return Container(
      height: 44,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: MockData.kedySuggests.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final s = MockData.kedySuggests[i];
          return GestureDetector(
            onTap: () => _send(s),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                color: _K.chip,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(s,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white)),
            ),
          );
        },
      ),
    );
  }

  // ---- Gradyan kenarlıklı input çubuğu --------------------------------------
  Widget _inputBar(double bottomInset) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomInset),
      child: _GradientBorder(
        radius: 999,
        thickness: 2,
        colors: _K.inputGradient,
        child: Container(
          decoration: const BoxDecoration(
            color: _K.bg,
            borderRadius: BorderRadius.all(Radius.circular(999)),
          ),
          padding: const EdgeInsets.fromLTRB(18, 10, 12, 10),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _controller,
                  textInputAction: TextInputAction.send,
                  onSubmitted: _send,
                  cursorColor: Colors.white,
                  style: const TextStyle(fontSize: 15, color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Canın ne çekiyor?',
                    hintStyle: TextStyle(fontSize: 15, color: _K.placeholder),
                    border: InputBorder.none,
                    isCollapsed: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _send(_controller.text),
                child: const SizedBox(
                  width: 36,
                  height: 36,
                  child: Icon(Icons.pets, color: Colors.white, size: 24),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Akan (animasyonlu) gradyan kenarlık — CSS'teki `ci-flow` animasyonu.
class _GradientBorder extends StatefulWidget {
  final Widget child;
  final double radius;
  final double thickness;
  final List<Color> colors;

  const _GradientBorder({
    required this.child,
    required this.radius,
    required this.thickness,
    required this.colors,
  });

  @override
  State<_GradientBorder> createState() => _GradientBorderState();
}

class _GradientBorderState extends State<_GradientBorder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = _c.value;
        return Container(
          padding: EdgeInsets.all(widget.thickness),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              colors: widget.colors,
              begin: Alignment(-1 + 4 * t, 0),
              end: Alignment(1 + 4 * t, 0),
              tileMode: TileMode.repeated,
            ),
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
