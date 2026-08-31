import 'dart:async';

import 'package:dlibphonenumber/dlibphonenumber.dart' as libphone;
import 'package:flutter/material.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';

import '../data/api.dart';
import '../data/auth_service.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// Üye giriş/kayıt ekranını açar. Başarılıysa `true` ile kapanır.
Future<bool?> openLogin(BuildContext context) {
  return Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => const LoginScreen(),
      fullscreenDialog: true,
    ),
  );
}

/// Parolasız üye giriş/kayıt ekranı (UYE_GIRIS_SMS.md).
///
/// **Giriş:** telefon → SMS kodu → oturum. Parola kullanılmaz.
/// **Kayıt:** Ad, Soyad, E-posta, Telefon + SMS kodu (parola sorulmaz);
/// cinsiyet, doğum günü, ilçe opsiyonel — şehir hep İstanbul.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _register = false; // false: giriş, true: kayıt
  bool _busy = false;
  String? _error;
  String? _info; // bilgilendirme (ör. kod gönderildi / kayıt gerekli)

  // Hız sınırı (429) sonrası kısa geri sayım (rest-api-v2 §4): buton bu süre
  // boyunca kilitlenir; kullanıcı tekrar tekrar denemeye zorlanmaz.
  int _cooldown = 0;
  Timer? _cooldownTimer;

  // Kayıt SMS kodu için ayrı "yeniden gönder" geri sayımı (ana butonu kilitlemez).
  int _resend = 0;
  Timer? _resendTimer;

  // SMS OTP: kod gönderildikten sonra kod alanı görünür (giriş ve kayıtta).
  bool _codeSent = false;

  // Kodun kalan geçerlilik süresi (sn) — sunucudan gelir (varsayılan 300).
  int _codeTtl = 0;
  Timer? _ttlTimer;

  // Kod gönderildiğinde sunucudan gelen üye adı ("Merhaba X" gösterimi).
  String? _girisAd;

  // Otomatik gönderimde aynı kodun tekrar denenmesini engeller.
  String? _lastTriedCode;

  final _isimC = TextEditingController();
  final _soyisimC = TextEditingController();
  final _emailC = TextEditingController();
  final _telefonC = TextEditingController();
  final _kodC = TextEditingController();

  String? _cinsiyet; // erkek | kadin | diger | null
  DateTime? _dogum;
  int? _ilceId;
  // Seçili ülke + tam uluslararası numara (intl_phone_number_input).
  PhoneNumber _phone = PhoneNumber(isoCode: 'TR');
  // Seçili ülkenin izin verdiği ulusal hane sayısı (limit) — ülke değişince
  // güncellenir. Kütüphanenin sabit 15 karakter limiti ülkeye göre değişmiyor,
  // bu yüzden haneleri kendimiz sınırlıyoruz.
  int _phoneMaxDigits = 10;
  String _phoneIso = 'TR';
  TextEditingValue _lastPhoneValue = TextEditingValue.empty;
  bool _enforcingPhone = false;

  @override
  void initState() {
    super.initState();
    _phoneMaxDigits = _maxDigitsFor(_phoneIso);
    _telefonC.addListener(_enforcePhoneLimit);
    _kodC.addListener(_autoSubmitCode);
  }

  /// 6 hane tamamlanınca (elle yazınca ya da SMS otomatik doldurmasıyla)
  /// doğrulamayı kendiliğinden başlatır — butona basmak gerekmez.
  void _autoSubmitCode() {
    final kod = _kodC.text.replaceAll(RegExp(r'\D'), '');
    // Alan temizlendiğinde/kısaldığında kilidi bırak: kullanıcı aynı kodu
    // yeniden yazarsa otomatik gönderim tekrar çalışsın.
    if (kod.length < 6) {
      _lastTriedCode = null;
      return;
    }
    if (!_codeSent || _busy || _cooldown > 0) return;
    if (kod == _lastTriedCode) return; // aynı kodu üst üste denemeyelim
    _lastTriedCode = kod;
    FocusScope.of(context).unfocus();
    _submit();
  }

  /// Seçili numarayı (ülke kodu, ulusal numara) olarak ayırır.
  (String, String) _splitPhone() {
    final dial = _phone.dialCode != null && _phone.dialCode!.isNotEmpty
        ? '+${_phone.dialCode!.replaceAll('+', '')}'
        : '+90';
    final full = _phone.phoneNumber ?? '';
    var national = full.startsWith(dial) ? full.substring(dial.length) : full;
    national = national.replaceAll(RegExp(r'\D'), '');
    if (national.isEmpty) {
      national = _telefonC.text.replaceAll(RegExp(r'\D'), '');
    }
    return (dial, national);
  }

  /// Bir ülkenin örnek mobil numarasından ulusal hane sayısını bulur.
  int _maxDigitsFor(String iso) {
    try {
      final util = libphone.PhoneNumberUtil.instance;
      final ex =
          util.getExampleNumberForType(
            regionCode: iso,
            type: libphone.PhoneNumberType.mobile,
          ) ??
          util.getExampleNumber(iso);
      if (ex == null) return 15;
      final nsn = util.getNationalSignificantNumber(ex);
      return nsn.isEmpty ? 15 : nsn.length;
    } catch (_) {
      return 15;
    }
  }

  /// Numara alanındaki hane sayısı ülke limitini aşarsa girişi engeller
  /// (son geçerli değere döner). Boşluk/format değerini bozmaz.
  void _enforcePhoneLimit() {
    if (_enforcingPhone) return;
    final digits = _telefonC.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > _phoneMaxDigits) {
      _enforcingPhone = true;
      _telefonC.value = _lastPhoneValue;
      _enforcingPhone = false;
    } else {
      _lastPhoneValue = _telefonC.value;
    }
  }

  List<Ilce> _ilceler = const [];
  bool _ilcelerLoaded = false;

  /// 429 sonrası [seconds] saniyelik geri sayımı başlatır; her saniye buton
  /// etiketini günceller, bitince butonu tekrar açar.
  void _startCooldown(int seconds) {
    _cooldownTimer?.cancel();
    setState(() => _cooldown = seconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _cooldown -= 1;
        if (_cooldown <= 0) t.cancel();
      });
    });
  }

  void _startResend(int seconds) {
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

  /// Kodun geçerlilik geri sayımı (300 sn) — bitince yeni kod istenmeli.
  void _startTtl(int seconds) {
    _ttlTimer?.cancel();
    setState(() => _codeTtl = seconds);
    _ttlTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _codeTtl -= 1;
        if (_codeTtl <= 0) t.cancel();
      });
    });
  }

  /// "mm:ss" biçiminde kalan kod süresi.
  String get _ttlLabel {
    final m = (_codeTtl ~/ 60).toString();
    final s = (_codeTtl % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  /// SMS kodunu yeniden gönderir (kod alanı görünürken; 60 sn kilitli).
  Future<void> _resendCode() async {
    if (_resend > 0 || _busy) return;
    final (ulkeKodu, ulusalTelefon) = _splitPhone();
    setState(() {
      _error = null;
      _info = null;
    });
    try {
      if (_register) {
        await AuthService.instance.kayitKodGonder(
          ulkeKodu: ulkeKodu,
          telefon: ulusalTelefon,
        );
        _startTtl(300);
      } else {
        final r = await AuthService.instance.girisKodGonder(
          ulkeKodu: ulkeKodu,
          telefon: ulusalTelefon,
        );
        if (!mounted) return;
        setState(() => _girisAd = r.ad ?? _girisAd);
        _startTtl(r.gecerlilikSn);
      }
      if (!mounted) return;
      setState(() => _info = 'Yeni kod gönderildi.');
      _startResend(60);
    } on RateLimitException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
      _startResend(e.retryAfter?.inSeconds ?? 60);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _msg(e));
    }
  }

  /// İstisnayı kullanıcıya gösterilecek metne çevirir.
  String _msg(Object e) => e is AuthException
      ? e.message
      : e.toString().replaceFirst('Exception: ', '');

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _resendTimer?.cancel();
    _ttlTimer?.cancel();
    _telefonC.removeListener(_enforcePhoneLimit);
    _kodC.removeListener(_autoSubmitCode);
    _isimC.dispose();
    _soyisimC.dispose();
    _emailC.dispose();
    _telefonC.dispose();
    _kodC.dispose();
    super.dispose();
  }

  void _toggleMode() {
    setState(() {
      _register = !_register;
      _error = null;
      _info = null;
      _codeSent = false; // mod değişince OTP durumunu sıfırla
      _girisAd = null;
      _kodC.clear();
    });
    _ttlTimer?.cancel();
    if (_register) _ensureIlceler();
  }

  /// Kod adımından telefon adımına geri döner (numarayı düzeltmek için).
  void _editPhone() {
    _ttlTimer?.cancel();
    setState(() {
      _codeSent = false;
      _codeTtl = 0;
      _kodC.clear();
      _error = null;
      _info = null;
    });
  }

  Future<void> _ensureIlceler() async {
    if (_ilcelerLoaded) return;
    _ilcelerLoaded = true;
    final list = await AuthService.instance.ilceler();
    if (!mounted) return;
    setState(() => _ilceler = list);
  }

  String get _dogumIso {
    final d = _dogum;
    if (d == null) return '';
    final m = d.month.toString().padLeft(2, '0');
    final g = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$g';
  }

  Future<void> _pickDogum() async {
    FocusScope.of(context).unfocus();
    final now = DateTime.now();
    final picked = await showNativeDatePicker(
      context,
      initialDate: _dogum ?? DateTime(now.year - 20, now.month, now.day),
      firstDate: DateTime(1920),
      lastDate: now,
      helpText: 'Doğum günün',
    );
    if (picked != null && mounted) setState(() => _dogum = picked);
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final email = _emailC.text.trim();
    final digits = _telefonC.text.replaceAll(RegExp(r'\D'), '');

    // --- Doğrulamalar ---------------------------------------------------------
    if (_register) {
      if (_isimC.text.trim().isEmpty) {
        setState(() => _error = 'Adını gir.');
        return;
      }
      if (_soyisimC.text.trim().isEmpty) {
        setState(() => _error = 'Soyadını gir.');
        return;
      }
      if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
        setState(() => _error = 'Geçerli bir e-posta adresi gir.');
        return;
      }
    }
    if (digits.length < 7 || digits.length > 15) {
      setState(() => _error = 'Geçerli bir telefon numarası gir.');
      return;
    }
    if (_codeSent && _kodC.text.trim().length < 6) {
      setState(() => _error = 'SMS ile gelen 6 haneli kodu gir.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    final (ulkeKodu, ulusalTelefon) = _splitPhone();
    try {
      // --- 1. adım: kod gönder ---
      if (!_codeSent) {
        if (_register) {
          await AuthService.instance.kayitKodGonder(
            ulkeKodu: ulkeKodu,
            telefon: ulusalTelefon,
          );
          if (!mounted) return;
          _startTtl(300);
        } else {
          final r = await AuthService.instance.girisKodGonder(
            ulkeKodu: ulkeKodu,
            telefon: ulusalTelefon,
          );
          if (!mounted) return;
          setState(() => _girisAd = r.ad);
          _startTtl(r.gecerlilikSn);
        }
        if (!mounted) return;
        setState(() => _codeSent = true);
        _startResend(60); // numara başına 60 sn bekleme
        return;
      }

      // --- 2. adım: kod ile giriş / kayıt ---
      if (_register) {
        await AuthService.instance.kayit(
          isim: _isimC.text,
          soyisim: _soyisimC.text,
          email: email,
          telefon: ulusalTelefon,
          ulkeKodu: ulkeKodu,
          kod: _kodC.text.trim(), // parola gönderilmez (SMS ile giriş)
          cinsiyet: _cinsiyet,
          dogumGunu: _dogumIso,
          ilceId: _ilceId,
        );
      } else {
        await AuthService.instance.girisKodIle(
          ulkeKodu: ulkeKodu,
          telefon: ulusalTelefon,
          kod: _kodC.text.trim(),
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on KayitGerekliException catch (e) {
      // Numara kayıtlı değil → kayıt moduna geçir, girilen numarayı koru.
      if (!mounted) return;
      setState(() {
        _register = true;
        _codeSent = false;
        _kodC.clear();
        _error = null;
        _info = e.message;
      });
      _ttlTimer?.cancel();
      _ensureIlceler();
    } on GirisGerekliException catch (e) {
      // Numara zaten kayıtlı → giriş moduna geçir, numarayı koru.
      if (!mounted) return;
      _ttlTimer?.cancel();
      setState(() {
        _register = false;
        _codeSent = false;
        _kodC.clear();
        _error = null;
        _info = e.message;
      });
    } on KodHataliException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _kodC.clear();
      });
    } on KodGerekliException catch (e) {
      // Kodun süresi doldu / hak bitti → yeni kod istenmeli.
      if (!mounted) return;
      _ttlTimer?.cancel();
      setState(() {
        _error = e.message;
        _codeTtl = 0;
        _kodC.clear();
      });
      _resendTimer?.cancel();
      setState(() => _resend = 0);
    } on RateLimitException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
      // Sunucu Retry-After verdiyse onu, yoksa makul bir varsayılan kullan.
      _startCooldown(e.retryAfter?.inSeconds ?? 20);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _msg(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _header(),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                22,
                8,
                22,
                24 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _codeSent
                        ? (_girisAd != null ? 'Merhaba $_girisAd' : 'Kodu gir')
                        : (_register ? 'Aramıza katıl' : 'Tekrar hoş geldin'),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _codeSent
                        ? 'Telefonuna gönderdiğimiz 6 haneli kodu gir.'
                        : (_register
                              ? 'Bilgilerinle ücretsiz bir hesap oluştur.'
                              : 'Telefon numaranla giriş yap, şifre gerekmez.'),
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 22),
                  if (_register) ...[
                    Row(
                      children: [
                        Expanded(
                          child: _field(
                            _isimC,
                            'Ad *',
                            Icons.person_outline,
                            textInputAction: TextInputAction.next,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _field(
                            _soyisimC,
                            'Soyad *',
                            Icons.badge_outlined,
                            textInputAction: TextInputAction.next,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                  ],
                  // Telefon her iki modda da giriş anahtarıdır. Kod adımında
                  // salt-okunur özet gösterilir ("Değiştir" ile geri dönülür).
                  if (_codeSent) _phoneSummary() else _phoneField(),
                  const SizedBox(height: 14),
                  if (_register && !_codeSent) ...[
                    _field(
                      _emailC,
                      'E-posta *',
                      Icons.mail_outline,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (_codeSent) _codeField(),
                  if (_register && !_codeSent) ...[
                    const SizedBox(height: 20),
                    _sectionLabel('Cinsiyet'),
                    const SizedBox(height: 8),
                    _genderChips(),
                    const SizedBox(height: 18),
                    _sectionLabel('Doğum günü (opsiyonel)'),
                    const SizedBox(height: 8),
                    _dogumField(),
                    if (_ilceler.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      _sectionLabel('İlçe (opsiyonel · İstanbul)'),
                      const SizedBox(height: 8),
                      _ilceField(),
                    ],
                  ],
                  if (_info != null) ...[
                    const SizedBox(height: 16),
                    _infoBox(_info!),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    _errorBox(_error!),
                  ],
                  const SizedBox(height: 24),
                  _primaryButton(),
                  const SizedBox(height: 16),
                  if (!_codeSent) _switchModeRow(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Sade beyaz başlık: kapat butonu + logo (gradyan kaldırıldı).
  Widget _header() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 18),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 20,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              width: 68,
              height: 68,
              decoration: const BoxDecoration(
                color: AppColors.primarySoft,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: KedyIcon(size: 34, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 12),
            const GezgahWordmark(color: AppColors.primary, size: 32),
          ],
        ),
      ),
    );
  }

  /// Kod adımında numarayı salt-okunur gösterir; "Değiştir" ile geri dönülür.
  Widget _phoneSummary() {
    final (dial, national) = _splitPhone();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          const Icon(Icons.phone_outlined, size: 19, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$dial $national',
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
          ),
          GestureDetector(
            onTap: _busy ? null : _editPhone,
            child: const Text(
              'Değiştir',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Bilgilendirme kutusu (kod gönderildi / kayıt gerekli gibi durumlar).
  Widget _infoBox(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Align(
    alignment: Alignment.centerLeft,
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      ),
    ),
  );

  Widget _genderChips() {
    const options = [('erkek', 'Erkek'), ('kadin', 'Kadın')];
    return Row(
      children: [
        for (final (value, label) in options) ...[
          Expanded(
            child: GestureDetector(
              onTap: () =>
                  setState(() => _cinsiyet = _cinsiyet == value ? null : value),
              child: Container(
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _cinsiyet == value
                      ? AppColors.primarySoft
                      : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _cinsiyet == value
                        ? AppColors.primary
                        : AppColors.line,
                    width: _cinsiyet == value ? 1.4 : 1,
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: _cinsiyet == value
                        ? AppColors.primary
                        : AppColors.ink,
                  ),
                ),
              ),
            ),
          ),
          if (value != options.last.$1) const SizedBox(width: 10),
        ],
      ],
    );
  }

  Widget _dogumField() {
    final has = _dogum != null;
    return GestureDetector(
      onTap: _pickDogum,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            const Icon(Icons.cake_outlined, size: 19, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                has
                    ? '${_dogum!.day.toString().padLeft(2, '0')}.'
                          '${_dogum!.month.toString().padLeft(2, '0')}.'
                          '${_dogum!.year}'
                    : 'Tarih seç',
                style: TextStyle(
                  fontSize: 15,
                  color: has ? AppColors.ink : AppColors.muted,
                ),
              ),
            ),
            if (has)
              GestureDetector(
                onTap: () => setState(() => _dogum = null),
                child: const Icon(
                  Icons.clear,
                  size: 18,
                  color: AppColors.muted,
                ),
              )
            else
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: AppColors.primary,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickIlce() async {
    FocusScope.of(context).unfocus();
    final res = await showNativePicker<int?>(
      context,
      title: 'İlçe seç',
      selected: _ilceId,
      options: [(null, 'Seçilmedi'), for (final i in _ilceler) (i.id, i.ad)],
    );
    if (res != null && mounted) setState(() => _ilceId = res.value);
  }

  Widget _ilceField() {
    String label = 'İlçe seç';
    if (_ilceId != null) {
      for (final i in _ilceler) {
        if (i.id == _ilceId) {
          label = i.ad;
          break;
        }
      }
    }
    final has = _ilceId != null;
    return GestureDetector(
      onTap: _pickIlce,
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
            const Icon(
              Icons.location_on_outlined,
              size: 19,
              color: AppColors.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  color: has ? AppColors.ink : AppColors.muted,
                ),
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down,
              size: 20,
              color: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }

  /// Kayıt SMS doğrulama kodu alanı (+ yeniden gönder).
  Widget _codeField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.primary, width: 1.4),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.sms_outlined,
                size: 19,
                color: AppColors.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _kodC,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  autofocus: true,
                  // iOS/Android klavyesinde SMS kodunu tek dokunuşla doldurur;
                  // doldurulduğunda otomatik gönderim devreye girer.
                  autofillHints: const [AutofillHints.oneTimeCode],
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  decoration: const InputDecoration(
                    hintText: 'SMS doğrulama kodu',
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
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                _codeTtl > 0
                    ? 'Kodun geçerlilik süresi: $_ttlLabel'
                    : 'Kodun süresi doldu, yeni kod isteyebilirsin.',
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ),
            GestureDetector(
              onTap: _resend > 0 ? null : _resendCode,
              child: Text(
                _resend > 0 ? 'Tekrar gönder ($_resend sn)' : 'Tekrar gönder',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: _resend > 0 ? AppColors.muted : AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _primaryButton() {
    final cooling = _cooldown > 0;
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: (_busy || cooling) ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.6),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: _busy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Text(
                cooling
                    ? 'Tekrar dene ($_cooldown sn)'
                    : (!_codeSent
                          ? 'Doğrulama Kodu Gönder'
                          : (_register ? 'Kayıt Ol' : 'Giriş Yap')),
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Widget _switchModeRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _register ? 'Zaten üye misin?' : 'Hesabın yok mu?',
          style: const TextStyle(fontSize: 13.5, color: AppColors.muted),
        ),
        TextButton(
          onPressed: _busy ? null : _toggleMode,
          child: Text(
            _register ? 'Giriş yap' : 'Kayıt ol',
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
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

  /// Bayraklı ülke seçici (+ülke kodu) + numara alanı. Ülke seçilince
  /// numaranın boşluk/gruplaması ve uzunluğu o ülkenin standardına göre
  /// (libphonenumber "as-you-type") otomatik biçimlenir.
  Widget _phoneField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: InternationalPhoneNumberInput(
        onInputChanged: (n) {
          _phone = n;
          final iso = n.isoCode;
          if (iso != null && iso != _phoneIso) {
            _phoneIso = iso;
            _phoneMaxDigits = _maxDigitsFor(iso);
            // Yeni ülke limitini mevcut girişe hemen uygula.
            _enforcePhoneLimit();
          }
        },
        initialValue: _phone,
        textFieldController: _telefonC,
        formatInput: true, // ülkeye göre boşluk/gruplama
        maxLength: 20, // hane limitini kendimiz uyguluyoruz (bkz. _enforce)
        keyboardType: TextInputType.phone,
        autoValidateMode: AutovalidateMode.disabled,
        ignoreBlank: true,
        spaceBetweenSelectorAndTextField: 0,
        selectorConfig: const SelectorConfig(
          selectorType: PhoneInputSelectorType.BOTTOM_SHEET,
          setSelectorButtonAsPrefixIcon: true,
          showFlags: true,
          useEmoji: false,
          leadingPadding: 8,
          trailingSpace: false,
        ),
        selectorTextStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
        textStyle: const TextStyle(fontSize: 15, color: AppColors.ink),
        inputDecoration: const InputDecoration(
          hintText: 'Telefon *',
          hintStyle: TextStyle(color: AppColors.muted),
          border: InputBorder.none,
          isCollapsed: true,
          contentPadding: EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String hint,
    IconData icon, {
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
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
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              textInputAction: textInputAction,
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
}
