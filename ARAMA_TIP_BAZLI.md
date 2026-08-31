# Arama — Mekan Tipine Göre (`type`)

`/arama` ucu artık **hangi mekan tipinde** arandığını `type` parametresiyle
alır. Parametre gönderilmezse davranış eskisiyle **birebir aynıdır** (restoran).

> Taban URL: `https://api.gezgah.com/rest`

## Ortak Başlıklar
| Başlık | Değer |
|---|---|
| `X-App-Key` | `ba9db8d2c420adbaeed122fe53c15e878fbcc67b55ba41cd` (zorunlu) |
| `Authorization` | `Bearer <cihaz_veya_uye_token>` (zorunlu) |

Yanıt zarfı: `{ "success": bool, "data": [...], "error": ..., "meta": {...} }`

---

## Endpoint

| Metot | Yol |
|---|---|
| GET | `/arama` |

### Query parametreleri
| Param | Zorunlu | Varsayılan | Açıklama |
|---|---|---|---|
| `q` | **Evet** | — | Arama terimi, en az 2 karakter |
| `type` | Hayır | `mekan` | `mekan` \| `plaj` \| `mesire` \| `otopark` |
| `tab` | Hayır | `mekan` | `mekan` (isim araması) \| `yemek` (menü/ürün araması) |
| `sort` | Hayır | konum varsa `distance` | `distance` \| `relevance` (yemekte: `price_asc`, `price_desc`, `likes`) |
| `filtreler` | Hayır | — | Virgüllü filtre id'leri, **AND** ile uygulanır |
| `lat`, `lng` | Hayır | — | Konum; `mesafe_m` ve mesafe sıralaması için |
| `page`, `limit` | Hayır | 1, 20 | `limit` max 100 |

### `type` değerleri

| Değer | `yzd_posts.type` | Kayıt (yayında) | Kabul edilen takma adlar |
|---|---|---|---|
| `mekan` | `restoran` | 159 | `restoran`, `isletme`, `yer`, `mekanlar` |
| `plaj` | `plaj` | 80 | `plajlar`, `sahil` |
| `mesire` | `mesire` | 22 | `mesireler`, `piknik`, `tabiat` |
| `otopark` | `otopark` | 1602 | `otoparklar`, `park` |

> `mekan` = restoran/işletme. Ayrı bir "hepsi" değeri **yoktur**; tek istekte
> birden çok tip aranamaz. Uygulamada tip sekmeleri varsa her sekme için ayrı
> istek atılmalıdır.

Geçersiz `type` **sessizce restorana düşmez**, `422` döner:

```json
{
  "success": false,
  "error": {
    "message": "Geçersiz type. İzinli değerler: mekan, plaj, mesire, otopark.",
    "details": { "izinli_tipler": ["mekan", "plaj", "mesire", "otopark"] }
  }
}
```

---

## Örnekler

```
GET /arama?q=koyu&type=plaj
GET /arama?q=tabiat&type=mesire
GET /arama?q=zeytinburnu&type=otopark
GET /arama?q=kahve                       (type=mekan varsayılan)
GET /arama?q=koyu&type=plaj&lat=41.05&lng=29.03      → mesafeye göre sıralı
GET /arama?q=deniz&type=plaj&filtreler=1457,1465     → Ücretli + Cankurtaran
```

### Yanıt (kısaltılmış)
```json
{
  "success": true,
  "data": [
    {
      "id": 1522, "type": "plaj", "slug": "korsan-koyu", "name": "Korsan Koyu",
      "sehir": "İstanbul", "ilce": "Beykoz",
      "thumbnail": "https://...", "kordinat": "41.1802, 29.0899",
      "dogrulanmis": false, "eslesme": ["isim"], "mesafe_m": 18442
    }
  ],
  "meta": {
    "q": "koyu", "tab": "mekan", "type": "plaj", "sort": "distance",
    "filtreler": [], "page": 1, "limit": 20, "total": 15, "pages": 1
  }
}
```

`meta.type` her zaman **normalize edilmiş** değeri döner (takma ad gönderilse
bile): `plajlar` → `plaj`.

