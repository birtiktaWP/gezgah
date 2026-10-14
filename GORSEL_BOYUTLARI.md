# Görsel boyutları — backend

Mekan detayındaki görseller geç açılıyor. Uygulama tarafındaki düzeltmeler yapıldı (detay isteği konumu beklemiyor, listenin küçük görseli anında gösteriliyor, görseller ekran boyutuna küçültülerek açılıyor). Kalan gecikme dosya boyutundan geliyor ve backend'de çözülmeli.

Ölçüm: canlı API, 14 Ekim 2026. Dosyalar Cloudflare üzerinden `max-age=604800` ile geliyor, önbellek ayarı sorun değil.

## 1. `galeri[].thumbnail` gerçek küçük sürüm olmalı (en büyük kazanç)

Bugün `GET /mekanlar/{id}` → `galeri[]` içinde `thumbnail`, `url` ile **aynı adres**. Örnek #4745: üç fotoğraf da 1440×1920 JPEG, 339–787 KB. Uygulama detayın üst görselinde bu orijinali indiriyor.

İstenen: her galeri fotoğrafı için yüklemede küçük sürüm üretilip `thumbnail`'a yazılsın.

| Alan | Boyut | Biçim | Kullanım |
|---|---|---|---|
| `thumbnail` | uzun kenar 1080 px | WebP, kalite ~80 | detay üst görsel, galeri ızgarası |
| `url` | orijinal | — | tam ekran yakınlaştırma |

Beklenen: fotoğraf başına ~80–150 KB (bugün 340–790 KB). Alan geldiğinde uygulama tarafında küçük bir değişiklikle detay `thumbnail`'ı kullanacak, tam ekran `url`'i.

## 2. `/kategoriler/{id}` da `thumbnails{}` göndersin

| Uç | `thumbnail` (360×360 WebP) | `thumbnails{square,card,wide}` |
|---|---|---|
| `GET /mekanlar` | var | var (100 kayıttan 99'u) |
| `GET /kategoriler/{id}` | var (60 kayıttan 58'i) | **yok (60/60)** |

Kategori listesi bugün her kart için 360 px kareyi kullanıyor; geniş kartlarda bulanık görünebilir. Aynı `thumbnails` nesnesini (`MekanController::summary()` ne üretiyorsa) bu uca da ekleyin. `thumbnail`'ı olmayan 2 kayıt orijinale (1,4 MB PNG) düşüyor; onlar için de üretilmeli.

## 3. Fotoğraflar PNG olarak saklanmasın

Liste kayıtlarında `image` (öne çıkan görsel) çoğunlukla PNG: `/kategoriler/4787` 60 kayıttan 32'si, `/mekanlar` 100 kayıttan 97'si. Örnek: 979×1306 PNG, 1,3–1,45 MB. Aynı fotoğraf JPEG/WebP olarak ~150–300 KB.

İstenen: yeni yüklemelerde fotoğraflar WebP'ye (ya da JPEG'e) çevrilsin; mevcutlar için bir kerelik toplu dönüştürme. Şeffaflık gereken logo vb. PNG kalabilir.

## Kontrol

```
GET /mekanlar/4745        → galeri[].thumbnail ≠ galeri[].url, dosya ≤ ~150 KB
GET /kategoriler/4787     → mekanlar[].thumbnails.{square,card,wide} dolu
```
