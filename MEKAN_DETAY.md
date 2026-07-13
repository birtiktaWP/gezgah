# Mekan Detayı (Get Item)

Bir mekanın (restoran / plaj / mesire) **detay sayfası** için tek kayıt döndüren
endpoint. Liste endpoint'lerindeki özet alanların tamamına ek olarak detaya özel
alanları (adres, e-posta, çalışma saatleri, özellikler, galeri, sayaçlar...) verir.

> Base URL: `https://api.gezgah.com/rest`

## Endpoint

| Method | Yol | Açıklama |
|--------|-----|----------|
| GET | `/mekanlar/{id}` | Tek mekanın tüm detayını döner |

- `{id}`: `yzd_posts.id`. Kayıt `restoran`, `plaj` veya `mesire` tipinde ve
  `status = 'publish'` olmalıdır; aksi halde **404**.
- Tüm korumalı endpoint'ler gibi erişim token'ı ister:
  `Authorization: Bearer <cihaz_token | uye_token>` (bkz. [GUVENLIK.md](GUVENLIK.md)).

> **Yan etki:** Bu endpoint bir **detay görüntüleme = tıklama** sayılır ve her
> çağrıda ilgili mekanın `tiklama` sayacını **+1** arttırır (bkz. sayaç mantığı
> [PAGINATION_ISLETMELER.md](PAGINATION_ISLETMELER.md)).

## İstek

```bash
curl "https://api.gezgah.com/rest/mekanlar/1597" \
     -H "Authorization: Bearer <token>"
```

## Yanıt (200)

```json
{
  "success": true,
  "data": {
    "id": 1597,
    "type": "restoran",
    "slug": "upperist",
    "name": "Upperist",
    "description": null,
    "thumbnail": "https://gezgah.com/uploads/....jpg",
    "image": "https://gezgah.com/uploads/....jpg",
    "status": "publish",
    "date": "2026-07-09",
    "telefon": "05345753175",
    "bolge": "13",
    "sehir": "Istanbul",
    "ilce": "Beyoğlu",
    "kordinat": "41.03639502, 28.98640833",
    "goruntulenme": 0,
    "kategori_ids": [1101],
    "kategoriler": [
      { "id": 1101, "name": "Bar & Kokteyl", "slug": "bar-kokteyl" }
    ],
    "listeleme": 12,
    "tiklama": 34,
    "adres": "Gümüşsuyu, Osmanlı Sk. No:1, 34437 Beyoğlu/İstanbul",
    "email": "",
    "masa_sayisi": 0,
    "qr_sistemi": false,
    "siparis_sistemi": false,
    "subdomain": "upperist",
    "calisma_saatleri": {
      "pazartesi": "18:00–01:00",
      "sali": "18:00–01:00",
      "carsamba": "18:00–01:00",
      "persembe": "18:00–01:00",
      "cuma": "18:00–01:00",
      "cumartesi": "18:00–01:00",
      "pazar": "18:00–01:00"
    },
    "ozellikler": [
      { "id": 131, "name": "Oyun Kafe", "slug": "oyun-kafe" }
    ],
    "filtreler": [
      { "id": 98, "name": "Otopark", "slug": "otopark", "icon": "<svg ...>...</svg>" },
      { "id": 101, "name": "Wifi", "slug": "wifi", "icon": "<svg ...>...</svg>" }
    ],
    "galeri": [
      {
        "id": 5001,
        "url": "https://gezgah.com/uploads/....jpg",
        "thumbnail": "https://gezgah.com/uploads/....jpg",
        "mime_type": "image/jpeg",
        "is_featured": true
      }
    ],
    "menu": [
      {
        "id": 400,
        "kategori": "Et Yemekleri",
        "urunler": [
          {
            "id": 402,
            "ad": "Çökertme Kebabı",
            "ad_en": "Cökertme Kebab",
            "aciklama": "Dana eti, kibrit patates, yoğurt",
            "aciklama_en": "Matchstick potatoes with yogurt...",
            "fiyat": "650",
            "gorsel": "https://app.gezgah.com/uploads/images/menu/gezgah_xxx.jpg",
            "gorsel_dosya": "gezgah_xxx.jpg",
            "kalori": 200,
            "icindekiler": "Patates, tereyağı, yoğurt, soğan"
          }
        ]
      }
    ]
  },
  "error": null
}
```

## Alanlar

### Özet alanlar (liste ile ortak)

