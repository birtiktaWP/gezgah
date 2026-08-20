import 'package:flutter/widgets.dart';

/// Mekan açık/kapanış durumu
enum OpenState { open, closing, closed }

/// Liste/kart görsel boyutları (thumbnail-update.md). Ekranda kapladığı alana
/// göre doğru thumbnail seçilir; yoksa `thumbnail`/`image`'a düşülür.
enum ThumbSize { square, card, wide }

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

  // Önceden üretilmiş thumbnail'ler (thumbnail-update.md). Öne çıkan görseli
  // olmayan mekanlarda null olabilir → `image`'a düşülür.
  final String? thumbnail; // top-level thumbnail (kare, küçük)
  final String? thumbSquare;
  final String? thumbCard;
  final String? thumbWide;

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
    this.thumbnail,
    this.thumbSquare,
    this.thumbCard,
    this.thumbWide,
  });

  /// Ekran alanına göre en uygun görsel URL'i: istenen boyut → `thumbnail` →
  /// asıl `image` (thumbnail-update.md §4 fallback zinciri).
  String thumb(ThumbSize size) {
    final t = switch (size) {
      ThumbSize.square => thumbSquare,
      ThumbSize.card => thumbCard,
      ThumbSize.wide => thumbWide,
    };
    if (t != null && t.isNotEmpty) return t;
    if (thumbnail != null && thumbnail!.isNotEmpty) return thumbnail!;
    return image;
  }
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
  final int id; // ikon eşlemesi için kullanılır (HomeConfig.iconFor)
  final String name;

  /// Post type slug'ı (kategori değil): `otopark` | `muze` | `mesire` | `plaj`.
  /// `/mekanlar?type=<type>` ile listelenir.
  final String type;

  const HomeShortcut(this.id, this.name, {this.type = ''});
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

  factory FeaturedEvent.fromJson(Map<String, dynamic> j) => FeaturedEvent(
        id: (j['id'] as num?)?.toInt() ?? 0,
        name: (j['name'] as String?)?.trim() ?? '',
        date: (j['date'] as String?)?.trim() ?? '',
        time: (j['time'] as String?)?.trim() ?? '',
        image: (j['image'] as String?)?.trim() ?? '',
      );

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'date': date, 'time': time, 'image': image};
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
  final int parent; // 0 = üst düzey kategori; >0 ise bir kategorinin alt öğesi
  final String? icon; // API'den gelen SVG ikon (kategori_svg_icon); yoksa null
  final int? sortOrder; // öne çıkan kategori sırası (küçük = önce); yoksa null
  const Category({
    required this.id,
    required this.name,
    this.slug = '',
    this.mekanSayisi = 0,
    this.parent = 0,
    this.icon,
    this.sortOrder,
  });

  bool get isTopLevel => parent == 0;

  factory Category.fromJson(Map<String, dynamic> j) => Category(
        id: (j['id'] as num?)?.toInt() ?? 0,
        name: (j['name'] as String?)?.trim().isNotEmpty == true
            ? j['name'] as String
            : 'Kategori',
        slug: j['slug'] as String? ?? '',
        mekanSayisi: (j['mekan_sayisi'] as num?)?.toInt() ?? 0,
        parent: (j['parent'] as num?)?.toInt() ?? 0,
        icon: (j['icon'] as String?)?.trim().isNotEmpty == true
            ? (j['icon'] as String).trim()
            : null,
        sortOrder: (j['sort_order'] as num?)?.toInt(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'slug': slug,
        'mekan_sayisi': mekanSayisi,
        'parent': parent,
        'icon': icon,
        'sort_order': sortOrder,
      };
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
  final String avatar; // avatar tam URL (Plus'a özel); yoksa ''
  final PlusInfo plus; // Gezgah Plus durumu

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
    this.avatar = '',
    this.plus = const PlusInfo(),
  });

  bool get isPlus => plus.aktif;

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
      avatar: (j['avatar'] as String?)?.trim() ?? '',
      plus: j['plus'] is Map<String, dynamic>
          ? PlusInfo.fromJson(j['plus'] as Map<String, dynamic>)
          : const PlusInfo(),
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
        'avatar': avatar,
        'plus': plus.toJson(),
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
    String? avatar,
    PlusInfo? plus,
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
        avatar: avatar ?? this.avatar,
        plus: plus ?? this.plus,
      );
}

/// Gezgah Plus durumu (UYELIK_PLUS.md). Üye nesnesinin `plus` alanı.
class PlusInfo {
  final bool aktif;
  final String? bitis; // "2027-08-16 12:00:00" | null

  const PlusInfo({this.aktif = false, this.bitis});

  factory PlusInfo.fromJson(Map<String, dynamic> j) => PlusInfo(
        aktif: j['aktif'] == true,
        bitis: j['bitis'] as String?,
      );

  Map<String, dynamic> toJson() => {'aktif': aktif, 'bitis': bitis};
}

/// Gezgah Plus ürünü (`/uye/plus/durum` → `urun`).
class PlusUrun {
  final String fiyat; // "199.99"
  final String para; // "TRY"
  final String periyot; // "yillik"
  final String iosId; // App Store ürün kimliği
  final String androidId; // Play ürün kimliği

