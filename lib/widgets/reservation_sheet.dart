import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/api.dart';
import '../data/auth_service.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import 'common.dart';

/// İşletme rezervasyonunu alttan açılan panelde üç adımda alır
/// (rezervasyon-api.md):
///
/// 1. **Form** — kişi, tarih (gün şeridi; kapalı günler pasif), saat
///    (tarih seçilince 15 dk aralıklı özel seçici kendiliğinden açılır),
///    bölge (seçilince masa/oda seçici kendiliğinden açılır), iletişim, KVKK.
/// 2. **SMS doğrulama** — "Rezervasyonu Oluştur"a basınca kod gönderilir;
///    6 hane girilince rezervasyon kendiliğinden oluşturulur.
/// 3. **Başarılı** — özet kartı.
///
/// Başarılıysa (tarih, kişi) özetini döner; iptal/başarısızsa null.
/// Başarı ekranı panelin içinde gösterilir (çağıranın ayrıca modal açmasına
/// gerek yok).
Future<({DateTime tarih, int kisi})?> showReservationSheet(
  BuildContext context, {
  required int mekanId,
  required String placeName,
  required RezervasyonSecenekler options,
}) {
  return showModalBottomSheet<({DateTime tarih, int kisi})>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => _ReservationSheet(
      mekanId: mekanId,
      placeName: placeName,
      options: options,
    ),
  );
}

/// Telefon numarasını 10 haneye normalize eder (başındaki 0 / 90 ayıklanır).
String normalizeReservationPhone(String raw) {
  var d = raw.replaceAll(RegExp(r'\D'), '');
  if (d.startsWith('90') && d.length > 10) d = d.substring(2);
  if (d.startsWith('0')) d = d.substring(1);
  if (d.length > 10) d = d.substring(d.length - 10);
  return d;
}

// ---------------------------------------------------------------------------
// Çalışma saatlerinden gün / saat dilimleri
// ---------------------------------------------------------------------------

/// Saat dilimi aralığı (dakika).
const int _slotStep = 15;

/// Bugün için en erken rezervasyon: şimdiden en az bu kadar sonra.
const Duration _minLead = Duration(minutes: 30);

/// Kapanıştan en geç bu kadar önce rezervasyon alınır.
const int _lastBeforeClose = 30;

/// Çalışma saati bilinmeyen günlerde varsayılan aralık (08:00 – 24:00).
const (int, int) _defaultRange = (8 * 60, 24 * 60);

const _gunKisa = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
const _gunUzun = [
  'Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar',
];
const _ayUzun = [
  'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', //
  'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
];

DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

String _p2(int n) => n.toString().padLeft(2, '0');

String _hm(DateTime d) => '${_p2(d.hour)}:${_p2(d.minute)}';

/// "Cumartesi, 16 Kasım"
String _gunTarih(DateTime d) =>
    '${_gunUzun[d.weekday - 1]}, ${d.day} ${_ayUzun[d.month - 1]}';

/// Seçilen günün rezervasyon saatleri (15 dk). Çalışma saati yoksa
/// varsayılan aralık; "Kapalı" gün boş liste. Gece yarısını aşan aralıkta
/// (18:00 – 02:00) ertesi güne taşan saatler de gelir. Bugünse şimdiden
/// [_minLead] sonrası.
List<DateTime> _slotsFor(DateTime day, Map<String, String?> hours) {
  final d = _dayOnly(day);
  (int, int)? range;
  if (hours.isEmpty) {
    range = _defaultRange;
  } else {
    final raw = (hours[kGunAnahtarlari[d.weekday - 1]] ?? '').trim();
    final m = RegExp(r'(\d{1,2}):(\d{2})\D+(\d{1,2}):(\d{2})').firstMatch(raw);
    if (m != null) {
      final s = int.parse(m.group(1)!) * 60 + int.parse(m.group(2)!);
      var e = int.parse(m.group(3)!) * 60 + int.parse(m.group(4)!);
      if (e == s) {
        range = (0, 24 * 60); // 24 saat açık
      } else {
        if (e < s) e += 24 * 60; // gece yarısını aşıyor
        range = (s, e);
      }
    } else if (raw.toLowerCase().startsWith('kapal')) {
      return const []; // yalnız açıkça "Kapalı" yazan gün kapalı
    } else {
      // Gün boş/null ya da biçim tanınmadı: bilinmiyor, kapalı sayma
      // (sunucu kapalı saatte `closed` ile reddeder).
      range = _defaultRange;
    }
  }
  final (s, e) = range;
  final start = ((s + _slotStep - 1) ~/ _slotStep) * _slotStep;
  final last = e == 24 * 60 && s == 0 ? e - _slotStep : e - _lastBeforeClose;
  final earliest = DateTime.now().add(_minLead);
  return [
    for (var m = start; m <= last; m += _slotStep)
      if (!d.add(Duration(minutes: m)).isBefore(earliest))
        d.add(Duration(minutes: m)),
  ];
}

