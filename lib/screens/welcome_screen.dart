import 'package:flutter/material.dart';
import '../data/device_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// İlk açılış karşılama ekranı. Yalnızca uygulama ilk kez açıldığında gösterilir.
/// Bu ekranda cihaz token'ı ("ilk kod") oluşturulur (CIHAZ_TOKEN.md / GUVENLIK.md).
class WelcomeScreen extends StatefulWidget {
  /// "Başla"ya basıldığında (token hazır) çağrılır.
  final VoidCallback onStart;
  const WelcomeScreen({super.key, required this.onStart});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  late final Future<String> _register;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // İlk açılışta cihaz token'ını oluştur/kaydet (arka planda başlar).
    _register = DeviceService.instance.register();
  }

  Future<void> _start() async {
    setState(() => _busy = true);
    try {
      await _register; // token hazır olsun
    } catch (_) {
      // hata olsa da devam (token yerel olarak üretildi)
    }
    if (!mounted) return;
    widget.onStart();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.6, -0.8),
            radius: 1.1,
            colors: [AppColors.primary2, AppColors.primary],
            stops: [0.0, 0.6],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
            child: Column(
              children: [
                const Spacer(flex: 3),
                // Logo
                const GezgahWordmark(color: Colors.white, size: 52),
                const SizedBox(height: 18),
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: const Center(
                      child: KedyIcon(size: 32, color: Colors.white)),
                ),
                const Spacer(flex: 2),
                // Hoş geldin metinleri (logonun altında)
                const Text(
                  'Hoş geldin',
                  style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5),
                ),
                const SizedBox(height: 12),
                Text(
                  'Gezgah ile yakınındaki en iyi mekanları, lezzetleri ve '
                  'etkinlikleri keşfet. Kedy sana en uygun yerleri önersin.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 14.5,
                      height: 1.5,
                      color: Colors.white.withValues(alpha: 0.85)),
                ),
                const Spacer(flex: 3),
                // Başla butonu
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _busy ? null : _start,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primary,
                      disabledBackgroundColor:
                          Colors.white.withValues(alpha: 0.7),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _busy
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: AppColors.primary),
                          )
                        : const Text('Başla',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Devam ederek Kullanıcı Sözleşmesi ve Gizlilik Politikası\'nı '
                  'kabul etmiş olursun.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 11.5,
                      height: 1.4,
                      color: Colors.white.withValues(alpha: 0.6)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
