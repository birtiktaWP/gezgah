# Gezi Rotası — Durak (Mekan) Fotoğrafları

Rotaya eklenen **her durak (mekan)** için birden fazla fotoğraf yüklenebilir.
Fotoğraflar 1:1 kare JPEG'e dönüştürülüp saklanır; durak başına en fazla **10** foto.

Taban URL: `https://api.gezgah.com/rest`

## Ortak Başlıklar
| Başlık | Değer |
|---|---|
| `X-App-Key` | `ba9db8d2c420adbaeed122fe53c15e878fbcc67b55ba41cd` (zorunlu) |
| `Authorization` | `Bearer <uye_token>` |

> Yükleme/silme **Plus** üyelik ister. Durak, isteği yapan üyenin rotasına ait olmalı.

Yanıt zarfı: `{ "success": bool, "data": ..., "error": ..., "meta": ... }`

---

## 1) Durağa Fotoğraf Yükle

`POST /uye/rotalar/{id}/mekan/gorsel`

İki gönderim biçiminden biri:

**A) JSON (base64 / data URI):**
```json
{ "durak_id": 17, "gorsel": "data:image/jpeg;base64,/9j/4AAQSkZ..." }
```
`Content-Type: application/json`

**B) multipart/form-data:**
```
durak_id=17
gorsel=<dosya>   (form alan adı: gorsel)
```

Kurallar:
- Kabul edilen biçimler: JPEG / PNG / WEBP. Ham girdi en fazla 6MB.
- Sunucuda 1:1 (1080×1080) kare JPEG'e dönüştürülür (merkez kırpma).
- Durak başına en fazla 10 foto; limit aşılırsa `422`.

Yanıt (201):
```json
{
  "success": true,
  "data": {
    "durum": "yuklendi",
    "durak_id": 17,
    "gorsel": { "id": 42, "url": "https://gezgah.com/uploads/app-rota-duraklar/17-a1b2c3d4e5f6.jpg" },
    "adet": 1
  }
}
```

Birden çok foto için çağrıyı her fotoğraf ile **tekrar** yapın.

---

## 2) Durak Fotoğrafını Sil

`DELETE /uye/rotalar/{id}/mekan/gorsel`

```json
{ "durak_id": 17, "gorsel_id": 42 }
```

Yanıt:
```json
{
  "success": true,
  "data": { "durum": "silindi", "durak_id": 17, "gorsel_id": 42, "adet": 0 }
}
```
(Foto yoksa `"durum": "bulunamadi"`.) Dosya diskten de silinir.

---

## 3) Fotoğrafların Görüntülenmesi

`GET /uye/rotalar/{id}` — her durakta `gorseller[]` döner (sıralı):

```json
{
  "success": true,
  "data": {
    "rota": {
      "id": 10,
      "duraklar": [
        {
          "durak_id": 17,
          "sira": 1,
          "yorum": "Manzara harika",
          "mekan": { "id": 37, "name": "...", "lat": 41.0, "lng": 29.0 },
          "urunler": [ ... ],
          "gorseller": [
            { "id": 42, "url": "https://gezgah.com/uploads/app-rota-duraklar/17-a1b2c3d4e5f6.jpg" },
            { "id": 43, "url": "https://gezgah.com/uploads/app-rota-duraklar/17-99aa88bb77cc.jpg" }
          ],
          "harita_link": "https://www.google.com/maps/search/?api=1&query=41.0,29.0"
        }
      ]
    }
  }
}
```

`gorseller` boş dizi olabilir (foto yüklenmemişse).

---

## Otomatik Temizlik
- Durak silinince (`DELETE /uye/rotalar/{id}/mekan`) o durağın tüm fotoğrafları (DB + dosya) silinir.
- Rota silinince (`DELETE /uye/rotalar/{id}`) tüm durakların fotoğrafları + kapak görseli silinir.

---

## Özet Endpoint Listesi
| Metot | Yol | Açıklama |
|---|---|---|
| POST | `/uye/rotalar/{id}/mekan/gorsel` | Durağa foto yükle (JSON base64 / multipart) |
| DELETE | `/uye/rotalar/{id}/mekan/gorsel` | Durak fotoğrafını sil (`gorsel_id`) |
| GET | `/uye/rotalar/{id}` | Detay — `duraklar[].gorseller[]` |

## Teknik Notlar
- Tablo: `app_rota_durak_gorsel (id, durak_id, url, sira, created_at)`.
- Depolama: `uploads/app-rota-duraklar/` · base URL `https://gezgah.com/uploads/app-rota-duraklar`.
- Boyut/limit ayarları `config/uploads.php` → `rota_durak` (w, h, max_bytes, max_adet).
