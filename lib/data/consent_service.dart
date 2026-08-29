import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sözleşme onayı takibi — her üye ilk girişinden sonra sözleşmeleri onaylamak
/// zorundadır (KVKK Aydınlatma, Gizlilik, Çerez, İade, Kullanıcı Sözleşmesi).
///
/// Onay üye bazlı ve yerelde saklanır (`consent_v1_<uyeId>`). Sürüm değişirse
/// [_version] artırılarak tüm kullanıcılardan yeniden onay istenebilir.
class ConsentService {
  ConsentService._();
  static final ConsentService instance = ConsentService._();

  /// Metinler esaslı biçimde değişirse artır → herkesten yeniden onay istenir.
  static const int _version = 1;

  static String _key(int uyeId) => 'consent_v${_version}_$uyeId';

  /// Aktif üyenin onay durumu. `true` = onaylandı, `false` = onay bekliyor.
  /// Giriş yapılmadığında `true` kabul edilir (onay kapısı yalnız üyeler için).
  final ValueNotifier<bool> accepted = ValueNotifier<bool>(true);

  int? _uyeId;

  /// Üye oturumu geldiğinde/değiştiğinde çağrılır; kayıtlı onayı okur.
  Future<void> load(int? uyeId) async {
    _uyeId = uyeId;
    if (uyeId == null || uyeId <= 0) {
      accepted.value = true; // giriş yok → kapı gösterilmez
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      accepted.value = prefs.getBool(_key(uyeId)) ?? false;
    } catch (_) {
      // Yerel depolama okunamazsa kullanıcıyı kilitlemek yerine geç.
      accepted.value = true;
    }
  }

  /// Kullanıcı tüm sözleşmeleri onayladı.
  Future<void> accept() async {
    final id = _uyeId;
    accepted.value = true;
    if (id == null || id <= 0) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key(id), true);
    } catch (_) {
      // yut: kayıt yazılamazsa bir sonraki açılışta yeniden sorulur
    }
  }

  /// Çıkış yapıldığında durumu sıfırla (kapı gösterilmesin).
  void clear() {
    _uyeId = null;
    accepted.value = true;
  }
}