| Alan | Tip | Açıklama |
|------|-----|----------|
| `id` | int | Mekan id (`yzd_posts.id`) |
| `type` | string | `restoran` \| `plaj` \| `mesire` |
| `slug` | string | URL kısaltması |
| `name` | string | Mekan adı |
| `description` | string\|null | Açıklama |
| `thumbnail` / `image` | string\|null | Öne çıkan görsel URL'i (yoksa `null`) |
| `status` | string | Yayın durumu (`publish`) |
| `date` | string | Ekleme tarihi |
| `telefon` | string\|null | GSM (`restoran_gsm`) |
| `bolge` | string\|null | Bölge id'si (`restoran_bolge`/`plaj_bolge`/`mesire_bolge`) |
| `sehir` | string\|null | Bölgeden çözülen şehir (`ilceler`) |
| `ilce` | string\|null | Bölgeden çözülen ilçe (`ilceler`) |
| `kordinat` | string\|null | "enlem, boylam" metni |
| `goruntulenme` | int | `restoran_goruntulenme` metası |
| `kategori_ids` | int[] | Bağlı kategori id'leri (`post_kategori`) |

### Detaya özel alanlar

| Alan | Tip | Kaynak | Açıklama |
|------|-----|--------|----------|
| `listeleme` | int | `isletme_stats` | Listede gösterim sayacı |
| `tiklama` | int | `isletme_stats` | Detay görüntüleme (tıklama) sayacı |
| `adres` | string\|null | `mekan_adres` | Açık adres |
| `email` | string\|null | `restoran_email` | E-posta |
| `masa_sayisi` | int\|null | `masa_sayisi` | Masa sayısı |
| `qr_sistemi` | bool | `qr_sistemi` | QR menü sistemi aktif mi |
| `siparis_sistemi` | bool | `siparis_sistemi` | Sipariş sistemi aktif mi |
| `subdomain` | string\|null | `subdomain` | Mekanın alt alan adı |
| `kategoriler` | object[] | `post_kategori` | Çözülmüş kategoriler: `[{ id, name, slug }]`. `kategori_ids` ile aynı kaynak, isim/slug ile |
| `calisma_saatleri` | object | `*_calisma_saatleri` | Gün → saat aralığı (7 gün) |
| `ozellikler` | object[] | `restoran_ozellik` | Nitelik etiketleri (`type='ozellik'`): `{ id, name, slug }`. Ör. Şömine, Oyun Kafe, Fasıl |
| `filtreler` | object[] | `filtre_{id}` meta | Mekanda **aktif** filtreler (`type='filtre'`): `{ id, name, slug, icon }`. Ör. Otopark, Wifi, Alkol (aşağıya bakın) |
| `galeri` | object[] | `files` | `{ id, url, thumbnail, mime_type, is_featured }` |
| `menu` | object[] | `yzd_qr` | QR menüsü: kategori → ürünler (aşağıya bakın) |

`calisma_saatleri` anahtarları: `pazartesi, sali, carsamba, persembe, cuma,
cumartesi, pazar`. Bir gün tanımsızsa değeri `null` olur.

### Özellikler vs. Filtreler

İki ayrı kavram vardır, ikisi de detayda döner:

- **`ozellikler`**: `restoran_ozellik` metasındaki `type='ozellik'` etiketleri
  (Şömine, Oyun Kafe, Fasıl, Sıra Gecesi...). Ortam/nitelik etiketleridir.
- **`filtreler`**: Filtre butonu sistemi (`type='filtre'`; Otopark, Wifi, Alkol,
  Vale, Rezervasyon...). Bir mekanda hangilerinin **aktif** olduğu mekan
  meta'sında `filtre_{id} = 1` ile tutulur. Detay yalnızca **aktif** (=1)
  filtreleri döner.

### Filtreler (`filtreler`)

Mekanda aktif olan filtreler. Her filtre:

| Alan | Kaynak | Açıklama |
|------|--------|----------|
| `id` | `yzd_posts.id` (`type='filtre'`) | Filtre id'si |
| `name` | `name` | Filtre adı (ör. Otopark, Wifi, Alkol) |
| `slug` | `slug` | URL dostu ad |
| `icon` | `filtre_ikon` meta | SVG ikon (tanımsızsa `null`) |

- Yalnızca `filtre_{id} = 1` olan filtreler listelenir; aktif filtre yoksa `[]`.
- Filtre tanımlarının tam listesi ve `type` grupları için bkz.
  [FILTRELER.md](FILTRELER.md) (`GET /filtreler`). İstemci `id` üzerinden
  eşleştirebilir.

