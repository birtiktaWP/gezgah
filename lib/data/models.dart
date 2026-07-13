import 'package:flutter/widgets.dart';

/// Mekan açık/kapanış durumu
enum OpenState { open, closing, closed }

class Place {
  final int id; // mekan id (`yzd_posts.id`); 0 = bilinmiyor (mock)
  final String name;
  final String category;
  String subtitle; // örn. "Geleneksel Türk · ₺₺" (mesafe sonradan eklenebilir)
  final double rating;
  String distance; // "1.2 km" (konuma göre hesaplanır)
  final String price; // "₺250"
  final String image;
  final OpenState state;
  final double lat;
  final double lng;
  final List<String> tags;
  final bool verified;
  final bool sponsored;
  final String date; // eklenme tarihi (ISO "2026-06-20"); sıralama için
  final List<int> filterIds; // aktif filtre id'leri (filtre_{id}=1)
  bool favorite;

  Place({
    this.id = 0,
    required this.name,
    required this.category,
    required this.subtitle,
    required this.rating,
    required this.distance,
    required this.price,
    required this.image,
    this.state = OpenState.open,
    this.lat = 40.9875,
    this.lng = 29.0270,
    this.tags = const [],
    this.verified = false,
    this.sponsored = false,
    this.date = '',
    this.filterIds = const [],
    this.favorite = false,
  });
}

class EventItem {
  final String title;
  final String tag; // "🎵 Konser"
  final String day; // "14"
  final String month; // "Haz"
  final String location; // "Harbiye Açıkhava · 20:00"
  final String image;

  const EventItem({
    required this.title,
    required this.tag,
    required this.day,
    required this.month,
    required this.location,
    required this.image,
  });
}

class CategoryChip {
  final String label;
  final IconData icon;
  const CategoryChip(this.label, this.icon);
}

/// Ana sayfa "Tümü" kısayol öğesi (home_page_settings → section_key `tumu`).
/// İkon, id'ye göre `HomeConfig.iconFor` ile belirlenir (emoji kullanılmaz).
class HomeShortcut {
  final int id; // kategori post id (0 = "Tümü")
  final String name;
  const HomeShortcut(this.id, this.name);
}

/// Öne çıkan / sponsorlu etkinlik (home_page_settings → sponsorlu_etkinlikler
/// içindeki çözülmüş `events`).
class FeaturedEvent {
  final int id;
  final String name;
  final String date; // "2025-10-14"
  final String time; // "22:23"
  final String image;

  const FeaturedEvent({
    required this.id,
    required this.name,
    this.date = '',
    this.time = '',
    this.image = '',
  });
}

/// Etkinlik (`GET /etkinlikler`). Alanlar repository'de host/tarih işlenerek
/// doldurulur; `day`/`month` gösterime hazır (ör. "14" / "Haz").
class Event {
  final int id;
  final String title;
  final String image;
  final String place; // konum/mekan (+ saat)
  final String tag; // kategori/tür etiketi
  final String day; // "14"
  final String month; // "Haz"

  const Event({
    required this.id,
    required this.title,
    this.image = '',
    this.place = '',
    this.tag = '',
    this.day = '',
    this.month = '',
  });

  /// Mock [EventItem]'dan üretir (API hatasında yedek vitrin için).
  factory Event.fromItem(EventItem e) => Event(
        id: 0,
        title: e.title,
        image: e.image,
        place: e.location,
        tag: e.tag,
        day: e.day,
        month: e.month,
      );
}

/// Filtre tanımı (`GET /filtreler`, FILTRELER.md).
class Filter {
  final int id;
  final String name;
  final String slug;
  final String type; // filter_type: restoran/plaj/...
  final String? icon; // SVG string (yoksa null)

  const Filter({
    required this.id,
    required this.name,
    this.slug = '',
    this.type = '',
    this.icon,
  });

  factory Filter.fromJson(Map<String, dynamic> j) => Filter(
        id: (j['id'] as num?)?.toInt() ?? 0,
        name: (j['name'] as String?)?.trim().isNotEmpty == true
            ? j['name'] as String
            : 'Filtre',
        slug: j['slug'] as String? ?? '',
        type: j['type'] as String? ?? '',
        icon: j['icon'] as String?,
      );
}

/// Sistem kategorisi (`GET /kategoriler`).
class Category {
  final int id;
  final String name;
  final String slug;
  final int mekanSayisi;
  const Category({
    required this.id,
    required this.name,
    this.slug = '',
    this.mekanSayisi = 0,
  });

