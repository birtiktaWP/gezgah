# Gezi Rotası — Google Places ile Yer Arama (Gezgah'ta Olmayan Yerler)

Mekan ekleme sekmesinde, Gezgah'ta kayıtlı olmayan yerleri de **Google Places autocomplete** ile
aratıp ekleyebilmek için 2 uç eklendi. Google anahtarı **sunucuda** kalır; mobil kendi tasarımıyla
sonuçları listeler. Seçilen yer, mevcut **Konum durağı** ucuyla rotaya eklenir.

Taban URL: `https://api.gezgah.com/rest`

## Ortak Başlıklar
| Başlık | Değer |
|---|---|
| `X-App-Key` | `ba9db8d2c420adbaeed122fe53c15e878fbcc67b55ba41cd` (zorunlu) |
| `Authorization` | `Bearer <uye_token>` |

> Arama uçları **giriş yapmış üye** ister (maliyet/kötüye kullanım koruması). Sonuçlar Redis'te kısa süre cache'lenir.

Yanıt zarfı: `{ "success": bool, "data": ..., "error": ..., "meta": ... }`

---

## Akış (mobil)
1. Kullanıcı arama kutusuna yazar → **autocomplete** ucunu çağır, `tahminler[]` listesini kendi tasarımınla göster.
2. Kullanıcı bir tahmine dokunur → **place detay** ucunu `place_id` ile çağır, `lat/lng/ad/adres` al.
3. Bu bilgilerle rotaya durak ekle → `POST /uye/rotalar/{id}/konum` (opsiyonel görsel ile).

Önce mevcut Gezgah mekan aramanı göster; sonuç yoksa/kullanıcı "haritadan ara" derse Google Places'e düş.

---

## 1) Otomatik Tamamlama (Autocomplete)

`GET /uye/rotalar/place/autocomplete?q=<kelime>&lat=&lng=&session=`

| Param | Zorunlu | Açıklama |
|---|---|---|
| `q` | ✓ | Aranan kelime (en az 2 karakter; kısa ise boş liste döner). `query` de kabul edilir. |
| `lat`, `lng` | – | Kullanıcının konumu — sonuçları yakına yanlılar (30km). |
| `session` | – | Google sessiontoken (faturalamayı ucuzlatır; aynı token'ı detayda da gönder). |

Yanıt:
```json
{
  "success": true,
  "data": {
    "tahminler": [
      {
        "place_id": "ChIJRcjsnv7nn0ARRzqDtykE0G4",
        "ad": "Kilyos Plaj Restaurant",
        "alt_bilgi": "Kumköy, Sarıyer/İstanbul",
        "aciklama": "Kilyos Plaj Restaurant, Kumköy, Sarıyer/İstanbul, Türkiye"
      }
    ]
  }
}
```
- `ad`: birincil metin (kalın gösterilecek), `alt_bilgi`: ikincil (adres), `aciklama`: tam metin.
- Arama Türkiye ile sınırlı (`country:tr`), dil `tr`.

---

## 2) Yer Detayı

`GET /uye/rotalar/place/detay?place_id=<id>&session=`

Autocomplete'ten gelen `place_id` ile yerin konumunu getirir.

Yanıt:
```json
{
  "success": true,
  "data": {
    "place_id": "ChIJRcjsnv7nn0ARRzqDtykE0G4",
    "ad": "Kilyos Plaj Restaurant",
    "adres": "Kumköy, Plaj Yolu Cd. No:28, 34450 Sarıyer/İstanbul, Türkiye",
    "lat": 41.2471095,
    "lng": 29.0344606
  }
}
```

---

## 3) Seçilen Yeri Rotaya Ekle

`POST /uye/rotalar/{id}/konum`  [Plus]

Detaydan gelen alanları doğrudan gönder (bkz. rota-konum-durak.md):
```json
{
  "lat": 41.2471095,
  "lng": 29.0344606,
  "ad": "Kilyos Plaj Restaurant",
  "adres": "Kumköy, Plaj Yolu Cd. No:28, Sarıyer/İstanbul",
  "yorum": "Deniz kenarı mola",
  "gorsel": "data:image/jpeg;base64,..."
}
```
Yer, rotada `tip: "konum"` durağı olarak görünür; harita ve polyline'a dahil edilir.

---

## Özet Endpoint Listesi
| Metot | Yol | Açıklama |
|---|---|---|
| GET | `/uye/rotalar/place/autocomplete` | Google Places otomatik tamamlama (Gezgah dışı yerler) |
| GET | `/uye/rotalar/place/detay` | Seçilen yerin ad/adres/lat/lng detayı |
| POST | `/uye/rotalar/{id}/konum` | Seçilen yeri rotaya durak olarak ekle |

## Notlar (mobil)
- Sonuçları **kendi UI tasarımınla** çiz (Google'ın hazır widget'ı zorunlu değil); veriyi bu uçlardan al.
- Faturalamayı düşürmek için: bir arama oturumunda aynı `session` token'ını autocomplete + detay çağrılarında kullan, seçim yapılınca token'ı yenile.
- Anahtar backend'de; istemciye Google anahtarı gömme.

## Teknik Notlar
- Config: `config/maps.php` → `places_key`, `places_autocomplete`, `places_details`, `places_language`, `places_region`. (Google Cloud'da "Places API" etkin olmalı — mevcut anahtarla doğrulandı.)
- Cache: autocomplete 1 saat, detay 1 gün (Redis; yoksa fail-open).
