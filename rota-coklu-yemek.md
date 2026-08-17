# Gezi Rotası — Durağa Çoklu Yemek (Menü Ürünü) Ekleme

Bir rota durağına (mekana) **birden fazla** QR menü ürünü (yemek) bağlanabilir.
Önceki tekil `qr_id` desteği korunur; artık her durak bir **ürün listesi** taşır.

Taban URL: `https://api.gezgah.com/rest`

## Ortak Başlıklar
| Başlık | Değer |
|---|---|
| `X-App-Key` | `ba9db8d2c420adbaeed122fe53c15e878fbcc67b55ba41cd` (tüm isteklerde zorunlu) |
| `Authorization` | `Bearer <uye_token>` |
| `Content-Type` | `application/json` |

> Yazma uçları (`mekan`, `mekan/guncelle`, `mekan/urun-ekle`, `mekan/urun`) **Plus** üyelik ister.

Yanıt zarfı: `{ "success": bool, "data": ..., "error": ..., "meta": ... }`

---

## 1) Durak Eklerken Çoklu Ürün

`POST /uye/rotalar/{id}/mekan`

Tekli veya çoklu durak; her durakta `qr_ids[]` (çoklu) **veya** tekil `qr_id`.

Tek durak, çoklu ürün:
```json
{ "post_id": 2, "qr_ids": [5, 12], "yorum": "İkisini de dene" }
```

Çoklu durak:
```json
{
  "duraklar": [
    { "post_id": 2, "qr_ids": [5, 12], "yorum": "başlangıç" },
    { "post_id": 8, "qr_id": 33 }
  ]
}
```

Kurallar:
- `qr_ids[]` içindeki her ürün **o mekanın** menüsünde gerçek bir ürün (kategori değil) olmalı; değilse durak atlanır.
- Tekrar eden `qr_id`'ler tekilleştirilir.
- Tek istekte en fazla 50 durak.

Yanıt (201):
```json
{
  "success": true,
  "data": {
    "durum": "eklendi",
    "eklenen_sayisi": 1,
    "eklenen": [ { "durak_id": 14, "post_id": 2, "qr_ids": [5, 12] } ],
    "atlanan": [],
    "durak_id": 14
  }
}
```

---

## 2) Rota Detayında Ürünler

`GET /uye/rotalar/{id}`

Her durakta `urunler[]` döner. Geriye dönük uyumluluk için `secili_urun` = ilk ürün.

```json
{
  "success": true,
  "data": {
    "rota": {
      "id": 10,
      "baslik": "...",
      "rota_fiyat": 450,
      "duraklar": [
        {
          "durak_id": 14,
          "sira": 1,
          "yorum": "İkisini de dene",
          "mekan": { "id": 2, "name": "...", "lat": 41.0, "lng": 29.0 },
          "urunler": [
            { "qr_id": 5,  "ad": "Köfte",  "fiyat": "250", "gorsel": "https://..." },
            { "qr_id": 12, "ad": "Ayran",  "fiyat": "200", "gorsel": "https://..." }
          ],
          "secili_urun": { "qr_id": 5, "ad": "Köfte", "fiyat": "250", "gorsel": "https://..." },
          "harita_link": "https://www.google.com/maps/search/?api=1&query=41.0,29.0"
        }
      ]
    }
  }
}
```

> `rota_fiyat`: durakların **tüm** seçili ürünlerinin fiyat toplamı (çoklu ürün dahil).

---

## 3) Durağa Tek Ürün Ekle

`POST /uye/rotalar/{id}/mekan/urun-ekle`

```json
{ "durak_id": 14, "qr_id": 33 }
```

Yanıt (201):
```json
{ "success": true, "data": { "durum": "eklendi", "durak_id": 14, "qr_id": 33 } }
```

- İdempotent: aynı ürün ikinci kez eklenirse çoğaltılmaz.
- Ürün o mekanın menüsünde değilse `422`.

---

## 4) Durağın Bir Ürününü Kaldır

`DELETE /uye/rotalar/{id}/mekan/urun`

```json
{ "durak_id": 14, "qr_id": 33 }
```

Yanıt:
```json
{ "success": true, "data": { "durum": "silindi", "durak_id": 14, "qr_id": 33 } }
```
(Ürün yoksa `durum": "bulunamadi"`.)

---

## 5) Durağın Ürün Kümesini Değiştir

`POST /uye/rotalar/{id}/mekan/guncelle`

`qr_ids[]` gönderilirse durağın **tüm ürün listesi** bu kümeyle değiştirilir
(boş dizi = tüm ürünleri temizle). `yorum` de aynı istekte güncellenebilir.

```json
{ "durak_id": 14, "qr_ids": [12, 33], "yorum": "güncel yorum" }
```

Tekil `qr_id` de kabul edilir (tek ürünlük küme olarak ayarlar).
Ürün seti temizlemek için:
```json
{ "durak_id": 14, "qr_ids": [] }
```

Yanıt:
```json
{ "success": true, "data": { "durum": "guncellendi", "durak_id": 14 } }
```

---

## 6) Mekan Menüsünü Listele (ürün seçimi için)

`GET /uye/rotalar/mekan-menu?post_id=2`

Kategori + ürün ağacı döner; `qr_id` değerleri yukarıdaki uçlarda kullanılır.

```json
{
  "success": true,
  "data": {
    "post_id": 2,
    "menu": [
      { "kategori_id": 1, "kategori": "Ana Yemek",
        "urunler": [ { "qr_id": 5, "ad": "Köfte", "fiyat": "250", "gorsel": "https://..." } ] }
    ]
  }
}
```

---

## Özet Endpoint Listesi
| Metot | Yol | Açıklama |
|---|---|---|
| POST | `/uye/rotalar/{id}/mekan` | Durak ekle (`qr_ids[]` / `qr_id`) |
| GET | `/uye/rotalar/{id}` | Detay — `duraklar[].urunler[]` |
| POST | `/uye/rotalar/{id}/mekan/urun-ekle` | Durağa tek ürün ekle |
| DELETE | `/uye/rotalar/{id}/mekan/urun` | Durağın bir ürününü kaldır |
| POST | `/uye/rotalar/{id}/mekan/guncelle` | `qr_ids[]` ile ürün kümesini değiştir |
| GET | `/uye/rotalar/mekan-menu?post_id=` | Mekan menüsü (ürün seçimi) |

## Geçiş Notları (mobil)
- Eski tekil `qr_id` ürün seçimleri, ilk deploy'da otomatik olarak `urunler[]` içine taşındı.
- `secili_urun` alanı geriye dönük uyumluluk içindir; yeni UI `urunler[]` kullanmalı.
