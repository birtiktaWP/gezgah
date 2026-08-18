# Gezi Rotası — Durak Ekleme: Mekan / Konum Sekmeleri

Rotaya durak eklerken iki tür durak var:
- **Mekan sekmesi:** Kayıtlı bir işletme (post_id) eklenir → mevcut `POST /uye/rotalar/{id}/mekan`.
- **Konum sekmesi (YENİ):** Kullanıcının bulunduğu **serbest konum** (lat/lng) + opsiyonel görsel paylaşılır → `POST /uye/rotalar/{id}/konum`.

Her iki tür de aynı rota içinde, sıralı duraklar olarak birlikte kullanılabilir.

Taban URL: `https://api.gezgah.com/rest`

## Ortak Başlıklar
| Başlık | Değer |
|---|---|
| `X-App-Key` | `ba9db8d2c420adbaeed122fe53c15e878fbcc67b55ba41cd` (zorunlu) |
| `Authorization` | `Bearer <uye_token>` |

> Durak ekleme **Plus** üyelik ister. Rota, isteği yapan üyeye ait olmalı.

Yanıt zarfı: `{ "success": bool, "data": ..., "error": ..., "meta": ... }`

---

## Konum Durağı Ekle (Konum sekmesi)

`POST /uye/rotalar/{id}/konum`

**A) JSON (görsel base64 ile, tek istek):**
```json
{
  "lat": 41.0082,
  "lng": 28.9784,
  "ad": "Sultanahmet Meydanı",
  "adres": "Fatih/İstanbul",
  "yorum": "Buluşma noktası",
  "gorsel": "data:image/jpeg;base64,/9j/4AAQSkZ..."
}
```

**B) multipart/form-data:**
```
lat=41.0082
lng=28.9784
ad=Sultanahmet Meydanı
adres=Fatih/İstanbul
yorum=Buluşma noktası
gorsel=<dosya>   (opsiyonel, form alan adı: gorsel)
```

Alanlar:
| Alan | Zorunlu | Açıklama |
|---|---|---|
| `lat`, `lng` | ✓ | Konum koordinatı (kullanıcının bulunduğu yer). Geçerli aralık dışında ise 422. |
| `ad` | – | Konum adı/başlığı (`konum_adi` da kabul edilir), en fazla 150 kr. |
| `adres` | – | Serbest adres metni, en fazla 255 kr. |
| `yorum` | – | Durak yorumu, en fazla 1000 kr. |
| `gorsel` | – | Bulunulan yerin fotoğrafı (data URI/base64 veya multipart). 1080×1080 kare JPEG'e dönüştürülür, max 6MB. |

Yanıt (201):
```json
{
  "success": true,
  "data": {
    "durum": "eklendi",
    "durak_id": 20,
    "tip": "konum",
    "lat": 41.0082,
    "lng": 28.9784,
    "ad": "Sultanahmet Meydanı",
    "adres": "Fatih/İstanbul",
    "gorsel": "https://gezgah.com/uploads/app-rota-duraklar/20-a1b2c3d4e5f6.jpg"
  }
}
```

> `gorsel` göndermediyseniz `null` döner. Sonradan daha fazla fotoğraf eklemek için durak fotoğraf ucunu kullanın: `POST /uye/rotalar/{id}/mekan/gorsel` `{ durak_id, gorsel }` (bkz. rota-durak-gorsel.md). Konum durakları da bu mekanizmayı kullanır.

---

## Rota Detayında Konum Durağı

`GET /uye/rotalar/{id}` — duraklar `tip` alanıyla döner. Konum durağı örneği:

```json
{
  "durak_id": 20,
  "sira": 1,
  "tip": "konum",
  "yorum": "Buluşma noktası",
  "mekan": {
    "tip": "konum",
    "ad": "Sultanahmet Meydanı",
    "name": "Sultanahmet Meydanı",
    "adres": "Fatih/İstanbul",
    "lat": 41.0082,
    "lng": 28.9784
  },
  "urunler": [],
  "gorseller": [ { "id": 88, "url": "https://gezgah.com/uploads/app-rota-duraklar/20-....jpg" } ],
  "harita_link": "https://www.google.com/maps/search/?api=1&query=41.0082,28.9784"
}
```

Mekan durağında ise `tip: "mekan"` gelir ve `mekan` alanı kayıtlı işletme bilgisidir (ad, thumbnail, bölge, lat/lng, `urunler[]` vb.).

Konum durakları da rota seviyesindeki `koordinatlar[]`, `polyline`, `harita_link` ve harita çizimine dahil edilir (her koordinat kaydında `tip` alanı vardır: `mekan`|`konum`).

---

## Durak Yönetimi (ortak)
Konum durağı da normal bir duraktır; şu uçlarla yönetilir:
- Silme: `DELETE /uye/rotalar/{id}/mekan` `{ durak_id }`
- Sıralama: `POST /uye/rotalar/{id}/sirala` `{ sira: [durak_id, ...] }`
- Fotoğraf ekle/sil: `POST` / `DELETE /uye/rotalar/{id}/mekan/gorsel`
- Yorum güncelle: `POST /uye/rotalar/{id}/mekan/guncelle` `{ durak_id, yorum }`

> Menü ürünü (`urunler`) yalnız **mekan** duraklarına özeldir; konum durağına ürün eklenmez.

---

## Özet Endpoint Listesi
| Metot | Yol | Açıklama |
|---|---|---|
| POST | `/uye/rotalar/{id}/mekan` | Mekan sekmesi — kayıtlı işletme durağı |
| POST | `/uye/rotalar/{id}/konum` | Konum sekmesi — serbest konum + opsiyonel görsel |
| GET | `/uye/rotalar/{id}` | Detay — `duraklar[].tip` (mekan\|konum) |
| POST/DELETE | `/uye/rotalar/{id}/mekan/gorsel` | Durağa foto ekle/sil (konum durakları dahil) |

## Teknik Notlar
- `app_gezi_rota_mekanlari`'ya eklendi: `tip` (mekan\|konum, varsayılan mekan), `lat`, `lng`, `konum_adi`, `adres`. Konum durağında `post_id = 0`.
- Fotoğraflar `app_rota_durak_gorsel` tablosunda (durak_id bazlı) — mekan ve konum duraklarıyla ortak.
