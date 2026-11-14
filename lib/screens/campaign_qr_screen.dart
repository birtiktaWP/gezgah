import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart' show Geolocator;
import 'package:mobile_scanner/mobile_scanner.dart';

import '../data/api.dart';
import '../data/auth_service.dart';
import '../data/kampanya.dart';
import '../theme/app_theme.dart';
import '../widgets/kampanya_widgets.dart';
import 'login_screen.dart';

/// Kampanya QR okutma akışı (KAMPANYA_QR.md):
///
/// 1. Giriş yoksa önce giriş istenir (401'i beklemeden).
/// 2. Okutucu açılır; ilk geçerli okumada durur ve okunan metin
///    `POST /kampanyalar/qr`'a gönderilir (yanıt gelene kadar yeni gönderim
///    yok).
/// 3. Başarıda onay ekranı ("Bu ekranı kasada gösterin") açılır.
///
/// Kampanya QR'ı olmayan kod, süresi dolmuş QR ve bitmiş kampanyada mesaj
/// gösterilir, okutucu açık kalır. Başarılıysa sonucu döner (çağıran ekran
/// kendi durumunu günceller); vazgeçilirse null.
Future<KampanyaQrSonuc?> openKampanyaQr(BuildContext context) async {
  if (!AuthService.instance.isLoggedIn) {
    final ok = await openLogin(context);
    if (ok != true || !context.mounted || !AuthService.instance.isLoggedIn) {
      return null;
    }
  }
  // Tam ekran, opak rota. `MaterialPageRoute(fullscreenDialog: true)` iOS'ta
  // üstten boşluklu kart (sheet) gibi açılıyor, kamera ekranın ~%10 kısa
  // görünüyordu. Kök navigator: alttaki sayfa/tab bar hiç görünmesin.
  final sonuc = await Navigator.of(context, rootNavigator: true)
      .push<KampanyaQrSonuc>(
        PageRouteBuilder<KampanyaQrSonuc>(
          opaque: true,
          barrierColor: Colors.black,
          transitionDuration: const Duration(milliseconds: 260),
          reverseTransitionDuration: const Duration(milliseconds: 200),
          pageBuilder: (_, __, ___) => const CampaignQrScanScreen(),
          transitionsBuilder: (_, anim, __, child) => FadeTransition(
            opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
            child: child,
          ),
        ),
      );
  if (sonuc == null || !context.mounted) return null;
  await Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => CampaignQrSuccessScreen(sonuc: sonuc)),
  );
  return sonuc;
}

class CampaignQrScanScreen extends StatefulWidget {
  const CampaignQrScanScreen({super.key});

  @override
  State<CampaignQrScanScreen> createState() => _CampaignQrScanScreenState();
}

