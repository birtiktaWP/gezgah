# Kategori detay / listeleme

Bir kategori id'sine ait **tüm listeleme verisini** tek istekte döndüren
endpoint:

- Kategori bilgisi (ad, slug, ikon, mekan sayısı)
- İçindeki **restoranlar** (sayfalı)
- Varsa **alt kategoriler** (`parent` ile bağlı)
- Varsa **sabit (pinlenmiş) restoran**

> Base URL: `https://api.gezgah.com/rest`

## Endpoint

| Method | Yol |
|--------|-----|
| GET | `/kategoriler/{id}` |

> İlgili: `/kategoriler/{id}/mekanlar` yalnızca kategori mekanlarının düz
> sayfalı listesini döner. `/kategoriler/{id}` ise kategori + alt kategoriler +
> sabit restoran + mekanları birlikte döndürür.

### Query parametreleri

| Parametre | Tip | Varsayılan | Açıklama |
|-----------|-----|-----------|----------|
| `page` | int | 1 | Restoran listesi sayfası |
| `limit` | int | 20 | Sayfa başına restoran (min 1, max 100) |

`mekanlar` listesi **sayfalıdır** (varsayılan **20/sayfa**). `alt_kategoriler`
ve `sabit_restoran` sayfalamadan etkilenmez; her sayfada aynı döner (istemci
ilk sayfada kullanabilir).

## Nasıl çalışır?

- **Restoranlar:** `type IN (restoran, plaj, mesire)`, `status = 'publish'` ve
  `post_kategori` metası bu kategori id'sini içerenler. `id DESC` sıralı,
  sayfalı.
- **Alt kategoriler:** `type = 'kategori'` ve `parent = {id}` olan kayıtlar.
- **Sabit restoran:** Kategorinin `sabit` metası bir restoran id'si tutar
  (ör. kategori 122 → `sabit = 2`). Bu restoran ayrı alanda döner ve
  **mekan listesinden çıkarılır** (çift gösterimi önlemek için).
- **İkon:** Kategori/alt kategori ikonu `kategori_svg_icon` metasından gelir
  (tanımlı değilse `null`).
- **Şehir/ilçe:** Restoranların bölge id'si (`restoran_bolge`) `ilceler`
  tablosuyla eşleştirilerek `sehir`/`ilce` alanları üretilir.

## Örnek istek

```bash
curl "https://api.gezgah.com/rest/kategoriler/122?page=1&limit=20"
```

## Yanıt formatı

```json
{
  "success": true,
  "data": {
    "kategori": {
      "id": 122,
      "type": "kategori",
      "slug": "restoran",
      "name": "Restoran",
      "thumbnail": null,
      "status": "publish",
      "date": "2025-07-13",
      "icon": null,
      "mekan_sayisi": 175
    },
    "alt_kategoriler": [
      { "id": 1053, "type": "kategori", "slug": "kebap", "name": "Kebap", "icon": null },
      { "id": 1054, "type": "kategori", "slug": "corba", "name": "Çorba", "icon": null }
    ],
    "sabit_restoran": {
      "id": 2,
      "type": "restoran",
      "slug": "gezgah-kafe",
      "name": "Gezgah Kafe",
      "thumbnail": "https://gezgah.com/uploads/....jpg",
      "image": "https://gezgah.com/uploads/....jpg",
      "telefon": "1234567890",
      "bolge": "35",
      "sehir": "Istanbul",
      "ilce": "Şişli",
      "kordinat": "123456"
    },
    "mekanlar": [
      {
        "id": 1592,
        "type": "restoran",
        "slug": "carsi-et-ve-balik",
        "name": "Çarşı Et ve Balık",
        "thumbnail": null,
        "status": "publish",
        "date": "2026-06-20",
        "telefon": "5314694686",
        "bolge": "1",
        "sehir": "Istanbul",
        "ilce": "Adalar",
        "kordinat": "",
        "filtre_ids": [101, 104, 105, 106, 108, 111, 112, 115]
      }
    ]
  },
  "error": null,
  "meta": { "page": 1, "limit": 20, "total": 175, "pages": 9, "has_more": true, "next_page": 2 }
}
```

### `data` alanları

| Alan | Açıklama |
|------|----------|
| `kategori` | Kategori bilgisi (`id, name, slug, icon, mekan_sayisi` ...) |
| `kategori.mekan_sayisi` | Listedeki toplam restoran sayısı (sabit hariç) |
| `alt_kategoriler` | Alt kategoriler dizisi (yoksa `[]`). Öğe: `{ id, name, slug, icon }` |
| `sabit_restoran` | Pinlenmiş restoran (yoksa `null`) |
| `mekanlar` | Kategorideki restoranlar (sayfalı, sabit hariç) |

### `data[].mekanlar[]` / `sabit_restoran` restoran alanları

| Alan | Açıklama |
|------|----------|
| `id` | Restoran id'si |
| `type` | `restoran` \| `plaj` \| `mesire` |
| `slug` / `name` | URL dostu ad / ad |
| `thumbnail` / `image` | Öne çıkan görsel (yoksa `null`) |
| `telefon` | İletişim numarası |
| `bolge` | Bölge id'si |
| `sehir` / `ilce` | Bölge id → `ilceler` çözümü |
| `kordinat` | "enlem, boylam" metni |
| `filtre_ids` | Restoranda **aktif** filtrelerin id'leri (`filtre_{id} = 1`). `/filtreler` listesindeki id'lerle eşleşir. Aktif filtre yoksa `[]`. |

> **Filtre eşleştirme:** `filtre_ids`, `GET /filtreler` endpoint'inden dönen
> filtre id'leriyle birebir eşleşir. Böylece mobil app, restoranın hangi
> filtrelere (Otopark, Wifi, Alkol...) sahip olduğunu isim/ikon ile
> gösterebilir veya seçili filtrelere göre yerel eşleştirme yapabilir.
> Bkz. [FILTRELER.md](FILTRELER.md).

### `meta` alanları

| Alan | Açıklama |
|------|----------|
| `page` / `limit` | Sayfalama (varsayılan 20/sayfa) |
| `total` | Kategorideki restoran sayısı (sabit hariç) |
| `pages` | Toplam sayfa |
| `has_more` | Sonraki sayfa var mı? (`true`/`false`) |
| `next_page` | Sonraki sayfa numarası (yoksa `null`) |

## Hata yanıtı

```json
{ "success": false, "data": null, "error": { "message": "Kategori bulunamadı." } }
```

## Notlar

- Alt kategorisi olmayan kategori → `alt_kategoriler: []`.
- Sabit restoranı olmayan kategori → `sabit_restoran: null`.
- Sabit restoran, `mekanlar` listesinde tekrar **gösterilmez**.
- `sabit` metası ile birlikte `sabitleme_baslangic` / `sabitleme_bitis`
  (pin tarih aralığı) metaları da bulunabilir; bu endpoint şu an tarih
  penceresine bakmadan sabit restoranı döndürür.
