# Tip Bazlı Filtreler — `GET /filtreler?type=`

Mekan tipine göre (restoran / plaj / mesire / otopark / etkinlik) filtre listesi.
Bu doküman canlı veritabanından doğrulanmış **tam filtre listelerini** içerir;
mobil tarafta filtre modalini tipe göre doldurmak için referans olarak kullanılır.

> Taban URL: `https://api.gezgah.com/rest` · İlgili: [FILTRELER.md](FILTRELER.md) ·
> [KATEGORI_OZELLIK_FILTRE.md](KATEGORI_OZELLIK_FILTRE.md)
> Doğrulama tarihi: 26 Ağustos 2026

## Ortak Başlıklar
| Başlık | Değer |
|---|---|
| `X-App-Key` | `ba9db8d2c420adbaeed122fe53c15e878fbcc67b55ba41cd` (zorunlu) |
| `Authorization` | `Bearer <cihaz_veya_uye_token>` (zorunlu) |

---

## Endpoint

```
GET /filtreler?type=<restoran|plaj|mesire|otopark|etkinlik>
```

| Parametre | Zorunlu | Açıklama |
|---|---|---|
| `type` | Hayır | Filtreleri mekan tipine göre süzer. **Verilmezse 56 filtrenin tamamı** döner. |

**Nasıl çalışır:** Her filtre postunun (`yzd_posts.type='filtre'`) `filter_type` metası
hangi mekan tipine ait olduğunu belirler. Mekan tarafında aktiflik `filtre_{id} = 1`
metası ile tutulur ve liste uçlarındaki `filtre_ids` dizisiyle eşleşir.

### Tip başına filtre sayısı

| `type` | Filtre sayısı | Mekanlarda kullanım (aktif filtresi olan / yayında) |
|---|---|---|
| `restoran` | 20 | 309 / 160 |
| `mesire` | 15 | 42 / 19 |
| `plaj` | 13 | 79 / 80 |
| `otopark` | 7 | 1602 / 1602 |
| `etkinlik` | 1 | — |
| *(parametresiz)* | **56** | — |

> Not: "aktif filtresi olan" sayısı taslak/eski kayıtları da kapsadığı için bazı tiplerde
> yayında olan sayıdan yüksek görünür. Liste uçları `status='publish'` süzdüğü için bu
> durum istemciye yansımaz.

---

## Filtre Listeleri (id · ad)

### `?type=restoran` — 20 filtre
| id | Ad | | id | Ad |
|---|---|---|---|---|
| 96 | Rezervasyon | | 107 | Alkol |
| 98 | Otopark | | 108 | Alkolsüz |
| 99 | Vale | | 109 | Sigara |
| 100 | Dijital Menü | | 110 | Sigarasız |
| 101 | Wifi | | 111 | Evcil Hayvan |
| 102 | Çocuk Alanı | | 112 | Yabancı Dil |
| 103 | Çalışma Alanı | | 114 | Nargile |
| 104 | Toplu Etkinlik | | 115 | Engelsiz |
| 105 | Soğutucu | | 116 | Mescit |
| 106 | Isıtıcı | | 117 | Çevre Otoparkı |

### `?type=plaj` — 13 filtre
| id | Ad | | id | Ad |
|---|---|---|---|---|
| 1457 | Ücretli | | 1464 | Şezlong |
| 1458 | Ücretsiz | | 1465 | Cankurtaran |
| 1459 | Kum | | 1466 | Dalgakıran |
| 1460 | Çakıl | | 1467 | Koylar |
| 1461 | Kayalık | | 1468 | Beach Club |
| 1462 | Otopark | | 1474 | Halk Plajı |
| 1463 | Yeme-İçme | | | |

### `?type=mesire` — 15 filtre
| id | Ad | | id | Ad |
|---|---|---|---|---|
| 25 | Ateş | | 33 | Plaj |
| 26 | Yürüyüş Parkuru | | 34 | Tesis |
| 27 | Piknik | | 35 | Kamp |
| 28 | Seyir Terası | | 36 | Otopak *(yazım hatası: "Otopark")* |
| 29 | Oturma Alanı | | 80 | Mescit |
| 30 | F&B Sahası | | 81 | WC |
| 31 | Oyun Parkı | | 92 | Tenis Kortu |
| 32 | Göl Kenarı | | | |

### `?type=otopark` — 7 filtre
| id | Ad |
|---|---|
| 91 | Test Otopark *(test kaydı — bkz. Bilinen Sorunlar)* |
| 118 | Açık Otopark |
| 119 | Kapalı Otopark |
| 121 | Yol Üstü Park |
| 136 | Katlı Otopark |
| 139 | Özel Otopark |
| 140 | İspark |

### `?type=etkinlik` — 1 filtre
| id | Ad |
|---|---|
| 138 | Tür |