class _CampaignQrScanScreenState extends State<CampaignQrScanScreen> {
  // `noDuplicates` kullanılmaz: girişten sonra aynı QR yeniden okutulabilmeli.
  // Tekrarları [_busy], [_rejected] ve [_lastFailed] süzer.
  final MobileScannerController _ctrl = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );

  bool _busy = false; // sunucuya gönderiliyor (tek gönderim)
  String? _message; // altta gösterilen uyarı
  bool _messageError = false;
  // Kesin reddedilen kodlar (kampanya QR'ı değil / süresi dolmuş / bitmiş /
  // bulunamadı): ekran açıkken bir daha gönderilmez. İşletme ekranı 45 sn'de
  // bir yeni kod üretir, yenisi okunur.
  final Set<String> _rejected = {};
  // Geçici hata (ağ vb.) sonrası aynı kod 4 sn bekletilir, sonra yeniden
  // denenir.
  String? _lastFailed;
  DateTime _lastFailedAt = DateTime(2000);

  @override
  void dispose() {
    unawaited(_ctrl.dispose());
    super.dispose();
  }

  void _show(String m, {bool error = true}) {
    setState(() {
      _message = m;
      _messageError = error;
    });
  }

  Future<void> _resume() async {
    if (!mounted) return;
    setState(() => _busy = false);
    try {
      await _ctrl.start();
    } catch (_) {
      // Zaten çalışıyorsa sorun değil.
    }
  }

  Future<void> _onDetect(BarcodeCapture cap) async {
    if (_busy) return;
    final raw = cap.barcodes
        .map((b) => b.rawValue ?? '')
        .firstWhere((s) => s.trim().isNotEmpty, orElse: () => '');
    if (raw.isEmpty) return;

    // Reddedilen kod çerçevede duruyorsa tekrar işleme / gönderme.
    if (_rejected.contains(raw)) return;
    if (raw == _lastFailed &&
        DateTime.now().difference(_lastFailedAt) < const Duration(seconds: 4)) {
      return;
    }

    if (!KampanyaRepository.kampanyaQrMi(raw)) {
      _rejected.add(raw);
      HapticFeedback.lightImpact();
      _show('Bu QR bir kampanya kodu değil.');
      return;
    }

    // İlk geçerli okumada dur; yanıt gelene kadar yeni gönderim yok.
    setState(() {
      _busy = true;
      _message = null;
    });
    unawaited(_ctrl.stop());
    HapticFeedback.mediumImpact();
    try {
      final s = await KampanyaRepository.instance.qrOkut(raw);
      if (!mounted) return;
      Navigator.of(context).pop(s);
    } on AuthException catch (e) {
      if (!mounted) return;
      _show(e.message);
      final ok = await openLogin(context);
      if (!mounted) return;
      if (ok != true) {
        Navigator.of(context).pop();
        return;
      }
      _show('Giriş yapıldı. Kodu yeniden okut.', error: false);
      await _resume();
    } on KampanyaException catch (e) {
      if (!mounted) return;
      if (e.suresiDoldu) {
        _show(
          'QR kodunun süresi doldu. İşletmeden ekrandaki güncel kodu '
          'okutmanı iste.',
        );
      } else if (e.gecersizQr) {
        _show('Bu QR bir kampanya kodu değil.');
      } else if (e.bitti) {
        _show('Bu kampanya sona erdi.');
      } else if (e.bulunamadi) {
        _show('Kampanya bulunamadı.');
      } else {
        _show(e.message);
      }
      if (e.suresiDoldu || e.gecersizQr || e.bitti || e.bulunamadi) {
        _rejected.add(raw);
      } else {
        _lastFailed = raw;
        _lastFailedAt = DateTime.now();
      }
      await _resume();
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final side = (mq.size.width * 0.68).clamp(200.0, 320.0);
    final center = Offset(mq.size.width / 2, mq.size.height * 0.42);
    final window = Rect.fromCenter(center: center, width: side, height: side);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: false,
        extendBody: true,
        extendBodyBehindAppBar: true,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Kamera tüm ekranı kaplar (güvenli alanlar dahil, kırparak).
            SizedBox.expand(
              child: MobileScanner(
                controller: _ctrl,
                fit: BoxFit.cover,
                onDetect: _onDetect,
                errorBuilder: (context, error) => _cameraError(error),
              ),
            ),
            // Çerçeve dışı karartma + köşeli çerçeve.
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: _FramePainter(window)),
              ),
            ),
            // Üst çubuk: kapat + fener.
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Row(
                  children: [
                    _roundBtn(
                      Icons.close,
                      'Kapat',
                      () => Navigator.of(context).pop(),
                    ),
                    const Spacer(),
                    ValueListenableBuilder<MobileScannerState>(
                      valueListenable: _ctrl,
                      builder: (_, st, __) {
                        if (st.torchState == TorchState.unavailable) {
                          return const SizedBox.shrink();
                        }
                        final on = st.torchState == TorchState.on;
                        return _roundBtn(
                          on ? Icons.flash_on : Icons.flash_off,
                          on ? 'Feneri kapat' : 'Feneri aç',
                          _ctrl.toggleTorch,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            // Çerçevenin üstünde başlık, altında açıklama / durum.
            Positioned(
              left: 24,
              right: 24,
              bottom: mq.size.height - window.top + 22,
              child: const Text(
                'Kampanya QR’ını okut',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            Positioned(
              left: 28,
              right: 28,
              top: window.bottom + 22,
              child: Column(
                children: [
                  const Text(
                    'İşletmedeki ekranda gösterilen QR kodunu çerçevenin içine '
                    'getir.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_busy)
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Doğrulanıyor…',
                          style: TextStyle(fontSize: 14, color: Colors.white),
                        ),
                      ],
                    )
                  else if (_message != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 11,
                      ),
                      decoration: BoxDecoration(
                        color: _messageError
                            ? const Color(0xE6E0533D)
                            : const Color(0xE616A34A),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _message!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          height: 1.35,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _roundBtn(IconData icon, String label, VoidCallback onTap) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }

  Widget _cameraError(MobileScannerException error) {
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.no_photography_outlined,
                size: 48,
                color: Colors.white70,
              ),
              const SizedBox(height: 14),
              Text(
                denied
                    ? 'Kampanyayı kullanmak için kamera izni gerekli.'
                    : 'Kamera açılamadı.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              if (denied) ...[
                const SizedBox(height: 8),
                const Text(
                  'Ayarlar › Gezgah bölümünden kamera iznini açıp tekrar dene.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13.5, color: Colors.white70),
                ),
                const SizedBox(height: 18),
                ElevatedButton(
                  onPressed: Geolocator.openAppSettings,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Ayarları aç',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Çerçeve dışını karartır, çerçeve köşelerine beyaz çizgiler çizer.
class _FramePainter extends CustomPainter {
  final Rect window;
  _FramePainter(this.window);

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(window, const Radius.circular(22));
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Offset.zero & size),
        Path()..addRRect(r),
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.55),
    );
    final p = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    const l = 34.0, rad = 22.0;
    final w = window;
    // Sol üst
    canvas.drawPath(
      Path()
        ..moveTo(w.left, w.top + l)
        ..lineTo(w.left, w.top + rad)
        ..arcToPoint(
          Offset(w.left + rad, w.top),
          radius: const Radius.circular(rad),
        )
        ..lineTo(w.left + l, w.top),
      p,
    );
    // Sağ üst
    canvas.drawPath(
      Path()
        ..moveTo(w.right - l, w.top)
        ..lineTo(w.right - rad, w.top)
        ..arcToPoint(
          Offset(w.right, w.top + rad),
          radius: const Radius.circular(rad),
        )
        ..lineTo(w.right, w.top + l),
      p,
    );
    // Sağ alt
    canvas.drawPath(
      Path()
        ..moveTo(w.right, w.bottom - l)
        ..lineTo(w.right, w.bottom - rad)
        ..arcToPoint(
          Offset(w.right - rad, w.bottom),
          radius: const Radius.circular(rad),
        )
        ..lineTo(w.right - l, w.bottom),
      p,
    );
    // Sol alt
    canvas.drawPath(
      Path()
        ..moveTo(w.left + l, w.bottom)
        ..lineTo(w.left + rad, w.bottom)
        ..arcToPoint(
          Offset(w.left, w.bottom - rad),
          radius: const Radius.circular(rad),
        )
        ..lineTo(w.left, w.bottom - l),
      p,
    );
  }

  @override
  bool shouldRepaint(_FramePainter old) => old.window != window;
}

// ---------------------------------------------------------------------------

/// Başarı ekranı: işletme, kampanya başlığı, büyük oran, büyük onay kodu ve
/// "Bu ekranı kasada gösterin". Daha önce kullanıldıysa not düşülür.
class CampaignQrSuccessScreen extends StatelessWidget {
  final KampanyaQrSonuc sonuc;
  const CampaignQrSuccessScreen({super.key, required this.sonuc});

  static String _tarih(DateTime d) {
    String p(int n) => n.toString().padLeft(2, '0');
    return '${p(d.day)}.${p(d.month)}.${d.year} · ${p(d.hour)}:${p(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final k = sonuc.kampanya;
    final u = sonuc.kullanim;
    final mekan = k?.mekan?.ad ?? '';
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: IconButton(
                  tooltip: 'Kapat',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: AppColors.ink),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(26, 0, 26, 24),
                children: [
                  Center(
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF0FBF4),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        size: 44,
                        color: AppColors.open,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    u.yeni ? 'Kampanya onaylandı' : 'Daha önce kullandın',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  if (!u.yeni) ...[
                    const SizedBox(height: 6),
                    const Text(
                      'Bu kampanyayı zaten kullandın. Onay kodun aşağıda.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13.5, color: AppColors.muted),
                    ),
                  ],
                  const SizedBox(height: 22),
                  Container(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F7FB),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        if (k != null) KampanyaRozet(k.oran, fontSize: 18),
                        if (mekan.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            mekan,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: AppColors.ink,
                            ),
                          ),
                        ],
                        if (k != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            k.gosterilenBaslik,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        const Text(
                          'Onay kodu',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AppColors.muted,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Semantics(
                          label: 'Onay kodu ${u.kod.split('').join(' ')}',
                          excludeSemantics: true,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: AppColors.primary,
                                width: 1.4,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              u.kod,
                              style: const TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 7,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                        if (u.tarih != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _tarih(u.tarih!),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Bu ekranı kasada göster. İşletme aynı kodu kendi ekranında '
                    'görüp indirimi uygular.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.45,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Tamam',
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