  const PlusUrun({
    this.fiyat = '199.99',
    this.para = 'TRY',
    this.periyot = 'yillik',
    this.iosId = 'plus',
    this.androidId = 'plus',
  });

  factory PlusUrun.fromJson(Map<String, dynamic> j) => PlusUrun(
        fiyat: j['fiyat']?.toString() ?? '199.99',
        para: (j['para'] as String?) ?? 'TRY',
        periyot: (j['periyot'] as String?) ?? 'yillik',
        iosId: (j['ios'] as String?) ?? 'plus',
        androidId: (j['android'] as String?) ?? 'plus',
      );
}

/// Gezgah Plus durumu (`GET /uye/plus/durum`, UYELIK_PLUS.md §4.1).
class PlusDurum {
  final bool aktif;
  final String? bitis;
  final int? kalanGun;
  final String? platform;
  final String? productId;
  final PlusUrun urun;
  final List<String> ozellikler;

  const PlusDurum({
    this.aktif = false,
    this.bitis,
    this.kalanGun,
    this.platform,
    this.productId,
    this.urun = const PlusUrun(),
    this.ozellikler = const ['avatar', 'gezi_rotalari', 'kedy'],
  });

  factory PlusDurum.fromJson(Map<String, dynamic> j) => PlusDurum(
        aktif: j['aktif'] == true,
        bitis: j['bitis'] as String?,
        kalanGun: (j['kalan_gun'] as num?)?.toInt(),
        platform: j['platform'] as String?,
        productId: j['product_id'] as String?,
        urun: j['urun'] is Map<String, dynamic>
            ? PlusUrun.fromJson(j['urun'] as Map<String, dynamic>)
            : const PlusUrun(),
        ozellikler: (j['ozellikler'] as List<dynamic>?)
                ?.whereType<String>()
                .toList() ??
            const ['avatar', 'gezi_rotalari', 'kedy'],
      );
}

/// Gezi rotası (`/uye/rotalar`, UYELIK_PLUS.md §6). Sıralı mekan listesi + her
/// durakta yorum. Liste görünümünde durak sayısıyla, detayda [duraklar] dolu.
class GeziRota {
  final int id;
  final String baslik;
  final String aciklama;
  final String gorunurluk; // 'gizli' | 'herkese_acik'
  final int durakSayisi;
  final String kapakGorsel; // kapak görseli tam URL; yoksa ''
  final RotaSahip? sahip; // keşfet/detay yanıtında rotanın sahibi
  final bool benim; // detayda: rota oturumdaki üyeye mi ait
  final int begeniSayisi; // rotanın toplam beğeni sayısı
  final bool begendim; // isteği yapan üye bu rotayı beğendi mi
  final int goruntulenme; // detay görüntülenme sayısı (rota-istatistik.md)
  final int gosterim; // listede gösterim (impression) sayısı
  final double? rotaFiyat; // seçili ürünlerin fiyat toplamı (yoksa null)
  final int? mesafeM; // ilk durağa mesafe (metre); konum verildiyse
  final bool yorumlarAcik; // rotaya yorum yapılabilir mi (rota-yorumlar.md)
  final int yorumSayisi; // toplam yorum sayısı
  final String haritaLink; // tüm rotayı gezen Google Maps yol tarifi (yoksa '')
  // Uygulama içi harita (rota-app-ici-harita.md): sıralı koordinatlar + yol
  // çizgisi (encoded polyline) + toplam mesafe/süre. Yalnız detayda dolu.
  final List<RotaNokta> koordinatlar;
  final String polyline; // Google encoded polyline (yoksa '')
  final int? toplamMesafeM;
  final int? toplamSureSn;
  final List<RotaDurak> duraklar; // yalnız detay yanıtında dolu

  const GeziRota({
    required this.id,
    this.baslik = '',
    this.aciklama = '',
    this.gorunurluk = 'gizli',
    this.durakSayisi = 0,
    this.kapakGorsel = '',
    this.sahip,
    this.benim = false,
    this.begeniSayisi = 0,
    this.begendim = false,
    this.goruntulenme = 0,
    this.gosterim = 0,
    this.rotaFiyat,
    this.mesafeM,
    this.yorumlarAcik = true,
    this.yorumSayisi = 0,
    this.haritaLink = '',
    this.koordinatlar = const [],
    this.polyline = '',
    this.toplamMesafeM,
    this.toplamSureSn,
    this.duraklar = const [],
  });

  /// Uygulama içi haritada gösterilebilir mi (en az bir koordinat var mı).
  bool get haritadaGosterilebilir => koordinatlar.isNotEmpty;

  bool get herkeseAcik => gorunurluk == 'herkese_acik';

  /// "₺450" — seçili ürünler fiyat toplamı (yoksa '').
  String get fiyatLabel {
    final f = rotaFiyat;
    if (f == null || f <= 0) return '';
    final s = f == f.roundToDouble() ? f.toInt().toString() : f.toStringAsFixed(2);
    return '₺$s';
  }