  factory Category.fromJson(Map<String, dynamic> j) => Category(
        id: (j['id'] as num?)?.toInt() ?? 0,
        name: (j['name'] as String?)?.trim().isNotEmpty == true
            ? j['name'] as String
            : 'Kategori',
        slug: j['slug'] as String? ?? '',
        mekanSayisi: (j['mekan_sayisi'] as num?)?.toInt() ?? 0,
      );
}

class QuickCategory {
  final String label;
  final IconData icon;
  const QuickCategory(this.label, this.icon);
}

class NotificationItem {
  final String title;
  final String body;
  final String time;
  final String group; // "Bugün", "Bu Hafta", "Daha Önce"
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  bool unread;

  NotificationItem({
    required this.title,
    required this.body,
    required this.time,
    required this.group,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    this.unread = true,
  });
}

/// Uygulama bildirimi (`GET /bildirimler`). Metin HTML'den arındırılır,
/// tarih parse edilir; okundu durumu yerelde tutulur.
class AppNotification {
  final int id;
  final String text;
  final DateTime? date;
  bool unread;

  AppNotification({
    required this.id,
    required this.text,
    this.date,
    this.unread = true,
  });
}

class Amenity {
  final String name;
  final IconData icon;
  final bool available;
  const Amenity(this.name, this.icon, this.available);
}

class InfoRow {
  final String title;
  final String value;
  final IconData icon;
  const InfoRow(this.title, this.value, this.icon);
}

/// Uygulama üyesi (`app_uyeler`). Parolasız `/uye/giris` yanıtındaki `uye`
/// objesinden üretilir; oturum sırasında yerelde saklanır (bkz. AuthService,
/// UYE_LOGIN.md). Şehir her zaman 34 (İstanbul); ilçe `ilceler.id`'yi referanslar.
class AppUser {
  final int id;
  final String isim;
  final String soyisim;
  final String email;
  final String telefon;
  final String ulkeKodu; // "+90"
  final String cinsiyet; // erkek | kadin | diger | ''
  final String dogumGunu; // "1990-05-12" | ''
  final int sehir; // her zaman 34
  final int? ilceId; // ilceler.id
  final String ilce; // çözülmüş ilçe adı (yanıttan)

  const AppUser({
    required this.id,
    this.isim = '',
    this.soyisim = '',
    this.email = '',
    this.telefon = '',
    this.ulkeKodu = '+90',
    this.cinsiyet = '',
    this.dogumGunu = '',
    this.sehir = 34,
    this.ilceId,
    this.ilce = '',
  });

  /// "Ad Soyad" (ikisi de boşsa boş string döner).
  String get fullName =>
      [isim, soyisim].where((s) => s.trim().isNotEmpty).join(' ').trim();

  factory AppUser.fromJson(Map<String, dynamic> j) {
    final uk = (j['ulke_kodu'] as String?)?.trim();
    return AppUser(
      id: (j['id'] as num?)?.toInt() ?? 0,
      isim: (j['isim'] as String?)?.trim() ?? '',
      soyisim: (j['soyisim'] as String?)?.trim() ?? '',
      email: (j['email'] as String?)?.trim() ?? '',
      telefon: (j['telefon'] as String?)?.trim() ?? '',
      ulkeKodu: (uk != null && uk.isNotEmpty) ? uk : '+90',
      cinsiyet: (j['cinsiyet'] as String?)?.trim() ?? '',
      dogumGunu: (j['dogum_gunu'] as String?)?.trim() ?? '',
      sehir: (j['sehir'] as num?)?.toInt() ?? 34,
      ilceId: (j['ilce_id'] as num?)?.toInt(),
      ilce: (j['ilce'] as String?)?.trim() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'isim': isim,
        'soyisim': soyisim,
        'email': email,
        'telefon': telefon,
        'ulke_kodu': ulkeKodu,
        'cinsiyet': cinsiyet,
        'dogum_gunu': dogumGunu,
        'sehir': sehir,
        'ilce_id': ilceId,
        'ilce': ilce,
      };

  AppUser copyWith({
    String? isim,
    String? soyisim,
    String? email,
    String? telefon,
    String? ulkeKodu,
    String? cinsiyet,
    String? dogumGunu,
    int? ilceId,
    String? ilce,
  }) =>
      AppUser(
        id: id,
        isim: isim ?? this.isim,
        soyisim: soyisim ?? this.soyisim,
        email: email ?? this.email,
        telefon: telefon ?? this.telefon,
        ulkeKodu: ulkeKodu ?? this.ulkeKodu,
        cinsiyet: cinsiyet ?? this.cinsiyet,
        dogumGunu: dogumGunu ?? this.dogumGunu,
        sehir: sehir,
        ilceId: ilceId ?? this.ilceId,
        ilce: ilce ?? this.ilce,
      );
}

/// İlçe (`GET /ilceler`). Üye formundaki ilçe seçimi için kullanılır
/// (UYE_LOGIN.md — hepsi İstanbul ilçesidir).
class Ilce {
  final int id;
  final String ad;
  const Ilce({required this.id, required this.ad});

