# Thumbnail Spec — Liste/Kart Görsel Boyutları & Crop

Mobil uygulamada mekan/ürün görsellerinin **ekranda kapladığı alanlar** ve
**kırpma (crop) davranışı**. Backend thumbnail üretirken bu en-boy oranlarına
**merkezden kırparsa (center-crop)** uygulamadaki görüntüyle **birebir aynı**
kadraj elde edilir.

---

## 0) Genel kural (çok önemli)

- Uygulamadaki **tüm** liste/kart görselleri `BoxFit.cover` + **merkez hizalama
  (Alignment.center)** ile çizilir → yani her görsel **merkezden kırpılır**,
  taşan kenarlar kesilir, boşluk bırakılmaz.
- Dolayısıyla thumbnail, hedef **en-boy oranına merkezden kırpılmış** olmalı.
  Thumbnail'in oranı ekrandaki kutunun oranıyla **aynıysa**, uygulama ekstra
  kırpma yapmaz → kadraj birebir aynı olur.
- **Köşe yuvarlama uygulama tarafında yapılır.** Thumbnail düz dikdörtgen
  olmalı — yuvarlak köşe/gölge/padding **gömülmemeli**.
- Kaynak görselin ODAK noktası önemliyse (ör. yemek ortada değilse) merkez-crop
  kadrajı bozabilir; şimdilik tüm uygulama merkez-crop kullanıyor, backend de
  merkez-crop üretmeli (tutarlılık için).

## Yoğunluk (DPR)
Boyutlar **logical pixel** (pt). iPhone'lar @2x/@3x olduğundan thumbnail'ler
**fiziksel piksel** olarak üretilmeli. Öneri: **logical × 3** (retina için net).
Tek bir büyük thumbnail üretip her yerde kullanmak yerine, aşağıdaki 3 kanonik
oran yeterli.

---

## 1) Ana Sayfa (home)

| Kart | Görsel alanı (logical WxH) | Oran | Crop |
|------|----------------------------|------|------|
| **PopCard** — "Yakındakiler", "Yeni Eklenenler" rail'i | **168 × 116** | ~1.45:1 (42:29) | cover / merkez |
| **Büyük kart** — "Sponsorlu Restoranlar", "Öne Çıkan Etkinlikler" | genişlik = ekran genişliği × **0.84**, yükseklik **150** | cihaza bağlı (~2.1–2.2:1) | cover / merkez |

> Büyük kartın genişliği cihaz ekranına göre değişir → oran sabit değildir.
> Bu yüzden geniş bir thumbnail üretilip uygulama cover ile ince ayar kırpar;
> ~**2.15:1** hedeflemek yeterli.

## 2) Kategori / Listeleme sayfası (CategoryScreen)

| Kart | Görsel alanı (logical WxH) | Oran | Crop |
|------|----------------------------|------|------|
| **ListTileCard** (standart liste öğesi) | **108 × 108** | 1:1 (kare) | cover / merkez |
| **ListTileCard — sponsorlu varyant** | genişlik = kart tam genişliği (ekran − 44), yükseklik **160** | cihaza bağlı (~2.1:1) | cover / merkez |

## 3) Arama sayfası (search)

| Kart | Görsel alanı (logical WxH) | Oran | Crop |
|------|----------------------------|------|------|
| **Mekan sonucu** (Mekanlar sekmesi) | **56 × 56** | 1:1 (kare) | cover / merkez |
| **Yemek sonucu** (Yemekler sekmesi) | **56 × 56** | 1:1 (kare) | cover / merkez |

## 4) Diğer (aynı thumbnail'ler yeniden kullanılır)

| Ekran | Görsel alanı (logical WxH) | Oran |
|-------|----------------------------|------|
| Favoriler satırı | 110 × 110 | 1:1 |
| Etkinlikler satırı | 110 × 110 | 1:1 |
| Harita alt kartı | 120 × 130 | ~0.92:1 (hafif dikey) |
| Detay üst görsel (hero) | tam genişlik × 350 | cover (detay — thumbnail değil, tam görsel kullanılmalı) |

---

## 5) Backend'in üreteceği kanonik thumbnail'ler (öneri)

Üç oran tüm liste/kart ihtiyacını karşılar (hepsi **merkez-crop**, düz
dikdörtgen, ~3x fiziksel):

| Ad | Oran | Önerilen fiziksel boyut | Kullanım |
|----|------|-------------------------|----------|
| `square` | **1:1** | **360 × 360** | Arama (56), kategori liste (108), favoriler/etkinlik (110), harita (~kare kabul) |
| `card`   | **~1.45:1 (42:29)** | **520 × 360** | Ana sayfa PopCard (168×116) |
| `wide`   | **~2.15:1** | **1080 × 500** | Ana sayfa büyük kart + kategori sponsorlu (tam genişlik banner) |

- Küçük alanlar (56, 108, 110) hep 1:1 → **tek `square`** thumbnail hepsini
  besler; uygulama küçültüp cover ile gösterir (oran aynı olduğundan kırpma yok).
- Detay hero (tam genişlik × 350) için thumbnail değil, **yüksek çözünürlüklü
  asıl görsel** kullanılmalı (ör. genişlik ≥ 1080).

---

## 6) Uygulama entegrasyon notu

- Uygulama görselde önce `image`, yoksa `thumbnail` alanını kullanır ve
  `BoxFit.cover` ile çizer. Liste/kartlarda küçük thumbnail, detayda büyük
  görsel istiyorsak: liste yanıtlarında `thumbnail` bu spec'e göre üretilmiş
  **küçük** URL, `image` ise detay için **büyük** URL olabilir.
- Öneri: liste/özet uçlarında (`/mekanlar`, `/yerler`, `/arama`,
  `/kategoriler/{id}`...) `thumbnail` = uygun kanonik boyut; detay ucunda
  (`/mekanlar/{id}`) `image`/`galeri` = tam çözünürlük.
- Thumbnail formatı: WebP (küçük boyut) veya JPEG q~75; köşe/gölge yok.

---

## 7) Özet (backend agent için)

1. Tüm liste görselleri **merkezden kırpılır** (cover, center). Thumbnail'i hedef
   orana **merkez-crop** üret.
2. Üç oran yeterli: **1:1 (360²)**, **42:29 (520×360)**, **~2.15:1 (1080×500)**.
3. Köşe yuvarlama / padding / gölge **gömme** — düz dikdörtgen.
4. Detay ekranı için tam çözünürlüklü asıl görseli ayrıca sun.
