/// Derleme zamanı gizli değerleri (GUVENLIK.md).
///
/// Kaynağa GÖMÜLMEZ; `--dart-define` ile verilir:
///   flutter run --dart-define=APP_KEY=... --dart-define=SIGNING_SECRET=...
///
/// Boş bırakılırsa ilgili güvenlik başlığı gönderilmez (sunucu tarafı da
/// kapalıysa istekler normal çalışır). Sunucuda `app_key`/`require_signature`
/// aktifleştiğinde bu değerleri build'e geçmek yeterlidir.
class AppSecrets {
  AppSecrets._();

  /// Sunucudaki `APP_KEY` ile aynı olmalı (`X-App-Key`). Canlıda zorunlu
  /// (UYELIK_PLUS.md §2.3): göndermeyen istek 401 alır. `--dart-define=APP_KEY`
  /// verilirse o kullanılır; verilmezse aşağıdaki canlı varsayılan gönderilir.
  /// (Client secret değildir; amacı bot/script trafiğini elemektir.)
  static const String _envAppKey = String.fromEnvironment('APP_KEY');
  static const String _defaultAppKey =
      'ba9db8d2c420adbaeed122fe53c15e878fbcc67b55ba41cd';
  static String get appKey =>
      _envAppKey.isNotEmpty ? _envAppKey : _defaultAppKey;

  /// HMAC istek imzası gizli anahtarı (`SIGNING_SECRET`). Şu an sunucuda kapalı;
  /// yalnızca `--dart-define=SIGNING_SECRET` verilirse gönderilir.
  static const String signingSecret = String.fromEnvironment('SIGNING_SECRET');

  static bool get hasAppKey => appKey.isNotEmpty;
  static bool get hasSigning => signingSecret.isNotEmpty;
}