  factory Ilce.fromJson(Map<String, dynamic> j) {
    final ad = (j['ilce_ad'] ?? j['ad'] ?? j['name'] ?? j['ilce'] ?? '')
        .toString()
        .trim();
    return Ilce(id: (j['id'] as num?)?.toInt() ?? 0, ad: ad);
  }
}

/// Mekan detayı (`GET /mekanlar/{id}`, MEKAN_DETAY.md). Liste özet alanlarına
/// ek olarak adres, çalışma saatleri, özellikler, galeri ve QR menüsünü taşır.
class PlaceDetail {
  final int id;
  final String type; // restoran | plaj | mesire
  final String name;
  final String description;
  final String image; // öne çıkan görsel (tam URL) — yoksa ''
  final String telefon;
  final String email;
  final String adres;
  final String sehir;
  final String ilce;
  final double? lat;
  final double? lng;
  final int goruntulenme;
  final int tiklama;
  final bool qrSistemi;
  final Map<String, String> calismaSaatleri; // gün → "18:00–01:00"
  final List<Category> kategoriler; // çözülmüş kategoriler {id, name, slug}
  final List<OzellikItem> ozellikler; // nitelik/ortam etiketleri (type='ozellik')
  final List<Filter> filtreler; // mekanda aktif filtreler (type='filtre')
  final List<GaleriItem> galeri;
  final List<MenuKategori> menu;

  const PlaceDetail({
    required this.id,
    this.type = '',
    this.name = '',
    this.description = '',
    this.image = '',
    this.telefon = '',
    this.email = '',
    this.adres = '',
    this.sehir = '',
    this.ilce = '',
    this.lat,
    this.lng,
    this.goruntulenme = 0,
    this.tiklama = 0,
    this.qrSistemi = false,
    this.calismaSaatleri = const {},
    this.kategoriler = const [],
    this.ozellikler = const [],
    this.filtreler = const [],
    this.galeri = const [],
    this.menu = const [],
  });

  bool get hasCoord => lat != null && lng != null;

  /// "İl · İlçe" (yalnızca dolu olanlar).
  String get cityDistrict =>
      [sehir, ilce].where((s) => s.trim().isNotEmpty).join(' · ');