> **Not:** `icon` alanı SVG içerdiğinden yanıtı büyütebilir. İstemci ikonları
> zaten `GET /filtreler`'den aldıysa, detaydaki `id`/`name` ile eşleştirip
> `icon`'u yok sayabilir. İkonların detaydan tamamen çıkarılması istenirse
> `MekanController::resolveFiltreler()`'de `icon` alanı kaldırılabilir.

### QR Menüsü (`menu`)

`menu`, restoranın QR menüsünü **kategori → ürünler** yapısında verir. Kaynak
`yzd_qr` tablosudur (`parent = 0` → kategori, `parent = <kategori id>` → ürün).
Yalnızca aktif (`status = 1`) kayıtlar döner; ürünü olmayan kategoriler atlanır.
Menüsü olmayan mekanlarda (çoğu plaj/mesire) `menu` **boş dizi** (`[]`) olur.

Her kategori:

| Alan | Tip | Açıklama |
|------|-----|----------|
| `id` | int\|null | Kategori id (`yzd_qr.id`). Kategorisi bulunamayan ürünler `null` grubunda toplanır |
| `kategori` | string\|null | Kategori adı |
| `urunler` | object[] | Kategorideki ürünler |

Her ürün (`urunler[]`):

| Alan | Tip | Kaynak | Açıklama |
|------|-----|--------|----------|
| `id` | int | `id` | Ürün id |
| `ad` | string | `name` | Ürün adı (TR) |
| `ad_en` | string\|null | `gb_item_name` | Ürün adı (EN) |
| `aciklama` | string\|null | `description` | Açıklama (TR) |
| `aciklama_en` | string\|null | `gb_item_desc` | Açıklama (EN) |
| `fiyat` | string\|null | `price` | Fiyat (ör. `"650"`); para birimi uygulanmaz |
| `gorsel` | string\|null | `image` | Ürün görseli tam URL'i |
| `gorsel_dosya` | string\|null | `image` | Görsel ham dosya adı |
| `kalori` | int\|null | `kalori` | Kalori (0 ise `null`) |
| `icindekiler` | string\|null | `icindekiler` | İçindekiler (TR) |

> **Görsel URL'i (`gorsel`)**: `image` alanı yalnızca dosya adıdır
> (`gezgah_xxx.jpg`). Tam URL, `QR_MEDIA_BASE_URL` kökü (varsayılan
> `https://app.gezgah.com/uploads/images/menu`) ile birleştirilerek üretilir.
> **Bu kök canlıda doğrulanamadı**; görsel açılmıyorsa `QR_MEDIA_BASE_URL`
> ortam değişkenini düzeltin. `gorsel_dosya` her zaman ham dosya adını verir,
> böylece istemci gerekirse kendi kökünü uygulayabilir.

## Hatalar

| Durum | Sebep |
|-------|-------|
| `404` | Mekan bulunamadı (id yok, yayında değil ya da mekan tipi değil) |
| `401` | Geçerli erişim token'ı yok |

## Notlar

- **Görsel URL'leri**: `thumbnail`/`image`/`galeri` `MEDIA_BASE_URL`
  (`https://gezgah.com/uploads`) kökü ile birleştirilir. Sunucuda küçük (thumb_)
  görseller üretilmediği için `thumbnail` alanı da tam görseli işaret eder.
- **Harita**: `kordinat` "enlem, boylam" metnidir; mobil app `parse` edip harita
  pini/rota için kullanabilir. Ayrıştırılmış enlem/boylam gerekiyorsa `GET /harita`
  ya da `GET /mekanlar/yakindakiler` alanları örnek alınabilir.
- **Menü**: QR menüsü (`yzd_qr`) artık detaya dahildir (`menu` alanı). Menüsü
  büyük restoranlarda yanıt büyüyebilir; istemci menüyü sekme/lazy-load ile
  gösterebilir. QR görsel kökü `QR_MEDIA_BASE_URL` ile yapılandırılır.

## İlgili dokümanlar

- Liste: `GET /mekanlar` — [README.md](README.md)
- Sayaç mantığı: [PAGINATION_ISLETMELER.md](PAGINATION_ISLETMELER.md)
- Güvenlik / token: [GUVENLIK.md](GUVENLIK.md), [CIHAZ_TOKEN.md](CIHAZ_TOKEN.md)
