import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

/// Kullanıcı kimliği yönetimi.
///
/// Uygulama loginsiz kullanılabildiği için, uygulamayı açan her cihaza bir
/// kez üretilip **yerel olarak** (SharedPreferences) saklanan anonim bir
/// kimlik atanır. Bu kimlik, gerçek bir `user_id` olmayan kullanıcılar için
/// user_id görevi görür. Kullanıcı giriş yaparsa `setUserId` ile gerçek id
/// kaydedilir ve bundan sonra o kullanılır.
class UserService {
  UserService._();
  static final UserService instance = UserService._();

  static const _kUserId = 'user_id'; // gerçek (login) kullanıcı id'si
  static const _kDeviceId = 'device_id'; // anonim cihaz id'si (fallback)

  String? _cachedId;

  /// Aktif kimlik: gerçek `user_id` varsa o, yoksa anonim `device_id`.
  /// `device_id` yoksa bir kez üretilir ve kalıcı olarak saklanır.
  Future<String> currentId() async {
    if (_cachedId != null) return _cachedId!;

    final prefs = await SharedPreferences.getInstance();

    final real = prefs.getString(_kUserId);
    if (real != null && real.isNotEmpty) {
      return _cachedId = real;
    }

    var device = prefs.getString(_kDeviceId);
    if (device == null || device.isEmpty) {
      device = _generateUuidV4();
      await prefs.setString(_kDeviceId, device);
    }
    return _cachedId = device;
  }

  /// Gerçek kullanıcı girişinde çağrılır; sonraki `currentId` çağrıları bunu
  /// döndürür.
  Future<void> setUserId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUserId, id);
    _cachedId = id;
  }

  /// Çıkışta gerçek id'yi temizler; anonim cihaz id'sine geri dönülür.
  Future<void> clearUserId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kUserId);
    _cachedId = null;
  }

  /// Rastgele (güvenli) UUID v4 üretir — harici paket gerektirmez.
  String _generateUuidV4() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // sürüm 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // varyant
    String hex(int b) => b.toRadixString(16).padLeft(2, '0');
    final h = bytes.map(hex).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-'
        '${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }
}
