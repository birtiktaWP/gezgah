import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../navigation/main_nav.dart';
import '../screens/detail_screen.dart';
import '../screens/routes_screen.dart';
import 'auth_service.dart';
import 'models.dart';

/// Push bildirimleri (OneSignal) — uygulamadaki TÜM OneSignal çağrıları bu
/// sınıftan geçer (PUSH_BILDIRIM.md).
///
/// - [init]: `main()` içinde, `runApp`'tan önce.
/// - Üye girişi/çıkışı otomatik izlenir: girişte cihaz `external_id` = üye id
///   ile OneSignal kullanıcısına bağlanır (backend bu id'ye bildirim atar),
///   çıkışta bağ kaldırılır.
/// - [askPermissionOnce]: bildirim izni uygulama içinde bir kez istenir
///   (Android 13+ ve iOS). Reddedilirse tekrar sorulmaz.
/// - Bildirime dokununca `additionalData`'ya göre ilgili sayfa açılır.
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  /// OneSignal App ID (OneSignal panel → Settings → Keys & IDs). Gizli
  /// değildir; uygulamaya gömülmesi OneSignal'in öngördüğü kullanımdır.
  static const String appId = '201144c0-3c92-4868-893f-f630f90ccc9a';

  /// Bildirime dokununca sayfa açmak için uygulamanın kök navigator'ı
  /// (`MaterialApp.navigatorKey`).
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static const String _kAskedKey = 'push_permission_asked';

  bool _ready = false;
  String? _boundUserId; // OneSignal'e bağlı üye id'si (external_id)

  // Uygulama açılırken (navigator hazır olmadan) dokunulan bildirim.
  Map<String, dynamic>? _pendingData;

  /// SDK'yı başlatır. Web/masaüstünde ve hata durumunda sessizce atlanır
  /// (bildirim olmadan uygulama normal çalışır).
  void init() {
    if (_ready || kIsWeb) return;
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }
    try {
      OneSignal.Debug.setLogLevel(
        kDebugMode ? OSLogLevel.warn : OSLogLevel.none,
      );
      OneSignal.initialize(appId);
      OneSignal.Notifications.addClickListener(_onClick);
      _ready = true;
    } catch (e) {
      debugPrint('OneSignal başlatılamadı: $e');
      return;
    }
    // Açılışta oturum varsa bağla; sonraki giriş/çıkışları dinle.
    _syncUser();
    AuthService.instance.user.addListener(_syncUser);
  }

  /// Oturumdaki üyeyi OneSignal kullanıcısına bağlar / bağı kaldırır.
  void _syncUser() {
    if (!_ready) return;
    final AppUser? u = AuthService.instance.user.value;
    final id = (u != null && u.id > 0) ? u.id.toString() : null;
    if (id == _boundUserId) return;
    try {
      if (id != null) {
        OneSignal.login(id);
      } else {
        OneSignal.logout();
      }
      _boundUserId = id;
    } catch (e) {
      debugPrint('OneSignal kullanıcı eşlemesi başarısız: $e');
    }
  }

  /// Bildirim iznini uygulama içinde bir kez ister. İzin zaten verilmişse ya
  /// da daha önce sorulduysa hiçbir şey yapmaz.
  Future<void> askPermissionOnce() async {
    if (!_ready) return;
    try {
      if (OneSignal.Notifications.permission) return;
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_kAskedKey) ?? false) return;
      if (!await OneSignal.Notifications.canRequest()) return;
      await prefs.setBool(_kAskedKey, true);
      // fallbackToSettings: false → reddedilirse ayarlara yönlendirme yok.
      await OneSignal.Notifications.requestPermission(false);
    } catch (e) {
      debugPrint('Bildirim izni istenemedi: $e');
    }
  }

  void _onClick(OSNotificationClickEvent event) {
    final data = event.notification.additionalData ?? const {};
    final url = event.notification.launchUrl;
    final merged = <String, dynamic>{
      ...data,
      if (url != null && url.isNotEmpty && data['url'] == null) 'url': url,
    };
    if (navigatorKey.currentState == null) {
      _pendingData = merged; // uygulama yeni açılıyor; MainShell hazır olunca
      return;
    }
    _open(merged);
  }

  /// MainShell ilk karede çağırır: uygulama bildirimle açıldıysa ilgili
  /// sayfaya gider.
  void handlePending() {
    final d = _pendingData;
    if (d == null) return;
    _pendingData = null;
    _open(d);
  }

  /// `additionalData` sözleşmesi (PUSH_BILDIRIM.md §3):
  /// `tip`: `mekan` | `etkinlik` | `rota` | `url`, `id`: kayıt id'si,
  /// `ad`: mekan adı (opsiyonel), `url`: açılacak bağlantı.
  void _open(Map<String, dynamic> d) {
    final nav = navigatorKey.currentState;
    if (nav == null) return;
    final tip = (d['tip'] ?? d['type'] ?? '').toString().toLowerCase();
    final id = int.tryParse('${d['id'] ?? ''}') ?? 0;
    switch (tip) {
      case 'mekan':
        if (id <= 0) return;
        nav.push(
          detailRoute(
            builder: (_) => DetailScreen(
              place: Place(
                id: id,
                name: (d['ad'] ?? '').toString(),
                category: '',
                subtitle: '',
                rating: 0,
                distance: '',
                price: '',
                image: '',
              ),
            ),
          ),
        );
      case 'rota':
        if (id <= 0) return;
        nav.push(
          MaterialPageRoute(builder: (_) => RouteDetailScreen(rotaId: id)),
        );
      case 'etkinlik':
        MainNav.instance.select(3); // Etkinlikler
      default:
        final url = (d['url'] ?? '').toString().trim();
        final uri = Uri.tryParse(url);
        if (uri != null && uri.hasScheme) {
          launchUrl(uri, mode: LaunchMode.externalApplication);
        }
    }
  }
}
