import 'package:dio/dio.dart';

import 'api.dart';
import 'models.dart';

/// "Değerlendirmelerim" ve "Rezervasyonlarım" (Hesabım → Profilim).
///
/// Uçlar (UYE_DEGERLENDIRME_REZERVASYON.md):
/// - `GET    /uye/degerlendirmeler`            üyenin değerlendirmeleri
/// - `DELETE /uye/degerlendirmeler/{id}`       değerlendirmeyi sil
///   (düzenleme mevcut `POST /mekanlar/{id}/degerlendirme` upsert ucuyla)
/// - `GET    /uye/rezervasyonlar?durum=`       yaklaşan | gecmis
/// - `PATCH  /uye/rezervasyonlar/{id}`         tarih / kişi / not değiştir
/// - `POST   /uye/rezervasyonlar/{id}/iptal`   iptal et
///
/// Hepsi üye token'ı ister. Uç henüz yayında değilse (404)
/// [UyeAktiviteHazirDegil] fırlatılır; ekran "yakında" bilgisi gösterir.
class UyeAktiviteRepository {
  UyeAktiviteRepository._();
  static final UyeAktiviteRepository instance = UyeAktiviteRepository._();

  Dio get _dio => Api.instance.dio;

  Future<Options> _auth() async {
    final token = await Api.instance.uyeToken;
    if (token == null || token.isEmpty) {
      throw AuthException('Bu sayfa için giriş yapmalısın.');
    }
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  // ---- Değerlendirmelerim --------------------------------------------------

  Future<Sayfa<Degerlendirmem>> degerlendirmeler({
    int page = 1,
    int limit = 20,
  }) async {
    final body = await _get('/uye/degerlendirmeler', {
      'page': page,
      'limit': limit,
    });
    return Sayfa.parse(body, Degerlendirmem.fromJson, page);
  }

  Future<void> degerlendirmeSil(int id) => _send(
    () async =>
        _dio.delete('/uye/degerlendirmeler/$id', options: await _auth()),
  );

  // ---- Rezervasyonlarım ----------------------------------------------------

  /// [gecmis] false → yaklaşan (tarihi gelmemiş, iptal edilmemiş).
  Future<Sayfa<Rezervasyonum>> rezervasyonlar({
    required bool gecmis,
    int page = 1,
    int limit = 20,
  }) async {
    final body = await _get('/uye/rezervasyonlar', {
      'durum': gecmis ? 'gecmis' : 'yaklasan',
      'page': page,
      'limit': limit,
    });
    return Sayfa.parse(body, Rezervasyonum.fromJson, page);
  }

  /// Tarih ("YYYY-MM-DDTHH:MM"), kişi ve not değişikliği. Onaylı bir
  /// rezervasyon değişince işletme yeniden onaylar (durum → beklemede).
  /// Güncel kaydı döner.
  Future<Rezervasyonum?> rezervasyonGuncelle(
    int id, {
    String? tarih,
    int? kisi,
    String? not,
  }) async {
    final data = await _sendData(
      () async => _dio.patch(
        '/uye/rezervasyonlar/$id',
        data: {'tarih': ?tarih, 'kisi': ?kisi, 'not': ?not},
        options: await _auth(),
      ),
    );
    return data is Map<String, dynamic> ? Rezervasyonum.fromJson(data) : null;
  }

  Future<void> rezervasyonIptal(int id, {String? neden}) => _send(
    () async => _dio.post(
      '/uye/rezervasyonlar/$id/iptal',
      data: {
        if (neden != null && neden.trim().isNotEmpty) 'neden': neden.trim(),
      },
      options: await _auth(),
    ),
  );

  // ---- iç yardımcılar ------------------------------------------------------

  Future<Map> _get(String path, Map<String, dynamic> q) async {
    try {
      final res = await _dio.get(
        path,
        queryParameters: q,
        options: await _auth(),
      );
      final body = res.data;
      if (res.statusCode == 404) throw const UyeAktiviteHazirDegil();
      if (body is! Map || body['success'] != true) {
        throw AuthException(_msg(body) ?? 'Liste alınamadı.');
      }
      return body;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) throw const UyeAktiviteHazirDegil();
      final err = e.error;
      if (err is RateLimitException) throw err;
      throw AuthException('Sunucuya ulaşılamadı. Lütfen tekrar dene.');
    }
  }

  Future<void> _send(Future<Response> Function() run) async {
    await _sendData(run);
  }

