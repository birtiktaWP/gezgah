import 'package:dlibphonenumber/dlibphonenumber.dart' as libphone;
import 'package:flutter/material.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/auth_service.dart';
import '../data/legal_texts.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'favorites_screen.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback onGoHome;
  final VoidCallback onOpenNotifications;
  const ProfileScreen({
    super.key,
    required this.onGoHome,
    required this.onOpenNotifications,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Sözleşme başlıkları — içerik uygulama içinde metin olarak gösterilir
  // (bkz. data/legal_texts.dart).
  static const List<String> _legalDocs = [
    'Kullanıcı Sözleşmesi',
    'Gizlilik Politikası',
    'KVKK Aydınlatma Metni',
    'Açık Rıza Metni',
  ];

  AppUser? get _user => AuthService.instance.user.value;

  /// Ad/soyaddan baş harf(ler) — avatar yerine kullanılır.
  String get _initials {
    final parts = _displayName
        .trim()
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'Ü';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts[1].substring(0, 1))
        .toUpperCase();
  }

  /// Kartta gösterilecek ad (yoksa e-posta ön eki, o da yoksa "Üye").
  String get _displayName {
    final u = _user;
    if (u == null) return 'Misafir';
    if (u.fullName.isNotEmpty) return u.fullName;
    if (u.email.isNotEmpty) return u.email.split('@').first;
    return 'Üye';
  }

  String get _displayEmail => _user?.email ?? '';

  @override
  Widget build(BuildContext context) {
    // Oturum değişince (giriş/çıkış/profil düzenleme) kart otomatik güncellenir.
    return ValueListenableBuilder<AppUser?>(
      valueListenable: AuthService.instance.user,
      builder: (context, _, __) {
        return ListView(
          padding: const EdgeInsets.only(bottom: 130),
          children: [
            _hero(),
            const SizedBox(height: 18),
            _stats(),
            const SizedBox(height: 8),
            _group('Profilim', [
              _row(Icons.person_outline, 'Profil Bilgileri',
                  'Ad, e-posta, telefon',
                  onTap: _openProfileEdit),
              _row(Icons.favorite_border, 'Favorilerim',
                  'Kaydettiğin mekanlar',
                  onTap: _openFavorites),
              _row(Icons.lock_outline, 'Şifre Değiştir',
                  'Hesap parolanı güncelle',
                  onTap: _openPasswordChange),
            ]),
            _group('Sözleşmeler', [
              for (final title in _legalDocs)
                _row(_docIcon(title), title, _docSub(title),
                    onTap: () => _openDoc(title)),
            ]),
            _group(null, [
              _row(Icons.logout, 'Çıkış Yap', null,
                  danger: true, onTap: _confirmLogout),
            ]),
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Center(
                child: Text('Gezgah · Sürüm 1.0.0',
                    style: TextStyle(fontSize: 12, color: AppColors.muted)),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Onay iste, ardından oturumu kapat ve ana sayfaya dön (Hesabım giriş ister).
  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Çıkış Yap'),
        content:
            const Text('Hesabından çıkış yapmak istediğine emin misin?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Çıkış Yap',
                style: TextStyle(
                    color: AppColors.closing, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await AuthService.instance.logout();
    if (!mounted) return;
    widget.onGoHome();
  }

  IconData _docIcon(String name) {
    switch (name) {
      case 'Gizlilik Politikası':
        return Icons.shield_outlined;
      case 'KVKK Aydınlatma Metni':
        return Icons.lock_outline;
      case 'Açık Rıza Metni':
        return Icons.how_to_reg_outlined;
      default:
        return Icons.description_outlined;
    }
  }

  String _docSub(String name) {
    switch (name) {
      case 'Kullanıcı Sözleşmesi':
        return 'Hizmet kullanım koşulları';
      case 'Gizlilik Politikası':
        return 'Verilerinin korunması';
      case 'KVKK Aydınlatma Metni':
        return 'Kişisel veri politikası';
      case 'Açık Rıza Metni':
        return 'Onay ve izin beyanları';
      default:
        return '';
    }
  }

  Widget _hero() {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 30),
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
                    icon: Icons.chevron_left, onTap: widget.onGoHome),
                const Expanded(
                  child: Center(
                    child: Text('Hesabım',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Colors.white)),
                  ),
                ),
                GlassButton(
                  icon: Icons.notifications_none,
                  showDot: true,
                  onTap: widget.onOpenNotifications,
                ),
                const SizedBox(width: 10),
                GlassButton(icon: Icons.settings_outlined, onTap: _openSettings),
              ],
            ),
            const SizedBox(height: 22),
            _userCard(),
          ],
        ),
      ),
    );
  }

  Widget _userCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.2),
              border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
            ),
            child: Text(_initials,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_displayName,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
                if (_displayEmail.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(_displayEmail,
                      style: TextStyle(
                          fontSize: 12.5,
                          color: Colors.white.withValues(alpha: 0.8))),
                ],
              ],
            ),
          ),
          GestureDetector(
            onTap: _openProfileEdit,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit_outlined, size: 15, color: AppColors.primary),
                  SizedBox(width: 5),
                  Text('Düzenle',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stats() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 22),
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppShadows.listTile,
      ),
      child: Row(
        children: [
          _stat('24', 'Favori'),
          _statDivider(),
          _stat('12', 'Değerlendirme'),
          _statDivider(),
          _stat('340', 'Puan'),
        ],
      ),
    );
  }

  Widget _stat(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(fontSize: 11, color: AppColors.muted)),
        ],
      ),
    );
  }

  Widget _statDivider() =>
      Container(width: 1, height: 32, color: AppColors.line);

  Widget _group(String? title, List<Widget> rows) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink)),
            ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppShadows.listTile,
            ),
            child: Column(children: rows),
          ),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String title, String? sub,
      {bool danger = false, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                  color: danger
                      ? const Color(0x1AE0533D)
                      : AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(11)),
              child: Icon(icon,
                  size: 19,
                  color: danger ? AppColors.closing : AppColors.primary),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: danger ? AppColors.closing : AppColors.ink)),
                  if (sub != null) ...[
                    const SizedBox(height: 2),
                    Text(sub,
                        style: const TextStyle(
                            fontSize: 12.5, color: AppColors.muted)),
                  ],
                ],
              ),
            ),
            if (!danger)
              const Icon(Icons.chevron_right,
                  size: 20, color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  // ---- Paneller ----

  void _openSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _SettingsSheet(),
    );
  }

  void _openDoc(String title) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LegalSheet(title: title),
    );
  }

  void _openProfileEdit() {
    final u = _user;
    if (u == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProfileEditSheet(user: u),
    );
  }

  void _openFavorites() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FavoritesScreen()),
    );
  }

  void _openPasswordChange() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _PasswordChangeSheet(),
    );
  }
}

