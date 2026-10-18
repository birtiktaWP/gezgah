# Liste uç noktalarına `mesafe_m` eklenmesi

## Sorun

Mobil uygulama artık km'yi kendisi tahmin etmiyor. Sadece backend'in gönderdiği `mesafe_m` / `mesafe_km` gösteriliyor.

Detay (`/mekanlar/{id}?lat=&lng=`) mesafeyi doğru dönüyor. Liste uç noktaları ise lat/lng gönderilse bile mesafe dönmüyor. Bu yüzden listelerde ve harita kartında km şu an boş kalıyor.

Canlı kontrol (konum Üsküdar 41.0255, 29.0153):

| Mekan | Eski uygulama tahmini (kuş uçuşu ×1.3) | Detay `mesafe_km` (doğru) |
|---|---|---|
| Ghala #5321 | 15.8 | 16.33 |
| The Göbektaşı #5318 | 9.5 | 16.08 |
| Olden 1772 #5314 | 4.7 | 12.86 |
| Aya Nikola #1562 | 27.5 | 24.36 |

`/kategoriler/4807?lat=..&lng=..` ve `/yerler?type=plaj&lat=..&lng=..` yanıtlarında `mesafe_m` yok.

## İstek

Detayda kullanılan hesaplamanın aynısıyla aşağıdaki yanıtlardaki her mekan objesine `mesafe_m` (int, metre) ve `mesafe_km` (float, 2 hane) ekleyin:

- `GET /kategoriler/{id}`: `mekanlar[]` ve `sabit_restoran`
- `GET /kategoriler/{id}/mekanlar`
- `GET /yerler`
- `GET /harita`
- `GET /mekanlar` (arama / liste)
- `GET /mekanlar/yeni-eklenenler`
- Anasayfa sponsorlu / öne çıkan listeleri

Kurallar:

- Algoritma detaydakiyle aynı olmalı. Aynı mekan için liste ve detay aynı km'yi göstermeli.
- `lat`/`lng` gelmezse veya mekanın koordinatı yoksa `mesafe_m: null`, `mesafe_km: null` dönün. Alanı hiç göndermemek de olur, uygulama ikisini de "km yok" olarak işler.
- Uygulama tüm bu isteklerde `lat` ve `lng` query parametrelerini zaten gönderiyor (`/harita` dahil).

## Opsiyonel: mesafeye göre sıralama

Kategori listesinde "Yakınlık" sıralaması şu an uygulamada, sayfa sayfa ve kuş uçuşu ile yapılıyor. Bu yalnızca sıralama için, ekranda gösterilmiyor. `lat`/`lng` geldiğinde backend'de `?sira=yakinlik` (veya mevcut sıralama parametresi) ile tüm sonuç kümesi mesafeye göre sıralanırsa sayfalar arası tutarlılık sağlanır.

## Mobil tarafı

Uygulama sürümü gerekmiyor. Alan eklendiği anda mevcut sürüm km'yi gösterir (`mesafe_m` ya da `mesafe_km` okunuyor).

## Kontrol

```
GET /kategoriler/4807?lat=41.0255&lng=29.0153
```

Her `mekanlar[].mesafe_m` değeri, aynı mekan için şununla aynı olmalı:

```
GET /mekanlar/{id}?lat=41.0255&lng=29.0153
```