  Future<dynamic> _sendData(Future<Response> Function() run) async {
    try {
      final res = await run();
      final body = res.data;
      if (res.statusCode == 404 && _msg(body)?.contains('Kaynak') == true) {
        throw const UyeAktiviteHazirDegil();
      }
      if (body is! Map || body['success'] != true) {
        throw AuthException(_msg(body) ?? 'İşlem tamamlanamadı.');
      }
      return body['data'];
    } on DioException catch (e) {
      final err = e.error;
      if (err is RateLimitException) throw err;
      final m = _msg(e.response?.data);
      if (e.response?.statusCode == 404 && (m?.contains('Kaynak') ?? true)) {
        throw const UyeAktiviteHazirDegil();
      }
      throw AuthException(m ?? 'Sunucuya ulaşılamadı. Lütfen tekrar dene.');
    }
  }

  String? _msg(dynamic body) {
    if (body is! Map) return null;
    final err = body['error'];
    if (err is Map && err['message'] is String) {
      final s = (err['message'] as String).trim();
      return s.isEmpty ? null : s;
    }
    return null;
  }
}

/// Uç henüz yayında değil (404 "Kaynak bulunamadı").
class UyeAktiviteHazirDegil implements Exception {
  const UyeAktiviteHazirDegil();
}

/// Sayfalı liste sonucu.
class Sayfa<T> {
  final List<T> items;
  final bool hasMore;
  final int? nextPage;
  final int total;
  const Sayfa(
    this.items, {
    this.hasMore = false,
    this.nextPage,
    this.total = 0,
  });

  static Sayfa<T> parse<T>(
    Map body,
    T Function(Map<String, dynamic>) fromJson,
    int page,
  ) {
    final data = body['data'];
    final items = data is List
        ? data.whereType<Map<String, dynamic>>().map(fromJson).toList()
        : <T>[];
    final meta = (body['meta'] as Map?) ?? const {};
    final cur = (meta['page'] as num?)?.toInt() ?? page;
    final pages = (meta['pages'] as num?)?.toInt() ?? 1;
    final hasMore = meta['has_more'] as bool? ?? cur < pages;
    return Sayfa(
      items,
      hasMore: hasMore,
      nextPage: hasMore
          ? ((meta['next_page'] as num?)?.toInt() ?? cur + 1)
          : null,
      total: (meta['total'] as num?)?.toInt() ?? items.length,
    );
  }
}

/// Liste kayıtlarındaki mekan özeti.
class AktiviteMekan {
  final int id;
  final String ad;
  final String gorsel; // kare küçük görsel (tam URL) — yoksa ''
  final String sehir;
  final String ilce;
  final String telefon;
  final double? lat;
  final double? lng;

  /// `mekan.yayinda` — mekan yayından kalktıysa false; detaya gidilmez.
  final bool yayinda;

  const AktiviteMekan({
    required this.id,
    this.ad = '',
    this.gorsel = '',
    this.sehir = '',
    this.ilce = '',
    this.telefon = '',
    this.lat,
    this.lng,
    this.yayinda = true,
  });

  String get konum =>
      [sehir, ilce].where((s) => s.trim().isNotEmpty).join(' · ');

  bool get hasCoord => lat != null && lng != null;

  static String _abs(dynamic v) {
    if (v is! String || v.trim().isEmpty) return '';
    final s = v.trim();
    return s.startsWith('http') ? s : '$kApiHost$s';
  }

  factory AktiviteMekan.fromJson(Map<String, dynamic> j) {
    final tn = j['thumbnails'];
    double? lat = (j['enlem'] as num?)?.toDouble();
    double? lng = (j['boylam'] as num?)?.toDouble();
    final k = j['kordinat'];
    if ((lat == null || lng == null) && k is String && k.contains(',')) {
      final parts = k.split(',');
      lat = double.tryParse(parts[0].trim());
      lng = double.tryParse(parts[1].trim());
    }
    return AktiviteMekan(
      id: (j['id'] as num?)?.toInt() ?? 0,
      ad: (j['name'] ?? j['ad'] ?? '').toString().trim(),
      gorsel: _abs(
        (tn is Map ? tn['square'] : null) ?? j['thumbnail'] ?? j['image'],
      ),
      sehir: (j['sehir'] ?? '').toString().trim(),
      ilce: (j['ilce'] ?? '').toString().trim(),
      telefon: (j['telefon'] ?? '').toString().trim(),
      lat: lat,
      lng: lng,
      yayinda: j['yayinda'] != false,
    );
  }

  Place toPlace() => Place(
    id: id,
    name: ad,
    category: 'Mekan',
    subtitle: konum,
    rating: 0,
    distance: konum,
    price: '',
    image: gorsel,
    lat: lat ?? double.nan,
    lng: lng ?? double.nan,
    thumbnail: gorsel.isEmpty ? null : gorsel,
  );
}

/// Üyenin değerlendirmesi (`GET /uye/degerlendirmeler`).
class Degerlendirmem {
  final int id;
  final int puan; // 1–5
  final String yorum;
  final DateTime? tarih;

