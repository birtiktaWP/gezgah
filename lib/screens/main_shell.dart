import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import '../data/auth_service.dart';
import '../data/consent_service.dart';
import '../data/models.dart';
import '../navigation/main_nav.dart';
import '../theme/app_theme.dart';
import '../widgets/category_sheet.dart';
import '../widgets/consent_sheet.dart';
import '../widgets/kedy_chat.dart';
import '../widgets/notifications_modal.dart';
import '../widgets/search_modal.dart';
import '../widgets/tabbar.dart';
import 'category_screen.dart';
import 'detail_screen.dart';
import 'events_screen.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'profile_screen.dart';

/// Uygulama iskeleti: sayfa içeriği + yüzen tab bar.
/// 0 Keşfet · 1 Kategori (sheet) · 2 Kedy (modal) · 3 Etkinlikler · 4 Hesabım
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  bool _kedyOpen = false;
  bool _consentOpen = false; // sözleşme onay paneli açık mı
  bool _wasLoggedIn = false; // önceki oturum durumu (giriş geçişini yakalamak için)

  @override
  void initState() {
    super.initState();
    // Tüm footer yönlendirmesini bu shell üstlenir (bkz. MainNav).
    MainNav.instance.attach(_selectTab);
    // Oturum kapanırsa Hesabım sekmesinde kalınmasın.
    _wasLoggedIn = AuthService.instance.isLoggedIn;
    AuthService.instance.user.addListener(_onAuthChanged);
    // Açılışta oturum geri geldiyse sözleşme onayını kontrol et.
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkConsent());
  }

  /// Üye girişliyse sözleşme onayını kontrol eder; onaylanmamışsa kapatılamayan
  /// onay panelini açar (onaylanmadan uygulama kullanılamaz).
  Future<void> _checkConsent() async {
    final u = AuthService.instance.user.value;
    await ConsentService.instance.load(u?.id);
    if (!mounted || _consentOpen) return;
    if (ConsentService.instance.accepted.value) return;
    _consentOpen = true;
    await showConsentSheet(context);
    _consentOpen = false;
    // Onaylanmadan kapandıysa (beklenmeyen durum) tekrar sor.
    if (mounted && !ConsentService.instance.accepted.value) _checkConsent();
  }

  @override
  void dispose() {
    MainNav.instance.detach(_selectTab);
    AuthService.instance.user.removeListener(_onAuthChanged);
    super.dispose();
  }

  /// İtilen bir sayfadan (Etkinlikler/Kategori/Favoriler…) footer'a basılınca
  /// çağrılır: önce üstteki tüm sayfaları kapat, sonra sekmeyi/aksiyonu uygula.
  void _selectTab(int i) {
    Navigator.of(context).popUntil((r) => r.isFirst);
    _onTab(i);
  }

  void _onAuthChanged() {
    if (!mounted) return;
    final loggedIn = AuthService.instance.isLoggedIn;
    // Yalnız "girişsiz → girişli" geçişini yakala; profil güncellemeleri de
    // user'ı değiştirdiği için bayrak olmadan yanlış tetiklenir.
    final justLoggedIn = loggedIn && !_wasLoggedIn;
    _wasLoggedIn = loggedIn;

    if (!loggedIn && _index == 4) {
      setState(() => _index = 0);
    }
    if (loggedIn) {
      // Girişten sonra ana sayfaya dön: üstteki sayfaları (login, profil,
      // paywall…) kapat ve Keşfet sekmesine geç.
      if (justLoggedIn) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Navigator.of(context).popUntil((r) => r.isFirst);
          if (_index != 0) setState(() => _index = 0);
        });
      }
      // Yeni giriş: sözleşme onayı alınmamışsa panel açılır.
      _checkConsent();
    } else {
      ConsentService.instance.clear();
    }
  }

  void _onTab(int i) {
    switch (i) {
      case 1:
        _openCategorySheet();
        break;
      case 2:
        _openKedy();
        break;
      case 3:
        Navigator.push(
            context, MaterialPageRoute(builder: (_) => const EventsScreen()));
        break;
      case 4:
        _openAccount();
        break;
      default:
        setState(() => _index = i);
    }
  }

  /// Hesabım: giriş yapılmışsa sekmeye geç; değilse önce login ekranını aç,
  /// giriş başarılıysa Hesabım sekmesini göster.
  Future<void> _openAccount() async {
    if (AuthService.instance.isLoggedIn) {
      setState(() => _index = 4);
      return;
    }
    final ok = await openLogin(context);
    if (!mounted) return;
    if (ok == true && AuthService.instance.isLoggedIn) {
      setState(() => _index = 4);
    }
  }

  Future<void> _openKedy() async {
    setState(() => _kedyOpen = true);
    await showKedyChat(context);
    if (mounted) setState(() => _kedyOpen = false);
  }

  /// Footer "Kategori": alttan kategori paneli açar; seçilen kategori liste
  /// sayfasında (CategoryScreen) açılır.
  void _openCategorySheet() {
    showCategorySheet(context, onSelect: (id, name) {
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => CategoryScreen(categoryId: id, title: name)),
      );
    });
  }

  /// Ana sayfadaki arama kutusu için gelişmiş arama modalı.
  void _openSearch() => showSearchModal(context, onOpenDetail: _openDetail);

  void _openDetail(Place p) {
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => DetailScreen(place: p)));
  }

  void _openNotifications() => showNotifications(context);

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomeScreen(
        // Ana sayfadaki arama kutusu gelişmiş arama modalını açar (footer
        // artık "Kategori"; arama yalnızca ana sayfa kutusundan tetiklenir).
        onOpenSearch: _openSearch,
        onOpenNotifications: _openNotifications,
      ),
      const SizedBox.shrink(), // 1: Ara (modal)
      const SizedBox.shrink(), // 2: Kedy (modal)
      const SizedBox.shrink(), // 3: Etkinlikler (ayrı sayfa olarak push edilir)
      ProfileScreen(
        onGoHome: () => setState(() => _index = 0),
        onOpenNotifications: _openNotifications,
      ),
    ];

    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          IndexedStack(index: _index, children: pages),
          if (!_kedyOpen) ...[
            // iOS tarzı buzlu cam: tab bar bölgesinden geçen içerik bulanıklaşır,
            // üst kenarda yumuşak geçiş için maskelenir (tam gözükmez).
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 140 + bottomInset,
              child: IgnorePointer(
                child: ShaderMask(
                  shaderCallback: (r) => const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black],
                    stops: [0.0, 0.55],
                  ).createShader(r),
                  blendMode: BlendMode.dstIn,
                  child: ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: Container(
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                child: FloatingTabBar(
                    activeIndex: _index, onTap: MainNav.instance.select),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
