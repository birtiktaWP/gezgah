import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../theme/app_theme.dart';

/// Sesli arama paneli. Açılınca mikrofon (iOS'ta ayrıca konuşma tanıma) izni
/// istenir ve dinlemeye başlanır; konuşma metni canlı gösterilir. Kullanıcı
/// susunca (ya da "Tamam"a basınca) tanınan metin döner. Vazgeçilirse,
/// izin verilmezse ya da hiçbir şey anlaşılmazsa `null` döner.
Future<String?> showVoiceSearch(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (_) => const _VoiceSheet(),
  );
}

enum _Phase { starting, listening, denied, unavailable, error }

class _VoiceSheet extends StatefulWidget {
  const _VoiceSheet();

  @override
  State<_VoiceSheet> createState() => _VoiceSheetState();
}

class _VoiceSheetState extends State<_VoiceSheet> {
  // Tek örnek: speech_to_text initialize'ı uygulama ömrü boyunca bir kez yapar.
  static final SpeechToText _stt = SpeechToText();

  _Phase _phase = _Phase.starting;
  String _text = '';
  double _level = 0; // ses seviyesi (dalga animasyonu)
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    bool ok;
    try {
      // İlk çağrıda işletim sistemi izin pencerelerini gösterir.
      ok = await _stt.initialize(onError: _onError, onStatus: _onStatus);
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    if (!ok) {
      final perm = await _stt.hasPermission;
      if (!mounted) return;
      setState(() => _phase = perm ? _Phase.unavailable : _Phase.denied);
      return;
    }
    final locale = await _turkishLocale();
    if (!mounted) return;
    setState(() {
      _phase = _Phase.listening;
      _text = '';
    });
    HapticFeedback.lightImpact();
    await _stt.listen(
      onResult: _onResult,
      onSoundLevelChange: (l) {
        if (mounted) setState(() => _level = l);
      },
      listenOptions: SpeechListenOptions(
        localeId: locale,
        listenMode: ListenMode.search,
        partialResults: true,
        cancelOnError: true,
        listenFor: const Duration(seconds: 20),
        pauseFor: const Duration(seconds: 3),
      ),
    );
  }

  /// Cihazda Türkçe tanıma varsa onu, yoksa cihaz varsayılanını kullanır.
  Future<String?> _turkishLocale() async {
    try {
      final all = await _stt.locales();
      for (final l in all) {
        final id = l.localeId.toLowerCase().replaceAll('-', '_');
        if (id.startsWith('tr')) return l.localeId;
      }
    } catch (_) {}
    return null;
  }

  void _onResult(SpeechRecognitionResult r) {
    if (!mounted) return;
    setState(() => _text = r.recognizedWords);
    if (r.finalResult) _finish();
  }

  void _onStatus(String s) {
    // Dinleme bitti (sessizlik / süre doldu) ama final sonuç gelmediyse:
    // elde ne varsa onunla bitir.
    if (s == SpeechToText.doneStatus || s == SpeechToText.notListeningStatus) {
      if (mounted && _phase == _Phase.listening) _finish();
    }
  }

  void _onError(SpeechRecognitionError e) {
    if (!mounted || _done) return;
    final msg = e.errorMsg.toLowerCase();
    if (msg.contains('permission')) {
      setState(() => _phase = _Phase.denied);
    } else if (msg.contains('no_match') || msg.contains('speech_timeout')) {
      // Hiçbir şey anlaşılmadı → kullanıcı tekrar deneyebilsin.
      if (_text.trim().isEmpty) setState(() => _phase = _Phase.error);
    } else if (_text.trim().isEmpty) {
      setState(() => _phase = _Phase.error);
    }
  }

  void _finish() {
    if (_done) return;
    final t = _text.trim();
    if (t.isEmpty) {
      if (mounted && _phase == _Phase.listening) {
        setState(() => _phase = _Phase.error);
      }
      return;
    }
    _done = true;
    _stt.stop();
    HapticFeedback.selectionClick();
    if (mounted) Navigator.of(context).pop(t);
  }

  Future<void> _retry() async {
    setState(() {
      _phase = _Phase.starting;
      _text = '';
    });
    await _start();
  }

  @override
  void dispose() {
    if (!_done) _stt.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(24, 14, 24, 20 + bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.line,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 22),
          _micVisual(),
          const SizedBox(height: 20),
          Semantics(
            liveRegion: true,
            child: Text(_title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink)),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Text(_subtitle,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: _text.isNotEmpty ? 18 : 14,
                    height: 1.35,
                    fontWeight:
                        _text.isNotEmpty ? FontWeight.w600 : FontWeight.w400,
                    color: _text.isNotEmpty
                        ? AppColors.primary
                        : AppColors.muted)),
          ),
          const SizedBox(height: 18),
          _actions(),
        ],
      ),
    );
  }

  String get _title => switch (_phase) {
        _Phase.starting => 'Mikrofon hazırlanıyor…',
        _Phase.listening => _text.isEmpty ? 'Dinliyorum…' : 'Anladığım',
        _Phase.denied => 'Mikrofon izni gerekli',
        _Phase.unavailable => 'Sesli arama kullanılamıyor',
        _Phase.error => 'Anlayamadım',
      };

  String get _subtitle => switch (_phase) {
        _Phase.starting => '',
        _Phase.listening =>
          _text.isNotEmpty ? _text : 'Örn. "Kadıköy\'de kahvaltı"',
        _Phase.denied =>
          'Sesli arama için Ayarlar › Gezgah bölümünden mikrofon ve konuşma '
              'tanıma iznini aç.',
        _Phase.unavailable =>
          'Bu cihazda konuşma tanıma desteklenmiyor ya da kapalı.',
        _Phase.error => 'Tekrar dene ya da aramayı yazarak yap.',
      };

  Widget _micVisual() {
    final listening = _phase == _Phase.listening;
    final bad = _phase == _Phase.denied || _phase == _Phase.unavailable;
    // Ses seviyesi (~-2..10 dB) → halka büyüklüğü.
    final glow = listening ? (_level.clamp(0, 10) / 10) : 0.0;
    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 84 + 36 * glow,
            height: 84 + 36 * glow,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary
                  .withValues(alpha: listening ? 0.14 : 0.0),
            ),
          ),
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: bad ? AppColors.primarySoft : AppColors.primary,
            ),
            child: _phase == _Phase.starting
                ? const Padding(
                    padding: EdgeInsets.all(26),
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white),
                  )
                : Icon(bad ? Icons.mic_off_outlined : Icons.mic,
                    size: 34,
                    color: bad ? AppColors.primary : Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _actions() {
    if (_phase == _Phase.listening) {
      return Row(
        children: [
          Expanded(child: _btn('Vazgeç', () => Navigator.pop(context))),
          const SizedBox(width: 12),
          Expanded(
            child: _btn('Tamam', _text.trim().isEmpty ? null : _finish,
                primary: true),
          ),
        ],
      );
    }
    if (_phase == _Phase.error) {
      return Row(
        children: [
          Expanded(child: _btn('Kapat', () => Navigator.pop(context))),
          const SizedBox(width: 12),
          Expanded(child: _btn('Tekrar dene', _retry, primary: true)),
        ],
      );
    }
    if (_phase == _Phase.starting) {
      return _btn('Vazgeç', () => Navigator.pop(context));
    }
    return _btn('Tamam', () => Navigator.pop(context), primary: true);
  }

  Widget _btn(String label, VoidCallback? onTap, {bool primary = false}) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: primary
          ? ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    AppColors.primary.withValues(alpha: 0.35),
                disabledForegroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600)),
            )
          : OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.line),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600)),
            ),
    );
  }
}
