# Gezi Rotası — Yemek (Ürün) Fotoğrafı

Bir durakta **seçili her yemek (ürün)** için kullanıcı **en fazla 1 fotoğraf** yükleyebilir.
Yeni yükleme öncekini değiştirir (tek foto sınırı). Foto 1:1 kare JPEG'e dönüştürülür.

> Durak fotoğrafından (`gorseller[]`, durak başına çoklu) farklıdır. Bu, **ürün başına tek** fotoğraftır.

Taban URL: `https://api.gezgah.com/rest`

## Ortak Başlıklar
| Başlık | Değer |
|---|---|
| `X-App-Key` | `ba9db8d2c420adbaeed122fe53c15e878fbcc67b55ba41cd` (zorunlu) |
| `Authorization` | `Bearer <uye_token>` |

> Yükleme/silme **Plus** üyelik ister. Ürün, ilgili durakta **seçili** olmalı (`urunler[]` içinde).

Yanıt zarfı: `{ "success": bool, "data": ..., "error": ..., "meta": ... }`

---

## 1) Yemeğe Fotoğraf Yükle

`POST /uye/rotalar/{id}/mekan/urun-gorsel`

**A) JSON (base64 / data URI):**
```json
{ "durak_id": 18, "qr_id": 5, "gorsel": "data:image/jpeg;base64,/9j/4AAQSkZ..." }
```

**B) multipart/form-data:**
```
durak_id=18
qr_id=5
gorsel=<dosya>   (form alan adı: gorsel)
```

Kurallar:
- Ürün (`qr_id`) durakta seçili değilse `422` (önce `mekan/urun-ekle` veya `qr_ids` ile ekleyin).
- Kabul: JPEG / PNG / WEBP, en fazla 6MB. Sunucuda 1080×1080 kare JPEG'e dönüştürülür.
- Ürün başına 1 foto: tekrar yüklenince eski dosya silinir, yenisi geçer.

Yanıt (201):
```json
{
  "success": true,
  "data": {
    "durum": "yuklendi",
    "durak_id": 18,
    "qr_id": 5,
    "foto": "https://gezgah.com/uploads/app-rota-urunler/18-5-a1b2c3d4e5.jpg"
  }
}
```

---

## 2) Yemek Fotoğrafını Sil

`DELETE /uye/rotalar/{id}/mekan/urun-gorsel`

```json
{ "durak_id": 18, "qr_id": 5 }
```

Yanıt:
```json
{ "success": true, "data": { "durum": "silindi", "durak_id": 18, "qr_id": 5, "foto": null } }
```
(Foto yoksa `"durum": "bulunamadi"`.) Dosya diskten de silinir.

---

## 3) Fotoğrafların Görüntülenmesi

`GET /uye/rotalar/{id}` — her durakta `urunler[]` içinde her ürünün `foto` alanı döner:

```json
{
  "success": true,
  "data": {
    "rota": {
      "duraklar": [
        {
          "durak_id": 18,
          "urunler": [
            {
              "qr_id": 5,
              "ad": "Köfte",
              "fiyat": "250",
              "gorsel": "https://.../menu-image.jpg",
              "foto": "https://gezgah.com/uploads/app-rota-urunler/18-5-a1b2c3d4e5.jpg"
            },
            {
              "qr_id": 12,
              "ad": "Ayran",
              "fiyat": "50",
              "gorsel": "https://.../menu-image2.jpg",
              "foto": null
            }
          ]
        }
      ]
    }
  }
}
```

Alan ayrımı:
- `gorsel`: menüdeki hazır (QR menü) görseli — sistemden gelir.
- `foto`: kullanıcının bu rota için yüklediği fotoğraf (max 1, yoksa `null`).

---

## Otomatik Temizlik
- Ürün durakdan çıkarılınca (`mekan/urun` sil veya `mekan/guncelle` `qr_ids` ile küme değişimi) o ürünün fotoğrafı (DB + dosya) silinir.
- **Kalan ürünlerin fotoğrafı korunur** — küme güncellemesi mevcut ürünleri bozmaz.
- Durak veya rota silinince tüm yemek fotoğrafları da temizlenir.

---

## Özet Endpoint Listesi
| Metot | Yol | Açıklama |
|---|---|---|
| POST | `/uye/rotalar/{id}/mekan/urun-gorsel` | Yemeğe foto yükle (max 1, değiştirir) |
| DELETE | `/uye/rotalar/{id}/mekan/urun-gorsel` | Yemek fotoğrafını sil |
| GET | `/uye/rotalar/{id}` | Detay — `duraklar[].urunler[].foto` |

## Teknik Notlar
- Kolon: `app_rota_durak_urun.gorsel VARCHAR(255) NULL` (ürün başına tek foto).
- Depolama: `uploads/app-rota-urunler/` · base URL `https://gezgah.com/uploads/app-rota-urunler`.
- Boyut ayarları `config/uploads.php` → `rota_urun` (w, h, max_bytes).
