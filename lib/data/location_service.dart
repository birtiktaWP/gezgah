import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

/// Konum izni ve mesafe hesaplama yardımcıları.
class LocationService {
  LocationService._();

  /// Konum hiç alınamazsa kullanılacak varsayılan merkez (İstanbul, Kadıköy).
  /// Böylece vitrinde mesafe her zaman gösterilir; gerçek cihazda gerçek
  /// konumla değişir.
  static const double _fallbackLat = 40.9904;
  static const double _fallbackLng = 29.0292;

  /// Mesafe hesabı için bir konum çözer.
  /// Sıra: anlık konum → son bilinen konum → varsayılan merkez.
  /// `real`, gerçek cihaz konumu kullanılıp kullanılmadığını belirtir.
  static Future<({double lat, double lng, bool real})> resolve() async {
    final pos = await _tryGetPosition();
    if (pos != null) {
      return (lat: pos.latitude, lng: pos.longitude, real: true);
    }
    return (lat: _fallbackLat, lng: _fallbackLng, real: false);
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

  /// İki koordinat arasındaki mesafeyi metre cinsinden hesaplar.
  static double distanceMeters(
      double lat1, double lng1, double lat2, double lng2) {
    return Geolocator.distanceBetween(lat1, lng1, lat2, lng2);
  }

  /// Metreyi okunabilir mesafeye çevirir: tek ondalıklı km — "1.1 km" / "0.8 km".
  static String format(double meters) {
    final km = meters / 1000;
    return '${km.toStringAsFixed(1)} km';
  }

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
