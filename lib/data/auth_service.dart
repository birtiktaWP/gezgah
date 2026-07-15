import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'models.dart';
import 'user_service.dart';

/// Üye oturumu yönetimi.
///
/// Giriş yapan kullanıcı [user] içinde tutulur; `null` ise oturum yok
/// (misafir). [user] bir [ValueNotifier] olduğu için ekranlar
/// `ValueListenableBuilder` ile canlı dinleyebilir.
///
/// Profil (hassas olmayan ad/e-posta vb.) `SharedPreferences`'te JSON olarak
/// saklanır; üye token'ı güvenli depoda (bkz. [Api.userToken]) tutulur.
/// Ayrıca giriş/çıkışta [UserService] güncellenir; böylece favoriler gibi
/// `user_id` gerektiren uçlar gerçek üye id'sini kullanır.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const _kUserKey = 'auth_user'; // JSON profil

  /// Oturumdaki üye (null = giriş yapılmadı). Değişince dinleyiciler bilgilenir.
  final ValueNotifier<AppUser?> user = ValueNotifier<AppUser?>(null);

  bool get isLoggedIn => user.value != null;

  /// Açılışta yerelde saklı profili yükleyip oturumu geri getirir (varsa).
  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kUserKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      user.value = AppUser.fromJson(map);
    } catch (_) {
      await prefs.remove(_kUserKey);
    }
  }

  /// E-posta + parola ile giriş (UYE_LOGIN.md). Başarısızsa [AuthException].
  Future<AppUser> giris(String ulkeKodu, String telefon, String parola) async {
    final u = await UyeRepository.instance.giris(ulkeKodu, telefon, parola);
    await _persist(u);
    return u;
  }

  /// Parolalı yeni hesap oluşturur ve oturum açar. Başarısızsa [AuthException].
  Future<AppUser> kayit({
    required String isim,
    required String soyisim,
    required String email,
    required String telefon,
    required String parola,
    String ulkeKodu = '+90',
    String? cinsiyet,
    String? dogumGunu,
    int? ilceId,
  }) async {
    final u = await UyeRepository.instance.kayit(
      isim: isim,
      soyisim: soyisim,
      email: email,
      telefon: telefon,
      parola: parola,
      ulkeKodu: ulkeKodu,
      cinsiyet: cinsiyet,
      dogumGunu: dogumGunu,
      ilceId: ilceId,
    );
    await _persist(u);
    return u;
  }

  /// Giriş yapmış üyenin profilini sunucuda günceller (`/uye/guncelle`) ve
  /// yereldeki oturumu (profil) yeniler. Başarısızsa [AuthException].
  Future<AppUser> guncelleProfil({
    required String isim,
    required String soyisim,
    required String email,
    required String telefon,
    String? ulkeKodu,
    String? cinsiyet,
    String? dogumGunu,
    int? ilceId,
  }) async {
    final u = await UyeRepository.instance.guncelle(
      isim: isim,
      soyisim: soyisim,
      email: email,
      telefon: telefon,
      ulkeKodu: ulkeKodu,
      cinsiyet: cinsiyet,
      dogumGunu: dogumGunu,
      ilceId: ilceId,
    );
    await _persist(u);
    return u;
  }

  /// Giriş yapmış üyenin parolasını değiştirir (`/uye/sifre-degistir`).
  /// Başarılıysa üye token'ı yenilenir. Başarısızsa [AuthException].
  Future<void> sifreDegistir(String eskiParola, String yeniParola) =>
      UyeRepository.instance.sifreDegistir(eskiParola, yeniParola);

  /// Üye formundaki ilçe seçenekleri (`GET /ilceler`, hepsi İstanbul).
  Future<List<Ilce>> ilceler() => UyeRepository.instance.ilceler();

  /// Oturumu kapatır: sunucuda token'ı geçersiz kılar (varsa) ve yerel profili,
  /// üye token'ını, üye id'sini temizler. Hata olsa da yerel temizlik yapılır.
  Future<void> logout() async {
    try {
      await UyeRepository.instance.cikis();
    } catch (_) {
      // yut: yerelde yine de çıkış yapacağız
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kUserKey);
    await UserService.instance.clearUserId();
    user.value = null;
  }

  /// Profili yerelde günceller (sunucuya yazmadan) ve kalıcılaştırır.
  Future<void> updateProfile({
    String? isim,
    String? soyisim,
    String? email,
    String? telefon,
  }) async {
    final cur = user.value;
    if (cur == null) return;
    final updated = cur.copyWith(
        isim: isim, soyisim: soyisim, email: email, telefon: telefon);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUserKey, jsonEncode(updated.toJson()));
    user.value = updated;
  }

  /// Profili sakla + üye id'sini [UserService]'e yaz + notifier'ı güncelle.
  Future<void> _persist(AppUser u) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUserKey, jsonEncode(u.toJson()));
    if (u.id > 0) {
      await UserService.instance.setUserId(u.id.toString());
    }
    user.value = u;
  }
}
