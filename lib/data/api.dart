import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'app_secrets.dart';
import 'models.dart';

/// Sunucu kökü (göreli görsel yollarını tamamlamak için).
const String kApiHost = 'https://api.gezgah.com';

/// Gezgah REST API istemcisi — tek (singleton) Dio örneği.
/// FLUTTER_API_GUIDE.md + GUVENLIK.md yapılandırmasını izler.
///
/// Güvenlik interceptor'ı her isteğe (yapılandırıldıysa) şunları ekler:
///  - `X-App-Key` (AppSecrets.appKey)
///  - `Authorization: Bearer <cihaz token>` (güvenli depodan)
///  - HMAC imza başlıkları `X-Timestamp` / `X-Nonce` / `X-Signature`
class Api {
  Api._();
  static final Api instance = Api._();

  static const _storage = FlutterSecureStorage();
  static const _deviceTokenKey = 'device_token';

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
  )..interceptors.add(_SecurityInterceptor());

  // --- Cihaz token (güvenli depo) --------------------------------------------
  Future<String?> get deviceToken => _storage.read(key: _deviceTokenKey);
  Future<void> saveDeviceToken(String t) =>
      _storage.write(key: _deviceTokenKey, value: t);
  Future<void> clearDeviceToken() => _storage.delete(key: _deviceTokenKey);
}

/// Her isteğe güvenlik başlıklarını ekler (bkz. GUVENLIK.md §4).
class _SecurityInterceptor extends Interceptor {
  @override
  Future<void> onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    // 1) Uygulama anahtarı (yapılandırıldıysa).
    if (AppSecrets.hasAppKey) {
      options.headers['X-App-Key'] = AppSecrets.appKey;
    }

    // 2) Cihaz token'ı → Bearer (varsa).
    final token = await Api.instance.deviceToken;
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    // 3) HMAC istek imzası (signing_secret yapılandırıldıysa).
    if (AppSecrets.hasSigning) {
      final ts = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
      final nonce = _nonce();
      final path = _normalizePath(options.path);
      final bodyStr = options.data == null
          ? ''
          : (options.data is String
              ? options.data as String
              : jsonEncode(options.data));
      final bodyHash = sha256.convert(utf8.encode(bodyStr)).toString();
      final base =
          '${options.method.toUpperCase()}\n$path\n$ts\n$nonce\n$bodyHash';
      final sig = Hmac(sha256, utf8.encode(AppSecrets.signingSecret))
          .convert(utf8.encode(base))
          .toString();
      options.headers['X-Timestamp'] = ts;
      options.headers['X-Nonce'] = nonce;
      options.headers['X-Signature'] = sig;
    }

