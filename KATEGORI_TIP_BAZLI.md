# Mekan Tipine Göre Kategoriler — `GET /kategoriler/tip/{type}`

Belirli bir **mekan tipinde** (restoran / plaj / mesire / otopark / müze) fiilen
kullanılan kategorileri id'leriyle döndürür. O tipte en çok kullanılan kategori
en üstte gelir.

> Taban URL: `https://api.gezgah.com/rest` · Doğrulama: 26 Ağustos 2026
> İlgili: [KATEGORI_LISTELEME.md](KATEGORI_LISTELEME.md) · [FILTRELER_TIP_BAZLI.md](FILTRELER_TIP_BAZLI.md)

## Ortak Başlıklar
| Başlık | Değer |
|---|---|
| `X-App-Key` | `ba9db8d2c420adbaeed122fe53c15e878fbcc67b55ba41cd` (zorunlu) |
| `Authorization` | `Bearer <cihaz_veya_uye_token>` (zorunlu) |

---

## Neden ayrı bir uç gerekti?

Gezgah'ta kategoriler **tek ortak havuzdadır** (`yzd_posts.type='kategori'`, 58 kayıt).
Kategorinin kendisinde "ben otopark kategorisiyim" gibi bir tip alanı **yoktur**;
bağ, mekan tarafındaki `post_kategori` metası ile kurulur. Bu yüzden:

- `GET /kategoriler` → ana sayfa için kürateli/kök kategoriler (tip süzgeci yok)
- `GET /kategoriler/agac` → tüm kategoriler + parent ilişkileri (tip süzgeci yok)
- **`GET /kategoriler/tip/{type}`** → *(yeni)* tipe göre türetilmiş liste

---

## Endpoint

| Metot | Yol |
|---|---|
| GET | `/kategoriler/tip/{type}` |

### Yol parametresi

| Parametre | Değerler | Açıklama |
|---|---|---|
| `type` | `restoran` · `plaj` · `mesire` · `otopark` · `muze` | Zorunlu. Geçersiz değer → **422**. |

### Örnek istekler
```bash
curl -H "X-App-Key: <key>" -H "Authorization: Bearer <token>" \
  "https://api.gezgah.com/rest/kategoriler/tip/otopark"

curl -H "X-App-Key: <key>" -H "Authorization: Bearer <token>" \
  "https://api.gezgah.com/rest/kategoriler/tip/restoran"
```

---

## Yanıt

```json
{
  "success": true,
  "data": [
    {
      "id": 1600,
      "type": "kategori",
      "slug": "otopark",
      "name": "Otopark",
      "description": "",
      "thumbnail": null,
      "status": "publish",
      "date": "2026-05-02",
      "icon": null,
      "parent": 0,
      "parents": [],
      "is_root": true,
      "mekan_sayisi": 1602
    },
    {
      "id": 1605,
      "type": "kategori",
      "slug": "ispark",
      "name": "İSPARK",
      "icon": null,
      "parent": 0,
      "parents": [1600],
      "is_root": false,
      "mekan_sayisi": 669
    }
  ],
  "error": null,
  "meta": { "total": 6, "type": "otopark", "kategorili_mekan": 1602 }
}
```

### `data[]` alanları

| Alan | Tip | Açıklama |
|---|---|---|
| `id` | int | Kategori id'si. `GET /kategoriler/{id}` ve `/kategoriler/{id}/mekanlar` ile kullanılır. |
| `name` / `slug` | string | Ad / URL dostu ad |
| `icon` | string? | Kategori ikonu (SVG, `kategori_ikon` metası). Yoksa `null`. |
| `parent` | int | Legacy tek üst kategori (`0` = kök) |
| `parents` | int[] | Çoklu üst kategori id'leri (`erp_kategori_parents`). Boşsa kök. |
| `is_root` | bool | Üstü yok mu (kök kategori mi) |
| **`mekan_sayisi`** | int | **YALNIZ istenen tipteki** yayında mekan sayısı |
| `thumbnail`, `description`, `status`, `date` | — | Standart post alanları |

### `meta` alanları

| Alan | Açıklama |
|---|---|
| `total` | Dönen kategori sayısı |
| `type` | Uygulanan mekan tipi |
| `kategorili_mekan` | Bu tipte kategori ataması olan yayında mekan sayısı |
| `not` | Yalnız sonuç boşsa: açıklama metni |

