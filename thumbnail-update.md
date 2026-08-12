# Thumbnail Güncellemesi — Mobil API (liste/kart görselleri)

Liste/kart görselleri artık **önceden üretilmiş, merkez-crop thumbnail** olarak
sunuluyor. Amaç: mobilde hızlı yükleme + `thumbnail-spec.md`'deki kadrajla birebir
uyum. Orijinal görseller korunuyor; thumbnail'ler **yalnızca galeri sisteminde
ÖNE ÇIKARILAN (is_featured) görseller** için üretildi.

---

## 1) Yeni yanıt alanları

Liste/özet uçlarındaki her öğede (mekan) ve yemek sonucundaki `mekan` bloğunda:

| Alan         | Tip           | Açıklama |
|--------------|---------------|----------|
| `image`      | string/null   | **Asıl görsel** (tam çözünürlük). Detay/hero ve genel yedek. |
| `thumbnail`  | string/null   | Liste için **küçük** görsel = `thumbnails.square` (yoksa `image`). |
| `thumbnails` | object/null   | `{ square, card, wide }` thumbnail URL'leri. Öne çıkan görsel yoksa **null**. |

### `thumbnails` boyutları (WebP, düz dikdörtgen, merkez-crop)
| Anahtar  | Boyut (px)  | Oran      | Nerede kullan |
|----------|-------------|-----------|----------------|
| `square` | 360 × 360   | 1:1       | Arama (56²), kategori liste (108²), favoriler/etkinlik (110²), harita kartı |
| `card`   | 520 × 360   | ~1.45:1   | Ana sayfa PopCard (168×116) |
| `wide`   | 1080 × 500  | ~2.15:1   | Ana sayfa büyük kart / kategori sponsorlu banner |

> Tümü **merkezden kırpılmış** (cover/center) ve düz dikdörtgen — köşe yuvarlama,
> gölge, padding **yok** (uygulama tarafında uygulanır). ~3x fiziksel çözünürlük.

---

## 2) Örnek yanıt

```json
{
  "id": 1038,
  "name": "9 Kahve Tophane",
  "image": "https://gezgah.com/uploads/dd1dafd786e948de631b29c46f13fba7.jpeg",
  "thumbnail": "https://gezgah.com/uploads/thumbs/square/dd1dafd786e948de631b29c46f13fba7.webp",
  "thumbnails": {
    "square": "https://gezgah.com/uploads/thumbs/square/dd1dafd786e948de631b29c46f13fba7.webp",
    "card":   "https://gezgah.com/uploads/thumbs/card/dd1dafd786e948de631b29c46f13fba7.webp",
    "wide":   "https://gezgah.com/uploads/thumbs/wide/dd1dafd786e948de631b29c46f13fba7.webp"
  }
}
```

Yemek sonucunda aynı alanlar `mekan` bloğunda döner:
```json
{
  "urun_id": 820, "urun": "Köfte Wrap", "fiyat": "420", "gorsel": "https://qr.gezgah.com/img.php?t=g&f=...jpg",
  "mekan": {
    "id": 1099, "ad": "Swanky İstanbul",
    "image": "https://gezgah.com/uploads/....jpeg",
    "thumbnail": "https://gezgah.com/uploads/thumbs/square/....webp",
    "thumbnails": { "square": "...", "card": "...", "wide": "..." }
  }
}
```

---

## 3) Ekran → hangi alan kullanılmalı

| Ekran / Kart | Kullanılacak alan |
|--------------|-------------------|
| Arama — Mekanlar (56²) | `thumbnails.square` |
| Arama — Yemekler (mekan görseli) | `mekan.thumbnails.square` (ürünün kendi `gorsel`'i varsa onu tercih et) |
| Kategori liste (108²), Favoriler (110²), Etkinlik (110²), Harita kartı | `thumbnails.square` |
| Ana sayfa PopCard (Yakındakiler/Yeni Eklenenler, 168×116) | `thumbnails.card` |
| Ana sayfa büyük kart / kategori sponsorlu banner | `thumbnails.wide` |
| Detay hero (tam genişlik × 350) | `image` (thumbnail DEĞİL) |

Hepsinde `BoxFit.cover` + `Alignment.center` kullanmaya devam et — thumbnail oranı
kutu oranıyla aynı olduğundan ekstra kırpma olmaz, kadraj birebir olur.

---

## 4) Yedekleme (fallback) kuralı — ÖNEMLİ

`thumbnails` **null olabilir** (o mekanın galeride öne çıkarılmış görseli yoksa).
Bu durumda:

```
görsel = thumbnails?.{istenen boyut}  ??  thumbnail  ??  image  ??  (placeholder)
```

Yani: istenen kanonik boyutu dene → yoksa `thumbnail` → yoksa `image` → yoksa
yer tutucu. Yemek sonucunda ürünün kendi `gorsel` alanı varsa onu, yoksa
`mekan.thumbnails/thumbnail`'ı kullan.

---

## 5) Notlar

- Thumbnail'ler `https://gezgah.com/uploads/thumbs/{square|card|wide}/<dosya>.webp`
  altında statik dosya olarak sunulur (CDN/cache dostu, `image/webp`).
- Yalnız **öne çıkarılan** galeri görselleri için üretildi; diğer görseller için
  `thumbnails` gelmez (o mekanlar için `image` kullanılır).
- Bu değişiklik yalnız **yeni alan ekler**; mevcut `image`/`thumbnail` alanları
  bozulmadı → geriye dönük uyumlu. İstersen kademeli geçebilirsin.
- Kapsayan uçlar: `/mekanlar`, `/mekanlar/yakindakiler`, `/mekanlar/yeni-eklenenler`,
  `/one-cikan-firmalar`, `/pagination_isletmeler`, `/yerler`, `/arama` (mekan+yemek),
  `/kategoriler/{id}/mekanlar`, favoriler uçları. Detay (`/mekanlar/{id}`) tam
  çözünürlük `image` + `galeri` döndürmeye devam eder.
