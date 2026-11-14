import 'package:dio/dio.dart';

import 'api.dart';
import 'location_service.dart';
import 'models.dart';

/// İşletme kampanyaları (KAMPANYALAR.md):
///
/// - `GET  /kampanyalar`               aktif kampanyası olan işletmeler
/// - `GET  /kampanyalar/{id}`          kampanya detayı (+ ürünler, kullanımım)
/// - `POST /kampanyalar/{id}/kullan`   kod üret (üye girişi zorunlu)
///
/// Kullanım: kullanıcı "Kampanyayı kullan" der → sunucu 6 haneli kod verir →
/// kullanıcı kodu kasada gösterir. Aynı üye tekrar çağırırsa aynı kod döner.
class KampanyaRepository {
  KampanyaRepository._();
  static final KampanyaRepository instance = KampanyaRepository._();

  Dio get _dio => Api.instance.dio;

  /// Üye girişliyse üye token'ı (detayda `kullanimim` gelsin); yoksa null →
  /// interceptor cihaz token'ını ekler.
  Future<Options?> _uyeOpt() async {
    final t = await Api.instance.uyeToken;
    if (t == null || t.isEmpty) return null;
    return Options(headers: {'Authorization': 'Bearer $t'});
  }

  /// Aktif kampanyası olan işletmeler. Konum biliniyorsa en yakın önce
  /// (`siralama=mesafe`), yoksa en yüksek indirim önce. [tip] `genel` /
  /// `urun`; [mekanId] tek işletmenin kampanyaları (mekan detayı).
  /// Hata → [KampanyaException].
  Future<({List<KampanyaliMekan> items, bool hasMore, int? nextPage})> liste({
    int page = 1,
    int limit = 20,
    String? tip,
    int? mekanId,
    String? siralama,
  }) async {
    final me = LocationService.lastReal;
    final sort = siralama ?? (me != null ? 'mesafe' : 'indirim');
    try {
      final res = await _dio.get(
        '/kampanyalar',
        queryParameters: {
          'page': page,
          'limit': limit,
          'siralama': sort == 'mesafe' && me == null ? 'indirim' : sort,
          if (me != null) 'lat': me.lat,
          if (me != null) 'lng': me.lng,
          if (tip != null && tip.isNotEmpty) 'tip': tip,
          if (mekanId != null && mekanId > 0) 'mekan_id': mekanId,
        },
      );
      final body = res.data;
      if (body is! Map || body['success'] != true) {
        throw KampanyaException(_msg(body) ?? 'Kampanyalar alınamadı.');
      }
      final data = body['data'];
      final items = data is List
          ? data
                .whereType<Map<String, dynamic>>()
                .map(KampanyaliMekan.fromJson)
                .where((m) => m.mekan.id > 0 && m.kampanyalar.isNotEmpty)
                .toList()
          : <KampanyaliMekan>[];
      final meta = (body['meta'] as Map?) ?? const {};
      final cur = (meta['page'] as num?)?.toInt() ?? page;
      final pages = (meta['pages'] as num?)?.toInt() ?? 1;
      final hasMore = meta['has_more'] as bool? ?? cur < pages;
      return (
        items: items,
        hasMore: hasMore,
        nextPage: hasMore
            ? ((meta['next_page'] as num?)?.toInt() ?? cur + 1)
            : null,
      );
    } on DioException catch (e) {
      throw KampanyaException(
        _msg(e.response?.data) ?? 'Kampanyalar alınamadı.',
      );
    }
  }

  /// Tek işletmenin aktif kampanyaları (mekan detayındaki bölüm). Hata ya da
  /// kampanya yoksa boş liste.
  Future<List<Kampanya>> mekanKampanyalari(int mekanId) async {
    if (mekanId <= 0) return const [];
    try {
      final r = await liste(mekanId: mekanId, limit: 1, siralama: 'indirim');
      return r.items.isEmpty ? const [] : r.items.first.kampanyalar;
    } catch (_) {
      return const [];
    }
  }