  /// `yayinda` | `beklemede` (moderasyon) | `reddedildi`.
  final String durum;
  final AktiviteMekan mekan;

  const Degerlendirmem({
    required this.id,
    required this.puan,
    this.yorum = '',
    this.tarih,
    this.durum = 'yayinda',
    required this.mekan,
  });

  factory Degerlendirmem.fromJson(Map<String, dynamic> j) => Degerlendirmem(
    id: (j['id'] as num?)?.toInt() ?? 0,
    puan: ((j['puan'] as num?)?.toInt() ?? 0).clamp(0, 5),
    yorum: (j['yorum'] ?? '').toString().trim(),
    tarih: DateTime.tryParse('${j['tarih'] ?? j['created_at'] ?? ''}'),
    durum: (j['durum'] ?? 'yayinda').toString().trim(),
    mekan: AktiviteMekan.fromJson(
      (j['mekan'] as Map?)?.cast<String, dynamic>() ?? const {},
    ),
  );
}

/// Rezervasyon durumu.
enum RezDurum { beklemede, onaylandi, reddedildi, iptal, tamamlandi, gelmedi }

RezDurum _rezDurum(String s) => switch (s.toLowerCase()) {
  'onaylandi' || 'onaylandı' || 'confirmed' => RezDurum.onaylandi,
  'reddedildi' || 'red' || 'rejected' => RezDurum.reddedildi,
  'iptal' || 'iptal_edildi' || 'cancelled' => RezDurum.iptal,
  'tamamlandi' || 'tamamlandı' || 'completed' => RezDurum.tamamlandi,
  'gelmedi' || 'no_show' => RezDurum.gelmedi,
  _ => RezDurum.beklemede,
};

/// Üyenin rezervasyonu (`GET /uye/rezervasyonlar`).
class Rezervasyonum {
  final int id;
  final String hash;
  final RezDurum durum;
  final DateTime? tarih; // yerel saat
  final int kisi;
  final String bolge;
  final String masa;
  final String not;

  /// `red_nedeni` — yalnız işletme reddettiğinde / iptal ettiğinde dolu.
  final String redNedeni;

  /// `iptal_nedeni` — üyenin kendi yazdığı iptal nedeni.
  final String iptalNedeni;

  /// `olusturma` — rezervasyonun yapıldığı zaman (yerel saat).
  final DateTime? olusturma;
  final bool iptalEdilebilir;
  final bool duzenlenebilir;
  final AktiviteMekan mekan;

  const Rezervasyonum({
    required this.id,
    this.hash = '',
    this.durum = RezDurum.beklemede,
    this.tarih,
    this.kisi = 1,
    this.bolge = '',
    this.masa = '',
    this.not = '',
    this.redNedeni = '',
    this.iptalNedeni = '',
    this.olusturma,
    this.iptalEdilebilir = false,
    this.duzenlenebilir = false,
    required this.mekan,
  });

  /// Tarihi geçmemiş ve iptal/red edilmemiş.
  bool get yaklasan =>
      (durum == RezDurum.beklemede || durum == RezDurum.onaylandi) &&
      (tarih == null || tarih!.isAfter(DateTime.now()));

  factory Rezervasyonum.fromJson(Map<String, dynamic> j) {
    final durum = _rezDurum((j['durum'] ?? '').toString());
    final tarih = DateTime.tryParse('${j['tarih'] ?? ''}')?.toLocal();
    final aktif = durum == RezDurum.beklemede || durum == RezDurum.onaylandi;
    final ileride = tarih == null || tarih.isAfter(DateTime.now());
    return Rezervasyonum(
      id: (j['id'] as num?)?.toInt() ?? 0,
      hash: (j['hash'] ?? '').toString(),
      durum: durum,
      tarih: tarih,
      kisi: (j['kisi'] as num?)?.toInt() ?? 1,
      bolge: (j['bolge'] ?? j['bolge_adi'] ?? '').toString().trim(),
      masa: (j['masa'] ?? '').toString().trim(),
      not: (j['not'] ?? '').toString().trim(),
      redNedeni: (j['red_nedeni'] ?? '').toString().trim(),
      iptalNedeni: (j['iptal_nedeni'] ?? '').toString().trim(),
      olusturma: DateTime.tryParse('${j['olusturma'] ?? ''}')?.toLocal(),
      // Sunucu söylemezse: aktif ve tarihi gelmemişse yönetilebilir.
      iptalEdilebilir: j['iptal_edilebilir'] as bool? ?? (aktif && ileride),
      duzenlenebilir: j['duzenlenebilir'] as bool? ?? (aktif && ileride),
      mekan: AktiviteMekan.fromJson(
        (j['mekan'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
    );
  }
}
