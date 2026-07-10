import 'dart:math';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'api.dart';

/// Cihaz token akışı (CIHAZ_TOKEN.md).
///
/// İlk açılışta bir cihaz token'ı üretir, güvenli depoda saklar ve
/// `POST /cihaz/kayit` ile sunucuya bildirir. Sunucu kendi token'ını dönerse
/// onu saklar. Endpoint henüz yayında değilse (404) yerel token korunur;
/// böylece Authorization: Bearer başlığı yine gönderilir ve backend
/// yayınlandığında aynı token upsert edilir.
class DeviceService {
  DeviceService._();
  static final DeviceService instance = DeviceService._();

  bool _registeredThisSession = false;

  /// Cihaz token'ını hazırlar ve sunucuya (varsa) kaydeder. Token döner.
  Future<String> register() async {
    final existing = await Api.instance.deviceToken;
    var token = (existing != null && existing.isNotEmpty)
        ? existing
        : _generateToken();
    // Bearer başlığında hemen kullanılabilsin diye önce sakla.
    await Api.instance.saveDeviceToken(token);

    final info = await _deviceInfo();
    try {
      final res = await Api.instance.dio.post('/cihaz/kayit', data: {
        'token': token,
        ...info,
      });
      final body = res.data;
      if (body is Map && body['success'] == true) {
        final data = body['data'];
        final srv = (data is Map ? data['token'] : null) as String?;
        if (srv != null && srv.isNotEmpty && srv != token) {
          token = srv;
          await Api.instance.saveDeviceToken(token);
        }
      }
    } catch (_) {
      // Endpoint yok / ağ hatası → yerel token yeterli.
    }
    _registeredThisSession = true;
    return token;
  }

  /// Uygulama açılışında bir kez, arka planda çağrılır (hata yutulur).
  void ensureRegistered() {
    if (_registeredThisSession) return;
    register().catchError((_) => '');
  }

  /// 64 hex karakterlik rastgele token (CIHAZ_TOKEN.md formatı).
  String _generateToken() {
    final r = Random.secure();
    final bytes = List<int>.generate(32, (_) => r.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  String get _platform {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.android:
        return 'android';
      default:
        return 'other';
    }
  }

  Future<Map<String, dynamic>> _deviceInfo() async {
    final out = <String, dynamic>{'platform': _platform};
    try {
      final pkg = await PackageInfo.fromPlatform();
      if (pkg.version.isNotEmpty) out['app_version'] = pkg.version;
    } catch (_) {}
    try {
      final di = DeviceInfoPlugin();
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        final a = await di.androidInfo;
        out['device_model'] = a.model;
        out['os_version'] = a.version.release;
        out['device_uuid'] = a.id;
      } else if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        final i = await di.iosInfo;
        out['device_model'] = i.utsname.machine;
        out['os_version'] = i.systemVersion;
        if (i.identifierForVendor != null) {
          out['device_uuid'] = i.identifierForVendor;
        }
      }
    } catch (_) {}
    return out;
  }
}
