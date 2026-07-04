# arama (Search)

Restoranları **iki kaynak** üzerinden arayan endpoint:

1. **Restoran adı** — `yzd_posts.name` (`type = 'restoran'`)
2. **Yemek / menü adı** — `yzd_qr` tablosundaki ürün adları (`name`, `gb_item_name`)

Her iki alanda da `LIKE '%q%'` (kısmi eşleşme) kullanılır. Sonuçta, adı veya
menüsündeki bir ürün arama terimiyle eşleşen restoranların **tüm bilgisi**
döner (şehir/ilçe, koordinat, telefon, kategori id'leri vb.).

> Base URL: `https://api.gezgah.com/rest`

## Endpoint

| Method | Yol |
|--------|-----|
| GET | `/arama` |

### Query parametreleri

| Parametre | Tip | Varsayılan | Açıklama |
|-----------|-----|-----------|----------|
| `q` | string | — | **Zorunlu.** Arama terimi (en az 2 karakter). |
| `page` | int | 1 | Sayfa numarası |
| `limit` | int | 20 | Sayfa başına kayıt (min 1, max 100) |

Yalnızca `type = 'restoran'` ve `status = 'publish'` olan kayıtlar döner.
Sıralama `id DESC` (en yeni önce).

## Nasıl çalışır?

- Restoran adı `LIKE '%q%'` ise → sonuca eklenir, `eslesme` içinde `"isim"`.
- Menüde (`yzd_qr`, `parent <> 0` yani ürün satırları) `name` veya
  `gb_item_name` `LIKE '%q%'` ise → o ürünün restoranı sonuca eklenir,
  `eslesme` içinde `"menu"` ve eşleşen ürünler `eslesen_urunler` alanında
  listelenir.
- Bir restoran hem adıyla hem menüsüyle eşleşebilir → `eslesme: ["isim","menu"]`.

## Örnek istekler

```bash
curl "https://api.gezgah.com/rest/arama?q=burger"
curl "https://api.gezgah.com/rest/arama?q=kahve&page=1&limit=20"
```

## Yanıt formatı

```json
{
  "success": true,
  "data": [
    {
      "id": 1581,
      "type": "restoran",
      "slug": "chunky-smash-burger",
      "name": "Chunky Smash Burger",
      "description": null,
      "thumbnail": null,
      "status": "publish",
      "date": "2026-06-19",
      "telefon": "5472752525",
      "bolge": "23",
      "sehir": "Istanbul",
      "ilce": "Kadıköy",
      "kordinat": "",
      "goruntulenme": 0,
      "kategori_ids": [1048, 129],
      "eslesme": ["isim"]
    },
    {
      "id": 1342,
      "type": "restoran",
      "slug": "kuzguncuk-burger-kafe",
      "name": "Kuzguncuk Burger Kafe",
      "telefon": "5388854818",
      "bolge": "38",
      "sehir": "Istanbul",
      "ilce": "Üsküdar",
      "kategori_ids": [1048, 129, 122, 1],
      "eslesen_urunler": ["Texas Burger", "Cheese Burger", "Tavuk Burger"],
      "eslesme": ["isim", "menu"]
    },
    {
      "id": 1316,
      "type": "restoran",
      "slug": "limandere-kavurmacisi",
      "name": "Limandere Kavurmacısı",
      "sehir": "Istanbul",
      "ilce": "Sarıyer",
      "eslesen_urunler": ["Lim Burger", "Sucuk Burger"],
      "eslesme": ["menu"]
    }
  ],
  "error": null,
  "meta": { "q": "burger", "page": 1, "limit": 20, "total": 22, "pages": 2 }
}
```

### `data[]` öğe alanları

Standart restoran özeti + arama alanları:

| Alan | Açıklama |
|------|----------|
| `id` | Restoran id'si (`yzd_posts.id`) |
| `type` | `restoran` |
| `slug` | URL dostu ad |
| `name` | Restoran adı |
| `thumbnail` | Öne çıkan görsel (yoksa `null`) |
| `status` | Yayın durumu |
| `date` | Eklenme tarihi |
| `telefon` | İletişim numarası |
| `bolge` | Bölge id'si |
| `sehir` | Şehir (bölge id → `ilceler`) |
| `ilce` | İlçe (bölge id → `ilceler`) |
| `kordinat` | "enlem, boylam" metni (boş olabilir) |
| `goruntulenme` | Görüntülenme sayacı |
| `kategori_ids` | Bağlı kategori id'leri |
| `eslesme` | Eşleşme nedeni dizisi: `"isim"` ve/veya `"menu"` |
| `eslesen_urunler` | Yalnızca menüde eşleşme varsa: eşleşen ürün adları |

### `meta` alanları

| Alan | Açıklama |
|------|----------|
| `q` | Arama terimi |
| `page` | Mevcut sayfa |
| `limit` | Sayfa başına kayıt |
| `total` | Toplam eşleşen restoran sayısı |
| `pages` | Toplam sayfa sayısı |

## Hata yanıtı

```json
{ "success": false, "data": null, "error": { "message": "En az 2 karakterlik arama terimi (q) gerekli." } }
```

## Notlar

- Menü verisi `yzd_qr` tablosundan gelir; `parent = 0` satırlar kategori,
  `parent <> 0` satırlar üründür. Arama yalnızca ürün satırlarında yapılır.
- Menüde birden çok ürün eşleşirse hepsi `eslesen_urunler` içinde
  (tekilleştirilmiş) döner.
- Arama büyük/küçük harfe duyarsızdır (MySQL varsayılan collation).
