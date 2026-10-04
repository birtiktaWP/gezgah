import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

/// Konum izni ve mesafe hesaplama yardımcıları.
class LocationService {
  LocationService._();

  /// Konum hiç alınamazsa kullanılacak varsayılan merkez (İstanbul, Kadıköy).
  /// Yalnız harita merkezi vb. için; `real: false` döner ve mesafe
  /// hesabında/isteklerinde kullanılmaz (MESAFE-MOBIL.md §6).
  static const double _fallbackLat = 40.9904;
  static const double _fallbackLng = 29.0292;

  // Uygulama geneli kısa süreli konum cache'i. İlk çözümden sonra diğer
  // ekranlar (kategori, harita, ana sayfa) aynı konumu anında kullanır;
  // böylece her ekranda yeniden GPS fix'i beklenmez.
  static ({double lat, double lng, bool real})? _cached;
  static DateTime? _cachedAt;
  static const Duration _cacheTtl = Duration(minutes: 5);

  /// Mesafe hesabı için bir konum çözer.
  /// Sıra: (taze cache) → anlık konum → son bilinen konum → varsayılan merkez.
  /// `real`, gerçek cihaz konumu kullanılıp kullanılmadığını belirtir.
  static Future<({double lat, double lng, bool real})> resolve(
      {bool forceRefresh = false}) async {
    final c = _cached;
    if (!forceRefresh &&
        c != null &&
        _cachedAt != null &&
        DateTime.now().difference(_cachedAt!) < _cacheTtl) {
      return c;
    }
    final pos = await _tryGetPosition();
    final r = pos != null
        ? (lat: pos.latitude, lng: pos.longitude, real: true)
        : (lat: _fallbackLat, lng: _fallbackLng, real: false);
    _cached = r;
    _cachedAt = DateTime.now();
    return r;
  }

  static Future<Position?> _tryGetPosition() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      // Anlık konum (emülatörde sabit yoksa zaman aşımına uğrayabilir).
      if (await Geolocator.isLocationServiceEnabled()) {
        try {
          return await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
              timeLimit: Duration(seconds: 10),
            ),
          );
        } catch (_) {
          // zaman aşımı / sabit yok → son bilinen konuma düş
        }
      }

      // Son bilinen konum (emülatör/çevrimdışı için yedek).
      return await Geolocator.getLastKnownPosition();
    } catch (_) {
      return null;
    }
  }

  /// Gerçek cihaz konumu; izin yoksa ya da [timeout] içinde alınamazsa null.
  /// Mesafe isteyen uçlara yalnız bu gönderilir (MESAFE-MOBIL.md §6):
  /// varsayılan merkez (Kadıköy) asla mesafe hesabına girmez.
  static Future<({double lat, double lng})?> realLocation(
      {Duration timeout = const Duration(seconds: 3)}) async {
    try {
      final r = await resolve().timeout(timeout);
      return r.real ? (lat: r.lat, lng: r.lng) : null;
    } catch (_) {
      return null; // zaman aşımı: çözüm arka planda sürer ve cache'lenir
    }
  }

  /// İki koordinat arasındaki kuş uçuşu mesafe (metre). Yalnız **sıralama**
  /// için kullanılır; ekranda gösterilmez (MESAFE-MOBIL.md: ekranda yalnız
  /// sunucunun tahmini yol mesafesi).
  static double distanceMeters(
      double lat1, double lng1, double lat2, double lng2) {
    return Geolocator.distanceBetween(lat1, lng1, lat2, lng2);
  }

  /// Sunucu mesafesini (metre) ekran metnine çevirir (MESAFE-MOBIL.md §5):
  /// < 1 km → 50 m'ye yuvarlı "350 m", 1–10 km → "7,6 km", ≥ 10 km → "31 km".
  static String format(double meters) {
    if (meters.isNaN || meters.isInfinite || meters < 0) return '';
    if (meters < 1000) {
      final m = (meters / 50).round() * 50;
      if (m < 1000) return '${m < 50 ? 50 : m} m';
    }
    final km = meters / 1000;
    if (km < 9.95) return '${km.toStringAsFixed(1).replaceAll('.', ',')} km';
    return '${km.round()} km';
  }

  /// Sunucudan gelen `mesafe_m` (metre) → metin; null ise ''.
  static String formatM(num? meters) =>
      meters == null ? '' : format(meters.toDouble());

  /// Koordinattan "İl, İlçe" (veya [districtFirst] ile "İlçe, İl") etiketini
  /// üretir (reverse geocoding). Başarısız olursa `null` döner.
  static Future<String?> cityDistrict(double lat, double lng,
      {bool districtFirst = false}) async {
    try {
      final marks = await placemarkFromCoordinates(lat, lng);
      if (marks.isEmpty) return null;
      final p = marks.first;
      final il = (p.administrativeArea ?? '').trim();
      final ilce = (p.subAdministrativeArea ?? '').trim().isNotEmpty
          ? p.subAdministrativeArea!.trim()
          : (p.locality ?? '').trim();
      final ordered = districtFirst ? [ilce, il] : [il, ilce];
      final parts = ordered.where((s) => s.isNotEmpty).toList();
      if (parts.isEmpty) return null;
      return parts.join(', ');
    } catch (_) {
      return null;
    }
  }
}