// ---------------------------------------------------------------------------

enum _Step { form, code, done }

class _ReservationSheet extends StatefulWidget {
  final int mekanId;
  final String placeName;
  final RezervasyonSecenekler options;

  const _ReservationSheet({
    required this.mekanId,
    required this.placeName,
    required this.options,
  });

  @override
  State<_ReservationSheet> createState() => _ReservationSheetState();
}

class _ReservationSheetState extends State<_ReservationSheet> {
  final _adC = TextEditingController();
  final _telC = TextEditingController();
  final _notC = TextEditingController();
  final _kodC = TextEditingController();
  final _kodFocus = FocusNode();

  _Step _step = _Step.form;

  int _kisi = 2;
  DateTime? _gun; // seçilen gün (saat yok)
  DateTime? _tarih; // gün + saat
  int? _bolgeId;
  String? _masa;
  bool _kvkk = false;

  // SMS kodu: hangi numaraya, ne zaman gönderildi (aynı numarayla geri
  // dönülürse süresi dolmadıysa yeniden gönderilmez).
  String? _codePhone;
  DateTime? _codeSentAt;
  int _validitySec = 300;
  int _resend = 0; // yeniden gönderim geri sayımı (sn)
  Timer? _resendTimer;

  bool _busy = false; // kod gönderiliyor / rezervasyon oluşturuluyor
  String? _error;

  @override
  void initState() {
    super.initState();
    final u = AuthService.instance.user.value;
    if (u != null) {
      if (u.fullName.isNotEmpty) _adC.text = u.fullName;
      if (u.telefon.isNotEmpty) {
        _telC.text = normalizeReservationPhone(u.telefon);
      }
    }
    // Tek bölge varsa otomatik seç.
    if (widget.options.bolgeler.length == 1) {
      _bolgeId = widget.options.bolgeler.first.id;
    }
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _adC.dispose();
    _telC.dispose();
    _notC.dispose();
    _kodC.dispose();
    _kodFocus.dispose();
    super.dispose();
  }

  // ---- türetilmiş değerler -------------------------------------------------

  Map<String, String?> get _hours => widget.options.calismaSaatleri;

  String get _telefon => normalizeReservationPhone(_telC.text);

  bool get _bolgeGerekli =>
      widget.options.bolgeZorunlu || widget.options.bolgeler.isNotEmpty;

  List<String> get _masalar => _bolgeId == null
      ? const []
      : (widget.options.masalar[_bolgeId] ?? const []);

  String? get _bolgeAdi => widget.options.bolgeler
      .where((b) => b.id == _bolgeId)
      .map((b) => b.isim)
      .firstOrNull;

  /// Gün şeridi: bugünden itibaren 14 gün.
  List<DateTime> get _days {
    final today = _dayOnly(DateTime.now());
    return [for (var i = 0; i < 14; i++) today.add(Duration(days: i))];
  }

  bool get _codeValid =>
      _codePhone == _telefon &&
      _codeSentAt != null &&
      DateTime.now().difference(_codeSentAt!).inSeconds < _validitySec - 15;

  /// "YYYY-MM-DDTHH:MM" biçimi (API formatı).
  String _fmtApi(DateTime d) =>
      '${d.year}-${_p2(d.month)}-${_p2(d.day)}T${_p2(d.hour)}:${_p2(d.minute)}';

  void _hideKeyboard() => FocusScope.of(context).unfocus();

  // ---- seçimler --------------------------------------------------------------

  /// Gün seçildi → saat seçici kendiliğinden açılır. Önceki saat yeni günde
  /// de varsa korunur.
  Future<void> _selectDay(DateTime day) async {
    _hideKeyboard();
    final prev = _tarih;
    final slots = _slotsFor(day, _hours);
    setState(() {
      _gun = day;
      _error = null;
      _tarih = prev == null
          ? null
          : slots
                .where((s) => s.hour == prev.hour && s.minute == prev.minute)
                .firstOrNull;
    });
    if (slots.isNotEmpty) await _pickTime();
  }