  /// "3.5 km" / "450 m" — ilk durağa mesafe (yoksa '').
  String get mesafeLabel {
    final m = mesafeM;
    if (m == null) return '';
    return m >= 1000 ? '${(m / 1000).toStringAsFixed(1)} km' : '$m m';
  }

  /// Beğeni sayısı/durumu güncellenmiş kopya (optimistic UI için).
  GeziRota copyWithBegeni({required bool begendim, required int begeniSayisi}) =>
      GeziRota(
        id: id,
        baslik: baslik,
        aciklama: aciklama,
        gorunurluk: gorunurluk,
        durakSayisi: durakSayisi,
        kapakGorsel: kapakGorsel,
        sahip: sahip,
        benim: benim,
        begeniSayisi: begeniSayisi,
        begendim: begendim,
        goruntulenme: goruntulenme,
        gosterim: gosterim,
        rotaFiyat: rotaFiyat,
        mesafeM: mesafeM,
        yorumlarAcik: yorumlarAcik,
        yorumSayisi: yorumSayisi,
        haritaLink: haritaLink,
        koordinatlar: koordinatlar,
        polyline: polyline,
        toplamMesafeM: toplamMesafeM,
        toplamSureSn: toplamSureSn,
        duraklar: duraklar,
      );

  /// Yorum sayısı güncellenmiş kopya (optimistic UI için).
  GeziRota copyWithYorumSayisi(int yorumSayisi) => GeziRota(
        id: id,
        baslik: baslik,
        aciklama: aciklama,
        gorunurluk: gorunurluk,
        durakSayisi: durakSayisi,
        kapakGorsel: kapakGorsel,
        sahip: sahip,
        benim: benim,
        begeniSayisi: begeniSayisi,
        begendim: begendim,
        goruntulenme: goruntulenme,
        gosterim: gosterim,
        rotaFiyat: rotaFiyat,
        mesafeM: mesafeM,
        yorumlarAcik: yorumlarAcik,
        yorumSayisi: yorumSayisi,
        haritaLink: haritaLink,
        koordinatlar: koordinatlar,
        polyline: polyline,
        toplamMesafeM: toplamMesafeM,
        toplamSureSn: toplamSureSn,
        duraklar: duraklar,
      );

  factory GeziRota.fromJson(Map<String, dynamic> j, {String host = ''}) {
    final raw = j['duraklar'] ?? j['mekanlar'];
    final duraklar = (raw is List)
        ? raw
            .whereType<Map<String, dynamic>>()
            .map((m) => RotaDurak.fromJson(m, host: host))
            .toList()
        : <RotaDurak>[];
    return GeziRota(
      id: (j['id'] as num?)?.toInt() ?? 0,
      baslik: (j['baslik'] as String?)?.trim() ?? '',
      aciklama: (j['aciklama'] as String?)?.trim() ?? '',
      gorunurluk: (j['gorunurluk'] as String?)?.trim().isNotEmpty == true
          ? (j['gorunurluk'] as String).trim()
          : 'gizli',
      durakSayisi: (j['durak_sayisi'] as num?)?.toInt() ?? duraklar.length,
      kapakGorsel: _absUrl(j['kapak_gorsel'], host),
      sahip: j['sahip'] is Map<String, dynamic>
          ? RotaSahip.fromJson(j['sahip'] as Map<String, dynamic>, host: host)
          : null,
      benim: j['benim'] == true,
      begeniSayisi: (j['begeni_sayisi'] as num?)?.toInt() ?? 0,
      begendim: j['begendim'] == true,
      goruntulenme: (j['goruntulenme'] as num?)?.toInt() ?? 0,
      gosterim: (j['gosterim'] as num?)?.toInt() ?? 0,
      rotaFiyat: (j['rota_fiyat'] as num?)?.toDouble(),
      mesafeM: (j['mesafe_m'] as num?)?.toInt(),
      yorumlarAcik: j['yorumlar_acik'] == null
          ? true
          : (j['yorumlar_acik'] == true || j['yorumlar_acik'] == 1),
      yorumSayisi: (j['yorum_sayisi'] as num?)?.toInt() ?? 0,
      haritaLink: (j['harita_link'] as String?)?.trim() ?? '',
      koordinatlar: (j['koordinatlar'] is List)
          ? (j['koordinatlar'] as List)
              .whereType<Map<String, dynamic>>()
              .map(RotaNokta.fromJson)
              .where((n) => n.hasCoord)
              .toList()
          : const [],
      polyline: (j['polyline'] as String?)?.trim() ?? '',
      toplamMesafeM: (j['toplam_mesafe_m'] as num?)?.toInt(),
      toplamSureSn: (j['toplam_sure_sn'] as num?)?.toInt(),
      duraklar: duraklar,
    );
  }
}

/// Rota harita noktası (`rota.koordinatlar[]`, rota-app-ici-harita.md §2).
class RotaNokta {
  final int sira;
  final int durakId;
  final int postId;
  final String name;
  final double? lat;
  final double? lng;
  const RotaNokta({
    this.sira = 0,
    this.durakId = 0,
    this.postId = 0,
    this.name = '',
    this.lat,
    this.lng,
  });