/// Ortak panel başlığı
class _SheetScaffold extends StatelessWidget {
  final String title;
  final Widget child;
  final bool backArrow;
  const _SheetScaffold(
      {required this.title, required this.child, this.backArrow = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(backArrow ? Icons.chevron_left : Icons.close,
                      color: AppColors.ink),
                ),
                Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.line),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _SettingsSheet extends StatefulWidget {
  const _SettingsSheet();

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  bool _notif = true;
  bool _location = true;

  @override
  Widget build(BuildContext context) {
    return _SheetScaffold(
      title: 'Uygulama Ayarları',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
        children: [
          const Text('Tercihler',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink)),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppShadows.listTile,
            ),
            child: Column(
              children: [
                _switchRow(Icons.notifications_none, 'Bildirimler',
                    'Kampanya ve etkinlik bildirimleri', _notif,
                    (v) => setState(() => _notif = v)),
                _switchRow(Icons.location_on_outlined, 'Konum İzni',
                    'Yakınındaki mekanları göster', _location,
                    (v) => setState(() => _location = v)),
                _navRow(Icons.language, 'Dil', 'Türkçe',
                    onTap: _showLanguageSheet),
                _navRow(Icons.chat_outlined, 'WhatsApp Destek',
                    'Bize WhatsApp\u2019tan yaz', onTap: _openWhatsApp),
              ],
            ),
          ),
          const SizedBox(height: 26),
          SizedBox(
            height: 50,
            child: OutlinedButton.icon(
              onPressed: _confirmDeleteAccount,
              icon: const Icon(Icons.delete_outline, size: 20),
              label: const Text('Hesabımı Sil',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.closing,
                side: const BorderSide(color: AppColors.closing),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// WhatsApp destek hattına mesaj penceresi açar (0552 701 77 73).
  Future<void> _openWhatsApp() async {
    final uri = Uri.parse('https://wa.me/905527017773');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// Dil değiştirme alt sayfası — görsel amaçlı, henüz işlevsel değil.
  void _showLanguageSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 18, 20, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Dil',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
            for (final lang in const [
              ('Türkçe', true),
              ('English', false),
              ('Deutsch', false),
              ('Русский', false),
            ])
              ListTile(
                title: Text(lang.$1),
                trailing: lang.$2
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () => Navigator.pop(ctx),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Hesap silme talebi — onay sonrası "talebiniz alınmıştır" modalı gösterir
  /// ve ardından otomatik olarak oturumu kapatır.
  Future<void> _confirmDeleteAccount() async {
    final navigator = Navigator.of(context);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Color(0xFFEAF8EF),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle,
                  size: 40, color: AppColors.open),
            ),
            const SizedBox(height: 16),
            const Text('Talebiniz alınmıştır',
                textAlign: TextAlign.center,
                style:
                    TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text(
                'Hesap silme talebin alındı. İşlem tamamlandığında '
                'bilgilendirileceksin.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13.5, color: AppColors.muted)),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Tamam',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
    // Onaydan sonra oturumu kapat ve ayarlar sayfasını kapat. MainShell
    // oturum kapanınca otomatik olarak ana sayfaya döner.
    await AuthService.instance.logout();
    navigator.pop();
  }

  Widget _switchRow(IconData icon, String title, String sub, bool value,
      ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          _iconBox(icon),
          const SizedBox(width: 13),
          Expanded(child: _texts(title, sub)),
          Switch(
            value: value,
            activeThumbColor: Colors.white,
            activeTrackColor: AppColors.primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _navRow(IconData icon, String title, String sub, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            _iconBox(icon),
            const SizedBox(width: 13),
            Expanded(child: _texts(title, sub)),
            const Icon(Icons.chevron_right, size: 20, color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  Widget _iconBox(IconData icon) => Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(11)),
        child: Icon(icon, size: 19, color: AppColors.primary),
      );

  Widget _texts(String title, String sub) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(sub,
              style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
        ],
      );
}

/// Sözleşme metnini modal içinde metin olarak gösterir (bkz. legal_texts.dart).
class _LegalSheet extends StatelessWidget {
  final String title;
  const _LegalSheet({required this.title});

  @override
  Widget build(BuildContext context) {
    final sections = kLegalTexts[title];
    return _SheetScaffold(
      title: title,
      backArrow: true,
      child: sections == null
          ? _placeholder()
          : ListView.separated(
              padding: EdgeInsets.fromLTRB(
                  22, 20, 22, 28 + MediaQuery.of(context).viewInsets.bottom),
              itemCount: sections.length,
              separatorBuilder: (_, __) => const SizedBox(height: 20),
              itemBuilder: (_, i) => _section(sections[i]),
            ),
    );
  }

  Widget _placeholder() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.description_outlined, size: 40, color: AppColors.muted),
            SizedBox(height: 12),
            Text('Bu metin yakında eklenecek.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppColors.muted)),
          ],
        ),
      ),
    );
  }

  Widget _section(LegalSection s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (s.heading != null) ...[
          Text(s.heading!,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink)),
          const SizedBox(height: 10),
        ],
        for (var i = 0; i < s.paragraphs.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _paragraph(s.paragraphs[i]),
        ],
      ],
    );
  }

  /// `**...**` işaretli kısımları kalın gösteren basit paragraf oluşturucu.
  Widget _paragraph(String text) {
    const base = TextStyle(
        fontSize: 13.5, height: 1.55, color: AppColors.muted);
    final spans = <TextSpan>[];
    final parts = text.split('**');
    for (var i = 0; i < parts.length; i++) {
      if (parts[i].isEmpty) continue;
      spans.add(TextSpan(
        text: parts[i],
        style: i.isOdd
            ? const TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink)
            : null,
      ));
    }
    return RichText(text: TextSpan(style: base, children: spans));
  }
}

