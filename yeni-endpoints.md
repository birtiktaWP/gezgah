# Yeni Endpoint'ler

Mobil API'ye (api.gezgah.com) eklenen iki yeni uç.

- **Taban URL:** `https://api.gezgah.com/rest`
- **Kimlik doğrulama:** Diğer okuma uçlarıyla aynı — `Authorization: Bearer <cihaz_token>` zorunludur. Token, `POST /cihaz/kayit` ile alınır.
- **Önbellek:** Her iki uç Redis ile önbelleklenir (fail-open: Redis yoksa doğrudan DB).

---

## 1) `GET /yerler` — Restoran dışı yerler

Restoran DIŞINDAKİ mekan tiplerini **tek uçtan** listeler: `otopark`, `muze`, `mesire`, `plaj`.
(Restoranlar için `/mekanlar` kullanılır.)

### Sorgu parametreleri
| Param | Zorunlu | Açıklama |
|-------|---------|----------|
| `type` | Hayır | `otopark` \| `muze` \| `mesire` \| `plaj`. Verilmezse **dördü birden** döner. Geçersiz değer → 422. |
| `bolge` | Hayır | İlçe id (tip-özel `*_bolge` metasına göre filtre). |
| `kategori` | Hayır | Kategori id (`post_kategori`). |
| `page` | Hayır | Sayfa (varsayılan 1). |
| `limit` | Hayır | Sayfa boyutu (varsayılan 20, en fazla 100). |

> Not: `muze` tipi şu an veritabanında kayıt içermiyor (whitelist'te ileriye dönük olarak bulunur; boş döner).

### Örnek istek
```
GET /rest/yerler?type=plaj&limit=2
Authorization: Bearer <token>
```

### Örnek yanıt
```json
{
  "success": true,
  "data": [
    {
      "id": 987,
      "type": "plaj",
      "slug": "aya-nikola-plaji",
      "name": "Aya Nikola Plajı",
      "description": "...",
      "thumbnail": "https://.../uploads/...jpg",
      "image": "https://.../uploads/...jpg",
      "status": "publish",
      "date": "2025-06-01",
      "telefon": null,
      "bolge": "34",
      "sehir": "İstanbul",
      "ilce": "Adalar",
      "kordinat": "40.86,29.12",
      "kategori_ids": [123]
    }
  ],
  "meta": { "type": "plaj", "page": 1, "limit": 2, "total": 80, "pages": 40 }
}
```

### Öğe alanları
`id, type, slug, name, description, thumbnail, image, status, date, telefon, bolge, sehir, ilce, kordinat, goruntulenme, kategori_ids` — `/mekanlar` ile aynı özet format.

### Notlar
- Yalnızca `status = 'publish'` kayıtlar döner.
- `type` verilmezse `meta.type = "all"` ve dört tip birlikte listelenir.
- Kaynak: MySQL (bu tipler Elasticsearch index'inde yok) + Redis önbellek (300 sn).

---

## 2) `GET /kategoriler/agac` — Tüm kategoriler + parent ilişkileri

Yayındaki **tüm** kategorileri, üst–alt (parent) ilişkileriyle birlikte tek yanıtta döner.
İstemci bu düz listeden kategori ağacını kurabilir.

### Sorgu parametreleri
Yok.

### Örnek istek
```
GET /rest/kategoriler/agac
Authorization: Bearer <token>
```

### Örnek yanıt
```json
{
  "success": true,
  "data": [
    {
      "id": 1101,
      "type": "kategori",
      "slug": "bar-kokteyl",
      "name": "Bar & Kokteyl",
      "description": "",
      "thumbnail": null,
      "status": "publish",
      "date": "2024-01-01",
      "icon": "<svg ...>",
      "parent": 0,
      "parents": [],
      "children": [1201, 1202],
      "is_root": true,
      "mekan_sayisi": 12
    },
    {
      "id": 1254,
      "name": "Balık",
      "parent": 122,
      "parents": [1096, 122],
      "children": [],
      "is_root": false,
      "mekan_sayisi": 30
    }
  ],
  "meta": { "total": 58, "roots": [1101, 122, 130, ...] }
}
```

### Alan açıklamaları
| Alan | Açıklama |
|------|----------|
| `parent` | **Legacy tek üst** kategori id (`yzd_posts.parent`). `0` = kök. Geriye dönük uyumluluk. |
| `parents` | **Çoklu üst** kategori id listesi (`erp_kategori_parents`). Bir kategori birden çok üste bağlı olabilir (ör. `[1096, 122]`). |
| `children` | Bu kategorinin doğrudan alt kategori id'leri. |
| `is_root` | Üstü olmayan (kök) kategori mi. |
| `icon` | Kategori ikonu (SVG, `kategori_ikon` metası). Yoksa `null`. |
| `mekan_sayisi` | Bu kategoriye bağlı yayındaki mekan sayısı. |
| `meta.roots` | Kök kategori id'leri, ERP'deki kök sırasına (`erp_kategori_root.sort`) göre. |

### Notlar
- Parent ilişkileri ERP'nin **çoklu-üst** tablosundan (`erp_kategori_parents`) alınır; tablo yoksa `parents`, legacy `parent`'a düşer.
- Yalnızca `status = 'publish'` kategoriler döner.
- Kaynak: MySQL + Redis önbellek (600 sn).

---

## Örnek doğrulama (canlı)
```
/yerler?type=plaj    -> total 80
/yerler?type=otopark -> total 1602
/yerler?type=mesire  -> total 43
/yerler (type yok)   -> total 1725  (80 + 43 + 1602 + 0 müze)
/kategoriler/agac    -> total 58, roots 7
```