  bool get hasCoord => lat != null && lng != null;

  factory RotaNokta.fromJson(Map<String, dynamic> j) => RotaNokta(
        sira: (j['sira'] as num?)?.toInt() ?? 0,
        durakId: (j['durak_id'] as num?)?.toInt() ?? 0,
        postId: (j['post_id'] as num?)?.toInt() ?? 0,
        name: (j['name'] as String?)?.trim() ?? '',
        lat: (j['lat'] as num?)?.toDouble(),
        lng: (j['lng'] as num?)?.toDouble(),
      );
}

/// Rota sahibi özeti (`/rotalar` keşfet + detay `sahip`, SOSYAL_BEGENI_TAKIP.md).
class RotaSahip {
  final int uyeId;
  final String isim;
  final String soyisim;
  final String avatar; // tam URL; yoksa ''
  final bool? takipEdiyorum; // isteği yapan üye takip ediyor mu (kendisi: null)
  const RotaSahip({
    required this.uyeId,
    this.isim = '',
    this.soyisim = '',
    this.avatar = '',
    this.takipEdiyorum,
  });

  String get adSoyad =>
      [isim, soyisim].where((s) => s.trim().isNotEmpty).join(' ').trim();

  factory RotaSahip.fromJson(Map<String, dynamic> j, {String host = ''}) =>
      RotaSahip(
        uyeId: (j['uye_id'] as num?)?.toInt() ?? (j['id'] as num?)?.toInt() ?? 0,
        isim: (j['isim'] as String?)?.trim() ?? '',
        soyisim: (j['soyisim'] as String?)?.trim() ?? '',
        avatar: _absUrl(j['avatar'], host),
        takipEdiyorum:
            j['takip_ediyorum'] is bool ? j['takip_ediyorum'] as bool : null,
      );
}

/// Google Places otomatik tamamlama tahmini (rota-place-arama.md §1).
class PlaceTahmin {
  final String placeId;
  final String ad; // birincil metin (kalın)
  final String altBilgi; // ikincil metin (adres)
  final String aciklama; // tam metin
  const PlaceTahmin({
    required this.placeId,
    this.ad = '',
    this.altBilgi = '',
    this.aciklama = '',
  });

  factory PlaceTahmin.fromJson(Map<String, dynamic> j) => PlaceTahmin(
        placeId: (j['place_id'] as String?)?.trim() ?? '',
        ad: (j['ad'] as String?)?.trim() ?? '',
        altBilgi: (j['alt_bilgi'] as String?)?.trim() ?? '',
        aciklama: (j['aciklama'] as String?)?.trim() ?? '',
      );
}

/// Google Places yer detayı (rota-place-arama.md §2). Konum durağı eklemek için.
class PlaceDetay {
  final String placeId;
  final String ad;
  final String adres;
  final double lat;
  final double lng;
  const PlaceDetay({
    required this.placeId,
    this.ad = '',
    this.adres = '',
    required this.lat,
    required this.lng,
  });

  factory PlaceDetay.fromJson(Map<String, dynamic> j) => PlaceDetay(
        placeId: (j['place_id'] as String?)?.trim() ?? '',
        ad: (j['ad'] as String?)?.trim() ?? '',
        adres: (j['adres'] as String?)?.trim() ?? '',
        lat: (j['lat'] as num?)?.toDouble() ?? 0,
        lng: (j['lng'] as num?)?.toDouble() ?? 0,
      );
}

/// Rota yorumu (`/uye/rotalar/{id}/yorumlar`, rota-yorumlar.md). [silebilir]
/// true ise bu kullanıcı (yorumu yazan veya rota sahibi) yorumu silebilir.
class RotaYorum {
  final int id;
  final String yorum;
  final DateTime? createdAt;
  final RotaSahip uye;
  final bool benim;
  final bool silebilir;
  // Yorum beğeni/beğenmeme (rota-yorum-begeni.md).
  final int begeniSayisi;
  final int begenmemeSayisi;
  final bool begendim;
  final bool begenmedim;
  const RotaYorum({
    required this.id,
    this.yorum = '',
    this.createdAt,
    this.uye = const RotaSahip(uyeId: 0),
    this.benim = false,
    this.silebilir = false,
    this.begeniSayisi = 0,
    this.begenmemeSayisi = 0,
    this.begendim = false,
    this.begenmedim = false,
  });

  RotaYorum copyWith({
    int? begeniSayisi,
    int? begenmemeSayisi,
    bool? begendim,
    bool? begenmedim,
  }) =>
      RotaYorum(
        id: id,
        yorum: yorum,
        createdAt: createdAt,
        uye: uye,
        benim: benim,
        silebilir: silebilir,
        begeniSayisi: begeniSayisi ?? this.begeniSayisi,
        begenmemeSayisi: begenmemeSayisi ?? this.begenmemeSayisi,
        begendim: begendim ?? this.begendim,
        begenmedim: begenmedim ?? this.begenmedim,
      );

