# Mekan detayı üst görseli — kare galeri görseli (backend)

Mekan detayı açılırken üst görsel önce listenin küçük görseliyle anında görünüyor, sonra büyük fotoğraf geliyor. Büyük fotoğraf gelince "boyut / zoom değişiyor" sorunu vardı. Uygulama tarafı düzeltildi; tam ve hızlı çözüm için backend'den tek bir alan isteniyor.

Base URL: `https://api.gezgah.com/rest` · Uç: `GET /mekanlar/{id}` → `data.galeri[]`.

## 1. Neden oluyordu (ölçüldü)

- Liste kartlarının kare küçük görseli (`thumbnail` / `thumbnails.square`, 360×360 WebP) sunucuda orijinalin **tam ortasından kare kırpılıyor**. 6 mekanda orijinalden üretilen orta / üst / alt kırpımla piksel farkı ölçüldü: orta ≈ 3, diğerleri 36–75. Yani kırpım doğru ve tutarlı.
- Detaydaki büyük görsel ise `galeri[].url` **orijinal** dosya: 1360×2040, 2720×1540, 3840×2160 gibi farklı oranlarda ve 340 KB – 1,4 MB.
- Üst görsel alanı ≈390×350. Kare önizleme ile farklı oranlı orijinal bu alana farklı kırpılınca kadraj değişiyordu. Yatay fotoğraflarda fark %11–23 zoom.

## 2. Uygulamada yapılan (bu sürüm)

- Üst görselin tüm sayfaları artık **ortadan kare kadrajla** çiziliyor: görsel, alanın uzun kenarı kadar bir kareye `cover` ile yerleşip ortalanıyor. Bu, sunucunun kare küçük görseliyle aynı kırpım. Önizleme ve büyük görsel aynı alanı gösteriyor; geçişte zoom/kayma yok, yalnız netleşme var.
- Önizleme altta kalıyor, büyük görsel üstte 350 ms'de beliriyor (gri boşluk / yeniden yükleme yok).
- Kalan sorun **hız**: büyük katman hâlâ orijinali (1,4 MB'a kadar) indiriyor. Yavaş bağlantıda netleşme saniyeler sürebiliyor.

## 3. İstenen: `galeri[].kare`

Her galeri fotoğrafı için yüklemede (ve mevcutlara bir kerelik) **ortadan kare kırpılmış** hafif bir sürüm üretip `galeri[]` öğesine ekleyin:

```json
"galeri": [
  {
    "id": 2895,
    "url": "https://gezgah.com/uploads/2f7ad912633251ecb554b38acb999aa8.jpg",
    "thumbnail": "https://gezgah.com/uploads/2f7ad912633251ecb554b38acb999aa8.jpg",
    "kare": "https://gezgah.com/uploads/thumbs/2f7ad912633251ecb554b38acb999aa8_kare.webp",
    "mime_type": "image/jpeg",
    "is_featured": true
  }
]
```

| Kural | Değer |
|---|---|
| Kırpım | **Ortadan kare**: kenar = `min(genişlik, yükseklik)`, merkez hizalı. Mevcut `thumbnails.square` ile **aynı algoritma** olmalı; aksi halde önizleme ↔ büyük geçişinde kadraj kayar |
| Boyut | 1080×1080. Orijinal 1080'den küçükse büyütmeyin, kendi kare boyutunda bırakın |
| Biçim | WebP, kalite ~80 (beklenen 80–150 KB) |
| EXIF | Yönlendirmeyi (orientation) kırpmadan **önce** uygulayın; yan dönük fotoğraf kırpılmasın |
| Adres | Mutlak URL. Dosya adı içerik değişince değişmeli (önbellek `max-age=604800`) |
| Video öğeleri | `kare` göndermeyin |
| Yoksa | Alanı göndermeyin ya da `null`. Uygulama orijinale düşer |

Ayrıca `image` (öne çıkan) galeride yoksa aynı kuralla `image_kare` da eklenebilir (isteğe bağlı; bugün kontrol edilen tüm mekanlarda `image` galerinin içinde).

## 4. Uygulama nasıl kullanıyor

- `GaleriItem.fromJson` → `kare` (`lib/data/models.dart`). **Bu sürümde zaten okunuyor**; alan eklenince yeni uygulama sürümü gerekmeden üst görsel `kare`'yi kullanır.
- Üst görsel şeridi: `kare` varsa o, yoksa `url`.
- Tam ekran görüntüleyici (yakınlaştırma) ve galeri ızgarası **orijinal `url`'i** kullanmaya devam eder; `url`'i küçültmeyin.

## 5. Kontrol

```
GET /mekanlar/5323   (yatay 3840×2160)
→ galeri[0].kare ≠ galeri[0].url
→ kare dosyası 1080×1080 WebP, ≤ ~150 KB
→ kare'nin 360 px'e küçültülmüşü ile thumbnails.square arasında görsel fark yok (aynı kırpım)
```

Test için repodaki ölçüm yaklaşımı: orijinalden ortadan kare kırpıp küçük görselle piksel farkına bakmak (fark ≈ 0–5 olmalı).