  /// Kampanya detayı. Bitmiş kampanya da döner (`aktif: false`). Silinmiş /
  /// yayından kalkmış → [KampanyaException] (`bulunamadi: true`).
  Future<Kampanya> detay(int id) async {
    try {
      final res = await _dio.get('/kampanyalar/$id', options: await _uyeOpt());
      final body = res.data;
      final data = body is Map ? body['data'] : null;
      if (body is Map && body['success'] == true && data is Map) {
        return Kampanya.fromJson(data.cast<String, dynamic>());
      }
      throw _hata(res.statusCode, body, 'Kampanya bulunamadı.');
    } on DioException catch (e) {
      throw _hata(
        e.response?.statusCode,
        e.response?.data,
        'Kampanya bulunamadı.',
      );
    }
  }

  /// Hata yanıtını [KampanyaException]'a çevirir. Uygulamanın Dio'su 4xx'i
  /// fırlatmadan döndürdüğü (`validateStatus < 500`) için hem normal yanıt
  /// hem [DioException] yolunda kullanılır. [code] null → sunucuya ulaşılamadı.
  /// `error.details`'e göre dallanır (mesaj metni değişebilir).
  KampanyaException _hata(int? code, dynamic body, String fallback) {
    final d = body is Map && body['error'] is Map
        ? (body['error'] as Map)['details']
        : null;
    bool flag(String k) => d is Map && d[k] == true;
    return KampanyaException(
      _msg(body) ??
          (code == null
              ? 'Sunucuya ulaşılamadı. Bağlantını kontrol et.'
              : fallback),
      bitti: code == 409 || flag('bitti'),
      bulunamadi: code == 404,
      gecersizQr: flag('gecersiz_qr'),
      suresiDoldu: flag('suresi_doldu'),
    );
  }

  // `POST /kampanyalar/{id}/kullan` KAPATILDI (KAMPANYA_QR.md: 410,
  // `qr_gerekli`). Kullanıcı işletmeye gitmeden kampanyayı kullanabiliyordu;
  // artık yalnız işletmedeki QR okutularak kullanılıyor ([qrOkut]).

  /// Okunan metin bir Gezgah kampanya QR'ı mı (KAMPANYA_QR.md "QR içeriği").
  /// QR menü linki (`https://qr.gezgah.com/{slug}`) vb. değildir.
  static bool kampanyaQrMi(String raw) {
    final s = raw.trim();
    return s.startsWith('https://qr.gezgah.com/kampanya-qr.php?') ||
        s.startsWith('http://qr.gezgah.com/kampanya-qr.php?');
  }