  factory RotaYorum.fromJson(Map<String, dynamic> j, {String host = ''}) {
    final u = j['uye'];
    return RotaYorum(
      id: (j['id'] as num?)?.toInt() ?? 0,
      yorum: (j['yorum'] as String?)?.trim() ?? '',
      createdAt: DateTime.tryParse((j['created_at'] as String?) ?? ''),
      uye: u is Map<String, dynamic>
          ? RotaSahip.fromJson(u, host: host)
          : const RotaSahip(uyeId: 0),
      benim: j['benim'] == true,
      silebilir: j['silebilir_mi'] == true,
      begeniSayisi: (j['begeni_sayisi'] as num?)?.toInt() ?? 0,
      begenmemeSayisi: (j['begenmeme_sayisi'] as num?)?.toInt() ?? 0,
      begendim: j['begendim'] == true,
      begenmedim: j['begenmedim'] == true,
    );
  }
}

/// Yorum tepki (beğeni/beğenmeme) işlemi yanıtı (rota-yorum-begeni.md).
class YorumTepki {
  final bool begendim;
  final bool begenmedim;
  final int begeniSayisi;
  final int begenmemeSayisi;
  const YorumTepki({
    this.begendim = false,
    this.begenmedim = false,
    this.begeniSayisi = 0,
    this.begenmemeSayisi = 0,
  });

