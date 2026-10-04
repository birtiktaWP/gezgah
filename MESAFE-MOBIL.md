# Mesafe gösterimi — mobil uygulama rehberi

**Tarih:** 5 Ekim 2026
**API:** `https://api.gezgah.com/rest` (mevcut kimlik başlıkları aynı: `X-App-Key` + `Authorization: Bearer <token>`)

## Özet

Sunucu artık mesafeyi **kuş uçuşu değil, tahmini yol mesafesi** olarak hesaplıyor. Boğaz geçişleri (15 Temmuz, FSM, Yavuz Sultan Selim köprüleri, Avrasya Tüneli) ve şehir içi yol dolanması hesaba katılıyor.

Örnek: Beşiktaş → Üsküdar kuş uçuşu 2,0 km, sunucunun tahmini 7,6 km.

Uygulamanın **mesafeyi kendisi hesaplamaması** gerekiyor. Şu an bazı ekranlar sunucunun değerini, bazıları uygulamanın kendi kuş uçuşu hesabını gösteriyor. Aynı mekan listede 31 km, detayda 24 km görünüyor (ör. Poseidon Anadolu Feneri, Üsküdar'dan).

**Yapılacaklar:**
1. Mesafe gösteren her istekte kullanıcının konumunu `lat` ve `lng` olarak gönder.
2. Ekranda yalnız sunucunun döndürdüğü mesafe alanını göster.
3. Uygulamadaki Haversine / kuş uçuşu mesafe hesabını kaldır (ya da yalnız aşağıdaki yedek durum için tut).

---

## 1. Mekan detayı — YENİ alanlar

```
GET /mekanlar/{id}?lat=41.0255&lng=29.0153
```

`lat` ve `lng` gönderilirse yanıta iki alan eklenir:

| Alan | Tür | Açıklama |
|---|---|---|
| `mesafe_m` | int \| null | Tahmini yol mesafesi, metre |
| `mesafe_km` | float \| null | Aynı değer, km (2 ondalık) |

- Mekanın koordinatı yoksa ikisi de `null` gelir.
- `lat`/`lng` gönderilmezse alanlar **hiç gelmez** (eski davranış).
- Bu değer konuma bağlı olduğu için sunucuda önbelleğe alınmaz, her istekte taze hesaplanır.

```json
{
  "success": true,
  "data": {
    "id": 4740,
    "ad": "Poseidon Anadolu Feneri Restaurant",
    "kordinat": "41.217226, 29.152456",
    "mesafe_m": 31483,
    "mesafe_km": 31.48
  }
}
```

**Detay sayfasında:** `kordinat`'tan mesafe hesaplamayı bırak, `mesafe_km` alanını göster.

---

## 2. Yakındakiler

```
GET /mekanlar/yakindakiler?lat=41.0255&lng=29.0153&limit=20[&radius=5][&type=restoran]
```

| Alan | Tür | Açıklama |
|---|---|---|
| `mesafe_km` | float | Tahmini yol mesafesi, km. **Bunu göster.** |
| `kus_ucusu_km` | float | YENİ, yalnız bilgi amaçlı. Ekranda gösterme. |

- Liste sunucuda `mesafe_km`'ye göre **en yakından uzağa sıralı** gelir. Uygulamada tekrar sıralama.
- `radius` (km) de yol tahminine göre uygulanır.
- `type`: `restoran` (varsayılan), `mesire`, `plaj`, `otopark`, `muze`, `all`.

> **Önemli:** Bu uç `lat`/`lng` **olmadan** çağrılırsa "havuz modu"nda çalışır: tüm mekanlar `enlem`/`boylam` ile döner, **mesafe gelmez** ve sıralama yapılmaz. Mesafe göstereceksen bu uca her zaman konum gönder.

---

## 3. Arama

```
GET /arama?q=kahve&lat=41.0255&lng=29.0153
```

- Mekan sonuçlarında `mesafe_m` (metre) artık tahmini yol mesafesidir.
- "Yemekler" sekmesindeki ürün sonuçlarında mekan mesafesi `mesafe` alanında, yine metre ve aynı hesapla gelir.
- Konum varsa varsayılan sıralama mesafeye göredir. Arama Elasticsearch üzerinden yapıldığında sıralama kuş uçuşuna göre yapılır, gösterilen `mesafe_m` ise yol tahminidir. Bu yüzden listede nadiren bir mekan, kendisinden biraz daha yakın görünen bir mekanın önünde çıkabilir; bu bilinen bir durum.

---

## 4. Gezi rotaları

| Alan | Nerede | Açıklama |
|---|---|---|
| `mesafe_m` | Keşfet listesi (`?lat=&lng=` ile) | Kullanıcıdan rotanın ilk durağına tahmini yol, metre |
| `toplam_mesafe_m` | Rota detayı | Rotanın gerçek yol uzunluğu (Google Directions), metre. Değişmedi. |

---

## 5. Ekranda gösterim

Tüm ekranlarda aynı biçimi kullan:

| Mesafe | Gösterim | Örnek |
|---|---|---|
| < 1 km | 50 m'ye yuvarla, metre | `350 m` |
| 1–10 km | 1 ondalık | `7,6 km` |
| ≥ 10 km | tam sayı | `31 km` |
| `null` / alan yok | gösterme | — |

Değer tahmini olduğu için istersen başına `≈` koyabilirsin (`≈ 7,6 km`).

```dart
String? mesafeMetni(num? km) {
  if (km == null) return null;
  if (km < 1) {
    final m = ((km * 1000) / 50).round() * 50;
    return '${m < 50 ? 50 : m} m';
  }
  if (km < 10) return '${km.toStringAsFixed(1).replaceAll('.', ',')} km';
  return '${km.round()} km';
}
// mesafe_m gelen yerlerde: mesafeMetni(mesafeM == null ? null : mesafeM / 1000)
```

---

## 6. Konum ve yenileme

- Konumu ilk açılışta al. Kullanıcı **200 m'den fazla** hareket ettiyse listeleri ve açık detay sayfasını yeniden iste.
- Konum izni yoksa `lat`/`lng` gönderme ve mesafeyi **hiç gösterme**. Varsayılan bir konum (ör. Taksim) uydurma.
- Sunucu "yakındakiler" sonuçlarını konumu ~110 m'ye yuvarlayarak 5 dakika önbellekte tutar. Birkaç metrelik GPS oynamasında yeni istek atmaya gerek yok.

## 7. Yedek durum (çevrimdışı vb.)

Sunucudan mesafe alınamazsa (ağ hatası, eski önbellek) iki seçenek var. Öncelik sırasıyla:
1. Mesafeyi gösterme.
2. Kendi kuş uçuşu hesabını **× 1,3** ile çarpıp `≈` ile göster.

Saf kuş uçuşu gösterme; Boğaz'ın karşı yakasındaki mekanları 2–4 kat yakın gösterir.

---

## 8. Test

Üsküdar konumu (`lat=41.0255&lng=29.0153`) ile:

| Kontrol | Beklenen |
|---|---|
| `GET /mekanlar/4740?lat=41.0255&lng=29.0153` | `mesafe_km` ≈ 31,48 |
| `GET /arama?q=poseidon&lat=41.0255&lng=29.0153` | aynı mekanda `mesafe_m` ≈ 31483 |
| `GET /mekanlar/1231?lat=41.0255&lng=29.0153` (Fıstık Kebap, Beşiktaş) | `mesafe_km` ≈ 5,97 (kuş uçuşu 2,7) |
| Aynı mekan liste ve detayda | **aynı** mesafe |
| Konum izni kapalı | hiçbir ekranda mesafe yok |