  /// Şeritte olmayan ileri bir tarih (takvim).
  Future<void> _pickOtherDay() async {
    _hideKeyboard();
    final now = DateTime.now();
    final date = await showNativeDatePicker(
      context,
      initialDate: _gun ?? now.add(const Duration(days: 14)),
      firstDate: _dayOnly(now),
      lastDate: DateTime(now.year + 1, now.month, now.day),
      helpText: 'Rezervasyon günü',
    );
    if (date == null || !mounted) return;
    if (_slotsFor(date, _hours).isEmpty) {
      setState(() {
        _gun = _dayOnly(date);
        _tarih = null;
        _error = 'İşletme ${_gunTarih(date)} günü kapalı. Başka bir gün seç.';
      });
      return;
    }
    await _selectDay(_dayOnly(date));
  }

  Future<void> _pickTime() async {
    final day = _gun;
    if (day == null) return;
    _hideKeyboard();
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => _TimeSlotSheet(
        day: day,
        slots: _slotsFor(day, _hours),
        selected: _tarih,
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        _tarih = picked;
        _error = null;
      });
    }
  }

  /// Bölge seçildi → masası olan bölgede masa/oda seçici kendiliğinden açılır.
  Future<void> _pickBolge() async {
    _hideKeyboard();
    final id = await _showSelect<int>(
      title: 'Bölge seç',
      selected: _bolgeId,
      options: [
        for (final b in widget.options.bolgeler)
          (
            value: b.id,
            label: b.isim,
            sub: (widget.options.masalar[b.id]?.isNotEmpty ?? false)
                ? '${widget.options.masalar[b.id]!.length} masa / oda'
                : null,
          ),
      ],
    );
    if (id == null || !mounted) return;
    final changed = id != _bolgeId;
    setState(() {
      _bolgeId = id;
      if (changed) _masa = null; // bölge değişince masa seçimi sıfırlanır
      _error = null;
    });
    if (_masalar.isNotEmpty) await _pickMasa();
  }

  Future<void> _pickMasa() async {
    _hideKeyboard();
    final list = _masalar;
    if (list.isEmpty) return;
    final v = await _showSelect<String>(
      title: 'Masa / Oda seç',
      selected: _masa ?? '',
      options: [
        (value: '', label: 'Farketmez', sub: 'İşletme uygun olanı ayırır'),
        for (final m in list) (value: m, label: m, sub: null),
      ],
    );
    if (v != null && mounted) {
      setState(() => _masa = v.isEmpty ? null : v);
    }
  }

  /// Uygulamanın kendi seçim paneli (radyo listesi).
  Future<T?> _showSelect<T>({
    required String title,
    required T? selected,
    required List<({T value, String label, String? sub})> options,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        final maxH = MediaQuery.sizeOf(ctx).height * 0.7;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxH),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _Grabber(),
                _SheetTitle(title),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    children: [
                      for (final o in options)
                        _SelectRow(
                          label: o.label,
                          sub: o.sub,
                          selected: o.value == selected,
                          onTap: () => Navigator.pop(ctx, o.value),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---- adım 1 → 2: doğrula ve kod gönder ------------------------------------

  String? _validateForm() {
    if (_gun == null) return 'Rezervasyon günü seç.';
    if (_tarih == null) return 'Rezervasyon saati seç.';
    if (_bolgeGerekli && (_bolgeId == null || _bolgeId! <= 0)) {
      return 'Bölge seç.';
    }
    if (_adC.text.trim().isEmpty) return 'Ad soyad gir.';
    if (_telefon.length != 10) {
      return 'Geçerli bir telefon numarası gir (10 hane).';
    }
    if (!_kvkk) return 'Devam etmek için KVKK onayı gerekli.';
    if (_tarih!.isBefore(DateTime.now())) {
      return 'Seçtiğin saat geçti. Yeni bir saat seç.';
    }
    return null;
  }

  Future<void> _continue() async {
    _hideKeyboard();
    final err = _validateForm();
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    // Aynı numaraya gönderilmiş ve süresi dolmamış kod varsa tekrar gönderme.
    if (_codeValid) {
      _goCode();
      return;
    }
    final ok = await _sendCode();
    if (ok && mounted) _goCode();
  }

  void _goCode() {
    setState(() {
      _step = _Step.code;
      _error = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _kodFocus.requestFocus();
    });
  }

  Future<bool> _sendCode() async {
    final tel = _telefon;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final validity = await RezervasyonRepository.instance.kodGonder(
        mekanId: widget.mekanId,
        telefon: tel,
      );
      if (!mounted) return false;
      setState(() {
        _codePhone = tel;
        _codeSentAt = DateTime.now();
        _validitySec = validity;
        _kodC.clear();
      });
      // Telefon başına 60 sn bekleme (rezervasyon-api.md §2).
      _startResendCooldown(60);
      return true;
    } on RateLimitException catch (e) {
      if (!mounted) return false;
      setState(() => _error = e.message);
      _startResendCooldown(e.retryAfter?.inSeconds ?? 60);
      return false;
    } on ReservationException catch (e) {
      if (!mounted) return false;
      setState(() => _error = e.message);
      return false;
    } catch (_) {
      if (!mounted) return false;
      setState(() => _error = 'Kod gönderilemedi. Lütfen tekrar dene.');
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _startResendCooldown(int seconds) {
    _resendTimer?.cancel();
    setState(() => _resend = seconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _resend -= 1;
        if (_resend <= 0) t.cancel();
      });
    });
  }

  // ---- adım 2 → 3: rezervasyonu oluştur -------------------------------------

  Future<void> _submit() async {
    if (_busy) return;
    final kod = _kodC.text.trim();
    if (kod.length < 6) {
      setState(() => _error = 'SMS ile gelen 6 haneli kodu gir.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await RezervasyonRepository.instance.olustur(
        mekanId: widget.mekanId,
        adSoyad: _adC.text.trim(),
        telefon: _telefon,
        kisi: _kisi,
        tarih: _fmtApi(_tarih!),
        bolgeId: _bolgeId,
        masa: _masa,
        not: _notC.text,
        kod: kod,
        kvkk: _kvkk,
      );
      if (!mounted) return;
      _hideKeyboard();
      setState(() => _step = _Step.done);
    } on ReservationException catch (e) {
      if (!mounted) return;
      switch (e.detail) {
        case 'code_wrong':
          _kodC.clear();
          setState(() => _error = 'Girdiğin kod hatalı. Tekrar dene.');
          _kodFocus.requestFocus();
        case 'need_code':
          _kodC.clear();
          setState(() {
            _codeSentAt = null;
            _error = 'Kodun süresi doldu. Yeni kod iste.';
          });
        default:
          // Formla ilgili hata: forma dön, mesajı orada göster.
          setState(() {
            _step = _Step.form;
            _error = _detailMessage(e);
          });
      }
    } on RateLimitException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _error = 'Rezervasyon oluşturulamadı. Lütfen tekrar dene.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Sunucu `error.details` kodunu kullanıcıya uygun mesaja çevirir.
  String _detailMessage(ReservationException e) {
    switch (e.detail) {
      case 'need_consent':
        return 'KVKK onayı gerekli.';
      case 'closed':
        return 'Seçtiğin gün/saat işletme kapalı. Farklı bir zaman seç.';
      case 'need_bolge':
        return 'Bölge seçmelisin.';
      default:
        return e.message;
    }
  }

  void _close() {
    final t = _tarih;
    Navigator.of(context).pop(
      _step == _Step.done && t != null ? (tarih: t, kisi: _kisi) : null,
    );
  }

  // ---- arayüz ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final bottomInset = mq.viewInsets.bottom;
    // Sabit yükseklik: ekranın %92'si; klavye açıkken kalan alana sığar.
    final height = math.min(
      mq.size.height * 0.92,
      mq.size.height - bottomInset - mq.padding.top - 8,
    );
    return PopScope(
      // Başarı ekranından sürükleyip kapatınca da sonuç dönsün.
      canPop: _step != _Step.done,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SizedBox(
          height: height,
          child: Column(
            children: [
              const _Grabber(),
              _header(),
              Expanded(
                // Her adımın kendi listesi var (adım geçişinde iki liste aynı
                // anda ekranda olur; ortak kaydırma denetleyicisi olamaz).
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween(
                        begin: const Offset(0.06, 0),
                        end: Offset.zero,
                      ).animate(anim),
                      child: child,
                    ),
                  ),
                  child: switch (_step) {
                    _Step.form => KeyedSubtree(
                      key: const ValueKey('form'),
                      child: _form(),
                    ),
                    _Step.code => KeyedSubtree(
                      key: const ValueKey('code'),
                      child: _codeStep(),
                    ),
                    _Step.done => KeyedSubtree(
                      key: const ValueKey('done'),
                      child: _doneStep(),
                    ),
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    final title = switch (_step) {
      _Step.form => 'Rezervasyon',
      _Step.code => 'Telefonunu doğrula',
      _Step.done => 'Rezervasyon',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
      child: Row(
        children: [
          if (_step == _Step.code)
            _iconBtn(Icons.chevron_left, () {
              setState(() {
                _step = _Step.form;
                _error = null;
              });
            })
          else
            const SizedBox(width: 8),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.placeName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: AppColors.muted),
                ),
              ],
            ),
          ),
          _iconBtn(Icons.close, _close),
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: AppColors.ink, size: 20),
    ),
  );

  // ---- adım 1: form ---------------------------------------------------------

  Widget _form() {
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(22, 6, 22, 28),
      children: [
        _section('Kaç kişisiniz?'),
        _kisiStepper(),
        const SizedBox(height: 24),
        _section('Hangi gün?'),
        _dayStrip(),
        const SizedBox(height: 14),
        // Saat, gün seçilince gelir.
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: _gun == null
              ? const SizedBox(width: double.infinity)
              : _timeField(),
        ),
        if (_bolgeGerekli) ...[
          const SizedBox(height: 24),
          _section(widget.options.bolgeZorunlu ? 'Bölge *' : 'Bölge'),
          _selectField(
            icon: Icons.map_outlined,
            text: _bolgeAdi ?? 'Bölge seç',
            has: _bolgeAdi != null,
            onTap: _pickBolge,
          ),
          if (_masalar.isNotEmpty) ...[
            const SizedBox(height: 10),
            _selectField(
              icon: Icons.table_restaurant_outlined,
              text: _masa ?? 'Masa / oda: Farketmez',
              has: _masa != null,
              onTap: _pickMasa,
            ),
          ],
        ],
        const SizedBox(height: 24),
        _section('İletişim'),
        _textField(
          _adC,
          'Ad soyad',
          Icons.person_outline,
          formatters: [LengthLimitingTextInputFormatter(150)],
        ),
        const SizedBox(height: 10),
        _textField(
          _telC,
          '5xx xxx xx xx',
          Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          formatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9 +]')),
            LengthLimitingTextInputFormatter(16),
          ],
        ),
        const SizedBox(height: 10),
        _textField(
          _notC,
          'Not (opsiyonel) — örn. pencere kenarı',
          Icons.notes_outlined,
          maxLines: 2,
          formatters: [LengthLimitingTextInputFormatter(500)],
        ),
        const SizedBox(height: 18),
        _kvkkRow(),
        if (_error != null) ...[
          const SizedBox(height: 14),
          _errorBox(_error!),
        ],
        const SizedBox(height: 20),
        _primaryButton(
          label: 'Rezervasyonu Oluştur',
          busy: _busy,
          onTap: _continue,
        ),
        const SizedBox(height: 10),
        const Text(
          'Devam edince telefonuna doğrulama kodu gönderilir.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: AppColors.muted),
        ),
      ],
    );
  }

  Widget _section(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      t,
      style: const TextStyle(
        fontSize: 14.5,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      ),
    ),
  );

  Widget _kisiStepper() {
    Widget btn(IconData ic, VoidCallback onTap, bool enabled) => Semantics(
      button: true,
      enabled: enabled,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: enabled ? Colors.white : const Color(0xFFF7F7FB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.line),
          ),
          child: Icon(
            ic,
            size: 20,
            color: enabled ? AppColors.primary : AppColors.muted,
          ),
        ),
      ),
    );
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7FB),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          btn(Icons.remove, () => setState(() => _kisi--), _kisi > 1),
          Expanded(
            child: Column(
              children: [
                Text(
                  '$_kisi',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                    height: 1.1,
                  ),
                ),
                const Text(
                  'kişi',
                  style: TextStyle(fontSize: 11.5, color: AppColors.muted),
                ),
              ],
            ),
          ),
          btn(Icons.add, () => setState(() => _kisi++), _kisi < 50),
        ],
      ),
    );
  }

  /// Yatay gün şeridi (14 gün) + "Diğer" (takvim). Kapalı günler pasif.
  Widget _dayStrip() {
    final today = _dayOnly(DateTime.now());
    final days = _days;
    final sel = _gun;
    final selOutside =
        sel != null && !days.any((d) => d.isAtSameMomentAs(sel));
    return SizedBox(
      height: 74,
      child: ListView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        children: [
          for (final d in days) ...[
            _dayChip(
              top: d == today
                  ? 'Bugün'
                  : d == today.add(const Duration(days: 1))
                  ? 'Yarın'
                  : _gunKisa[d.weekday - 1],
              mid: '${d.day}',
              bottom: _ayUzun[d.month - 1].substring(0, 3),
              selected: sel != null && d.isAtSameMomentAs(sel),
              enabled: _slotsFor(d, _hours).isNotEmpty,
              onTap: () => _selectDay(d),
            ),
            const SizedBox(width: 8),
          ],
          if (selOutside) ...[
            _dayChip(
              top: _gunKisa[sel.weekday - 1],
              mid: '${sel.day}',
              bottom: _ayUzun[sel.month - 1].substring(0, 3),
              selected: true,
              enabled: true,
              onTap: _pickOtherDay,
            ),
            const SizedBox(width: 8),
          ],
          _dayChip(
            top: 'Diğer',
            icon: Icons.calendar_month_outlined,
            bottom: 'Takvim',
            selected: false,
            enabled: true,
            onTap: _pickOtherDay,
          ),
        ],
      ),
    );
  }

  Widget _dayChip({
    required String top,
    String? mid,
    IconData? icon,
    required String bottom,
    required bool selected,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    final fg = selected
        ? Colors.white
        : enabled
        ? AppColors.ink
        : const Color(0xFFB9B9C6);
    final sub = selected
        ? Colors.white70
        : enabled
        ? AppColors.muted
        : const Color(0xFFC9C9D4);
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: enabled ? null : '$top kapalı',
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 58,
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.line,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                top,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: sub,
                ),
              ),
              const SizedBox(height: 3),
              if (icon != null)
                Icon(icon, size: 20, color: fg)
              else
                Text(
                  mid ?? '',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: fg,
                    height: 1.1,
                    decoration: enabled ? null : TextDecoration.lineThrough,
                    decorationColor: fg,
                  ),
                ),
              const SizedBox(height: 2),
              Text(
                enabled ? bottom : 'Kapalı',
                style: TextStyle(fontSize: 10.5, color: sub),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _timeField() {
    final day = _gun!;
    final slots = _slotsFor(day, _hours);
    if (slots.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          _dayOnly(DateTime.now()).isAtSameMomentAs(day)
              ? 'Bugün için uygun saat kalmadı. Başka bir gün seç.'
              : 'İşletme bu gün kapalı. Başka bir gün seç.',
          style: const TextStyle(fontSize: 12.5, color: AppColors.closing),
        ),
      );
    }
    final t = _tarih;
    final nextDay = t != null && !_dayOnly(t).isAtSameMomentAs(day);
    return _selectField(
      icon: Icons.schedule_outlined,
      text: t == null
          ? 'Saat seç'
          : '${_gunTarih(day)} · ${_hm(t)}${nextDay ? ' (ertesi gün)' : ''}',
      has: t != null,
      onTap: _pickTime,
    );
  }

  Widget _selectField({
    required IconData icon,
    required String text,
    required bool has,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: has ? AppColors.primary : AppColors.line,
              width: has ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 19, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: has ? FontWeight.w600 : FontWeight.w400,
                    color: has ? AppColors.ink : AppColors.muted,
                  ),
                ),
              ),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 22,
                color: AppColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _textField(
    TextEditingController c,
    String hint,
    IconData icon, {
    TextInputType? keyboardType,
    int maxLines = 1,
    List<TextInputFormatter>? formatters,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        crossAxisAlignment: maxLines > 1
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Padding(
            padding: EdgeInsets.only(top: maxLines > 1 ? 15 : 0),
            child: Icon(icon, size: 19, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: c,
              keyboardType: keyboardType,
              maxLines: maxLines,
              inputFormatters: formatters,
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(color: AppColors.muted),
                border: InputBorder.none,
                isCollapsed: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kvkkRow() {
    return Semantics(
      checked: _kvkk,
      child: GestureDetector(
        onTap: () => setState(() {
          _kvkk = !_kvkk;
          _error = null;
        }),
        behavior: HitTestBehavior.opaque,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              width: 24,
              height: 24,
              margin: const EdgeInsets.only(top: 1),
              decoration: BoxDecoration(
                color: _kvkk ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color: _kvkk ? AppColors.primary : AppColors.line,
                  width: 1.5,
                ),
              ),
              child: _kvkk
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Rezervasyon bilgilerimin işletmeyle paylaşılmasını ve KVKK '
                'kapsamında işlenmesini kabul ediyorum.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.ink,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorBox(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0x14E0533D),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x33E0533D)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 18, color: AppColors.closing),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.closing,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _primaryButton({
    required String label,
    required bool busy,
    required VoidCallback? onTap,
  }) {
    return SizedBox(
      height: 54,
      child: ElevatedButton(
        onPressed: busy ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.6),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: busy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  // ---- adım 2: SMS kodu -----------------------------------------------------

  Widget _codeStep() {
    final tel = _codePhone ?? _telefon;
    final shown = tel.length == 10
        ? '0${tel.substring(0, 3)} ${tel.substring(3, 6)} ${tel.substring(6, 8)} ${tel.substring(8)}'
        : tel;
    final cooling = _resend > 0;
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 10, 22, 28),
      children: [
        Text.rich(
          TextSpan(
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.muted,
              height: 1.45,
            ),
            children: [
              TextSpan(
                text: shown,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
              TextSpan(
                text:
                    ' numarasına 6 haneli bir kod gönderdik. Kod '
                    '${(_validitySec / 60).round()} dakika geçerli.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        _CodeBoxes(
          controller: _kodC,
          focusNode: _kodFocus,
          error: _error != null,
          onChanged: (v) {
            if (_error != null) setState(() => _error = null);
            if (v.length == 6) _submit(); // 6 hane girilince kendiliğinden
          },
        ),
        if (_error != null) ...[
          const SizedBox(height: 14),
          _errorBox(_error!),
        ],
        const SizedBox(height: 22),
        _primaryButton(label: 'Onayla', busy: _busy, onTap: _submit),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: _busy
                  ? null
                  : () => setState(() {
                      _step = _Step.form;
                      _error = null;
                    }),
              child: const Text(
                'Numarayı değiştir',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            TextButton(
              onPressed: (cooling || _busy) ? null : _sendCode,
              child: Text(
                cooling ? 'Tekrar gönder ($_resend sn)' : 'Kodu tekrar gönder',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _summaryCard(),
      ],
    );
  }

  // ---- adım 3: başarılı -----------------------------------------------------

  Widget _doneStep() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
      children: [
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: Color(0xFFF0FBF4),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.event_available_rounded,
              size: 38,
              color: AppColors.open,
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Rezervasyon talebin alındı',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Talebin işletmeye iletildi. Onay durumunu Hesabım › '
          'Rezervasyonlarım bölümünden takip edebilirsin.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13.5, color: AppColors.muted, height: 1.45),
        ),
        const SizedBox(height: 22),
        _summaryCard(),
        const SizedBox(height: 24),
        _primaryButton(label: 'Tamam', busy: false, onTap: _close),
      ],
    );
  }

  /// Rezervasyon özeti (kod ekranında ve başarı ekranında).
  Widget _summaryCard() {
    final t = _tarih;
    final rows = <(IconData, String, String)>[
      (Icons.storefront_outlined, 'Mekan', widget.placeName),
      if (t != null) (Icons.event_outlined, 'Tarih', _gunTarih(t)),
      if (t != null) (Icons.schedule_outlined, 'Saat', _hm(t)),
      (Icons.people_outline, 'Kişi', '$_kisi kişi'),
      if (_bolgeAdi != null) (Icons.map_outlined, 'Bölge', _bolgeAdi!),
      if (_masa != null) (Icons.table_restaurant_outlined, 'Masa / Oda', _masa!),
      if (_notC.text.trim().isNotEmpty)
        (Icons.notes_outlined, 'Not', _notC.text.trim()),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7FB),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                border: i == rows.length - 1
                    ? null
                    : const Border(bottom: BorderSide(color: AppColors.line)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(rows[i].$1, size: 17, color: AppColors.primary),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 86,
                    child: Text(
                      rows[i].$2,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      rows[i].$3,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Yardımcı parçalar
// ---------------------------------------------------------------------------

class _Grabber extends StatelessWidget {
  const _Grabber();

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 10, bottom: 8),
    width: 44,
    height: 5,
    decoration: BoxDecoration(
      color: AppColors.line,
      borderRadius: BorderRadius.circular(999),
    ),
  );
}

class _SheetTitle extends StatelessWidget {
  final String text;
  const _SheetTitle(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(22, 4, 22, 12),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
      ),
    ),
  );
}

/// Seçim panelindeki satır (radyo).
class _SelectRow extends StatelessWidget {
  final String label;
  final String? sub;
  final bool selected;
  final VoidCallback onTap;

  const _SelectRow({
    required this.label,
    required this.sub,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          decoration: BoxDecoration(
            color: selected ? AppColors.primarySoft : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: selected ? AppColors.primary : AppColors.ink,
                      ),
                    ),
                    if (sub != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        sub!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected
                        ? AppColors.primary
                        : const Color(0xFFC9C9D6),
                    width: selected ? 7 : 2,
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

/// Saat seçici: seçilen günün 15 dk aralıklı saatleri, gün bölümlerine göre
/// gruplu ızgara. Ertesi güne taşan saatlerde "+1" yazar.
class _TimeSlotSheet extends StatelessWidget {
  final DateTime day;
  final List<DateTime> slots;
  final DateTime? selected;

  const _TimeSlotSheet({
    required this.day,
    required this.slots,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final d0 = _dayOnly(day);
    String group(DateTime s) {
      if (!_dayOnly(s).isAtSameMomentAs(d0)) return 'Gece';
      if (s.hour < 12) return 'Sabah';
      if (s.hour < 17) return 'Öğle';
      if (s.hour < 21) return 'Akşam';
      return 'Gece';
    }

    final groups = <String, List<DateTime>>{};
    for (final s in slots) {
      groups.putIfAbsent(group(s), () => []).add(s);
    }
    final maxH = MediaQuery.sizeOf(context).height * 0.75;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _Grabber(),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 4, 22, 6),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Saat seç',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    _gunTarih(day),
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(22, 6, 22, 18),
                children: [
                  for (final e in groups.entries) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 10, bottom: 8),
                      child: Text(
                        e.key,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                    GridView.count(
                      crossAxisCount: 4,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 2.1,
                      children: [
                        for (final s in e.value)
                          _slotChip(
                            context,
                            s,
                            next: !_dayOnly(s).isAtSameMomentAs(d0),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _slotChip(BuildContext context, DateTime s, {required bool next}) {
    final sel = selected != null && selected!.isAtSameMomentAs(s);
    return Semantics(
      button: true,
      selected: sel,
      label: next ? '${_hm(s)}, ertesi gün' : _hm(s),
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => Navigator.pop(context, s),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: sel ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: sel ? AppColors.primary : AppColors.line,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _hm(s),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: sel ? Colors.white : AppColors.ink,
                ),
              ),
              if (next)
                Text(
                  '+1',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: sel ? Colors.white70 : AppColors.muted,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 6 haneli kod kutuları. Görünmez tek bir alan girişi alır (SMS'ten
/// otomatik doldurma desteklenir); kutular yalnız gösterir.
class _CodeBoxes extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool error;
  final ValueChanged<String> onChanged;

  const _CodeBoxes({
    required this.controller,
    required this.focusNode,
    required this.error,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: focusNode.requestFocus,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: [
          // Asıl giriş alanı (görünmez; imleç ve klavye bunun).
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                maxLength: 6,
                showCursor: false,
                enableInteractiveSelection: false,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: onChanged,
                decoration: const InputDecoration(
                  counterText: '',
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          ListenableBuilder(
            listenable: Listenable.merge([controller, focusNode]),
            builder: (context, _) {
              final v = controller.text;
              return Row(
                children: [
                  for (var i = 0; i < 6; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: AspectRatio(
                        aspectRatio: 0.82,
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: error
                                  ? AppColors.closing
                                  : (focusNode.hasFocus && i == v.length)
                                  ? AppColors.primary
                                  : AppColors.line,
                              width:
                                  (focusNode.hasFocus && i == v.length) || error
                                  ? 1.6
                                  : 1,
                            ),
                          ),
                          child: Text(
                            i < v.length ? v[i] : '',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