/// Profil düzenleme paneli — `/uye/guncelle` (UYE_LOGIN.md). Avatar yoktur;
/// ad, soyad, e-posta, telefon, cinsiyet, doğum günü ve ilçe güncellenebilir.
class _ProfileEditSheet extends StatefulWidget {
  final AppUser user;
  const _ProfileEditSheet({required this.user});

  @override
  State<_ProfileEditSheet> createState() => _ProfileEditSheetState();
}

class _ProfileEditSheetState extends State<_ProfileEditSheet> {
  late final TextEditingController _isimC =
      TextEditingController(text: widget.user.isim);
  late final TextEditingController _soyisimC =
      TextEditingController(text: widget.user.soyisim);
  late final TextEditingController _emailC =
      TextEditingController(text: widget.user.email);
  // Numara, uluslararası alan tarafından (initialValue) doldurulur.
  final TextEditingController _telefonC = TextEditingController();

  late String _cinsiyet = widget.user.cinsiyet; // '' | erkek | kadin | diger
  late String _dogumGunu = widget.user.dogumGunu; // '' | YYYY-MM-DD
  late int? _ilceId = widget.user.ilceId;

  // Telefon: seçili ülke + hane limiti (login ekranıyla aynı mantık).
  PhoneNumber _phone = PhoneNumber(isoCode: 'TR');
  int _phoneMaxDigits = 10;
  String _phoneIso = 'TR';
  TextEditingValue _lastPhoneValue = TextEditingValue.empty;
  bool _enforcingPhone = false;

