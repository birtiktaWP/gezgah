# Kategori Filtre Modalı — Filtre + Özellik (Uygulanan Biçim)

Kategori sayfasındaki filtre modalinde artık **filtrelerin** (`restoran_filtre`, `type='filtre'`)
yanına mekan **özellikleri** (`restoran_ozellik` → `type='ozellik'`: Teras, Bahçe, Deniz
Manzaralı, Şömine...) de gelir. Kullanıcı hem filtrelere hem özelliklere göre süzebilir.

Filtreleme **istemci tarafında** yapılır: seçenek listesi `/filtreler`'den, her mekanın
sahip olduğu id'ler liste yanıtındaki dizilerden gelir.

> Taban URL: `https://api.gezgah.com/rest`

## Ortak Başlıklar
| Başlık | Değer |
|---|---|
| `X-App-Key` | `ba9db8d2c420adbaeed122fe53c15e878fbcc67b55ba41cd` (zorunlu) |
| `Authorization` | `Bearer <cihaz_veya_uye_token>` (zorunlu — okuma uçları da token ister) |

Yanıt zarfı: `{ "success": bool, "data": ..., "error": ..., "meta": ... }`

---

## 1) `GET /filtreler` — filtreler + özellikler

**Önemli (geriye dönük uyum):** `data` **eskisi gibi filtre dizisidir** (değişmedi).
Özellikler **`meta.ozellikler`** altında ayrı gelir. Yani eski istemciler etkilenmez;
yeni istemci `meta.ozellikler`'i de okuyup modale ikinci grup olarak ekler.

### İstek
```
GET /filtreler?type=restoran
Authorization: Bearer <token>
```
- `type` (opsiyonel): `restoran | plaj | mesire | otopark | etkinlik`. **Filtreleri** bu tipe göre süzer.
  **Özellikler tipe bağlı değildir**; `meta.ozellikler` her zaman tüm özellikleri döndürür.

### Yanıt
```json
{
  "success": true,
  "data": [
    { "id": 109, "name": "Otopark", "slug": "otopark", "type": "restoran", "icon": "<svg…>", "meta_key": "filtre_109" },
    { "id": 112, "name": "Wi-Fi",   "slug": "wifi",     "type": "restoran", "icon": null,     "meta_key": "filtre_112" }
  ],
  "meta": {
    "total": 2,
    "type": "restoran",
    "ozellikler": [
      { "id": 918,  "name": "Teras",          "slug": "teras",          "type": "ozellik", "icon": null },
      { "id": 919,  "name": "Bahçe",          "slug": "bahce",          "type": "ozellik", "icon": null },
      { "id": 1082, "name": "Deniz Manzaralı","slug": "deniz-manzarali", "type": "ozellik", "icon": null },
      { "id": 3,    "name": "Şömine",         "slug": "somine",         "type": "ozellik", "icon": "<svg…>" }
    ]
  }
}
```

### `data[]` (filtreler)
| Alan | Açıklama |
|---|---|
| `id` | Filtre id'si (`/kategoriler/{id}` mekanlarındaki `filtre_ids` ile eşleşir). |
| `name` / `slug` | Ad / URL dostu ad. |
| `type` | Filtrenin mekan tipi (`restoran` vb.). |
| `icon` | SVG (yoksa `null` → kendi yedek ikonunu kullan). |
| `meta_key` | Backend meta anahtarı (`filtre_{id}`); istemci için bilgi amaçlı. |

### `meta.ozellikler[]` (özellikler)
| Alan | Açıklama |
|---|---|
| `id` | Özellik id'si (`ozellik_ids` ile eşleşir). Filtre id'leriyle **çakışmaz** (ayrı havuz). |
| `name` / `slug` | Ad / URL dostu ad. |
| `type` | Daima `"ozellik"`. |
| `icon` | SVG (yoksa `null`). |

> İstemci `data` (filtreler) + `meta.ozellikler` (özellikler) → tek modal, iki grup (ya da tek liste).

---

## 2) Mekan listelerinde `filtre_ids` + `ozellik_ids`

Her mekan kaydında artık **`ozellik_ids`** var (mevcut `filtre_ids` ile simetrik).

### Etkilenen uçlar
| Metot | Yol | Not |
|---|---|---|
| GET | `/kategoriler/{id}` | Kategori detay (mekanlar + sabit mekan) — **birincil** |
| GET | `/kategoriler/{id}/mekanlar` | Kategori mekan listesi |
| GET | `/mekanlar` | Genel mekan listesi |
| GET | `/yerler` | Restoran dışı yerler (plaj/mesire/otopark) |

### Örnek mekan kaydı
```json
{
  "id": 1592,
  "name": "Çarşı Et ve Balık",
  "thumbnail": "https://…",
  "filtre_ids": [109, 112],
  "ozellik_ids": [1082]
}
```
- `filtre_ids`: mekanda aktif filtreler (`filtre_{id}=1`). `data[]` id'leriyle eşleşir. Boşsa `[]`.
- `ozellik_ids`: mekanın özellikleri (`restoran_ozellik`). `meta.ozellikler` id'leriyle eşleşir. Boşsa `[]`.

> Not: `filtre_ids` `/kategoriler/{id}` ve `/kategoriler/{id}/mekanlar`'da bulunur.
> `/mekanlar` ve `/yerler` özet kayıtlarında şu an **`ozellik_ids`** eklenmiştir; bu iki uçta
> `filtre_ids` özet listede yer almaz (gerekiyorsa detay `/mekanlar/{id}` kullanılır).

---

## İstemci Akışı
1. `/filtreler` → `data` (filtreler) + `meta.ozellikler` (özellikler) modalde gösterilir.
2. Kategori mekanları `filtre_ids` + `ozellik_ids` taşır.
3. **AND mantığı:** Bir mekan, seçili **tüm** filtre id'lerini **ve** seçili **tüm** özellik
   id'lerini içeriyorsa listede kalır (mevcut süzme davranışıyla aynı).

---

## Özet
| Metot | Yol | Değişiklik |
|---|---|---|
| GET | `/filtreler` | `meta.ozellikler` eklendi (data değişmedi — geriye uyumlu) |
| GET | `/kategoriler/{id}` | Her mekana `ozellik_ids` |
| GET | `/kategoriler/{id}/mekanlar` | Her mekana `ozellik_ids` |
| GET | `/mekanlar`, `/yerler` | Her mekana `ozellik_ids` |

## Teknik Notlar (backend)
- Filtreler: `type='filtre'` postlar; mekan aktifliği `filtre_{id}=1` meta'sı.
- Özellikler: `type='ozellik'` postlar; mekan aktifliği `restoran_ozellik` meta'sı = JSON id dizisi (ör. `["1082"]`).
- Özellik ikonu: `ozellik_ikon` → yoksa `filtre_ikon` → yoksa `null`.
- `/filtreler` Redis'te önbelleklenir (30 dk); yanıt gövdesi genişledi, cache anahtarı değişmedi.
