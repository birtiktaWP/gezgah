import 'package:flutter/material.dart';
import '../data/auth_service.dart';
import '../data/mock_data.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

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
  static const String _avatar =
      'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=160&q=70';

  AppUser? get _user => AuthService.instance.user.value;

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
                  'Kaydettiğin mekanlar'),
              _row(Icons.lock_outline, 'Şifre Değiştir',
                  'Hesap parolanı güncelle',
                  onTap: _openPasswordChange),
            ]),
            _group('Sözleşmeler', [
              for (final entry in MockData.documents.entries)
                _row(_docIcon(entry.key), entry.key, _docSub(entry.key),
                    onTap: () => _openDoc(entry.key, entry.value)),
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
      case 'Çerez Politikası':
        return Icons.cookie_outlined;
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
      default:
        return 'Çerez tercihleri';
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
          ClipOval(
            child: SizedBox(
                width: 54, height: 54, child: NetImage(_avatar)),
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

  void _openDoc(String title, String body) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DocSheet(title: title, body: body),
    );
  }

  void _openProfileEdit() {
    final u = _user;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProfileEditSheet(
        name: u?.fullName ?? '',
        email: u?.email ?? '',
        avatar: _avatar,
        onSave: (n, e) {
          // "Ad Soyad" metnini ad + soyad olarak ayır.
          final parts =
              n.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
          final first = parts.isNotEmpty ? parts.first : '';
          final last = parts.length > 1 ? parts.sublist(1).join(' ') : '';
          AuthService.instance
              .updateProfile(isim: first, soyisim: last, email: e.trim());
        },
      ),
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
  bool _dark = false;

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
                _switchRow(Icons.dark_mode_outlined, 'Karanlık Mod',
                    'Koyu tema kullan', _dark, (v) => setState(() => _dark = v)),
                _navRow(Icons.language, 'Dil', 'Türkçe'),
                _navRow(Icons.help_outline, 'Yardım & Destek',
                    'Sıkça sorulan sorular'),
              ],
            ),
          ),
        ],
      ),
    );
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

  Widget _navRow(IconData icon, String title, String sub) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          _iconBox(icon),
          const SizedBox(width: 13),
          Expanded(child: _texts(title, sub)),
          const Icon(Icons.chevron_right, size: 20, color: AppColors.primary),
        ],
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

class _DocSheet extends StatelessWidget {
  final String title;
  final String body;
  const _DocSheet({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return _SheetScaffold(
      title: title,
      backArrow: true,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
        children: [
          const Text('Son güncelleme: 1 Haziran 2026',
              style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
          const SizedBox(height: 16),
          Text(body,
              style: const TextStyle(
                  fontSize: 14, height: 1.7, color: AppColors.ink)),
        ],
      ),
    );
  }
}

class _ProfileEditSheet extends StatefulWidget {
  final String name;
  final String email;
  final String avatar;
  final void Function(String name, String email) onSave;
  const _ProfileEditSheet({
    required this.name,
    required this.email,
    required this.avatar,
    required this.onSave,
  });

  @override
  State<_ProfileEditSheet> createState() => _ProfileEditSheetState();
}

class _ProfileEditSheetState extends State<_ProfileEditSheet> {
  late final TextEditingController _nameC =
      TextEditingController(text: widget.name);
  late final TextEditingController _emailC =
      TextEditingController(text: widget.email);
  late final TextEditingController _phoneC =
      TextEditingController(text: '+90 555 000 00 00');

  @override
  void dispose() {
    _nameC.dispose();
    _emailC.dispose();
    _phoneC.dispose();
    super.dispose();
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
          Center(
            child: Column(
              children: [
                Stack(
                  children: [
                    ClipOval(
                      child: SizedBox(
                          width: 88,
                          height: 88,
                          child: NetImage(widget.avatar)),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.camera_alt,
                            size: 15, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(widget.name,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                const Text('Fotoğrafı değiştirmek için dokun',
                    style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _label('Ad Soyad'),
          _field(_nameC, Icons.person_outline),
          const SizedBox(height: 16),
          _label('E-posta'),
          _field(_emailC, Icons.mail_outline),
          const SizedBox(height: 16),
          _label('Telefon'),
          _field(_phoneC, Icons.phone_outlined),
          const SizedBox(height: 28),
          GestureDetector(
            onTap: () {
              widget.onSave(_nameC.text.trim(), _emailC.text.trim());
              Navigator.pop(context);
            },
            child: Container(
              height: 50,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text('Değişiklikleri Kaydet',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
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

  Widget _field(TextEditingController c, IconData icon) {
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
              decoration: const InputDecoration(
                border: InputBorder.none,
                isCollapsed: true,
                contentPadding: EdgeInsets.symmetric(vertical: 15),
              ),
            ),
          ),
        ],
      ),
    );
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
