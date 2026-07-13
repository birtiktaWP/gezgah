import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'data/auth_service.dart';
import 'data/device_service.dart';
import 'data/user_service.dart';
import 'screens/main_shell.dart';
import 'screens/welcome_screen.dart';
import 'theme/app_theme.dart';

/// İlk açılış (Welcome) gösterildi mi?
const _kWelcomeSeenKey = 'welcome_seen';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  // Uygulamayı ilk açan her cihaz için anonim kimliği üret/yükle (yerel).
  UserService.instance.currentId();

  // Cihaz token'ını erkenden hazırla (üret + `POST /cihaz/kayit`). Böylece
  // ana sayfa API çağrıları (Bearer token gerektiren) token hazır olduktan
  // sonra gider. Bloklamıyoruz: güvenlik interceptor'ı aynı (dedup'lı)
  // future'ı beklediği için istekler token hazır olana dek kendiliğinden
  // bekler; bu sırada ana sayfa yükleniyor göstergelerini gösterir.
  // (İlk açılış dahil her senaryoda tetiklenir — bkz. GUVENLIK.md §4.)
  DeviceService.instance.ensureRegistered();

  // Varsa üye oturumunu yerelden geri yükle (Hesabım'ı giriş ekranı yerine
  // doğrudan gösterebilmek için ilk kareden önce hazır olsun).
  await AuthService.instance.restore();

  final prefs = await SharedPreferences.getInstance();
  final seenWelcome = prefs.getBool(_kWelcomeSeenKey) ?? false;

  runApp(GezgahApp(seenWelcome: seenWelcome));
}

class GezgahApp extends StatelessWidget {
  final bool seenWelcome;
  const GezgahApp({super.key, required this.seenWelcome});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gezgah',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: _PhoneFrame(child: _Root(seenWelcome: seenWelcome)),
    );
  }
}

/// İlk açılışta Welcome, sonrasında MainShell gösterir.
class _Root extends StatefulWidget {
  final bool seenWelcome;
  const _Root({required this.seenWelcome});

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  late bool _showMain = widget.seenWelcome;

  // Not: Cihaz kaydı artık main()'de koşulsuz başlatılır (ilk açılış dahil).
  // Eskiden burada yalnızca `seenWelcome` true iken çağrılıyordu; bu yüzden
  // ilk açılışta kayıt hiç yapılmıyor, ana sayfa istekleri token'sız gidip
  // 401 alıyor ve veriler gelmiyordu.

  Future<void> _finishWelcome() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kWelcomeSeenKey, true);
    if (!mounted) return;
    setState(() => _showMain = true);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      child: _showMain
          ? const MainShell()
          : WelcomeScreen(key: const ValueKey('welcome'), onStart: _finishWelcome),
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
