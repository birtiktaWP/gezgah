import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/main_shell.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const GezgahApp());
}

class GezgahApp extends StatelessWidget {
  const GezgahApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gezgah',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const _PhoneFrame(child: MainShell()),
    );
  }
}

/// Tasarım, mobil çerçeve için max 440px genişlikte tasarlandı.
/// Geniş ekranlarda (web/masaüstü) içeriği ortalar.
class _PhoneFrame extends StatelessWidget {
  final Widget child;
  const _PhoneFrame({required this.child});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.pageBg,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: child,
        ),
      ),
    );
  }
}
