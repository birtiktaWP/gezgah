import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/api.dart';
import '../data/auth_service.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import 'common.dart';

/// İşletme rezervasyon formunu alttan açılan panelde gösterir
/// (rezervasyon-api.md). Başarılıysa oluşan rezervasyonun (tarih, kişi)
/// özetini döner; çağıran başarı modalını gösterir. İptal/başarısızsa null.
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

  int _kisi = 2;
  DateTime? _tarih;
  int? _bolgeId;
  String? _masa;
  bool _kvkk = false;

  bool _codeSent = false;
  bool _sendingCode = false;
  bool _submitting = false;
  int _resend = 0; // yeniden gönderim geri sayımı (sn)
  int _validitySec = 300; // kod geçerlilik süresi (meta.gecerlilik_sn)
  Timer? _resendTimer;
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
    super.dispose();
  }

  String get _telefon => normalizeReservationPhone(_telC.text);

  bool get _bolgeGerekli =>
      widget.options.bolgeZorunlu || widget.options.bolgeler.isNotEmpty;

  List<String> get _masalar =>
      _bolgeId == null ? const [] : (widget.options.masalar[_bolgeId] ?? const []);

  /// "YYYY-MM-DDTHH:MM" biçimi (API formatı).
  String _fmtApi(DateTime d) {
    String p(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${p(d.month)}-${p(d.day)}T${p(d.hour)}:${p(d.minute)}';
  }

  String _fmtHuman(DateTime d) {
    String p(int n) => n.toString().padLeft(2, '0');
    return '${p(d.day)}.${p(d.month)}.${d.year}  ${p(d.hour)}:${p(d.minute)}';
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

  Future<void> _pickTarih() async {
    FocusScope.of(context).unfocus();
    final now = DateTime.now();
    final date = await showNativeDatePicker(
      context,
      initialDate: _tarih ?? now.add(const Duration(hours: 2)),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 1, now.month, now.day),
      helpText: 'Rezervasyon günü',
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime:
          TimeOfDay.fromDateTime(_tarih ?? now.add(const Duration(hours: 2))),
      helpText: 'Rezervasyon saati',
    );
    if (time == null || !mounted) return;
    setState(() {
      _tarih =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _pickBolge() async {
    FocusScope.of(context).unfocus();
    final res = await showNativePicker<int>(
      context,
      title: 'Bölge seç',
      selected: _bolgeId ?? -1,
      options: [
        for (final b in widget.options.bolgeler) (b.id, b.isim),
      ],
    );
    if (res != null && mounted) {
      setState(() {
        _bolgeId = res.value;
        _masa = null; // bölge değişince masa seçimini sıfırla
      });
    }
  }

  Future<void> _pickMasa() async {
    FocusScope.of(context).unfocus();
    final list = _masalar;
    if (list.isEmpty) return;
    final res = await showNativePicker<String>(
      context,
      title: 'Masa / Oda seç',
      selected: _masa ?? '',
      options: [
        ('', 'Farketmez'),
        for (final m in list) (m, m),
      ],
    );
    if (res != null && mounted) {
      setState(() => _masa = res.value.isEmpty ? null : res.value);
    }
  }

  Future<void> _sendCode() async {
    final tel = _telefon;
    if (tel.length != 10) {
      setState(() => _error = 'Geçerli bir telefon numarası gir (10 hane).');
      return;
    }
    setState(() {
      _sendingCode = true;
      _error = null;
    });
    try {
      final validity = await RezervasyonRepository.instance
          .kodGonder(mekanId: widget.mekanId, telefon: tel);
      if (!mounted) return;
      setState(() {
        _codeSent = true;
        _validitySec = validity;
      });
      _startResendCooldown(60); // telefon başına 60 sn bekleme (rezervasyon-api.md §2)
    } on RateLimitException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
      _startResendCooldown(e.retryAfter?.inSeconds ?? 60);
    } on ReservationException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Kod gönderilemedi. Lütfen tekrar dene.');
    } finally {
      if (mounted) setState(() => _sendingCode = false);
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final tel = _telefon;
    if (_adC.text.trim().isEmpty) {
      setState(() => _error = 'Ad soyad gir.');
      return;
    }
    if (tel.length != 10) {
      setState(() => _error = 'Geçerli bir telefon numarası gir.');
      return;
    }
    if (_tarih == null) {
      setState(() => _error = 'Tarih ve saat seç.');
      return;
    }
    if (_bolgeGerekli && (_bolgeId == null || _bolgeId! <= 0)) {
      setState(() => _error = 'Bölge seç.');
      return;
    }
    if (_kodC.text.trim().length < 6) {
      setState(() => _error = 'SMS ile gelen 6 haneli kodu gir.');
      return;
    }
    if (!_kvkk) {
      setState(() => _error = 'Devam etmek için KVKK onayı gerekli.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await RezervasyonRepository.instance.olustur(
        mekanId: widget.mekanId,
        adSoyad: _adC.text.trim(),
        telefon: tel,
        kisi: _kisi,
        tarih: _fmtApi(_tarih!),
        bolgeId: _bolgeId,
        masa: _masa,
        not: _notC.text,
        kod: _kodC.text.trim(),
        kvkk: _kvkk,
      );
      if (!mounted) return;
      Navigator.of(context).pop((tarih: _tarih!, kisi: _kisi));
    } on ReservationException catch (e) {
      if (!mounted) return;
      setState(() => _error = _detailMessage(e));
    } on RateLimitException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(
          () => _error = 'Rezervasyon oluşturulamadı. Lütfen tekrar dene.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// Sunucu `error.details` kodunu kullanıcıya uygun mesaja çevirir.
  String _detailMessage(ReservationException e) {
    switch (e.detail) {
      case 'need_consent':
        return 'KVKK onayı gerekli.';
      case 'need_code':
        return 'Kodun süresi doldu. Lütfen yeni kod iste.';
      case 'code_wrong':
        return 'Girdiğin kod hatalı. Tekrar dene.';
      case 'closed':
        return 'Seçtiğin gün/saat işletme kapalı. Farklı bir zaman seç.';
      case 'need_bolge':
        return 'Bölge seçmelisin.';
      default:
        return e.message;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bolge = widget.options.bolgeler
        .where((b) => b.id == _bolgeId)
        .map((b) => b.isim)
        .firstOrNull;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Column(
            children: [
              _grabber(),
              _header(),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
                  children: [
                    _label('Ad Soyad'),
                    _textField(_adC, 'Adın ve soyadın', Icons.person_outline,
                        formatters: [LengthLimitingTextInputFormatter(150)]),
                    const SizedBox(height: 16),
                    _label('Telefon'),
                    _textField(_telC, '5xx xxx xx xx', Icons.phone_outlined,
                        keyboardType: TextInputType.phone, enabled: !_codeSent),
                    const SizedBox(height: 16),
                    _label('Kişi Sayısı'),
                    _kisiStepper(),
                    const SizedBox(height: 16),
                    _label('Tarih & Saat'),
                    _pickerField(
                      icon: Icons.event_outlined,
                      text: _tarih == null
                          ? 'Tarih ve saat seç'
                          : _fmtHuman(_tarih!),
                      has: _tarih != null,
                      onTap: _pickTarih,
                    ),
                    if (_bolgeGerekli) ...[
                      const SizedBox(height: 16),
                      _label(widget.options.bolgeZorunlu ? 'Bölge *' : 'Bölge'),
                      _pickerField(
                        icon: Icons.map_outlined,
                        text: bolge ?? 'Bölge seç',
                        has: bolge != null,
                        onTap: _pickBolge,
                      ),
                    ],
                    if (_masalar.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _label('Masa / Oda'),
                      _pickerField(
                        icon: Icons.table_restaurant_outlined,
                        text: _masa ?? 'Farketmez',
                        has: _masa != null,
                        onTap: _pickMasa,
                      ),
                    ],
                    const SizedBox(height: 16),
                    _label('Not (opsiyonel)'),
                    _textField(_notC, 'Örn: Pencere kenarı olsun',
                        Icons.notes_outlined,
                        maxLines: 2,
                        formatters: [LengthLimitingTextInputFormatter(500)]),
                    const SizedBox(height: 20),
                    _codeSection(),
                    const SizedBox(height: 18),
                    _kvkkRow(),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      _errorBox(_error!),
                    ],
                    const SizedBox(height: 22),
                    _submitButton(),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _grabber() => Container(
        margin: const EdgeInsets.only(top: 10, bottom: 6),
        width: 44,
        height: 5,
        decoration: BoxDecoration(
          color: AppColors.line,
          borderRadius: BorderRadius.circular(999),
        ),
      );

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 6, 14, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Rezervasyon',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(widget.placeName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.muted)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFF0F0F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.close, color: AppColors.ink, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.ink)),
      );

  Widget _textField(
    TextEditingController c,
    String hint,
    IconData icon, {
    TextInputType? keyboardType,
    int maxLines = 1,
    bool enabled = true,
    List<TextInputFormatter>? formatters,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: enabled ? Colors.white : const Color(0xFFF7F7FB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 19, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: c,
              enabled: enabled,
              keyboardType: keyboardType,
              maxLines: maxLines,
              inputFormatters: formatters,
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

  Widget _pickerField({
    required IconData icon,
    required String text,
    required bool has,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            Icon(icon, size: 19, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(text,
                  style: TextStyle(
                      fontSize: 15,
                      color: has ? AppColors.ink : AppColors.muted)),
            ),
            const Icon(Icons.chevron_right, size: 20, color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  Widget _kisiStepper() {
    Widget btn(IconData ic, VoidCallback onTap, bool enabled) =>
        GestureDetector(
          onTap: enabled ? onTap : null,
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color:
                  enabled ? AppColors.primarySoft : const Color(0xFFF2F2F6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(ic,
                size: 20,
                color: enabled ? AppColors.primary : AppColors.muted),
          ),
        );
    return Row(
      children: [
        btn(Icons.remove, () => setState(() => _kisi--), _kisi > 1),
        Expanded(
          child: Center(
            child: Text('$_kisi kişi',
                style: const TextStyle(
                    fontSize: 15.5, fontWeight: FontWeight.w800)),
          ),
        ),
        btn(Icons.add, () => setState(() => _kisi++), _kisi < 50),
      ],
    );
  }

  Widget _codeSection() {
    final cooling = _resend > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('SMS Doğrulama'),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: _codeSent ? Colors.white : const Color(0xFFF7F7FB),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.line),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.sms_outlined,
                        size: 19, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _kodC,
                        enabled: _codeSent,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        decoration: const InputDecoration(
                          hintText: '6 haneli kod',
                          hintStyle: TextStyle(color: AppColors.muted),
                          border: InputBorder.none,
                          isCollapsed: true,
                          counterText: '',
                          contentPadding: EdgeInsets.symmetric(vertical: 15),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: (_sendingCode || cooling) ? null : _sendCode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      AppColors.primary.withValues(alpha: 0.5),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                child: _sendingCode
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.2, color: Colors.white))
                    : Text(
                        cooling
                            ? '$_resend sn'
                            : (_codeSent ? 'Tekrar' : 'Kod Gönder'),
                        style: const TextStyle(
                            fontSize: 13.5, fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
        if (_codeSent) ...[
          const SizedBox(height: 8),
          Text(
              'Kod $_telefon numarasına gönderildi (${(_validitySec / 60).round()} dk geçerli).',
              style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        ],
      ],
    );
  }

  Widget _kvkkRow() {
    return GestureDetector(
      onTap: () => setState(() => _kvkk = !_kvkk),
      behavior: HitTestBehavior.opaque,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            margin: const EdgeInsets.only(top: 1),
            decoration: BoxDecoration(
              color: _kvkk ? AppColors.primary : Colors.white,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(
                  color: _kvkk ? AppColors.primary : AppColors.line,
                  width: 1.5),
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
                  fontSize: 12.5, color: AppColors.ink, height: 1.35),
            ),
          ),
        ],
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
            child: Text(message,
                style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.closing,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _submitButton() {
    return SizedBox(
      height: 54,
      child: ElevatedButton(
        onPressed: _submitting ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.6),
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: _submitting
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: Colors.white))
            : const Text('Rezervasyonu Oluştur',
                style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
      ),
    );
  }
}