  factory YorumTepki.fromData(dynamic data) {
    final d = data is Map ? data : const {};
    return YorumTepki(
      begendim: d['begendim'] == true,
      begenmedim: d['begenmedim'] == true,
      begeniSayisi: (d['begeni_sayisi'] as num?)?.toInt() ?? 0,
      begenmemeSayisi: (d['begenmeme_sayisi'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Takip listesi öğesi (`/uye/takip/edenler|edilenler`, SOSYAL_BEGENI_TAKIP.md).
class TakipUye {
  final int uyeId;
  final String isim;
  final String soyisim;
  final String avatar;
  final bool? takipEdiyorum; // isteği yapan üye bu kişiyi takip ediyor mu
  const TakipUye({
    required this.uyeId,
    this.isim = '',
    this.soyisim = '',
    this.avatar = '',
    this.takipEdiyorum,
  });

  String get adSoyad =>
      [isim, soyisim].where((s) => s.trim().isNotEmpty).join(' ').trim();

  TakipUye copyWith({bool? takipEdiyorum}) => TakipUye(
        uyeId: uyeId,
        isim: isim,
        soyisim: soyisim,
        avatar: avatar,
        takipEdiyorum: takipEdiyorum ?? this.takipEdiyorum,
      );

  factory TakipUye.fromJson(Map<String, dynamic> j, {String host = ''}) =>
      TakipUye(
        uyeId: (j['uye_id'] as num?)?.toInt() ?? (j['id'] as num?)?.toInt() ?? 0,
        isim: (j['isim'] as String?)?.trim() ?? '',
        soyisim: (j['soyisim'] as String?)?.trim() ?? '',
        avatar: _absUrl(j['avatar'], host),
        takipEdiyorum:
            j['takip_ediyorum'] is bool ? j['takip_ediyorum'] as bool : null,
      );
}

/// Rota durağı (`/uye/rotalar/{id}` → `duraklar[]`). Silinmiş mekan
/// [silinmis]=true ve [mekan]=null olur. [seciliUrun] durağa bağlı QR menü
/// ürünü (PROFIL_VE_ROTA_URUN.md §1); yoksa null.
class RotaDurak {
  final int durakId;
  final int sira;
  final String yorum;
  final String tip; // 'mekan' | 'konum' (rota-konum-durak.md)
  final RotaMekan? mekan;
  final bool silinmis;
  final RotaUrun? seciliUrun; // geriye dönük uyumluluk (urunler[0])
  final List<RotaUrun> urunler; // durağa bağlı tüm QR menü ürünleri
  final List<DurakGorsel> gorseller; // durağa yüklenen fotoğraflar (sıralı)
  final String haritaLink; // durağı haritada açan Google Maps linki (yoksa '')

  const RotaDurak({
    required this.durakId,
    this.sira = 0,
    this.yorum = '',
    this.tip = 'mekan',
    this.mekan,
    this.silinmis = false,
    this.seciliUrun,
    this.urunler = const [],
    this.gorseller = const [],
    this.haritaLink = '',
  });

  /// Serbest konum durağı mı (kayıtlı işletme değil).
  bool get isKonum => tip == 'konum';

  factory RotaDurak.fromJson(Map<String, dynamic> j, {String host = ''}) {
    final m = j['mekan'];
    final silinmis =
        j['silinmis'] == true || (m is Map && m['silinmis'] == true);
    final secili = j['secili_urun'] is Map<String, dynamic>
        ? RotaUrun.fromJson(j['secili_urun'] as Map<String, dynamic>, host: host)
        : null;
    // Çoklu ürün: `urunler[]` (rota-coklu-yemek.md); yoksa secili_urun'a düş.
    final urunler = (j['urunler'] is List)
        ? (j['urunler'] as List)
            .whereType<Map<String, dynamic>>()
            .map((u) => RotaUrun.fromJson(u, host: host))
            .where((u) => u.qrId > 0)
            .toList()
        : (secili != null ? [secili] : <RotaUrun>[]);
    return RotaDurak(
      durakId:
          (j['durak_id'] as num?)?.toInt() ?? (j['id'] as num?)?.toInt() ?? 0,
      sira: (j['sira'] as num?)?.toInt() ?? 0,
      yorum: (j['yorum'] as String?)?.trim() ?? '',
      tip: (j['tip'] as String?)?.trim() == 'konum' ? 'konum' : 'mekan',
      mekan: (m is Map<String, dynamic> && !silinmis)
          ? RotaMekan.fromJson(m, host: host)
          : null,
      silinmis: silinmis,
      seciliUrun: secili ?? (urunler.isNotEmpty ? urunler.first : null),
      urunler: urunler,
      gorseller: (j['gorseller'] is List)
          ? (j['gorseller'] as List)
              .whereType<Map<String, dynamic>>()
              .map((g) => DurakGorsel.fromJson(g, host: host))
              .where((g) => g.url.isNotEmpty)
              .toList()
          : const [],
      haritaLink: (j['harita_link'] as String?)?.trim() ?? '',
    );
  }
}

/// Durağa yüklenen fotoğraf (`duraklar[].gorseller[]`, rota-durak-gorsel.md).
class DurakGorsel {
  final int id;
  final String url;
  const DurakGorsel({required this.id, this.url = ''});

  factory DurakGorsel.fromJson(Map<String, dynamic> j, {String host = ''}) =>
      DurakGorsel(
        id: (j['id'] as num?)?.toInt() ?? 0,
        url: _absUrl(j['url'], host),
      );
}

/// Rota durağına bağlanabilen QR menü ürünü (PROFIL_VE_ROTA_URUN.md §1).
/// [gorsel] QR menü `img.php` proxy tam URL'idir. [foto] kullanıcının bu rota
/// için yüklediği ürün fotoğrafı (rota-yemek-gorsel.md, ürün başına tek); yoksa ''.
class RotaUrun {
  final int qrId;
  final String ad;
  final String fiyat; // ham metin
  final String gorsel; // menüdeki hazır görsel; tam URL; yoksa ''
  final String foto; // kullanıcının yüklediği ürün fotoğrafı; tam URL; yoksa ''
  const RotaUrun({
    required this.qrId,
    this.ad = '',
    this.fiyat = '',
    this.gorsel = '',
    this.foto = '',
  });

  /// "350 ₺" / fiyat yoksa ''.
  String get fiyatLabel => fiyat.trim().isEmpty ? '' : '$fiyat ₺';

  RotaUrun copyWith({String? foto}) => RotaUrun(
        qrId: qrId,
        ad: ad,
        fiyat: fiyat,
        gorsel: gorsel,
        foto: foto ?? this.foto,
      );

  factory RotaUrun.fromJson(Map<String, dynamic> j, {String host = ''}) =>
      RotaUrun(
        qrId: (j['qr_id'] as num?)?.toInt() ?? 0,
        ad: (j['ad'] as String?)?.trim() ?? '',
        fiyat: j['fiyat']?.toString().trim() ?? '',
        gorsel: (j['gorsel'] as String?)?.trim() ?? '',
        foto: _absUrl(j['foto'], host),
      );
}

/// Mekan QR menüsü kategorisi (ürün seçici, `/uye/rotalar/mekan-menu`).
class MekanMenuKategori {
  final int kategoriId;
  final String kategori;
  final List<RotaUrun> urunler;
  const MekanMenuKategori({
    this.kategoriId = 0,
    this.kategori = '',
    this.urunler = const [],
  });

  factory MekanMenuKategori.fromJson(Map<String, dynamic> j) =>
      MekanMenuKategori(
        kategoriId: (j['kategori_id'] as num?)?.toInt() ?? 0,
        kategori: (j['kategori'] as String?)?.trim() ?? '',
        urunler: (j['urunler'] is List)
            ? (j['urunler'] as List)
                .whereType<Map<String, dynamic>>()
                .map(RotaUrun.fromJson)
                .where((u) => u.qrId > 0)
                .toList()
            : const <RotaUrun>[],
      );
}

/// Üye herkese açık profili (`GET /uye/profil/{id}`, PROFIL_VE_ROTA_URUN.md §2).
class UyeProfil {
  final int uyeId;
  final String isim;
  final String soyisim;
  final String avatar;
  final int rotaSayisi;
  final int takipciSayisi;
  final int takipEdilenSayisi;
  final int toplamBegeni;
  final bool? takipEdiyorum; // kendi/anonim → null
  final bool benim;

  const UyeProfil({
    required this.uyeId,
    this.isim = '',
    this.soyisim = '',
    this.avatar = '',
    this.rotaSayisi = 0,
    this.takipciSayisi = 0,
    this.takipEdilenSayisi = 0,
    this.toplamBegeni = 0,
    this.takipEdiyorum,
    this.benim = false,
  });

  String get adSoyad {
    final n = [isim, soyisim].where((s) => s.trim().isNotEmpty).join(' ').trim();
    return n.isEmpty ? 'Üye' : n;
  }

  UyeProfil copyWith({bool? takipEdiyorum, int? takipciSayisi}) => UyeProfil(
        uyeId: uyeId,
        isim: isim,
        soyisim: soyisim,
        avatar: avatar,
        rotaSayisi: rotaSayisi,
        takipciSayisi: takipciSayisi ?? this.takipciSayisi,
        takipEdilenSayisi: takipEdilenSayisi,
        toplamBegeni: toplamBegeni,
        takipEdiyorum: takipEdiyorum ?? this.takipEdiyorum,
        benim: benim,
      );

  factory UyeProfil.fromJson(Map<String, dynamic> j, {String host = ''}) =>
      UyeProfil(
        uyeId: (j['uye_id'] as num?)?.toInt() ?? 0,
        isim: (j['isim'] as String?)?.trim() ?? '',
        soyisim: (j['soyisim'] as String?)?.trim() ?? '',
        avatar: _absUrl(j['avatar'], host),
        rotaSayisi: (j['rota_sayisi'] as num?)?.toInt() ?? 0,
        takipciSayisi: (j['takipci_sayisi'] as num?)?.toInt() ?? 0,
        takipEdilenSayisi: (j['takip_edilen_sayisi'] as num?)?.toInt() ?? 0,
        toplamBegeni: (j['toplam_begeni'] as num?)?.toInt() ?? 0,
        takipEdiyorum:
            j['takip_ediyorum'] is bool ? j['takip_ediyorum'] as bool : null,
        benim: j['benim'] == true,
      );
}

/// Rota durağındaki mekan/konum özeti (`duraklar[].mekan`). Konum durağında
/// (rota-konum-durak.md) `id`=0 olur, [adres] dolu olabilir; mekan durağında
/// kayıtlı işletme bilgisidir.
class RotaMekan {
  final int id;
  final String name;
  final String image;
  final String sehir;
  final String ilce;
  final String adres; // konum durağında serbest adres metni
  final double? lat;
  final double? lng;
  const RotaMekan({
    required this.id,
    this.name = '',
    this.image = '',
    this.sehir = '',
    this.ilce = '',
    this.adres = '',
    this.lat,
    this.lng,
  });

  bool get hasCoord => lat != null && lng != null;

  String get cityDistrict {
    final byRegion = [sehir, ilce].where((s) => s.trim().isNotEmpty).join(' · ');
    return byRegion.isNotEmpty ? byRegion : adres;
  }

  factory RotaMekan.fromJson(Map<String, dynamic> j, {String host = ''}) {
    String img = _absUrl(j['thumbnail'], host);
    if (img.isEmpty) img = _absUrl(j['image'], host);
    return RotaMekan(
      id: (j['id'] as num?)?.toInt() ?? (j['post_id'] as num?)?.toInt() ?? 0,
      name: (j['name'] as String?)?.trim().isNotEmpty == true
          ? (j['name'] as String).trim()
          : (j['ad'] as String?)?.trim().isNotEmpty == true
              ? (j['ad'] as String).trim()
              : (j['konum_adi'] as String?)?.trim().isNotEmpty == true
                  ? (j['konum_adi'] as String).trim()
                  : (j['baslik'] as String?)?.trim() ?? '',
      image: img,
      sehir: (j['sehir'] as String?)?.trim() ?? '',
      ilce: (j['ilce'] as String?)?.trim() ?? '',
      adres: (j['adres'] as String?)?.trim() ?? '',
      lat: (j['lat'] as num?)?.toDouble(),
      lng: (j['lng'] as num?)?.toDouble(),
    );
  }
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
  final List<Etkinlik> etkinlikler; // mekana ait aktif etkinlikler

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
    this.etkinlikler = const [],
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
      etkinlikler:
          parseList(j['etkinlikler'], (m) => Etkinlik.fromJson(m, host: host)),
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

/// Rezervasyon bölgesi (`/rezervasyon/secenekler` → `bolgeler[]`).
class RezervasyonBolge {
  final int id;
  final String isim;
  const RezervasyonBolge({required this.id, this.isim = ''});

  factory RezervasyonBolge.fromJson(Map<String, dynamic> j) => RezervasyonBolge(
        id: (j['id'] as num?)?.toInt() ?? 0,
        isim: (j['isim'] ?? j['ad'] ?? '').toString().trim(),
      );
}

/// Rezervasyon seçenekleri (`GET /rezervasyon/secenekler`, rezervasyon-api.md).
/// [aktif] false ise işletme Gezgah Plus değildir → rezervasyon alınmaz.
class RezervasyonSecenekler {
  final int mekanId;
  final bool aktif;
  final bool bolgeZorunlu;
  final List<RezervasyonBolge> bolgeler;

  /// Bölge id → o bölgeye ait masa/oda adları.
  final Map<int, List<String>> masalar;

  /// Gün anahtarı → çalışma saati metni ("09:00 - 23:00" / "Kapalı" / null).
  final Map<String, String?> calismaSaatleri;

  const RezervasyonSecenekler({
    required this.mekanId,
    this.aktif = false,
    this.bolgeZorunlu = false,
    this.bolgeler = const [],
    this.masalar = const {},
    this.calismaSaatleri = const {},
  });

  factory RezervasyonSecenekler.fromJson(Map<String, dynamic> j) {
    final bolgeler = (j['bolgeler'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .map(RezervasyonBolge.fromJson)
            .where((b) => b.id > 0)
            .toList() ??
        const <RezervasyonBolge>[];

    final masalarRaw = j['masalar'];
    final masalar = <int, List<String>>{};
    if (masalarRaw is Map) {
      masalarRaw.forEach((k, v) {
        final id = int.tryParse(k.toString());
        if (id == null) return;
        if (v is List) {
          masalar[id] =
              v.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
        }
      });
    }

    final saatlerRaw = j['calisma_saatleri'];
    final saatler = <String, String?>{};
    if (saatlerRaw is Map) {
      saatlerRaw.forEach((k, v) {
        saatler[k.toString()] = v?.toString();
      });
    }

    return RezervasyonSecenekler(
      mekanId: (j['mekan_id'] as num?)?.toInt() ?? 0,
      aktif: j['rezervasyon_aktif'] == true,
      bolgeZorunlu: j['bolge_zorunlu'] == true,
      bolgeler: bolgeler,
      masalar: masalar,
      calismaSaatleri: saatler,
    );
  }
}

/// Arama "Yemekler" sekmesi sonucu (`GET /arama?tab=yemek`, arama-yeni-3.md).
/// Menüde eşleşen ürün + ait olduğu mekanın kompakt özeti.
class FoodResult {
  final int urunId;
  final String urun;
  final String fiyat; // ham metin ("550"); boşsa ''
  final String gorsel; // ürün görseli tam URL; yoksa ''
  final int begeni; // like_count
  final Place mekan; // ürünün ait olduğu mekan (id/ad/görsel/konum)
  final int? mesafeM; // konum verildiyse mekanın mesafesi (metre)

  const FoodResult({
    required this.urunId,
    this.urun = '',
    this.fiyat = '',
    this.gorsel = '',
    this.begeni = 0,
    required this.mekan,
    this.mesafeM,
  });
}

/// Mekana ait aktif etkinlik (`/mekanlar/{id}` → `etkinlikler[]` ve
/// `/etkinlikler/{id}`, mekan-detay-etkinlik.md).
class Etkinlik {
  final int id;
  final String name;
  final String description;
  final String price; // ham metin; boş = ücretsiz/yok
  final String date; // "YYYY-MM-DD"
  final String time; // "HH:MM" (boş olabilir)
  final String image; // tam URL; boş = yok

  const Etkinlik({
    required this.id,
    this.name = '',
    this.description = '',
    this.price = '',
    this.date = '',
    this.time = '',
    this.image = '',
  });

  static const List<String> _ay = [
    '', 'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz', //
    'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara',
  ];

  /// "20 Eyl 2026 · 21:00" (saat yoksa yalnız tarih).
  String get tarihSaat {
    final d = DateTime.tryParse(date);
    if (d == null) {
      return [date, time].where((s) => s.isNotEmpty).join(' · ');
    }
    final m = (d.month >= 1 && d.month <= 12) ? _ay[d.month] : '';
    final ds = '${d.day} $m ${d.year}';
    return time.isNotEmpty ? '$ds · $time' : ds;
  }

  /// "20 Eyl" (kart rozeti için kısa tarih).
  String get kisaTarih {
    final d = DateTime.tryParse(date);
    if (d == null) return date;
    final m = (d.month >= 1 && d.month <= 12) ? _ay[d.month] : '';
    return '${d.day} $m';
  }

  /// "150 ₺" / boşsa "Ücretsiz".
  String get fiyatLabel => price.trim().isEmpty ? 'Ücretsiz' : '$price ₺';

  factory Etkinlik.fromJson(Map<String, dynamic> j, {String host = ''}) => Etkinlik(
        id: (j['id'] as num?)?.toInt() ?? 0,
        name: (j['name'] as String?)?.trim() ?? '',
        description: (j['description'] as String?)?.trim() ?? '',
        price: j['price']?.toString().trim() ?? '',
        date: (j['date'] as String?)?.trim() ?? '',
        time: (j['time'] as String?)?.trim() ?? '',
        image: _absUrl(j['image'], host),
      );
}

/// Kedy sohbet mesajı (`/kedy/gecmis` ve yerel geçmiş için). [role] "user"
/// veya "assistant"; [content] mesaj metni (app-kedy.md).
class KedyMessage {
  final String role;
  final String content;
  const KedyMessage({required this.role, this.content = ''});

  bool get isUser => role == 'user';

  factory KedyMessage.fromJson(Map<String, dynamic> j) => KedyMessage(
        role: (j['role'] ?? '').toString().trim(),
        content: (j['content'] ?? '').toString(),
      );

  Map<String, String> toJson() => {'role': role, 'content': content};
}
