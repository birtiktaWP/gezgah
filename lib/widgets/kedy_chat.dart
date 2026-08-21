import 'package:flutter/material.dart';
import '../data/api.dart';
import '../data/auth_service.dart';
import '../data/models.dart';
import '../data/mock_data.dart';
import '../screens/login_screen.dart';
import '../screens/plus_screen.dart';
import 'common.dart';

/// Kedy yapay zeka asistanı — alttan açılan tam yükseklikli sohbet paneli
/// (app-kedy.md). [postId] verilirse "bu işletme" bağlamı olarak gönderilir.
/// [initialMessage] verilirse (ör. arama sayfası Kedy tavsiyeleri) panel açılıp
/// üye Plus ise bu mesaj otomatik olarak Kedy'ye gönderilir.
/// Tasarım: tasarim/index.html içindeki koyu (siyah) temalı chatbot paneli.
Future<void> showKedyChat(BuildContext context,
    {int? postId, String? initialMessage}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (_) =>
        _KedyChatSheet(postId: postId, initialMessage: initialMessage),
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
  final int? postId;
  final String? initialMessage;
  const _KedyChatSheet({this.postId, this.initialMessage});

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

  bool _sending = false; // Kedy yanıtı bekleniyor (yazıyor…)
  bool _loadingHistory = false;
  String? _pending; // açılışta otomatik gönderilecek mesaj (Kedy tavsiyesi)

  @override
  void initState() {
    super.initState();
    _pending = widget.initialMessage?.trim();
    // Geçmiş yalnız aktif Plus üyesi için var (UYELIK_PLUS.md §7).
    if (AuthService.instance.user.value?.isPlus ?? false) _init();
  }

  /// Geçmişi yükle, ardından (varsa) bekleyen tavsiye mesajını gönder.
  Future<void> _init() async {
    await _loadHistory();
    _maybeSendPending();
  }

  /// Açılışta iletilen tavsiye mesajını (yalnız Plus üyede) bir kez gönderir.
  void _maybeSendPending() {
    if (!(AuthService.instance.user.value?.isPlus ?? false)) return;
    final p = _pending;
    if (p != null && p.isNotEmpty && !_sending) {
      _pending = null;
      _send(p);
    }
  }

  /// Giriş yapmış Plus üyesinin sunucudaki Kedy geçmişini yükler (app-kedy.md).
  Future<void> _loadHistory() async {
    if (!(AuthService.instance.user.value?.isPlus ?? false)) return;
    setState(() => _loadingHistory = true);
    final hist = await KedyRepository.instance.gecmis(days: 7);
    if (!mounted) return;
    setState(() {
      _messages
        ..clear()
        ..addAll(hist.map((m) => _Message(m.content, m.isUser)));
      _loadingHistory = false;
    });
    _scrollDown();
  }

  Future<void> _send(String text) async {
    final value = text.trim();
    if (value.isEmpty || _sending) return;
    setState(() {
      _messages.add(_Message(value, true));
      _controller.clear();
      _sending = true;
    });
    _scrollDown();
    try {
      final answer = await KedyRepository.instance.sor(
        message: value,
        postId: widget.postId,
        lang: 'tr',
      );
      if (!mounted) return;
      setState(() => _messages.add(_Message(answer, false)));
    } on PlusRequiredException catch (e) {
      // Plus düştü/gerekli: mesajı göster ve paywall'a yönlendir.
      if (!mounted) return;
      setState(() => _messages.add(_Message(e.message, false)));
      if (e.girisGerekli) {
        await _openLogin();
      } else {
        await _openPlus();
      }
    } on RateLimitException catch (e) {
      if (!mounted) return;
      setState(() => _messages.add(_Message(e.message, false)));
    } on KedyException catch (e) {
      if (!mounted) return;
      setState(() => _messages.add(_Message(e.message, false)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _messages
          .add(_Message('Bir sorun oluştu. Lütfen tekrar dene.', false)));
    } finally {
      if (mounted) setState(() => _sending = false);
      _scrollDown();
    }
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
    final bottomInset = mq.viewInsets.bottom > mq.viewPadding.bottom
        ? mq.viewInsets.bottom
        : mq.viewPadding.bottom;
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
            // Üye girişine göre canlı: giriş yoksa ortada "Üye Girişi Yap"
            // kapısı, varsa sohbet + öneriler + giriş çubuğu.
            Expanded(
              child: ValueListenableBuilder<AppUser?>(
                valueListenable: AuthService.instance.user,
                builder: (_, user, __) {
                  if (user == null) return _loginGate();
                  if (!user.isPlus) return _plusGate();
                  return _chatBody(bottomInset);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chatBody(double bottomInset) {
    final started = _messages.isNotEmpty;
    return Column(
      children: [
        Expanded(
          child: _loadingHistory
              ? const Center(
                  child: SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white),
                  ),
                )
              : (started ? _list() : _welcome()),
        ),
        if (!started && !_loadingHistory) _suggests(),
        _inputBar(bottomInset),
      ],
    );
  }

  // ---- Üye girişi kapısı (giriş yoksa tam ortada) ---------------------------
  Widget _loginGate() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const KedyIcon(size: 88, color: Colors.white),
            const SizedBox(height: 18),
            const Text('Kedy seni bekliyor',
                style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w600,
                    color: Colors.white)),
            const SizedBox(height: 8),
            const SizedBox(
              width: 260,
              child: Text(
                'Kedy ile sohbet etmek, mekan önerileri almak ve rezervasyon '
                'yapmak için üye girişi yapmalısın.',
                textAlign: TextAlign.center,
                style:
                    TextStyle(fontSize: 13.5, height: 1.5, color: _K.muted),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 220,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _openLogin,
                icon: const Icon(Icons.login, size: 19),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                label: const Text('Üye Girişi Yap',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openLogin() async {
    final ok = await openLogin(context);
    if (ok == true && mounted && AuthService.instance.isLoggedIn) {
      _init();
    }
  }

  // ---- Gezgah Plus kapısı (giriş var ama Plus yok) --------------------------
  Widget _plusGate() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.workspace_premium,
                size: 78, color: Colors.white),
            const SizedBox(height: 18),
            const Text('Kedy, Gezgah Plus\u2019ta',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w600,
                    color: Colors.white)),
            const SizedBox(height: 8),
            const SizedBox(
              width: 270,
              child: Text(
                'Kedy ile sohbet etmek, mekan önerileri almak ve rezervasyon '
                'yapmak Gezgah Plus üyeliği gerektirir.',
                textAlign: TextAlign.center,
                style:
                    TextStyle(fontSize: 13.5, height: 1.5, color: _K.muted),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 240,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _openPlus,
                icon: const Icon(Icons.workspace_premium, size: 19),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                label: const Text('Gezgah Plus\u2019a Geç',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openPlus() async {
    final ok = await openPlus(context);
    if (ok == true && mounted && (AuthService.instance.user.value?.isPlus ?? false)) {
      _init();
    }
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
                        fontWeight: FontWeight.w600,
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

  // ---- Mesaj listesi (yazıyor… göstergesi dahil) ----------------------------
  Widget _list() {
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      itemCount: _messages.length + (_sending ? 1 : 0),
      itemBuilder: (_, i) {
        if (i >= _messages.length) return _typing();
        return _bubble(_messages[i]);
      },
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

  // ---- "Yazıyor…" göstergesi ------------------------------------------------
  Widget _typing() {
    return const Padding(
      padding: EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 30,
            height: 30,
            child: Center(child: KedyIcon(size: 22, color: Colors.white)),
          ),
          SizedBox(width: 9),
          Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text('yazıyor…',
                style: TextStyle(
                    fontSize: 13.5,
                    fontStyle: FontStyle.italic,
                    color: _K.muted)),
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
                  enabled: !_sending,
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
                onTap: _sending ? null : () => _send(_controller.text),
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: _sending
                      ? const Padding(
                          padding: EdgeInsets.all(7),
                          child: CircularProgressIndicator(
                              strokeWidth: 2.2, color: Colors.white),
                        )
                      : const Icon(Icons.pets, color: Colors.white, size: 24),
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