  /// İşletmedeki kampanya QR'ını kullanır (`POST /kampanyalar/qr`): okunan
  /// metin olduğu gibi gönderilir, sunucu kodu doğrulayıp kotadan düşer ve
  /// onay kodunu döner. Aynı üye tekrar okutursa aynı kod (`yeni: false`).
  ///
  /// Giriş yoksa [AuthException]; diğer hatalar [KampanyaException]
  /// (`gecersizQr`, `suresiDoldu`, `bitti`, `bulunamadi`).
  Future<KampanyaQrSonuc> qrOkut(String raw) async {
    final opt = await _uyeOpt();
    if (opt == null) {
      throw AuthException('Kampanyayı kullanmak için giriş yapın.');
    }
    try {
      final res = await _dio.post(
        '/kampanyalar/qr',
        data: {'qr': raw.trim()},
        options: opt,
      );
      final body = res.data;
      final data = body is Map ? body['data'] : null;
      if (body is Map && body['success'] == true && data is Map) {
        return KampanyaQrSonuc.fromJson(data.cast<String, dynamic>());
      }
      if (res.statusCode == 401) {
        throw AuthException(
          _msg(body) ?? 'Kampanyayı kullanmak için giriş yapın.',
        );
      }
      throw _hata(res.statusCode, body, 'Kampanya kullanılamadı.');
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      final body = e.response?.data;
      if (code == 401) {
        throw AuthException(
          _msg(body) ?? 'Kampanyayı kullanmak için giriş yapın.',
        );
      }
      throw _hata(code, body, 'Kampanya kullanılamadı.');
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

class KampanyaException implements Exception {
  final String message;
  final bool bitti; // 409: süre / kontenjan doldu ya da durduruldu
  final bool bulunamadi; // 404
  final bool gecersizQr; // 422 `gecersiz_qr`: kampanya QR'ı değil
  final bool suresiDoldu; // 422 `suresi_doldu`: QR'ın 120 sn'si geçti
  KampanyaException(
    this.message, {
    this.bitti = false,
    this.bulunamadi = false,
    this.gecersizQr = false,
    this.suresiDoldu = false,
  });
  @override
  String toString() => message;
}

/// `POST /kampanyalar/qr` başarılı yanıtı: onay kodu + kampanya (+ mekan).
class KampanyaQrSonuc {
  final KampanyaKullanim kullanim;
  final Kampanya? kampanya;

  const KampanyaQrSonuc({required this.kullanim, this.kampanya});

  factory KampanyaQrSonuc.fromJson(Map<String, dynamic> j) {
    final k = j['kampanya'];
    return KampanyaQrSonuc(
      kullanim: KampanyaKullanim.fromJson(j),
      kampanya: k is Map ? Kampanya.fromJson(k.cast<String, dynamic>()) : null,
    );
  }
}

// ---------------------------------------------------------------------------

/// Kampanya listelerindeki kısa mekan özeti
/// (`id, type, name, thumbnail, thumbnails, sehir, ilce, kordinat, telefon`
/// + konum gönderildiyse `mesafe_m`).
class KampanyaMekan {
  final int id;
  final String type;
  final String ad;

  /// Tam boy görsel (`image`). Kampanya yanıtları bugün göndermiyor
  /// (KAMPANYA_MEKAN_GORSEL.md); gelirse doğrudan kullanılır.
  final String image;
  final String thumbSquare;
  final String thumbCard;
  final String thumbWide;
  final String sehir;
  final String ilce;
  final double? lat;
  final double? lng;
  final String telefon;
  final int? mesafeM;

  const KampanyaMekan({
    required this.id,
    this.type = '',
    this.ad = '',
    this.image = '',
    this.thumbSquare = '',
    this.thumbCard = '',
    this.thumbWide = '',
    this.sehir = '',
    this.ilce = '',
    this.lat,
    this.lng,
    this.telefon = '',
    this.mesafeM,
  });

  static String _abs(dynamic v) {
    if (v is! String || v.trim().isEmpty) return '';
    final s = v.trim();
    return s.startsWith('http') ? s : '$kApiHost$s';
  }

  factory KampanyaMekan.fromJson(Map<String, dynamic> j) {
    final tn = j['thumbnails'];
    final thumb = _abs(j['thumbnail']);
    String t(String k) => tn is Map ? _abs(tn[k]) : '';
    double? lat, lng;
    final k = j['kordinat'];
    if (k is String && k.contains(',')) {
      final p = k.split(',');
      lat = double.tryParse(p[0].trim());
      lng = double.tryParse(p[1].trim());
    }
    return KampanyaMekan(
      id: (j['id'] as num?)?.toInt() ?? 0,
      type: (j['type'] ?? '').toString(),
      ad: (j['name'] ?? '').toString().trim(),
      image: _abs(j['image']),
      thumbSquare: t('square').isNotEmpty ? t('square') : thumb,
      thumbCard: t('card').isNotEmpty ? t('card') : thumb,
      thumbWide: t('wide').isNotEmpty ? t('wide') : thumb,
      sehir: (j['sehir'] ?? '').toString().trim(),
      ilce: (j['ilce'] ?? '').toString().trim(),
      lat: lat,
      lng: lng,
      telefon: (j['telefon'] ?? '').toString().trim(),
      mesafeM: parseMesafeM(j),
    );
  }

  /// Tam boy görsel adres adayları (sırayla denenir). `image` varsa yalnız o.
  /// Yoksa küçük görselin dosya adından türetilir: sunucu küçükleri
  /// `/uploads/thumbs/{square|card|wide}/{ad}.webp`, orijinali
  /// `/uploads/{ad}.{jpg|webp|png}` olarak saklıyor (250 mekanda ölçüldü:
  /// 197 jpg, 38 webp, 15 png).
  List<String> get tamGorselAdaylari {
    if (image.isNotEmpty) return [image];
    for (final t in [thumbWide, thumbCard, thumbSquare]) {
      final m = RegExp(
        r'^(https?://[^/]+/uploads/)thumbs/(?:square|card|wide)/([^/?#]+)\.webp$',
      ).firstMatch(t);
      if (m != null) {
        final base = '${m.group(1)}${m.group(2)}';
        return ['$base.jpg', '$base.webp', '$base.png'];
      }
    }
    return const [];
  }

  /// "Beşiktaş · 14,2 km"
  String get konum => [
    ilce.isNotEmpty ? ilce : sehir,
    LocationService.formatM(mesafeM),
  ].where((s) => s.isNotEmpty).join(' · ');

  /// Mekan detayını açmak için.
  Place toPlace() => Place(
    id: id,
    name: ad.isNotEmpty ? ad : 'Mekan',
    category: 'Mekan',
    subtitle: [sehir, ilce].where((s) => s.isNotEmpty).join(' · '),
    rating: 0,
    distance: [sehir, ilce].where((s) => s.isNotEmpty).join(' · '),
    price: '',
    image: thumbWide,
    lat: lat ?? double.nan,
    lng: lng ?? double.nan,
    thumbSquare: thumbSquare.isEmpty ? null : thumbSquare,
    thumbCard: thumbCard.isEmpty ? null : thumbCard,
    thumbWide: thumbWide.isEmpty ? null : thumbWide,
    mesafeM: mesafeM,
  );
}

/// Kampanya durumu (`durum`).
enum KampanyaDurum { aktif, suresiDoldu, limitDoldu, durduruldu }

KampanyaDurum _durum(dynamic v) => switch ('${v ?? ''}') {
  'suresi_doldu' => KampanyaDurum.suresiDoldu,
  'limit_doldu' => KampanyaDurum.limitDoldu,
  'durduruldu' => KampanyaDurum.durduruldu,
  _ => KampanyaDurum.aktif,
};

/// Ürün bazlı kampanyada indirimli ürün.
class KampanyaUrun {
  final int id;
  final String ad;
  final String aciklama;
  final String kategori;
  final String gorsel;
  final num? fiyat;
  final num? indirimliFiyat;

  const KampanyaUrun({
    required this.id,
    this.ad = '',
    this.aciklama = '',
    this.kategori = '',
    this.gorsel = '',
    this.fiyat,
    this.indirimliFiyat,
  });

  factory KampanyaUrun.fromJson(Map<String, dynamic> j) => KampanyaUrun(
    id: (j['id'] as num?)?.toInt() ?? 0,
    ad: (j['ad'] ?? '').toString().trim(),
    aciklama: (j['aciklama'] ?? '').toString().trim(),
    kategori: (j['kategori'] ?? '').toString().trim(),
    gorsel: KampanyaMekan._abs(j['gorsel']),
    fiyat: j['fiyat'] is num
        ? j['fiyat'] as num
        : num.tryParse('${j['fiyat']}'),
    indirimliFiyat: j['indirimli_fiyat'] is num
        ? j['indirimli_fiyat'] as num
        : num.tryParse('${j['indirimli_fiyat']}'),
  );
}

/// Kullanıcının kampanya kodu (`kullanimim` / `POST …/kullan`).
class KampanyaKullanim {
  final String kod;
  final DateTime? tarih;
  final bool yeni;
  final int? kalanKullanim;

  const KampanyaKullanim({
    required this.kod,
    this.tarih,
    this.yeni = false,
    this.kalanKullanim,
  });

  factory KampanyaKullanim.fromJson(Map<String, dynamic> j) => KampanyaKullanim(
    kod: (j['kod'] ?? '').toString().trim(),
    tarih: DateTime.tryParse('${j['tarih'] ?? ''}')?.toLocal(),
    yeni: j['yeni'] == true,
    kalanKullanim: (j['kalan_kullanim'] as num?)?.toInt(),
  );
}

class Kampanya {
  final int id;
  final int mekanId;
  final bool urunBazli; // tip: urun (yoksa genel = tüm menü)
  final String baslik;
  final String aciklama;
  final int oran; // %
  final DateTime? bitis;
  final DateTime? baslangic;
  final int? kullanimLimiti;
  final int kullanimSayisi;
  final int? kalanKullanim;
  final int? urunSayisi;
  final KampanyaDurum durum;
  final KampanyaMekan? mekan; // detayda dolu
  final List<KampanyaUrun> urunler; // detayda, ürün bazlıysa
  final KampanyaKullanim? kullanimim; // detayda, üye kullandıysa

  const Kampanya({
    required this.id,
    this.mekanId = 0,
    this.urunBazli = false,
    this.baslik = '',
    this.aciklama = '',
    this.oran = 0,
    this.bitis,
    this.baslangic,
    this.kullanimLimiti,
    this.kullanimSayisi = 0,
    this.kalanKullanim,
    this.urunSayisi,
    this.durum = KampanyaDurum.aktif,
    this.mekan,
    this.urunler = const [],
    this.kullanimim,
  });

  bool get aktif => durum == KampanyaDurum.aktif;

  /// Başlık boşsa (eski kayıt) sunucunun ürettiği biçim.
  String get gosterilenBaslik => baslik.isNotEmpty
      ? baslik
      : urunBazli
      ? 'Seçili ürünlerde %$oran indirim'
      : 'Tüm menüde %$oran indirim';

  /// "Tüm menüde geçerli" / "3 üründe geçerli".
  String get kapsam => urunBazli
      ? ((urunSayisi ?? urunler.length) > 0
            ? '${urunSayisi ?? urunler.length} üründe geçerli'
            : 'Seçili ürünlerde geçerli')
      : 'Tüm menüde geçerli';

  /// Kalan süre metni: "Bugün son gün", "Son 3 gün", "21 Kasım'a kadar".
  /// Bitiş yoksa null.
  String? kalanSure({DateTime? now}) {
    final b = bitis;
    if (b == null) return null;
    final n = now ?? DateTime.now();
    if (!b.isAfter(n)) return 'Süresi doldu';
    final gun = DateTime(
      b.year,
      b.month,
      b.day,
    ).difference(DateTime(n.year, n.month, n.day)).inDays;
    if (gun == 0) return 'Bugün son gün';
    if (gun <= 7) return 'Son ${gun + 1} gün';
    const ay = [
      'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', //
      'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
    ];
    return '${b.day} ${ay[b.month - 1]}\'a kadar';
  }

  /// "Son 5 kişi" (kontenjan azsa) / "38 kişilik kontenjan". Sınır yoksa null.
  String? kontenjan() {
    final k = kalanKullanim;
    if (k == null) return null;
    if (k <= 10) return 'Son $k kişi';
    return '$k kişilik kontenjan';
  }

  /// Pasif kampanyada düğme metni.
  String get pasifNedeni => switch (durum) {
    KampanyaDurum.suresiDoldu => 'Süresi doldu',
    KampanyaDurum.limitDoldu => 'Kontenjan doldu',
    KampanyaDurum.durduruldu => 'Şu an geçerli değil',
    KampanyaDurum.aktif => '',
  };

  factory Kampanya.fromJson(Map<String, dynamic> j) {
    final m = j['mekan'];
    final k = j['kullanimim'];
    final aktifFlag = j['aktif'];
    var durum = _durum(j['durum']);
    // `durum` yok ama `aktif: false` geldiyse (eski yanıt) "geçerli değil".
    if (j['durum'] == null && aktifFlag == false) {
      durum = KampanyaDurum.durduruldu;
    }
    return Kampanya(
      id: (j['id'] as num?)?.toInt() ?? 0,
      mekanId: (j['mekan_id'] as num?)?.toInt() ?? 0,
      urunBazli: '${j['tip'] ?? ''}' == 'urun',
      baslik: (j['baslik'] ?? '').toString().trim(),
      aciklama: (j['aciklama'] ?? '').toString().trim(),
      oran: (j['indirim_orani'] as num?)?.toInt() ?? 0,
      bitis: DateTime.tryParse('${j['bitis'] ?? ''}')?.toLocal(),
      baslangic: DateTime.tryParse('${j['baslangic'] ?? ''}')?.toLocal(),
      kullanimLimiti: (j['kullanim_limiti'] as num?)?.toInt(),
      kullanimSayisi: (j['kullanim_sayisi'] as num?)?.toInt() ?? 0,
      kalanKullanim: (j['kalan_kullanim'] as num?)?.toInt(),
      urunSayisi: (j['urun_sayisi'] as num?)?.toInt(),
      durum: durum,
      mekan: m is Map
          ? KampanyaMekan.fromJson(m.cast<String, dynamic>())
          : null,
      urunler: (j['urunler'] is List)
          ? (j['urunler'] as List)
                .whereType<Map>()
                .map((e) => KampanyaUrun.fromJson(e.cast<String, dynamic>()))
                .toList()
          : const [],
      kullanimim: k is Map && '${k['kod'] ?? ''}'.trim().isNotEmpty
          ? KampanyaKullanim.fromJson(k.cast<String, dynamic>())
          : null,
    );
  }

  Kampanya withKullanim(KampanyaKullanim u) => Kampanya(
    id: id,
    mekanId: mekanId,
    urunBazli: urunBazli,
    baslik: baslik,
    aciklama: aciklama,
    oran: oran,
    bitis: bitis,
    baslangic: baslangic,
    kullanimLimiti: kullanimLimiti,
    kullanimSayisi: kullanimSayisi + (u.yeni ? 1 : 0),
    kalanKullanim: u.kalanKullanim ?? kalanKullanim,
    urunSayisi: urunSayisi,
    durum: durum,
    mekan: mekan,
    urunler: urunler,
    kullanimim: u,
  );
}

/// `GET /kampanyalar` satırı: işletme + aktif kampanyaları.
class KampanyaliMekan {
  final KampanyaMekan mekan;
  final int enYuksekIndirim;
  final List<Kampanya> kampanyalar; // yüksek indirimden düşüğe

  const KampanyaliMekan({
    required this.mekan,
    this.enYuksekIndirim = 0,
    this.kampanyalar = const [],
  });

  factory KampanyaliMekan.fromJson(Map<String, dynamic> j) {
    final m = j['mekan'];
    final list = (j['kampanyalar'] is List)
        ? (j['kampanyalar'] as List)
              .whereType<Map>()
              .map((e) => Kampanya.fromJson(e.cast<String, dynamic>()))
              .where((k) => k.id > 0)
              .toList()
        : <Kampanya>[];
    final mekan = m is Map
        ? KampanyaMekan.fromJson(m.cast<String, dynamic>())
        : const KampanyaMekan(id: 0);
    final top =
        (j['en_yuksek_indirim'] as num?)?.toInt() ??
        list.fold<int>(0, (a, k) => k.oran > a ? k.oran : a);
    return KampanyaliMekan(
      mekan: mekan,
      enYuksekIndirim: top,
      kampanyalar: list,
    );
  }
}
