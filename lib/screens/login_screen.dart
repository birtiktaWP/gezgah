import 'package:dlibphonenumber/dlibphonenumber.dart' as libphone;
import 'package:flutter/material.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';

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

/// Parolalı üye giriş/kayıt ekranı (UYE_LOGIN.md).
///
/// İki mod: **Giriş** (e-posta + parola) ve **Kayıt** (Ad, Soyad, E-posta,
/// Telefon, Parola zorunlu; Cinsiyet, doğum günü, ilçe opsiyonel — şehir hep
/// İstanbul). Parola en az 6 karakter.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _register = false; // false: giriş, true: kayıt
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  final _isimC = TextEditingController();
  final _soyisimC = TextEditingController();
  final _emailC = TextEditingController();
  final _telefonC = TextEditingController();
  final _parolaC = TextEditingController();

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
      final ex = util.getExampleNumberForType(
              regionCode: iso, type: libphone.PhoneNumberType.mobile) ??
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

  @override
  void dispose() {
    _telefonC.removeListener(_enforcePhoneLimit);
    _isimC.dispose();
    _soyisimC.dispose();
    _emailC.dispose();
    _telefonC.dispose();
    _parolaC.dispose();
    super.dispose();
  }

  void _toggleMode() {
    setState(() {
      _register = !_register;
      _error = null;
    });
    if (_register) _ensureIlceler();
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
    final parola = _parolaC.text;
    final digits = _telefonC.text.replaceAll(RegExp(r'\D'), '');

    if (_register) {
      final isim = _isimC.text.trim();
      final soyisim = _soyisimC.text.trim();
      if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
        setState(() => _error = 'Geçerli bir e-posta adresi gir.');
        return;
      }
      if (isim.isEmpty) {
        setState(() => _error = 'Adını gir.');
        return;
      }
      if (soyisim.isEmpty) {
        setState(() => _error = 'Soyadını gir.');
        return;
      }
      if (digits.length < 7 || digits.length > 15) {
        setState(() => _error = 'Geçerli bir telefon numarası gir.');
        return;
      }
      if (parola.length < 6) {
        setState(() => _error = 'Şifre en az 6 karakter olmalı.');
        return;
      }
    } else {
      if (digits.length < 7 || digits.length > 15) {
        setState(() => _error = 'Geçerli bir telefon numarası gir.');
        return;
      }
      if (parola.isEmpty) {
        setState(() => _error = 'Şifreni gir.');
        return;
      }
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_register) {
        final (ulkeKodu, ulusalTelefon) = _splitPhone();
        await AuthService.instance.kayit(
          isim: _isimC.text,
          soyisim: _soyisimC.text,
          email: email,
          telefon: ulusalTelefon,
          ulkeKodu: ulkeKodu,
          parola: parola,
          cinsiyet: _cinsiyet,
          dogumGunu: _dogumIso,
          ilceId: _ilceId,
        );
      } else {
        final (ulkeKodu, ulusalTelefon) = _splitPhone();
        await AuthService.instance.giris(ulkeKodu, ulusalTelefon, parola);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          _header(),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                  22, 24, 22, 24 + MediaQuery.of(context).viewInsets.bottom),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(_register ? 'Aramıza katıl' : 'Tekrar hoş geldin',
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(
                    _register
                        ? 'Bilgilerinle ücretsiz bir hesap oluştur.'
                        : 'Telefon ve şifrenle giriş yap.',
                    style:
                        const TextStyle(fontSize: 13.5, color: AppColors.muted),
                  ),
                  const SizedBox(height: 22),
                  if (_register) ...[
                    Row(
                      children: [
                        Expanded(
                          child: _field(_isimC, 'Ad *', Icons.person_outline,
                              textInputAction: TextInputAction.next),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _field(
                              _soyisimC, 'Soyad *', Icons.badge_outlined,
                              textInputAction: TextInputAction.next),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                  ],
                  // Telefon her iki modda da giriş anahtarıdır.
                  _phoneField(),
                  const SizedBox(height: 14),
                  if (_register) ...[
                    _field(_emailC, 'E-posta *', Icons.mail_outline,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next),
                    const SizedBox(height: 14),
                  ],
                  _passwordField(),
                  if (_register) ...[
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
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    _errorBox(_error!),
                  ],
                  const SizedBox(height: 24),
                  _primaryButton(),
                  const SizedBox(height: 16),
                  _switchModeRow(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 26),
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0.7, -1.1),
          radius: 1.2,
          colors: [AppColors.primary2, AppColors.primary],
          stops: [0.0, 0.55],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Row(
              children: [
                GlassButton(
                    icon: Icons.close, onTap: () => Navigator.pop(context)),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child:
                  const Center(child: KedyIcon(size: 36, color: Colors.white)),
            ),
            const SizedBox(height: 12),
            const GezgahWordmark(color: Colors.white, size: 36.96),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Align(
        alignment: Alignment.centerLeft,
        child: Text(text,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.ink)),
      );

  Widget _genderChips() {
    const options = [
      ('erkek', 'Erkek'),
      ('kadin', 'Kadın'),
    ];
    return Row(
      children: [
        for (final (value, label) in options) ...[
          Expanded(
            child: GestureDetector(
              onTap: () => setState(
                  () => _cinsiyet = _cinsiyet == value ? null : value),
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
                      width: _cinsiyet == value ? 1.4 : 1),
                ),
                child: Text(label,
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: _cinsiyet == value
                            ? AppColors.primary
                            : AppColors.ink)),
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
                    color: has ? AppColors.ink : AppColors.muted),
              ),
            ),
            if (has)
              GestureDetector(
                onTap: () => setState(() => _dogum = null),
                child:
                    const Icon(Icons.clear, size: 18, color: AppColors.muted),
              )
            else
              const Icon(Icons.chevron_right,
                  size: 20, color: AppColors.primary),
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
      options: [
        (null, 'Seçilmedi'),
        for (final i in _ilceler) (i.id, i.ad),
      ],
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
            const Icon(Icons.location_on_outlined,
                size: 19, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 15,
                      color: has ? AppColors.ink : AppColors.muted)),
            ),
            const Icon(Icons.keyboard_arrow_down,
                size: 20, color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  Widget _primaryButton() {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: _busy ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.6),
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: _busy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: Colors.white),
              )
            : Text(_register ? 'Kayıt Ol' : 'Giriş Yap',
                style: const TextStyle(
                    fontSize: 15.5, fontWeight: FontWeight.w800)),
      ),
    );
  }

  Widget _switchModeRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(_register ? 'Zaten üye misin?' : 'Hesabın yok mu?',
            style: const TextStyle(fontSize: 13.5, color: AppColors.muted)),
        TextButton(
          onPressed: _busy ? null : _toggleMode,
          child: Text(_register ? 'Giriş yap' : 'Kayıt ol',
              style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary)),
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

  /// Parola alanı (göster/gizle ile).
  Widget _passwordField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline, size: 19, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _parolaC,
              obscureText: _obscure,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText: _register ? 'Şifre (en az 6 karakter) *' : 'Şifre *',
                hintStyle: const TextStyle(color: AppColors.muted),
                border: InputBorder.none,
                isCollapsed: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
          ),
          IconButton(
            icon: Icon(
                _obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: 20,
                color: AppColors.muted),
            onPressed: () => setState(() => _obscure = !_obscure),
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
            fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.ink),
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
