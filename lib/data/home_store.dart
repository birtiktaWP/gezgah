import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'home_config.dart';
import 'models.dart';

/// Ana sayfa verisini önbellekler — amaç: ana sayfa **hızlı** açılsın ve ağ
/// isteği yalnızca uygulama yeniden açıldığında (soğuk başlangıçta) yapılsın.
///
/// - Açılışta [preload] ile disk cache belleğe alınır; ekranlar bunu
///   `FutureBuilder.initialData` olarak **anında** gösterir (spinner yok).
/// - Her bölümün ağ isteği oturumda **bir kez** yapılır (future tekildir);
///   sonuç bir sonraki açılış için diske yazılır.
/// - Aynı oturumda (sekme değişimi, yeniden çizim) tekrar istek atılmaz;
///   ağ hatasında cache korunur.
class HomeStore {
  HomeStore._();
  static final HomeStore instance = HomeStore._();

  static const _kCategories = 'home_c_categories';
  static const _kSponsored = 'home_c_sponsored';
  static const _kNearby = 'home_c_nearby';
  static const _kNewest = 'home_c_newest';
  static const _kEvents = 'home_c_events';

  // Diskten önyüklenen anlık (senkron) cache — initialData için.
  List<Category> cachedCategories = const [];
  List<ApiPlace> cachedSponsored = const [];
  List<ApiPlace> cachedNearby = const [];
  List<ApiPlace> cachedNewest = const [];
  List<FeaturedEvent> cachedEvents = const [];

  // Oturum future'ları (soğuk başlangıçta bir kez oluşturulur).
  Future<List<Category>>? _catF;
  Future<List<ApiPlace>>? _spoF;
  Future<List<ApiPlace>>? _nearF;
  Future<List<ApiPlace>>? _newF;
  Future<List<FeaturedEvent>>? _evtF;

  SharedPreferences? _prefs;

  /// Uygulama açılışında bir kez: disk cache'i belleğe al (senkron erişim için).
  Future<void> preload() async {
    _prefs = await SharedPreferences.getInstance();
    cachedCategories = _read(_kCategories, Category.fromJson);
    cachedSponsored = _read(_kSponsored, ApiPlace.fromCache);
    cachedNearby = _read(_kNearby, ApiPlace.fromCache);
    cachedNewest = _read(_kNewest, ApiPlace.fromCache);
    cachedEvents = _read(_kEvents, FeaturedEvent.fromJson);
  }

  Future<List<Category>> categories() => _catF ??= _fetch(
        _kCategories,
        () => HomeRepository.instance.kategoriler(),
        (c) => c.toJson(),
        () => cachedCategories,
        (v) => cachedCategories = v,
      );

  Future<List<ApiPlace>> sponsorlu() => _spoF ??= _fetch(
        _kSponsored,
        () => HomeRepository.instance
            .sponsorluRestoranlar(HomeConfig.sponsorluRestoranlar),
        (p) => p.toCacheJson(),
        () => cachedSponsored,
        (v) => cachedSponsored = v,
      );

  Future<List<ApiPlace>> yakindakiler() => _nearF ??= _fetch(
        _kNearby,
        () => HomeRepository.instance.yakindakiler(),
        (p) => p.toCacheJson(),
        () => cachedNearby,
        (v) => cachedNearby = v,
      );

  Future<List<ApiPlace>> yeniEklenenler() => _newF ??= _fetch(
        _kNewest,
        () => HomeRepository.instance.yeniEklenenler(limit: 10),
        (p) => p.toCacheJson(),
        () => cachedNewest,
        (v) => cachedNewest = v,
      );

  Future<List<FeaturedEvent>> etkinlikler() => _evtF ??= _fetch(
        _kEvents,
        () => HomeRepository.instance.sponsorluEtkinlikler(),
        (e) => e.toJson(),
        () => cachedEvents,
        (v) => cachedEvents = v,
      );

  // --- iç yardımcılar --------------------------------------------------------

  List<T> _read<T>(String key, T Function(Map<String, dynamic>) fromJson) {
    try {
      final raw = _prefs?.getString(key);
      if (raw == null || raw.isEmpty) return <T>[];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <T>[];
      return decoded.whereType<Map<String, dynamic>>().map(fromJson).toList();
    } catch (_) {
      return <T>[];
    }
  }

  /// Ağdan çeker; başarılıysa cache'i (bellek + disk) günceller. Ağ hatası ya
  /// da boş sonuçta mevcut cache'i döndürür (hiç exception fırlatmaz).
  Future<List<T>> _fetch<T>(
    String key,
    Future<List<T>> Function() run,
    Map<String, dynamic> Function(T) toJson,
    List<T> Function() getCache,
    void Function(List<T>) setCache,
  ) async {
    try {
      final data = await run();
      if (data.isNotEmpty) {
        setCache(data);
        await _save(key, data, toJson);
        return data;
      }
      final cache = getCache();
      return cache.isNotEmpty ? cache : data;
    } catch (_) {
      return getCache();
    }
  }

  Future<void> _save<T>(String key, List<T> items,
      Map<String, dynamic> Function(T) toJson) async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      await prefs.setString(key, jsonEncode(items.map(toJson).toList()));
    } catch (_) {
      // yut: cache yazılamazsa sorun değil
    }
  }
}
