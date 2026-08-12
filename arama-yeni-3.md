# Arama v3 — İki Sekmeli Arama (Mekanlar / Yemekler)

Mobil arama sayfası artık **iki sekmelidir**. Tek uç (`GET /arama`) `tab`
parametresiyle iki modda çalışır. Amaç: performans + net kullanıcı deneyimi.

- **Mekanlar** (varsayılan): kelime **işletme adında** aranır. Elasticsearch
  (isim odaklı, yazım-hatası toleranslı) → erişilemezse DB (Türkçe-fold).
- **Yemekler**: aynı kelime **menü/ürün adında** aranır. Sonuçta eşleşen ürünler
  ve ait oldukları mekanlar döner. (DB, Türkçe-fold + kelime-sınırı; yzd_qr küçük
  olduğundan hızlıdır.)

Mobilde varsayılan aramada menü join'i yapılmadığından liste daha hızlı gelir;
kullanıcı **Yemekler** sekmesine dokununca aynı kelimeyle ürün araması tetiklenir.

---

## Uç

```
GET /rest/arama?q=<terim>&tab=mekan|yemek&page=1&limit=20
```

### Parametreler

| Param    | Tip    | Zorunlu | Varsayılan | Açıklama |
|----------|--------|---------|------------|----------|
| `q`      | string | Evet    | —          | Arama terimi (en az 2 karakter). |
| `tab`    | string | Hayır   | `mekan`    | `mekan` (işletme adı) veya `yemek` (menü ürünü). Takma adlar: `mekanlar`→`mekan`; `yemekler`/`urun`/`menu`→`yemek`. |
| `page`   | int    | Hayır   | `1`        | Sayfa (1'den başlar). |
| `limit`  | int    | Hayır   | `20`       | Sayfa başına kayıt (1–100). |
| `user_id`| int    | Hayır   | —          | Verilirse arama geçmişine bu üye ile yazılır (yalnız 1. sayfa). |

> Kimlik: Diğer uçlar gibi `X-App-Key` + geçerli cihaz/üye token'ı gerektirir
> (bkz. GUVENLIK.md).

---

## tab=mekan (varsayılan) — İşletme adına göre

İşletme **adında** eşleşen yayındaki restoranları döner. Menü araması yapılmaz.

### Örnek istek
```
GET /rest/arama?q=kahve&tab=mekan&limit=3
```

### Örnek yanıt
```json
{
  "success": true,
  "data": [
    {
      "id": 1038,
      "type": "restoran",
      "slug": "9kahve-tophane",
      "name": "9 Kahve Tophane",
      "thumbnail": "https://gezgah.com/uploads/....jpeg",
      "image": "https://gezgah.com/uploads/....jpeg",
      "telefon": "5338983788",
      "bolge": "13",
      "sehir": "Istanbul",
      "ilce": "Beyoğlu",
      "kordinat": "41.0279, 28.9802",
      "goruntulenme": 0,
      "kategori_ids": [1, 1427],
      "eslesme": ["isim"]
    }
  ],
  "error": null,
  "meta": { "q": "kahve", "tab": "mekan", "page": 1, "limit": 3, "total": 4, "pages": 2 }
}
```

`data[]` alanları `/mekanlar` özet formatıyla aynıdır; ek olarak
`eslesme: ["isim"]` döner.

---

## tab=yemek — Menü/ürün adına göre

Menüde (yzd_qr) **adında** eşleşen ürünleri döner; her ürün ait olduğu
**yayındaki** mekanın kompakt özetiyle gelir. Sıralama beğeni (like) azalan.

### Örnek istek
```
GET /rest/arama?q=köfte&tab=yemek&limit=4
```

### Örnek yanıt
```json
{
  "success": true,
  "data": [
    {
      "urun_id": 1423,
      "urun": "KÖFTE IZGARA PORSİYON",
      "fiyat": "550",
      "gorsel": "https://app.gezgah.com/uploads/images/menu/....jpg",
      "begeni": 0,
      "mekan": {
        "id": 1311,
        "slug": "belgrad-doner",
        "ad": "Belgrad Döner",
        "type": "restoran",
        "thumbnail": "https://gezgah.com/uploads/....jpeg",
        "image": "https://gezgah.com/uploads/....jpeg",
        "sehir": "Istanbul",
        "ilce": "Sarıyer",
        "telefon": "5324779601",
        "kordinat": "41.1671, 28.9903"
      }
    }
  ],
  "error": null,
  "meta": { "q": "köfte", "tab": "yemek", "page": 1, "limit": 4, "total": 12, "pages": 3 }
}
```

### Ürün alanları
| Alan       | Tip         | Açıklama |
|------------|-------------|----------|
| `urun_id`  | int         | Menü ürünü id (yzd_qr.id). |
| `urun`     | string      | Ürün adı (yoksa İngilizce ad `gb_item_name`). |
| `fiyat`    | string/null | Fiyat (ham metin; boşsa null). |
| `gorsel`   | string/null | Ürün görseli tam URL (yoksa null). |
| `begeni`   | int         | Beğeni sayısı (like_count). |
| `mekan`    | object      | Ürünün ait olduğu mekanın kompakt özeti (aşağıda). |

### `mekan` bloğu
`id`, `slug`, `ad`, `type`, `thumbnail`, `image`, `sehir`, `ilce`, `telefon`, `kordinat`.
Detay için `GET /rest/mekanlar/{id}` çağrılır.

---

## Türkçe arama davranışı (her iki sekme)

- **Diakritik-duyarsız (fold):** `köfte ↔ kofte`, `çay ↔ cay`, `şiş ↔ sis`.
  Kullanıcı Türkçe yazsa da veri ASCII (ör. "kofte") girilmişse eşleşir.
- **Kelime sınırı:** Terim bir kelimenin **başında veya sonunda** geçmeli.
  - `burger` → "Cheeseburger" **tutar** (kelime sonu).
  - `latte` → "Cheese Platter" **tutmaz** (kelime ortası — tesadüfi eşleşme elenir).

---

## Altyapı: Elasticsearch + Redis

- **Elasticsearch** (`gezgah_mekanlar` indeksi): `tab=mekan` aramasında isim
  odaklı (`name^5`, `name.autocomplete^3`, `description^0.5`, `fuzziness=AUTO`).
  **Fail-open:** ES kapalı/erişilemezse otomatik DB araması (Türkçe-fold) devreye
  girer; sistem asla ES yüzünden kırılmaz. DB **kaynak-doğruluktur**:
  zenginleştirmede `status='publish'` zorunlu tutulur (ES'te bayat kalmış kayıt
  gösterilmez).
- **`tab=yemek`** doğrudan DB (yzd_qr) üzerinden çalışır; ürün id/fiyat/beğeni
  kaynak-doğru buradadır. (ES indeksi mekan seviyesindedir; ürün seviyesi arama
  ileride ayrı bir dish-index ile ES'e taşınabilir.)
- **Redis:** Sonuçlar 2 dakika önbelleklenir. Anahtar `tab`, `q`, `page`, `limit`
  bazlıdır (`mek:arama:<tab>:<md5>`). Redis yoksa fail-open (her istek taze çalışır).

---

## Mobil entegrasyon notları

1. Arama ekranında iki sekme göster: **Mekanlar** (varsayılan) ve **Yemekler**.
2. Kullanıcı yazarken/enter'da `tab=mekan` ile çağır.
3. Kullanıcı **Yemekler** sekmesine geçince aynı `q` ile `tab=yemek` çağır.
4. Sekme değişiminde `page`'i 1'e sıfırla; "daha fazla yükle" için `page` artır.
5. `meta.total` ve `meta.pages` ile sonsuz kaydırma / sayfalama yönetilir.
6. Geriye dönük uyumluluk: `tab` gönderilmezse `mekan` (isim araması) çalışır.
   Eski davranıştaki birleşik (isim+menü) arama artık iki sekmeye ayrılmıştır.
```


---

# Arama v3.1 — Mesafe/Fiyat Sıralama + Filtreleme (EK)

`/arama` ucuna opsiyonel sıralama, konum ve filtre desteği eklendi. Yeni
parametreler gönderilmezse **eski davranış korunur** (mekan=alaka, yemek=beğeni).

## Yeni parametreler

| Param       | Tip    | Sekme        | Açıklama |
|-------------|--------|--------------|----------|
| `lat`       | float  | mekan, yemek | Kullanıcı enlemi (mesafe sıralaması + `mesafe_m`). |
| `lng`       | float  | mekan, yemek | Kullanıcı boylamı. |
| `sort`      | string | mekan, yemek | Sıralama biçimi (aşağıda). |
| `filtreler` | string | mekan, yemek | Virgülle ayrık filtre id (ör. `109,112`). Mekanın **hepsine** sahip olması gerekir (AND). Kaynak: `GET /filtreler`. |

### `sort` değerleri
- **tab=mekan:** `distance` (konum verildiyse VARSAYILAN) · `relevance` (konum yoksa varsayılan).
- **tab=yemek:** `distance` (konum verildiyse VARSAYILAN) · `price_asc` · `price_desc` · `likes` (konum yoksa varsayılan).

> Konum yoksa `distance` istense bile varsayılana düşülür. Boş fiyat/mesafe her
> iki yönde de **sona** atılır. Eşitlikte ikincil sıra `id` (sayfa-tutarlı).

## `mesafe_m` (metre, tam sayı)
Konum verildiğinde eklenir:
- **tab=mekan:** öğenin köküne — `{ "id":1038, ..., "mesafe_m":2203 }`
- **tab=yemek:** `mekan` bloğuna — `{ ..., "mekan":{ ..., "mesafe_m":1866 } }`

Konum yoksa alan eklenmez.

## meta (güncel)
```json
"meta": {
  "q": "köfte", "tab": "yemek",
  "sort": "price_asc",
  "filtreler": [109, 112],
  "has_coord": true,
  "page": 1, "limit": 20, "total": 12, "pages": 3
}
```

## Performans / Redis
- Önbellek anahtarı artık `tab`, `sort`, `filtreler` ve **yuvarlanmış konumu**
  (2 ondalık ≈ ~1.1 km kova) içerir → her metrede yeni anahtar oluşmaz.
- Mesafe/fiyat/filtre istendiğinde sıralama **tüm sonuç kümesi** üzerinde
  sunucuda yapılır (sayfa-tutarlı), sonra sayfalanır. Alaka (mekan) / beğeni
  (yemek) doğal sıra ise ES/DB sayfalı gider.
- `tab=yemek` eşleşen ürün kümesi tek sorguda (üst sınır 800) çekilir; yzd_qr
  küçük olduğundan hızlıdır. `tab=mekan` tam-küme yolunda aday üst sınırı 500.
- Mesafe Haversine ile hesaplanır (ES geo_point gerekmez; fail-open korunur).

## Örnek istekler
```
# Mekanlar — en yakın
GET /rest/arama?q=kahve&tab=mekan&lat=41.02&lng=28.98&sort=distance

# Yemekler — fiyat artan + filtre
GET /rest/arama?q=köfte&tab=yemek&sort=price_asc&filtreler=109,112

# Yemekler — en yakın (konum verilince varsayılan)
GET /rest/arama?q=köfte&tab=yemek&lat=41.02&lng=28.98
```

## Doğrulama (canlı)
- yemek `price_asc`: 400→420→445→465→500 ✓ · `price_desc`: 2500→1250→620… ✓
- yemek `distance`: Swanky 1866m → Kemer 16329m → Yılmaz 17446m ✓
- mekan `distance`: 9 Kahve Tophane 2203m → Koyu Kahve 5994m ✓
- filtre AND: `109`→12, `100,109`→12, `109,112`→4 ✓

## Gelecek optimizasyon (şimdilik gerekli değil)
`istek.md`'de önerilen kalıcı sayısal fiyat kolonu (`fiyat_num DECIMAL`) + index ve
ek DB index'leri **şu an uygulanmadı**: yzd_qr tablosu küçük olduğundan fiyat
metinden ayrıştırılıp (`Helpers::parsePrice`) sunucuda sıralanıyor ve yeterince
hızlı. Ürün sayısı belirgin büyürse (ör. on binler) şu adımlar eklenebilir:
- `yzd_qr.fiyat_num DECIMAL(10,2)` kolonu + tetikleyici/senkron ile doldurma,
- `yzd_qr(post_id)` ve fiyat/koordinat alanlarında index,
- `tab=yemek` için ES'e ürün-seviyesi (dish) indeksi.