    handler.next(options);
  }

  /// Sorgu parametrelerini ve sondaki `/`'ı atarak imza tabanındaki PATH'i verir.
  String _normalizePath(String p) {
    var path = p;
    final q = path.indexOf('?');
    if (q >= 0) path = path.substring(0, q);
    if (path.length > 1 && path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    return path;
  }

  String _nonce() {
    final r = Random.secure();
    final bytes = List<int>.generate(16, (_) => r.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
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

/// Bir mekan (`yzd_posts` restoran) API kaydını temsil eden ara model.
/// Koordinatı geçerli değilse [lat]/[lng] null kalır (mesafe hesaplanamaz).
class ApiPlace {
  final int id;
  final String name;
  final String image;
  final double? lat;
  final double? lng;
  final String sehir; // il
  final String ilce; // ilçe
  final List<int> categoryIds;

  const ApiPlace({
    required this.id,
    required this.name,
    required this.image,
    this.lat,
    this.lng,
    this.sehir = '',
    this.ilce = '',
    this.categoryIds = const [],
  });

  bool get hasCoord => lat != null && lng != null;

  /// "İl · İlçe" metni (yalnızca biri varsa onu, ikisi de yoksa boş döner).
  String get cityDistrict {
    final parts = [sehir, ilce].where((s) => s.trim().isNotEmpty).toList();
    return parts.join(' · ');
  }

  /// Uygulamadaki [Place] kartına dönüştürür.
  Place toPlace({String subtitle = '', String distance = ''}) => Place(
        name: name,
        category: 'Restoran',
        subtitle: subtitle,
        rating: 0,
        distance: distance,
        price: '',
        image: image,
        lat: lat ?? 41.0082,
        lng: lng ?? 28.9784,
        tags: const ['restoran'],
      );
}

/// Arama sonucu: mekan bilgisi + eşleşme ayrıntıları (ARAMA.md).
class SearchResult {
  final ApiPlace place;
  final List<String> matchedProducts; // eslesen_urunler
  final List<String> matchTypes; // eslesme: "isim" ve/veya "menu"

  const SearchResult({
    required this.place,
    this.matchedProducts = const [],
    this.matchTypes = const [],
  });

  bool get matchedByMenu => matchTypes.contains('menu');
}

/// Kategori detay/listeleme yanıtı (KATEGORI_LISTELEME.md).
class CategoryDetail {
  final Category category;
  final List<Category> subCategories; // alt_kategoriler
  final Place? pinned; // sabit_restoran
  final List<Place> places; // mekanlar (sayfalı)
  final int page;
  final int pages;
  final int total;
  final bool hasMore; // sonraki sayfa var mı
  final int? nextPage; // sonraki sayfa numarası (yoksa null)

  const CategoryDetail({
    required this.category,
    this.subCategories = const [],
    this.pinned,
    this.places = const [],
    this.page = 1,
    this.pages = 1,
    this.total = 0,
    this.hasMore = false,
    this.nextPage,
  });
}

/// Ana sayfa alanlarını besleyen repository.
/// Kategoriler, sponsorlu restoranlar, yakındakiler ve yeni eklenenler
/// (bkz. HOME_PAGE_SETTINGS.md). Yayınlanmamış özel endpoint'lerde `/mekanlar`
/// listesine zarifçe düşer.
class HomeRepository {
  HomeRepository._();
  static final HomeRepository instance = HomeRepository._();

  List<Category>? _categoriesCache;
  DateTime? _categoriesAt;
  static const _ttl = Duration(minutes: 12);

  Dio get _dio => Api.instance.dio;

  /// `GET /kategoriler` — tüm sistem kategorileri (kısa süreli cache).
  Future<List<Category>> kategoriler({bool forceRefresh = false}) async {
    final fresh = _categoriesAt != null &&
        DateTime.now().difference(_categoriesAt!) < _ttl;
    if (!forceRefresh && _categoriesCache != null && fresh) {
      return _categoriesCache!;
    }
    final res = await _dio.get('/kategoriler');
    final body = res.data as Map<String, dynamic>;
    if (body['success'] != true) {
      throw Exception(body['error']?['message'] ?? 'Kategoriler alınamadı');
    }
    final list = (body['data'] as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(Category.fromJson)
        .toList();
    _categoriesCache = list;
    _categoriesAt = DateTime.now();
    return list;
  }

  /// Kategori detayı: kategori + alt kategoriler + sabit restoran + mekanlar.
  /// Önce tam detay `GET /kategoriler/{id}` denenir; yayında değilse
  /// `GET /kategoriler/{id}/mekanlar` (yalnızca mekan listesi) kullanılır.
  Future<CategoryDetail> kategoriDetay(int id,
      {int page = 1, int limit = 20}) async {
    // 1) Tam detay endpoint'i (alt kategoriler + sabit restoran dahil).
    try {
      final res = await _dio.get(
        '/kategoriler/$id',
        queryParameters: {'page': page, 'limit': limit},
      );
      final body = res.data as Map<String, dynamic>;
      if (body['success'] == true && body['data'] is Map<String, dynamic>) {
        return _parseCategoryDetail(body, page);
      }
    } catch (_) {
      // detay endpoint'i yok → mekan listesine düş
    }
    // 2) Yedek: sadece kategori mekanları.
    return _kategoriMekanlar(id, page: page, limit: limit);
  }

  CategoryDetail _parseCategoryDetail(Map<String, dynamic> body, int page) {
    final data = body['data'] as Map<String, dynamic>;

    final kat = data['kategori'] is Map<String, dynamic>
        ? Category.fromJson(data['kategori'] as Map<String, dynamic>)
        : const Category(id: 0, name: 'Kategori');

    final subs = (data['alt_kategoriler'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .map(Category.fromJson)
            .toList() ??
        const <Category>[];

    final pinnedJson = data['sabit_restoran'];
    final pinned = pinnedJson is Map<String, dynamic>
        ? _restToPlace(pinnedJson, sponsored: true)
        : null;

    final places = (data['mekanlar'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .map((e) => _restToPlace(e))
            .toList() ??
        const <Place>[];

    final meta = (body['meta'] as Map<String, dynamic>?) ?? const {};
    final curPage = (meta['page'] as num?)?.toInt() ?? page;
    final pages = (meta['pages'] as num?)?.toInt() ?? 1;
    final hasMore = meta['has_more'] as bool? ?? (curPage < pages);
    return CategoryDetail(
      category: kat,
      subCategories: subs,
      pinned: pinned,
      places: places,
      page: curPage,
      pages: pages,
      total: (meta['total'] as num?)?.toInt() ?? places.length,
      hasMore: hasMore,
      nextPage: (meta['next_page'] as num?)?.toInt() ??
          (hasMore ? curPage + 1 : null),
    );
  }

  /// `GET /kategoriler/{id}/mekanlar` — kategori mekanlarının düz sayfalı
  /// listesi (kategori adı `meta.kategori`'den gelir).
  Future<CategoryDetail> _kategoriMekanlar(int id,
      {int page = 1, int limit = 20}) async {
    final res = await _dio.get(
      '/kategoriler/$id/mekanlar',
      queryParameters: {'page': page, 'limit': limit},
    );
    final body = res.data as Map<String, dynamic>;
    if (body['success'] != true) {
      throw Exception(body['error']?['message'] ?? 'Kategori bulunamadı');
    }
    final places = (body['data'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .map((e) => _restToPlace(e))
            .toList() ??
        const <Place>[];
    final meta = (body['meta'] as Map<String, dynamic>?) ?? const {};
    final name = (meta['kategori'] as String?)?.trim() ?? '';
    final curPage = (meta['page'] as num?)?.toInt() ?? page;
    final pages = (meta['pages'] as num?)?.toInt() ?? 1;
    final hasMore = meta['has_more'] as bool? ?? (curPage < pages);
    return CategoryDetail(
      category: Category(id: id, name: name.isNotEmpty ? name : 'Kategori'),
      places: places,
      page: curPage,
      pages: pages,
      total: (meta['total'] as num?)?.toInt() ?? places.length,
      hasMore: hasMore,
      nextPage: (meta['next_page'] as num?)?.toInt() ??
          (hasMore ? curPage + 1 : null),
    );
  }

  /// Kategori/arama restoran kaydını liste kartı [Place]'ine çevirir.
  /// Koordinat yoksa lat/lng NaN kalır (mesafe hesaplanamaz). `distance`
  /// alanına "İl · İlçe" yazılır (kart alt satırındaki konum ikonu için).
  Place _restToPlace(Map<String, dynamic> j, {bool sponsored = false}) {
    final ap = _parsePlace(j);
    return Place(
      name: ap.name,
      category: 'Restoran',
      subtitle: 'Restoran',
      rating: 0,
      distance: ap.cityDistrict,
      price: '',
      image: ap.image,
      lat: ap.lat ?? double.nan,
      lng: ap.lng ?? double.nan,
      tags: const ['restoran'],
      sponsored: sponsored,
      date: (j['date'] as String?) ?? '',
      filterIds: (j['filtre_ids'] as List<dynamic>?)
              ?.whereType<num>()
              .map((e) => e.toInt())
              .toList() ??
          const [],
    );
  }

  /// Harita mekanları (HARITA.md). `GET /harita?kategori=&type=`.
  /// Yalnızca koordinatı olanlar döner (sayfalama yok).
  Future<List<ApiPlace>> harita({int? kategori, String? type}) async {
    try {
      final res = await _dio.get(
        '/harita',
        queryParameters: {'kategori': ?kategori, 'type': ?type},
      );
      final body = res.data as Map<String, dynamic>;
      if (body['success'] != true) return const [];
      final data = body['data'];
      if (data is! List) return const [];
      return data
          .whereType<Map<String, dynamic>>()
          .map(_parsePlace)
          .where((p) => p.hasCoord)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Filtre listesi (FILTRELER.md). `GET /filtreler?type=`.
  Future<List<Filter>> filtreler({String? type}) async {
    try {
      final res = await _dio.get(
        '/filtreler',
        queryParameters: {'type': ?type},
      );
      final body = res.data as Map<String, dynamic>;
      if (body['success'] != true) return const [];
      final data = body['data'];
      if (data is! List) return const [];
      return data
          .whereType<Map<String, dynamic>>()
          .map(Filter.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Verilen id'lere ait kategorileri, [ids] sırasını koruyarak döner.
  Future<List<Category>> kategorilerByIds(List<int> ids) async {
    final all = await kategoriler();
    final byId = {for (final c in all) c.id: c};
    return [for (final id in ids) if (byId[id] != null) byId[id]!];
  }

  /// `GET /mekanlar/{id}` — tek mekan detayı → [ApiPlace].
  Future<ApiPlace?> mekan(int id) async {
    try {
      final res = await _dio.get('/mekanlar/$id');
      final body = res.data as Map<String, dynamic>;
      if (body['success'] != true) return null;
      final data = body['data'];
      if (data is! Map<String, dynamic>) return null;
      return _parsePlace(data);
    } catch (_) {
      return null;
    }
  }

  /// Sponsorlu restoranlar — id'lere göre paralel detay çekimi.
  Future<List<ApiPlace>> sponsorluRestoranlar(List<int> ids) async {
    final results = await Future.wait(ids.map(mekan));
    return results.whereType<ApiPlace>().toList();
  }

  /// Bir "*-page-settings/{key}" alanındaki `restaurant_ids` dizisini çeker.
  Future<List<int>> _sectionRestaurantIds(String path) async {
    try {
      final res = await _dio.get(path);
      final body = res.data as Map<String, dynamic>;
      if (body['success'] != true) return const [];
      final data = body['data'];
      if (data is! Map<String, dynamic>) return const [];
      final settings = data['settings'];
      if (settings is! Map<String, dynamic>) return const [];
      final ids = settings['restaurant_ids'];
      if (ids is! List) return const [];
      return ids.whereType<num>().map((e) => e.toInt()).toList();
    } catch (_) {
      return const [];
    }
  }

  /// Arama sayfası sponsorlu restoranları (SEARCH_PAGE_SETTINGS.md).
  /// `GET /search-page-settings/sponsorlu_restoranlar` → restaurant_ids,
  /// ardından `/mekanlar/{id}` ile görsel + şehir/ilçe çözülür.
  Future<List<ApiPlace>> aramaSponsorluRestoranlar() async {
    final ids = await _sectionRestaurantIds(
        '/search-page-settings/sponsorlu_restoranlar');
    if (ids.isEmpty) return const [];
    return sponsorluRestoranlar(ids);
  }

  /// `GET /mekanlar` — restoran listesi (yeni → eski sıralı gelir).
  Future<List<ApiPlace>> mekanlar({
    String type = 'restoran',
    int? kategori,
    int page = 1,
    int limit = 20,
  }) async {
    final res = await _dio.get(
      '/mekanlar',
      queryParameters: {
        'type': type,
        'kategori': ?kategori,
        'page': page,
        'limit': limit,
      },
    );
    final body = res.data as Map<String, dynamic>;
    if (body['success'] != true) {
      throw Exception(body['error']?['message'] ?? 'Mekanlar alınamadı');
    }
    return (body['data'] as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(_parsePlace)
        .toList();
  }

  /// Yeni eklenenler. Özel endpoint yayınlıysa onu, değilse `/mekanlar`
  /// listesini (zaten `date DESC` sıralı) kullanır.
  Future<List<ApiPlace>> yeniEklenenler({int limit = 10}) async {
    final special =
        await _tryList('/mekanlar/yeni-eklenenler', {'limit': limit});
    if (special != null) return special;
    return mekanlar(limit: limit);
  }

  /// Yakındakiler havuzu. Özel endpoint yayınlıysa onu, değilse `/mekanlar`
  /// listesini kullanır. Mesafe sıralaması app tarafında yapılır.
  Future<List<ApiPlace>> yakindakiler({int limit = 100}) async {
    final special =
        await _tryList('/mekanlar/yakindakiler', {'limit': limit});
    if (special != null) return special;
    return mekanlar(limit: limit);
  }

  /// Restoran araması (ARAMA.md). Ad + menü ürünlerinde `LIKE '%q%'`.
  /// `GET /arama?q=&page=&limit=` — en az 2 karakter gerekir.
  Future<List<SearchResult>> arama(
    String q, {
    int page = 1,
    int limit = 20,
    String? userId, // gönderilirse arama geçmişine kullanıcıyla kaydedilir
  }) async {
    final term = q.trim();
    if (term.length < 2) return const [];
    final res = await _dio.get(
      '/arama',
      queryParameters: {
        'q': term,
        'page': page,
        'limit': limit,
        if (userId != null && userId.isNotEmpty) 'user_id': userId,
      },
    );
    final body = res.data as Map<String, dynamic>;
    if (body['success'] != true) return const [];
    final data = body['data'];
    if (data is! List) return const [];
    return data.whereType<Map<String, dynamic>>().map((j) {
      return SearchResult(
        place: _parsePlace(j),
        matchedProducts: (j['eslesen_urunler'] as List<dynamic>?)
                ?.whereType<String>()
                .toList() ??
            const [],
        matchTypes: (j['eslesme'] as List<dynamic>?)
                ?.whereType<String>()
                .toList() ??
            const [],
      );
    }).toList();
  }

  /// En çok aranan kelimeler (ARAMA_GECMISI.md).
  /// `GET /populer-aramalar?limit=&days=` → terim listesi.
  Future<List<String>> populerAramalar({int limit = 6, int? days}) async {
    try {
      final res = await _dio.get(
        '/populer-aramalar',
        queryParameters: {'limit': limit, 'days': ?days},
      );
      final body = res.data as Map<String, dynamic>;
      if (body['success'] != true) return const [];
      final data = body['data'];
      if (data is! List) return const [];
      return data
          .whereType<Map<String, dynamic>>()
          .map((e) => (e['term'] as String?)?.trim() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Öne çıkan / sponsorlu etkinlikler.
  /// `GET /home-page-settings/sponsorlu_etkinlikler` → çözülmüş `events`.
  Future<List<FeaturedEvent>> sponsorluEtkinlikler() async {
    try {
      final res = await _dio.get('/home-page-settings/sponsorlu_etkinlikler');
      final body = res.data as Map<String, dynamic>;
      if (body['success'] != true) return const [];
      final data = body['data'];
      if (data is! Map<String, dynamic>) return const [];
      final settings = data['settings'];
      if (settings is! Map<String, dynamic>) return const [];
      final events = settings['events'];
      if (events is! List) return const [];
      return events
          .whereType<Map<String, dynamic>>()
          .map((e) {
            String image = '';
            final img = e['image'];
            if (img is String && img.isNotEmpty) {
              image = img.startsWith('http') ? img : '$kApiHost$img';
            }
            return FeaturedEvent(
              id: (e['id'] as num?)?.toInt() ?? 0,
              name: (e['name'] as String?)?.trim().isNotEmpty == true
                  ? e['name'] as String
                  : 'Etkinlik',
              date: e['date'] as String? ?? '',
              time: e['time'] as String? ?? '',
              image: image,
            );
          })
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Etkinlikler (`GET /etkinlikler`). Sayfalı; `upcoming=true` yalnızca
  /// bugünden sonrasını getirir. Sonuç + sayfalama meta'sı döner.
  Future<({List<Event> items, bool hasMore, int? nextPage, int total})>
      etkinlikler({bool upcoming = true, int page = 1, int limit = 20}) async {
    final res = await _dio.get('/etkinlikler', queryParameters: {
      'status': 1,
      if (upcoming) 'upcoming': 1,
      'page': page,
      'limit': limit,
    });
    final body = res.data as Map<String, dynamic>;
    if (body['success'] != true) {
      throw Exception(body['error']?['message'] ?? 'Etkinlikler alınamadı');
    }
    final data = body['data'];
    final list = (data is List ? data : const [])
        .whereType<Map<String, dynamic>>()
        .map(_parseEvent)
        .toList();
    final meta = (body['meta'] as Map<String, dynamic>?) ?? const {};
    final curPage = (meta['page'] as num?)?.toInt() ?? page;
    final pages = (meta['pages'] as num?)?.toInt() ?? 1;
    final hasMore = meta['has_more'] as bool? ?? (curPage < pages);
    return (
      items: list,
      hasMore: hasMore,
      nextPage: (meta['next_page'] as num?)?.toInt() ??
          (hasMore ? curPage + 1 : null),
      total: (meta['total'] as num?)?.toInt() ?? list.length,
    );
  }

  /// Bildirimler (`GET /bildirimler`). Metin HTML'den arındırılır ve aynı
  /// metin birden çok kez gelirse (log + post kayıtları) tek gösterilir.
  Future<List<AppNotification>> bildirimler({int page = 1, int limit = 30}) async {
    final res = await _dio.get(
      '/bildirimler',
      queryParameters: {'page': page, 'limit': limit},
    );
    final body = res.data as Map<String, dynamic>;
    if (body['success'] != true) {
      throw Exception(body['error']?['message'] ?? 'Bildirimler alınamadı');
    }
    final data = body['data'];
    if (data is! List) return const [];

    final seen = <String>{};
    final out = <AppNotification>[];
    for (final e in data.whereType<Map<String, dynamic>>()) {
      final raw = (e['baslik'] as String?) ?? (e['mesaj'] as String?) ?? '';
      final text = _stripHtml(raw);
      if (text.isEmpty) continue;
      if (!seen.add(text)) continue; // aynı metni tekrar gösterme
      // Cihaz token'ı varsa sunucu `okundu` döner; yoksa (null) yeni sayılır.
      final okundu = e['okundu'];
      out.add(AppNotification(
        id: (e['id'] as num?)?.toInt() ?? 0,
        text: text,
        date: DateTime.tryParse((e['tarih'] as String?)?.trim() ?? ''),
        unread: okundu is bool ? !okundu : true,
      ));
    }
    return out;
  }

  /// Cihazın tüm bildirimlerini okundu işaretler (`POST /bildirimler/okundu`).
  /// Cihaz token'ı interceptor ile eklenir. Başarılıysa `true`; endpoint
  /// yayında değilse / hata olursa `false` (UI yerel olarak yine işaretler).
  Future<bool> tumunuOkundu() async {
    try {
      final res = await _dio.post('/bildirimler/okundu');
      final body = res.data;
      return body is Map && body['success'] == true;
    } catch (_) {
      return false;
    }
  }

  /// HTML etiketlerini kaldırır ve boşlukları sadeleştirir.
  String _stripHtml(String s) => s
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static const List<String> _trMonths = [
    '', 'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz', //
    'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara',
  ];

  /// ISO tarihten ("2025-10-14") gösterime hazır (gün, ayKısa) üretir.
  (String, String) _eventDayMonth(String iso) {
    if (iso.isEmpty) return ('', '');
    final dt = DateTime.tryParse(iso);
    if (dt == null) return ('', '');
    final m = (dt.month >= 1 && dt.month <= 12) ? _trMonths[dt.month] : '';
    return (dt.day.toString(), m);
  }

  /// `/etkinlikler` kaydını [Event]'e çevirir (alan adları esnek eşlenir).
  Event _parseEvent(Map<String, dynamic> j) {
    String? pick(List<String> keys) {
      for (final k in keys) {
        final v = j[k];
        if (v is String && v.trim().isNotEmpty) return v.trim();
        if (v is num) return v.toString();
      }
      return null;
    }

    final title = pick(['name', 'title', 'baslik', 'ad']) ?? 'Etkinlik';

    String image = '';
    final img = pick(['image', 'thumbnail', 'gorsel', 'cover', 'kapak']);
    if (img != null) image = img.startsWith('http') ? img : '$kApiHost$img';

    final dateStr = pick(['date', 'tarih', 'start_date', 'baslangic']) ?? '';
    final (day, month) = _eventDayMonth(dateStr);

    final time = pick(['time', 'saat']) ?? '';
    final loc = pick(
            ['location', 'konum', 'yer', 'mekan', 'venue', 'adres', 'bolge']) ??
        '';
    final place = [loc, time].where((s) => s.isNotEmpty).join(' · ');

    final tag = pick(['kategori', 'category', 'type', 'tur']) ?? '';

    return Event(
      id: (j['id'] as num?)?.toInt() ?? 0,
      title: title,
      image: image,
      place: place,
      tag: tag,
      day: day,
      month: month,
    );
  }

  /// Bir listeleme endpoint'ini dener; 404 / success:false / hata olursa null.
  Future<List<ApiPlace>?> _tryList(
      String path, Map<String, dynamic> query) async {
    try {
      final res = await _dio.get(path, queryParameters: query);
      final body = res.data as Map<String, dynamic>;
      if (body['success'] != true) return null;
      final data = body['data'];
      if (data is! List) return null;
      return data
          .whereType<Map<String, dynamic>>()
          .map(_parsePlace)
          .toList();
    } catch (_) {
      return null;
    }
  }

  ApiPlace _parsePlace(Map<String, dynamic> j) {
    // Görsel: önce image, sonra thumbnail. Tam URL ya da göreli olabilir.
    String image = '';
    for (final key in ['image', 'thumbnail']) {
      final v = j[key];
      if (v is String && v.isNotEmpty) {
        image = v.startsWith('http') ? v : '$kApiHost$v';
        break;
      }
    }

    // Koordinat: önce enlem/boylam alanları, sonra "kordinat" metni.
    double? lat = (j['enlem'] as num?)?.toDouble();
    double? lng = (j['boylam'] as num?)?.toDouble();
    if (lat == null || lng == null) {
      final coord = _parseCoord(j['kordinat']);
      if (coord != null) {
        lat = coord.$1;
        lng = coord.$2;
      }
    }
    // "123456" gibi anlamsız/menzil dışı koordinatları ele.
    if (lat != null && (lat < -90 || lat > 90)) lat = null;
    if (lng != null && (lng < -180 || lng > 180)) lng = null;
    if (lat == null || lng == null) {
      lat = null;
      lng = null;
    }

    return ApiPlace(
      id: (j['id'] as num?)?.toInt() ?? 0,
      name: (j['name'] as String?)?.trim().isNotEmpty == true
          ? j['name'] as String
          : 'İsimsiz Mekan',
      image: image,
      lat: lat,
      lng: lng,
      sehir: (j['sehir'] as String?)?.trim() ?? '',
      ilce: (j['ilce'] as String?)?.trim() ?? '',
      categoryIds: (j['kategori_ids'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [],
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
