import 'package:dio/dio.dart';
import 'models.dart';

/// Sunucu kökü (göreli görsel yollarını tamamlamak için).
const String kApiHost = 'https://api.gezgah.com';

/// Gezgah REST API istemcisi — tek (singleton) Dio örneği.
/// FLUTTER_API_GUIDE.md'deki yapılandırmayı izler. Uygulama loginsiz
/// olduğundan token/AuthInterceptor eklenmemiştir; "öne çıkan firmalar"
/// endpoint'i public'tir.
class Api {
  Api._();
  static final Api instance = Api._();

  late final Dio dio = Dio(
    BaseOptions(
      baseUrl: '$kApiHost/rest',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      contentType: 'application/json',
      // 5xx altı durumlarda exception fırlatma; zarftaki success'e bakacağız.
      validateStatus: (status) => status != null && status < 500,
      headers: {'Accept': 'application/json'},
    ),
  );
}

/// Mekan (öne çıkan firma) verisi için repository.
class PlacesRepository {
  PlacesRepository._();
  static final PlacesRepository instance = PlacesRepository._();

  // Vitrin verisi sık değişmez → kısa süreli bellek cache (~12 dk).
  List<Place>? _featuredCache;
  DateTime? _featuredAt;
  static const _ttl = Duration(minutes: 12);

  /// Öne çıkan mekanları getirir (anasayfa "Popüler Mekanlar" vitrini).
  /// `GET /one-cikan-firmalar`
  Future<List<Place>> oneCikanFirmalar({
    String? type, // 'restoran' | 'plaj' | 'mesire' | null (hepsi)
    int page = 1,
    int limit = 20,
    bool forceRefresh = false,
  }) async {
    final fresh = _featuredAt != null &&
        DateTime.now().difference(_featuredAt!) < _ttl;
    if (!forceRefresh && _featuredCache != null && fresh) {
      return _featuredCache!;
    }

    final res = await Api.instance.dio.get(
      '/one-cikan-firmalar',
      queryParameters: {
        'type': ?type,
        'page': page,
        'limit': limit,
      },
    );

    final body = res.data as Map<String, dynamic>;
    if (body['success'] != true) {
      throw Exception(
          body['error']?['message'] ?? 'Öne çıkanlar alınamadı');
    }

    final list = (body['data'] as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(_fromFeatured)
        .toList();

    _featuredCache = list;
    _featuredAt = DateTime.now();
    return list;
  }

  /// API kaydını uygulamadaki Place modeline dönüştürür.
  Place _fromFeatured(Map<String, dynamic> json) {
    final typeLabel = switch (json['type']) {
      'restoran' => 'Restoran',
      'plaj' => 'Plaj',
      'mesire' => 'Mesire',
      _ => 'Mekan',
    };

    // thumbnail göreli yol olabilir; yoksa boş bırak (NetImage placeholder gösterir).
    final thumb = json['thumbnail'];
    String image = '';
    if (thumb is String && thumb.isNotEmpty) {
      image = thumb.startsWith('http') ? thumb : '$kApiHost$thumb';
    }

    final coord = _parseCoord(json['kordinat']);

    return Place(
      name: (json['name'] as String?)?.trim().isNotEmpty == true
          ? json['name'] as String
          : 'İsimsiz Mekan',
      category: typeLabel,
      subtitle: typeLabel,
      rating: 0, // API vitrin yanıtında puan yok → kartta gizlenir
      distance: '',
      price: '',
      image: image,
      lat: coord?.$1 ?? 41.0082,
      lng: coord?.$2 ?? 28.9784,
      tags: [json['type'] as String? ?? ''],
    );
  }

  /// "enlem, boylam" metnini (lat, lng) ikilisine çevirir.
  (double, double)? _parseCoord(dynamic raw) {
    if (raw is! String || raw.trim().isEmpty) return null;
    final parts = raw.split(',');
    if (parts.length != 2) return null;
    final lat = double.tryParse(parts[0].trim());
    final lng = double.tryParse(parts[1].trim());
    if (lat == null || lng == null) return null;
    return (lat, lng);
  }
}