  List<Ilce> _ilceler = const [];
  bool _ilcelerLoading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadIlceler();
    _phoneMaxDigits = _maxDigitsFor(_phoneIso);
    _telefonC.addListener(_enforcePhoneLimit);
    _initPhone();
  }

  /// Mevcut kayıtlı numarayı (ulusal numara + kayıtlı ülke kodu) uluslararası
  /// alana önceden yükler.
  Future<void> _initPhone() async {
    var raw = widget.user.telefon.trim();
    if (raw.isEmpty) return;
    if (!raw.startsWith('+')) {
      // Kayıtlı ülke kodunu kullan (yoksa +90); baştaki 0'ı at.
      final dial = widget.user.ulkeKodu.isNotEmpty ? widget.user.ulkeKodu : '+90';
      var d = raw.replaceAll(RegExp(r'\D'), '');
      if (d.startsWith('0')) d = d.substring(1);
      raw = '$dial$d';
    }
    try {
      final parsed = await PhoneNumber.getRegionInfoFromPhoneNumber(raw);
      if (!mounted) return;
      setState(() {
        _phone = parsed;
        _phoneIso = parsed.isoCode ?? 'TR';
        _phoneMaxDigits = _maxDigitsFor(_phoneIso);
      });
    } catch (_) {
      // Ayrıştırılamazsa TR varsayılanıyla boş başlar.
    }
  }

  /// Ülkenin örnek mobil numarasından izin verilen ulusal hane sayısı.
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

  /// Hane sayısı ülke limitini aşarsa girişi engeller (son geçerli değere döner).
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

  /// Bayraklı ülke seçici + numara alanı; ülkeye göre boşluk/limit (login ile
  /// aynı mantık).
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
            _enforcePhoneLimit();
          }
        },
        initialValue: _phone,
        textFieldController: _telefonC,
        formatInput: true,
        maxLength: 20,
        keyboardType:
            const TextInputType.numberWithOptions(signed: true, decimal: true),
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
          hintText: 'Telefon',
          hintStyle: TextStyle(color: AppColors.muted),
          border: InputBorder.none,
          isCollapsed: true,
          contentPadding: EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }

  Future<void> _loadIlceler() async {
    final list = await AuthService.instance.ilceler();
    if (!mounted) return;
    setState(() {
      _ilceler = list;
      _ilcelerLoading = false;
    });
  }

  @override
  void dispose() {
    _telefonC.removeListener(_enforcePhoneLimit);
    _isimC.dispose();
    _soyisimC.dispose();
    _emailC.dispose();
    _telefonC.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final isim = _isimC.text.trim();
    final soyisim = _soyisimC.text.trim();
    final email = _emailC.text.trim();
    // Seçili ülke kodu (+90…) ile ulusal numarayı ayrı gönder.
    final (ulkeKodu, telefon) = _splitPhone();
    if (isim.isEmpty || soyisim.isEmpty) {
      setState(() => _error = 'Ad ve soyad zorunlu.');
      return;
    }
    if (!email.contains('@') || !email.contains('.')) {
      setState(() => _error = 'Geçerli bir e-posta gir.');
      return;
    }
    if (telefon.replaceAll(RegExp(r'\D'), '').length < 7) {
      setState(() => _error = 'Geçerli bir telefon gir.');
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AuthService.instance.guncelleProfil(
        isim: isim,
        soyisim: soyisim,
        email: email,
        telefon: telefon,
        ulkeKodu: ulkeKodu,
        cinsiyet: _cinsiyet,
        dogumGunu: _dogumGunu,
        ilceId: _ilceId,
      );
      if (!mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(
        const SnackBar(content: Text('Profilin güncellendi.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SheetScaffold(
      title: 'Profil Bilgileri',
      backArrow: true,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
            22, 18, 22, 24 + MediaQuery.of(context).viewInsets.bottom),
        children: [
          _label('Ad'),
          _field(_isimC, Icons.person_outline,
              hint: 'Adın', textCap: TextCapitalization.words),
          const SizedBox(height: 16),
          _label('Soyad'),
          _field(_soyisimC, Icons.badge_outlined,
              hint: 'Soyadın', textCap: TextCapitalization.words),
          const SizedBox(height: 16),
          _label('E-posta'),
          _field(_emailC, Icons.mail_outline,
              hint: 'ornek@eposta.com',
              keyboard: TextInputType.emailAddress),
          const SizedBox(height: 16),
          _label('Telefon'),
          _phoneField(),
          const SizedBox(height: 16),
          _label('Cinsiyet'),
          _genderSelector(),
          const SizedBox(height: 16),
          _label('Doğum Günü'),
          _dateField(),
          const SizedBox(height: 16),
          _label('İlçe'),
          _ilceField(),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0x14E0533D),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0x33E0533D)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline,
                      size: 18, color: AppColors.closing),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(_error!,
                        style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.closing,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 26),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _busy ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    AppColors.primary.withValues(alpha: 0.6),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white),
                    )
                  : const Text('Değişiklikleri Kaydet',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 2),
        child: Text(t,
            style:
                const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      );

  Widget _field(TextEditingController c, IconData icon,
      {String? hint,
      TextInputType? keyboard,
      TextCapitalization textCap = TextCapitalization.none}) {
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
              controller: c,
              keyboardType: keyboard,
              textCapitalization: textCap,
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

  Widget _shell({required Widget child}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.line),
        ),
        child: child,
      );

  Widget _genderSelector() {
    return Row(
      children: [
        _genderChip('kadin', 'Kadın'),
        const SizedBox(width: 10),
        _genderChip('erkek', 'Erkek'),
      ],
    );
  }

  Widget _genderChip(String val, String label) {
    final sel = _cinsiyet == val;
    return Expanded(
      child: GestureDetector(
        // Seçiliye tekrar dokununca temizlenir (boş = belirtilmemiş).
        onTap: () => setState(() => _cinsiyet = sel ? '' : val),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: sel ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: sel ? AppColors.primary : AppColors.line),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: sel ? Colors.white : AppColors.ink)),
        ),
      ),
    );
  }

  Widget _dateField() {
    final has = _dogumGunu.isNotEmpty;
    return _shell(
      child: Row(
        children: [
          const Icon(Icons.cake_outlined, size: 19, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: _pickDate,
              behavior: HitTestBehavior.opaque,
              child: Text(has ? _formatTr(_dogumGunu) : 'Tarih seç',
                  style: TextStyle(
                      fontSize: 14,
                      color: has ? AppColors.ink : AppColors.muted)),
            ),
          ),
          if (has)
            GestureDetector(
              onTap: () => setState(() => _dogumGunu = ''),
              child: const Icon(Icons.close, size: 18, color: AppColors.muted),
            )
          else
            const Icon(Icons.chevron_right, size: 20, color: AppColors.primary),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    FocusScope.of(context).unfocus();
    var init = DateTime(2000, 1, 1);
    final parsed = DateTime.tryParse(_dogumGunu);
    if (parsed != null) init = parsed;
    final picked = await showNativeDatePicker(
      context,
      initialDate: init,
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
      helpText: 'Doğum Günü',
    );
    if (picked != null && mounted) {
      final m = picked.month.toString().padLeft(2, '0');
      final d = picked.day.toString().padLeft(2, '0');
      setState(() => _dogumGunu = '${picked.year}-$m-$d');
    }
  }

  /// "YYYY-MM-DD" → "GG.AA.YYYY".
  String _formatTr(String iso) {
    final p = iso.split('-');
    if (p.length != 3) return iso;
    return '${p[2]}.${p[1]}.${p[0]}';
  }

  Widget _ilceField() {
    if (_ilcelerLoading) {
      return _shell(
        child: Row(
          children: const [
            Icon(Icons.location_city_outlined,
                size: 19, color: AppColors.primary),
            SizedBox(width: 12),
            Text('İlçeler yükleniyor…',
                style: TextStyle(fontSize: 14, color: AppColors.muted)),
            Spacer(),
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.primary),
            ),
          ],
        ),
      );
    }
    final val = _validIlceValue();
    String label = 'İlçe seç';
    Color color = AppColors.muted;
    if (val != null) {
      for (final il in _ilceler) {
        if (il.id == val) {
          label = il.ad;
          color = AppColors.ink;
          break;
        }
      }
    }
    return _shell(
      child: GestureDetector(
        onTap: _pickIlce,
        behavior: HitTestBehavior.opaque,
        child: Row(
          children: [
            const Icon(Icons.location_city_outlined,
                size: 19, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: TextStyle(fontSize: 14, color: color)),
            ),
            const Icon(Icons.keyboard_arrow_down, color: AppColors.primary),
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
      selected: _validIlceValue(),
      options: [
        (null, 'Belirtilmemiş'),
        for (final il in _ilceler) (il.id, il.ad),
      ],
    );
    if (res != null && mounted) setState(() => _ilceId = res.value);
  }

  /// Mevcut ilçe id listede yoksa dropdown'ı null'a düşür (assertion'ı önler).
  int? _validIlceValue() {
    if (_ilceId == null) return null;
    return _ilceler.any((i) => i.id == _ilceId) ? _ilceId : null;
  }
}

/// Şifre değiştirme paneli — `/uye/sifre-degistir` (UYE_LOGIN.md).
class _PasswordChangeSheet extends StatefulWidget {
  const _PasswordChangeSheet();

  @override
  State<_PasswordChangeSheet> createState() => _PasswordChangeSheetState();
}

class _PasswordChangeSheetState extends State<_PasswordChangeSheet> {
  final _eskiC = TextEditingController();
  final _yeniC = TextEditingController();
  bool _obscureEski = true;
  bool _obscureYeni = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _eskiC.dispose();
    _yeniC.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final eski = _eskiC.text;
    final yeni = _yeniC.text;
    if (eski.isEmpty) {
      setState(() => _error = 'Mevcut şifreni gir.');
      return;
    }
    if (yeni.length < 6) {
      setState(() => _error = 'Yeni şifre en az 6 karakter olmalı.');
      return;
    }
    if (yeni == eski) {
      setState(() => _error = 'Yeni şifre eskisinden farklı olmalı.');
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AuthService.instance.sifreDegistir(eski, yeni);
      if (!mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(
        const SnackBar(content: Text('Şifren güncellendi.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SheetScaffold(
      title: 'Şifre Değiştir',
      child: ListView(
        padding: EdgeInsets.fromLTRB(
            22, 18, 22, 24 + MediaQuery.of(context).viewInsets.bottom),
        children: [
          _passField('Mevcut şifre', _eskiC, _obscureEski,
              () => setState(() => _obscureEski = !_obscureEski)),
          const SizedBox(height: 14),
          _passField('Yeni şifre (en az 6 karakter)', _yeniC, _obscureYeni,
              () => setState(() => _obscureYeni = !_obscureYeni)),
          if (_error != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0x14E0533D),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0x33E0533D)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline,
                      size: 18, color: AppColors.closing),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(_error!,
                        style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.closing,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _busy ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    AppColors.primary.withValues(alpha: 0.6),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white),
                    )
                  : const Text('Şifreyi Güncelle',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _passField(String hint, TextEditingController controller,
      bool obscure, VoidCallback onToggle) {
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
              controller: controller,
              obscureText: obscure,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(color: AppColors.muted),
                border: InputBorder.none,
                isCollapsed: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
          ),
          IconButton(
            icon: Icon(
                obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: 20,
                color: AppColors.muted),
            onPressed: onToggle,
          ),
        ],
      ),
    );
  }
}