---

## Yanıt Örneği

```
GET /filtreler?type=otopark
```

```json
{
  "success": true,
  "data": [
    { "id": 118, "name": "Açık Otopark",  "slug": "acik-otopark",  "type": "otopark", "icon": "<svg…>", "meta_key": "filtre_118" },
    { "id": 119, "name": "Kapalı Otopark","slug": "kapali-otopark","type": "otopark", "icon": null,     "meta_key": "filtre_119" }
  ],
  "error": null,
  "meta": {
    "total": 7,
    "type": "otopark",
    "ozellikler": [ /* … aşağıdaki uyarıya bakın … */ ]
  }
}
```

| Alan | Açıklama |
|---|---|
| `id` | Filtre id'si — mekan kayıtlarındaki `filtre_ids` ile eşleşir |
| `name` / `slug` | Ad / URL dostu ad |
| `type` | Filtrenin mekan tipi (`filter_type`) |
| `icon` | SVG (yoksa `null` → istemci kendi yedek ikonunu kullanır) |
| `meta_key` | Backend meta anahtarı (`filtre_{id}`), bilgi amaçlı |
| `meta.total` | Dönen filtre sayısı |
| `meta.type` | Uygulanan tip (parametresizse `null`) |

---

## ⚠️ `meta.ozellikler` tipe göre süzülmez

`meta.ozellikler` (Teras, Bahçe, Deniz Manzaralı, Şömine… 24 kayıt) **`type`
parametresinden bağımsızdır** ve her çağrıda tam liste döner. Kaynağı mekanların
`restoran_ozellik` metasıdır, yani pratikte **restoran odaklıdır**.

**İstemci önerisi:** `meta.ozellikler`'i yalnızca `type=restoran` çağrısında kullan.
Otopark / plaj / mesire filtre modalinde özellik grubunu **gösterme** — o tiplerde
`ozellik_ids` genelde boş (`[]`) döner ve kullanıcı seçim yaparsa sonuç boşalır.

| `type` | `data` (filtreler) | `meta.ozellikler` |
|---|---|---|
| `restoran` | Restoran filtreleri | ✅ Kullan |
| `plaj` / `mesire` / `otopark` | İlgili tipin filtreleri | ❌ Gösterme |

---

## Mekan Kayıtlarıyla Eşleştirme

Liste uçları (`/mekanlar`, `/yerler`, `/kategoriler/{id}`, `/kategoriler/{id}/mekanlar`,
`/uye/favoriler`) her mekanda şu dizileri döndürür:

```json
{ "id": 1592, "type": "plaj", "filtre_ids": [1459, 1464], "ozellik_ids": [] }
```

- `filtre_ids` → bu dokümandaki id'lerle eşleşir
- **AND mantığı:** Kullanıcının seçtiği **tüm** filtre id'lerini içeren mekanlar listede kalır
- Filtreleme **istemci tarafında** yapılır (sunucuya `filtreler=` parametresi yalnız `/arama` ucunda vardır)

### Örnek akış (plaj listesi)

```
1) GET /filtreler?type=plaj        → 13 seçenek modalde gösterilir
2) GET /yerler?type=plaj           → her plajın filtre_ids'i gelir
3) Kullanıcı "Kum (1459)" + "Şezlong (1464)" seçer
4) İstemci: filtre_ids içinde 1459 VE 1464 olan plajları bırakır
```

---

## Bilinen Sorunlar

| Konu | Durum |
|---|---|
| `#91 Test Otopark` | Canlıda görünen **test filtresi**. `?type=otopark` yanıtında geliyor. Temizlenmesi önerilir. |
| `#36 Otopak` (mesire) | Ad yazım hatası — "Otopark" olmalı. |
| `mesire` sayı tutarsızlığı | 42 mekanda aktif mesire filtresi var ama yayında 19 mesire kaydı görünüyor (taslak/eski kayıtlarda meta kalmış). İstemciye yansımıyor. |
| `etkinlik` filtresi | Yalnız 1 filtre (`Tür`) tanımlı; filtre modalı için pratikte yetersiz. |

---

## Teknik Notlar

- Kaynak: `yzd_posts` (`type='filtre'`, `status='publish'`) + `yzd_postmetas.filter_type`
- İkon: `filtre_ikon` metası (SVG); tanımlı değilse `null`
- **Önbellek:** Redis'te **30 dk** (`flt:<type|all>`). Filtre eklendiğinde/değiştiğinde
  yansıması için önbellek temizlenebilir:
  ```bash
  redis-cli --scan --pattern '*flt*' | xargs -r redis-cli del
  ```
- Controller: `api/rest/src/Controllers/FiltreController.php` → `index()`
- Rota: `index.php` → `$router->get('/filtreler', [$filtre, 'index']);`
