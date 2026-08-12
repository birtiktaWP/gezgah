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
