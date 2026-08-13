# Mekan Detayı — Aktif Etkinlikler

`GET /rest/mekanlar/{id}` yanıtına **`etkinlikler`** alanı eklendi. O mekana ait
**aktif ve süresi geçmemiş** etkinlikleri görselleriyle döndürür.

- **Uç:** `GET https://api.gezgah.com/rest/mekanlar/{id}`
- **Kimlik:** mevcut (X-App-Key + cihaz/üye token)
- **Yeni alan:** yanıt gövdesinin köküne `etkinlikler: [...]`

---

## Filtre kuralı (hangi etkinlikler döner)

Bir etkinlik listede yer alır ancak ve ancak:
- İlgili mekana ait (`yzd_etkinlik.boss = mekan post id`),
- `status = 1` (aktif/yayında),
- `date >= bugün` (süresi geçmemiş).

Sıralama: `date` artan, sonra `time` artan (en yakın etkinlik önce).
Aktif etkinlik yoksa `etkinlikler: []` (boş dizi) döner.

> **Tazelik:** Bu alan her istekte **canlı** hesaplanır; ES/Redis detay
> önbelleğine girmez. Böylece süresi bugün dolan etkinlik ertesi gün otomatik
> düşer (ekstra bir cache tazeleme gerekmez).

---

## Alanlar

| Alan          | Tip         | Açıklama |
|---------------|-------------|----------|
| `id`          | int         | Etkinlik id (`yzd_etkinlik.id`). |
| `name`        | string      | Etkinlik adı. |
| `description` | string/null | Açıklama. |
| `price`       | string/null | Giriş bedeli (ham metin; ücretsiz/boşsa `null`). |
| `date`        | string      | Tarih `YYYY-MM-DD`. |
| `time`        | string      | Saat `HH:MM` (boş olabilir). |
| `image`       | string/null | Etkinlik görseli tam URL (yoksa `null`). |

### `image` hakkında
- Görsel, menü ürün görselleriyle **aynı altyapıdan** servis edilir:
  `https://qr.gezgah.com/img.php?t=g&f=<dosya>` (qr proxy).
- İşletme sahibi pro panelinden ("Etkinlik Oluştur/Düzenle") görsel yüklerse dolu
  gelir; yüklememişse `null`.
- Boyut/oran sabit değildir (kullanıcı ne yüklerse); istemci `BoxFit.cover` ile
  gösterebilir.

---

## Örnek yanıt (kısaltılmış)

```json
{
  "success": true,
  "data": {
    "id": 1311,
    "name": "Belgrad Döner",
    "type": "restoran",
    "thumbnail": "https://gezgah.com/uploads/thumbs/square/....webp",
    "image": "https://gezgah.com/uploads/....jpeg",
    "menu": [ ... ],
    "galeri": [ ... ],
    "listeleme": 120,
    "tiklama": 45,
    "etkinlikler": [
      {
        "id": 5,
        "name": "Canlı Müzik Gecesi",
        "description": "Saat 21:00'den sonra canlı müzik performansı.",
        "price": "150",
        "date": "2026-09-20",
        "time": "21:00",
        "image": "https://qr.gezgah.com/img.php?t=g&f=gezgah_abc123.jpg"
      }
    ]
  },
  "error": null
}
```

---

## Mobil entegrasyon notları

1. `data.etkinlikler` boş dizi `[]` ise etkinlik bölümünü **gösterme**.
2. Her öğe için: `image` (varsa) üstte, altında `name`, `date`/`time`
   (ör. "20 Eyl 2026 · 21:00") ve varsa `price` ("150 ₺" / boşsa "Ücretsiz").
3. `image` `null` olabilir → yer tutucu ya da yalnız metin kartı göster.
4. Detay/ayrı etkinlik ekranı gerekiyorsa mevcut `GET /rest/etkinlikler/{id}`
   ucu aynı etkinliği döndürür.
5. Bu alan yalnız **detay** yanıtındadır; liste/özet uçlarında (`/mekanlar`,
   `/arama` ...) etkinlik dönmez.

---

## Notlar (backend)

- Etkinlik–mekan bağı `yzd_etkinlik.boss = post id` üzerindendir.
- Görsel yükleme pro tarafında `add_event`/`update_event` ile `/uploads/gallery/`
  altına kaydedilir (dosya adı `yzd_etkinlik.image`'da tutulur).
- Eski (görsel yüklenmemiş) etkinliklerde `image` `null` gelir; yalnız yeni
  yüklenenlerde doludur.
