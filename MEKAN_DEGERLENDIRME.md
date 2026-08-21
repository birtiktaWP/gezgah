# Mekan Değerlendirme (Puan + Yorum)

Kullanıcı, mekan detay sayfasından bir mekana **1–5 yıldız puan** ve **opsiyonel yorum** bırakabilir.
Şu an mobil taraf sahte (fake) çalışıyor; bu uçlar eklenince gerçek kayıt yapılacak.

Taban URL: `https://api.gezgah.com/rest`

## Ortak Başlıklar
| Başlık | Değer |
|---|---|
| `X-App-Key` | `ba9db8d2c420adbaeed122fe53c15e878fbcc67b55ba41cd` (zorunlu) |
| `Authorization` | `Bearer <uye_token>` |

> Değerlendirme **ekleme/güncelleme/silme** giriş yapmış üye ister. Listeleme cihaz/üye token'ıyla açıktır.

Yanıt zarfı: `{ "success": bool, "data": ..., "error": ..., "meta": ... }`

---

## 1) Değerlendirme Ekle / Güncelle

`POST /mekanlar/{id}/degerlendirme`  (giriş yapmış üye)

- `{id}` = mekanın post id'si (`yzd_posts.id`).
- Bir üyenin bir mekana **tek** değerlendirmesi olur. Tekrar gönderilirse **günceller** (upsert).

```json
{ "puan": 5, "yorum": "Manzara ve servis harikaydı." }
```

Kurallar:
- `puan`: **zorunlu**, tam sayı **1–5**. Aralık dışıysa `422`.
- `yorum`: opsiyonel, en fazla 1000 karakter (fazlası kırpılır). Boş olabilir.
- Aynı üye tekrar gönderirse mevcut kaydı günceller (`durum: "guncellendi"`).

Yanıt (201 / 200):
```json
{
  "success": true,
  "data": {
    "durum": "eklendi",              // eklendi | guncellendi
    "degerlendirme": {
      "id": 320,
      "puan": 5,
      "yorum": "Manzara ve servis harikaydı.",
      "created_at": "2026-08-22 14:05:00",
      "benim": true,
      "silebilir_mi": true,
      "uye": { "uye_id": 87, "isim": "Ahmet", "soyisim": "Yılmaz", "avatar": "https://..." }
    },
    "ozet": { "ortalama": 4.6, "sayi": 128 }
  }
}
```

---

## 2) Değerlendirmeleri Listele

`GET /mekanlar/{id}/degerlendirmeler?page=1&limit=20`  (cihaz veya üye token'ı)

En yeni değerlendirme en üstte, sayfalı.

```json
{
  "success": true,
  "data": [
    {
      "id": 320,
      "puan": 5,
      "yorum": "Manzara ve servis harikaydı.",
      "created_at": "2026-08-22 14:05:00",
      "benim": false,
      "silebilir_mi": false,
      "uye": { "uye_id": 87, "isim": "Ahmet", "soyisim": "Yılmaz", "avatar": "https://..." }
    }
  ],
  "meta": {
    "page": 1, "limit": 20, "total": 128, "pages": 7,
    "has_more": true, "next_page": 2,
    "ortalama": 4.6, "sayi": 128,
    "benim_puanim": null
  }
}
```

- `meta.ortalama` / `meta.sayi`: mekanın ortalama puanı ve toplam değerlendirme sayısı.
- `meta.benim_puanim`: giriş yapan üyenin bu mekana verdiği puan (yoksa `null`) — mobilde "Değerlendirmeni güncelle" için.
- `benim`: bu değerlendirme isteği yapan üyeye mi ait.
- `silebilir_mi`: kullanıcı bu değerlendirmeyi silebilir mi (yazan üye).

---

## 3) Değerlendirmeyi Sil

`DELETE /mekanlar/{id}/degerlendirme`  (giriş yapmış üye — yalnız kendi değerlendirmesi)

Body gerekmez (üyenin o mekandaki değerlendirmesi silinir) ya da `{ "degerlendirme_id": 320 }`.

```json
{ "success": true, "data": { "durum": "silindi", "ozet": { "ortalama": 4.5, "sayi": 127 } } }
```

---

## 4) Mekan Detayında Özet

`GET /mekanlar/{id}` çıktısına eklenir (varsa):
```json
{ "puan_ortalama": 4.6, "degerlendirme_sayisi": 128, "benim_puanim": 5 }
```
- `puan_ortalama`: 1 ondalık (ör. `4.6`); değerlendirme yoksa `0` veya `null`.
- `benim_puanim`: giriş yapan üyenin puanı (yoksa `null`).

> Böylece mekan detay/kartlarında yıldız + sayı gösterilebilir; kullanıcı daha önce puan verdiyse "Değerlendirmeni güncelle" akışı çalışır.

---

## Özet Endpoint Listesi
| Metot | Yol | Açıklama |
|---|---|---|
| POST | `/mekanlar/{id}/degerlendirme` | Puan + yorum ekle/güncelle (upsert) |
| GET | `/mekanlar/{id}/degerlendirmeler` | Değerlendirmeleri listele (sayfalı) + ortalama/sayı |
| DELETE | `/mekanlar/{id}/degerlendirme` | Kendi değerlendirmeni sil |
| GET | `/mekanlar/{id}` | Detayda `puan_ortalama` / `degerlendirme_sayisi` / `benim_puanim` |

## Mobil Akış (uygulama)
1. Mekan detayında "Değerlendirme Yap" → yıldız (1–5) + opsiyonel yorum modalı.
2. Gönder → `POST /mekanlar/{id}/degerlendirme`. Başarıda özet (`ortalama`/`sayi`) güncellenir; başlıktaki yıldız/sayı tazelenir.
3. Kullanıcı daha önce puan verdiyse (`benim_puanim` dolu) modal o puanla açılır; gönderim **günceller**.
4. Giriş yoksa önce login'e yönlendir.

## Teknik Notlar
- Tablo önerisi: `app_mekan_degerlendirme (id, post_id, uye_id, puan TINYINT, yorum TEXT NULL, created_at, updated_at, UNIQUE(post_id, uye_id))`.
- `UNIQUE(post_id, uye_id)` → kişi başına tek kayıt; tekrar gönderim UPDATE.
- Ortalama/sayı sorguları için `post_id` üzerinde index; istenirse `yzd_posts`'a denormalize `puan_ortalama`/`degerlendirme_sayisi` kolonları + tetikleyici.
- Mekan silinince değerlendirmeleri de temizlenir.
