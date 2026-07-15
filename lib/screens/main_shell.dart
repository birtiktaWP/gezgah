import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import '../data/auth_service.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/kedy_chat.dart';
import '../widgets/notifications_modal.dart';
import '../widgets/search_modal.dart';
import '../widgets/tabbar.dart';
import 'detail_screen.dart';
import 'events_screen.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'profile_screen.dart';

/// Uygulama iskeleti: sayfa içeriği + yüzen tab bar.
/// 0 Keşfet · 1 Ara (modal) · 2 Kedy (modal) · 3 Etkinlikler · 4 Hesabım
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  bool _kedyOpen = false;

  @override
  void initState() {
    super.initState();
    // Oturum kapanırsa Hesabım sekmesinde kalınmasın.
    AuthService.instance.user.addListener(_onAuthChanged);
  }

  @override
  void dispose() {
    AuthService.instance.user.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    if (!mounted) return;
    if (!AuthService.instance.isLoggedIn && _index == 4) {
      setState(() => _index = 0);
    }
  }

  void _onTab(int i) {
    switch (i) {
      case 1:
        showSearchModal(context, onOpenDetail: _openDetail);
        break;
      case 2:
        _openKedy();
        break;
      case 3:
        // Etkinlikler artık ayrı bir sayfa olarak açılır.
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

  void _openDetail(Place p) {
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => DetailScreen(place: p)));
  }

  void _openNotifications() => showNotifications(context);

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomeScreen(
        // Ana sayfadaki arama kutusu, footer'daki "Arama" sekmesiyle aynı
        // aksiyonu tetikler.
        onOpenSearch: () => _onTab(1),
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
                child: FloatingTabBar(activeIndex: _index, onTap: _onTab),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