---

## Yemek sekmesi yalnız `type=mekan`

QR menü yalnızca işletmelerde bulunur. `tab=yemek` ile `mekan` dışında bir tip
gönderilirse boş liste değil, açık bir hata döner:

```
GET /arama?q=kofte&tab=yemek&type=plaj
```
```json
{
  "success": false,
  "error": {
    "message": "Yemek araması yalnızca type=mekan ile yapılabilir. Plaj, mesire ve otoparklarda menü bulunmaz.",
    "details": { "izinli_tipler": ["mekan"], "tab": "yemek" }
  }
}
```

İstemci tarafında doğru davranış: tip sekmesi `mekan` dışında bir değere
geçtiğinde **Yemekler sekmesini gizlemek** (ya da devre dışı bırakmak).

---

## Filtreler ve tip birlikte

Filtre id'leri tipe özeldir. Hangi tipte hangi filtrelerin olduğunu
`GET /filtreler?type=<tip>` verir (bkz. `FILTRELER_TIP_BAZLI.md`).
Örnek: plaj filtreleri (Ücretli, Şezlong, Cankurtaran…) restoranda anlamsızdır
ve o tipte hiçbir mekanı eşleştirmez.

Kategori listeleri için de tip bazlı uç mevcuttur:
`GET /kategoriler/tip/{type}` (bkz. `KATEGORI_TIP_BAZLI.md`).

---

## Davranış ve performans notları

**Arama motoru seçimi.** `mekan`, `plaj` ve `mesire` Elasticsearch
(`gezgah_mekanlar`) üzerinden aranır: yazım hatası toleranslı, isim odaklı.
**Otopark Elasticsearch'te indekslenmiyor** (1602 kayıt, ES'te 0), bu yüzden
otopark aramaları doğrudan veritabanı üzerinden yapılır — Türkçe-fold + kelime
sınırı LIKE ile (`köfte` ↔ `kofte` eşleşir, `latte` → `Platter` eşleşmez).
Sonuç kalitesi ve sözleşme aynıdır, yalnız yazım hatası toleransı yoktur.

> Kod bunu `ES_TIPLERI` sabitiyle bilir. Otopark ileride indekslenirse sabite
> eklemek yeterlidir; eklenmezse arama çalışmaya devam eder (yalnız DB yolundan).

**Sıralama.** `sort=distance` ya da `filtreler` verildiğinde, sayfa tutarlılığı
için tüm eşleşen küme (üst sınır 500) çekilip sunucuda sıralanır. Aksi halde
ES/DB doğal alaka sırasıyla sayfalı gider (daha hızlı).

**Önbellek.** Yanıtlar Redis'te **120 saniye** tutulur. Anahtar `type`'ı da
içerir, yani tipler birbirinin önbelleğini ezmez.

**Yayın durumu.** Her iki yolda da yalnız `status = 'publish'` kayıtlar döner;
ES'ten gelen id'ler veritabanından tekrar doğrulanır (bayat indeks kaydı sızmaz).

---

## Doğrulama (canlı)

| Test | Sonuç |
|---|---|
| `type=plaj` (q=koyu) | 200, total 15, dönen tiplerin hepsi `plaj` |
| `type=mesire` (q=tabiat) | 200, total 9 |
| `type=otopark` (q=zeytinburnu) | 200, total 5 — DB yolu |
| `type` yok (q=kahve) | 200, `meta.type=mekan`, yalnız `restoran` |
| `type=plajlar` (takma ad) | 200, `meta.type=plaj` |
| `type=muze` | 422, izinli tipler listesi |
| `tab=yemek&type=mekan` | 200, total 101 ürün |
| `tab=yemek&type=plaj` | 422 |
| `type=plaj&lat&lng` | 200, `sort=distance`, mesafeye göre artan |
| Tip sızması (q=ka, 4 tip) | mekan→sadece restoran, plaj→sadece plaj, mesire→sadece mesire, otopark→sadece otopark |
| Sayfalama (plaj, limit=3) | sayfa 1 ve 2 kesişimi boş, `pages=3` |

Sürüm: Ağustos 2026