  factory PlaceDetail.fromJson(Map<String, dynamic> j, {String host = ''}) {
    // Koordinat: enlem/boylam alanları (varsa), yoksa "kordinat" metni.
    double? lat = (j['enlem'] as num?)?.toDouble();
    double? lng = (j['boylam'] as num?)?.toDouble();
    if (lat == null || lng == null) {
      final raw = j['kordinat'];
      if (raw is String && raw.contains(',')) {
        final parts = raw.split(',');
        if (parts.length == 2) {
          lat = double.tryParse(parts[0].trim());
          lng = double.tryParse(parts[1].trim());
        }
      }
    }
    if (lat != null && (lat < -90 || lat > 90)) lat = null;
    if (lng != null && (lng < -180 || lng > 180)) lng = null;
    if (lat == null || lng == null) {
      lat = null;
      lng = null;
    }

    String image = _absUrl(j['image'], host);
    if (image.isEmpty) image = _absUrl(j['thumbnail'], host);

    final cs = <String, String>{};
    final rawCs = j['calisma_saatleri'];
    if (rawCs is Map) {
      rawCs.forEach((k, v) {
        if (v is String && v.trim().isNotEmpty) cs[k.toString()] = v.trim();
      });
    }

    List<T> parseList<T>(dynamic v, T Function(Map<String, dynamic>) f) =>
        (v is List)
            ? v.whereType<Map<String, dynamic>>().map(f).toList()
            : <T>[];

    return PlaceDetail(
      id: (j['id'] as num?)?.toInt() ?? 0,
      type: (j['type'] as String?)?.trim() ?? '',
      name: (j['name'] as String?)?.trim() ?? '',
      description: (j['description'] as String?)?.trim() ?? '',
      image: image,
      telefon: (j['telefon'] as String?)?.trim() ?? '',
      email: (j['email'] as String?)?.trim() ?? '',
      adres: (j['adres'] as String?)?.trim() ?? '',
      sehir: (j['sehir'] as String?)?.trim() ?? '',
      ilce: (j['ilce'] as String?)?.trim() ?? '',
      lat: lat,
      lng: lng,
      goruntulenme: (j['goruntulenme'] as num?)?.toInt() ?? 0,
      tiklama: (j['tiklama'] as num?)?.toInt() ?? 0,
      qrSistemi: j['qr_sistemi'] == true,
      calismaSaatleri: cs,
      kategoriler: parseList(j['kategoriler'], Category.fromJson),
      ozellikler: parseList(j['ozellikler'], OzellikItem.fromJson),
      filtreler: parseList(j['filtreler'], Filter.fromJson),
      galeri: parseList(j['galeri'], (m) => GaleriItem.fromJson(m, host: host)),
      menu: parseList(j['menu'], MenuKategori.fromJson),
    );
  }
}

/// Mekan özelliği (`ozellikler[]`).
class OzellikItem {
  final int id;
  final String name;
  final String slug;
  const OzellikItem({required this.id, this.name = '', this.slug = ''});
  factory OzellikItem.fromJson(Map<String, dynamic> j) => OzellikItem(
        id: (j['id'] as num?)?.toInt() ?? 0,
        name: (j['name'] as String?)?.trim() ?? '',
        slug: (j['slug'] as String?)?.trim() ?? '',
      );
}

/// Galeri görseli (`galeri[]`).
class GaleriItem {
  final int id;
  final String url;
  final String thumbnail;
  final bool isFeatured;
  const GaleriItem({
    required this.id,
    this.url = '',
    this.thumbnail = '',
    this.isFeatured = false,
  });
  factory GaleriItem.fromJson(Map<String, dynamic> j, {String host = ''}) {
    final url = _absUrl(j['url'], host);
    final thumb = _absUrl(j['thumbnail'], host);
    return GaleriItem(
      id: (j['id'] as num?)?.toInt() ?? 0,
      url: url.isNotEmpty ? url : thumb,
      thumbnail: thumb.isNotEmpty ? thumb : url,
      isFeatured: j['is_featured'] == true,
    );
  }
}

/// QR menü kategorisi (`menu[]`).
class MenuKategori {
  final int? id;
  final String kategori;
  final List<MenuUrun> urunler;
  const MenuKategori({this.id, this.kategori = '', this.urunler = const []});
  factory MenuKategori.fromJson(Map<String, dynamic> j) => MenuKategori(
        id: (j['id'] as num?)?.toInt(),
        kategori: (j['kategori'] as String?)?.trim() ?? '',
        urunler: (j['urunler'] is List)
            ? (j['urunler'] as List)
                .whereType<Map<String, dynamic>>()
                .map(MenuUrun.fromJson)
                .toList()
            : const <MenuUrun>[],
      );
}

/// QR menü ürünü (`menu[].urunler[]`).
class MenuUrun {
  final int id;
  final String ad;
  final String aciklama;
  final String fiyat; // ör. "650" (para birimi uygulanmaz)
  final String gorsel; // tam URL (yoksa '')
  final int? kalori;
  final String icindekiler;
  const MenuUrun({
    required this.id,
    this.ad = '',
    this.aciklama = '',
    this.fiyat = '',
    this.gorsel = '',
    this.kalori,
    this.icindekiler = '',
  });
  factory MenuUrun.fromJson(Map<String, dynamic> j) {
    final g = j['gorsel'];
    return MenuUrun(
      id: (j['id'] as num?)?.toInt() ?? 0,
      ad: (j['ad'] as String?)?.trim() ?? '',
      aciklama: (j['aciklama'] as String?)?.trim() ?? '',
      fiyat: j['fiyat']?.toString().trim() ?? '',
      gorsel: (g is String && g.startsWith('http')) ? g : '',
      kalori: (j['kalori'] as num?)?.toInt(),
      icindekiler: (j['icindekiler'] as String?)?.trim() ?? '',
    );
  }
}

/// Göreli URL'i sunucu köküyle tamamlar (zaten `http` ile başlıyorsa dokunmaz).
String _absUrl(dynamic v, String host) {
  if (v is! String || v.isEmpty) return '';
  return v.startsWith('http') ? v : '$host$v';
}