> ⚠️ **`mekan_sayisi` farkı:** Bu uçtaki sayı **tipe özeldir**. `/kategoriler` ve
> `/kategoriler/agac` uçlarındaki `mekan_sayisi` ise **tüm tipleri** kapsar. Örn.
> "Otopark" kategorisi bu uçta `type=otopark` için 1602 dönerken, `/kategoriler/agac`'ta
> restoranların "Otopark" ataması varsa daha yüksek görünebilir.

---

## Sıralama

`mekan_sayisi` **azalan** (o tipte en yaygın kategori önce), eşitlikte **isme göre**.
Böylece istemci listeyi olduğu gibi gösterebilir; ek sıralama gerekmez.

---

## Canlı Veri Durumu (26 Ağustos 2026)

| `type` | Kategori sayısı | Kategorili mekan | Notlar |
|---|---|---|---|
| `restoran` | **43** | 160 | Restoran (84), Kafe (62), Dünya Mutfağı (32), Türk Mutfağı (30), Kahvaltı (22), Fast Food (19)… |
| `otopark` | **6** | 1602 | Otopark (1602), İSPARK (669), Açık (77), Kapalı (67), Katlı (31), Özel (7) |
| `plaj` | **0** | 0 | Kategori ataması yok → `data: []` |
| `mesire` | **0** | 0 | Kategori ataması yok → `data: []` |
| `muze` | **0** | 0 | Bu tipte yayında mekan yok |

**İstemci uyarısı:** `plaj` / `mesire` / `muze` için liste **boş** döner. Bu tiplerde
kategori sekmesi/çipleri **gösterme**; onların ayrımı **filtreler** üzerinden yapılıyor
(bkz. [FILTRELER_TIP_BAZLI.md](FILTRELER_TIP_BAZLI.md) — plaj 13, mesire 15 filtre).

Boş yanıt örneği:
```json
{
  "success": true,
  "data": [],
  "meta": {
    "total": 0, "type": "plaj", "kategorili_mekan": 0,
    "not": "Bu mekan tipinde kategori ataması bulunmuyor."
  }
}
```

Hata yanıtı (geçersiz tip):
```json
{
  "success": false, "data": null,
  "error": {
    "message": "Geçersiz tip. İzinli değerler: restoran, plaj, mesire, otopark, muze.",
    "details": { "izinli_tipler": ["restoran","plaj","mesire","otopark","muze"] }
  }
}
```

---

## Mobil Akış Önerisi

```
1) GET /kategoriler/tip/otopark      → kategori çipleri (Otopark, İSPARK, Açık, Kapalı…)
2) Kullanıcı "İSPARK (1605)" seçer
3) GET /kategoriler/1605/mekanlar    → o kategorideki mekanlar (sayfalı)
   veya
   GET /yerler?type=otopark&kategori=1605
```

- Hiyerarşi kurmak istersen `parents` / `is_root` alanlarını kullan (ör. Otopark kökü
  altında İSPARK, Açık, Kapalı, Katlı, Özel).
- `icon` `null` gelebilir (otopark kategorilerinin ikonu tanımlı değil) → istemci
  yedek ikon uygulamalı.

---

## Teknik Notlar

- **Kaynak:** `yzd_posts` (`type='kategori'`, `status='publish'`) + mekanların
  `post_kategori` metası (JSON id dizisi, ör. `["1600","1605"]`)
- Yalnız **yayında** (`publish`) mekanlar sayılır; yayından kaldırılmış veya
  silinmiş kategoriler listeye girmez (bu nedenle restoranda ham 45 farklı id'den
  43'ü döner — 2 tanesi yayında değil).
- **Önbellek:** Redis, **600 sn**, anahtar `kat:tip:<type>`. Temizleme:
  ```bash
  redis-cli --scan --pattern '*kat:tip*' | xargs -r redis-cli del
  ```
- Controller: `KategoriController::tipKategorileri()` / `buildTipKategorileri()`
- Rota: `index.php` → `$router->get('/kategoriler/tip/{type}', [$kategori, 'tipKategorileri']);`
  (literal `/kategoriler/agac` ve bu yol, `/kategoriler/{id}`'den **önce** tanımlıdır)
