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

  /// Sunucudaki `APP_KEY` ile aynı olmalı (`X-App-Key`).
  static const String appKey = String.fromEnvironment('APP_KEY');

  /// HMAC istek imzası gizli anahtarı (`SIGNING_SECRET`).
  static const String signingSecret = String.fromEnvironment('SIGNING_SECRET');

  static bool get hasAppKey => appKey.isNotEmpty;
  static bool get hasSigning => signingSecret.isNotEmpty;
}
