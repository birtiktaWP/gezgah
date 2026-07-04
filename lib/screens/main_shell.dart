import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/kedy_chat.dart';
import '../widgets/notifications_modal.dart';
import '../widgets/search_modal.dart';
import '../widgets/tabbar.dart';
import 'detail_screen.dart';
import 'events_screen.dart';
import 'home_screen.dart';
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

  void _onTab(int i) {
    switch (i) {
      case 1:
        showSearchModal(context, onOpenDetail: _openDetail);
        break;
      case 2:
        _openKedy();
        break;
      default:
        setState(() => _index = i);
    }
  }

  Future<void> _openKedy() async {
    setState(() => _kedyOpen = true);
    await showKedyChat(context);
    if (mounted) setState(() => _kedyOpen = false);
  }

  void _openDetail() {
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => const DetailScreen()));
  }

  void _openNotifications() => showNotifications(context);

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomeScreen(
        onOpenSearch: () => showSearchModal(context, onOpenDetail: _openDetail),
        onOpenNotifications: _openNotifications,
      ),
      const SizedBox.shrink(), // 1: Ara (modal)
      const SizedBox.shrink(), // 2: Kedy (modal)
      const EventsScreen(),
      ProfileScreen(
        onGoHome: () => setState(() => _index = 0),
        onOpenNotifications: _openNotifications,
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          IndexedStack(index: _index, children: pages),
          if (!_kedyOpen)
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                child: FloatingTabBar(activeIndex: _index, onTap: _onTab),
              ),
            ),
        ],
      ),
    );
  }
}
