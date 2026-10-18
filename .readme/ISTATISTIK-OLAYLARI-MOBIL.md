# İşletme istatistikleri: yeni olaylar (mobil)

**Tarih:** 5 Ekim 2026
**Uç:** mevcut `POST https://api.gezgah.com/rest/istatistik/goruntulenme` (yeni uç yok, başlıklar ve gövde biçimi aynı)

Bu olaylar işletmenin Gezgah Pro panelindeki **Gezgah Raporları** kartlarını besler. Sunucu tarafı hazır ve canlıda test edildi.

| Pro kartı | Uygulamanın göndereceği olay | Durum |
|---|---|---|
| Listeleme | `tip: "liste"` + `kaynak` | Kategori ve tip listeleri zaten gönderiyor. **Arama sonuçları eklenecek** |
| Tıklanma | `tip: "detay"` | Zaten gönderiliyor, değişiklik yok |
| QR Tıklama | `tip: "qr"` | **YENİ** |
| Yol Tarifi | `tip: "yol_tarifi"` | **YENİ** |
| Rezervasyon, Favori | — | Sunucu kendi tablolarından sayıyor, uygulamada iş yok |

Mevcut kuyruk, toplu gönderim (20 olay / 15 sn / arka plana geçerken) ve hata kodu davranışları (404, 429, 5xx) **aynen** geçerli. Sadece kuyruğa yeni olay türleri ekleniyor.

---

## 1. Listeleme: arama sonuçları

Arama sonuç listesinde görünen her mekan kartı için, kategori listesindeki kuralla aynı şekilde `liste` olayı gönder:

- Kart ekranda en az %50 görünür halde 1 sn kalırsa sayılır.
- Aynı arama sonuç ekranında bir mekan bir kez sayılır. Yeni bir arama yapılırsa yeniden sayılır.

```json
{ "mekan_id": 4740, "tip": "liste", "kaynak": "arama", "kaynak_id": "poseidon", "sira": 0, "zaman": "2026-10-05T11:22:05.123Z" }
```

| Alan | Değer |
|---|---|
| `kaynak` | `"arama"` (sabit) |
| `kaynak_id` | Aranan metin, **en fazla 32 karakter** (uzunsa kırp). Boş arama ya da filtreli listede gönderme |
| `sira` | Sonuç listesindeki 0 tabanlı konum |

Kurallar:
- Sadece **mekan** sonuçları sayılır. "Yemekler" sekmesindeki ürün kartlarını gönderme.
- Kategori listesi (`kaynak: "kategori"`) ve tip listesi (`kaynak: "tip"`) bugünkü gibi kalır.
- İleride ana sayfa ya da harita listeleri eklenirse aynı biçimle `kaynak: "ana_sayfa"` ya da `kaynak: "harita"` kullan. Sunucu `^[a-z_]{1,20}$` desenine uyan her kaynağı kabul eder.

---

## 2. QR Tıklama — `tip: "qr"`

Kullanıcı bir mekanın **QR menüsünü açtığında** bir olay gönder:

- Detay sayfasındaki "QR Menü" / "Menü" butonuna basınca
- Uygulamanın QR okuyucusuyla bir Gezgah QR'ı okutulup menü açılınca

```json
{ "mekan_id": 4740, "tip": "qr", "zaman": "2026-10-05T11:23:10.002Z" }
```

- `kaynak`, `kaynak_id`, `sira` gönderme (sunucu yok sayar).
- Menü açılamazsa (ağ hatası vb.) da gönderebilirsin. Sayılan şey kullanıcının niyeti.

## 3. Yol Tarifi — `tip: "yol_tarifi"`

Kullanıcı bir mekan için **yol tarifi başlattığında** bir olay gönder:

- Detaydaki "Yol Tarifi" butonuna basınca
- Harita / Apple Haritalar / Google Maps / Yandex seçimi çıkıyorsa **seçim yapıldığında** (seçim penceresi kapatılırsa gönderme)
- Harita ekranındaki mekan kartından yol tarifi açılınca

```json
{ "mekan_id": 4740, "tip": "yol_tarifi", "zaman": "2026-10-05T11:24:41.550Z" }
```

**Önemli:** Yol tarifi harici bir harita uygulamasını açar ve Gezgah arka plana geçer. Olayı harita uygulamasını açmadan **önce** kuyruğa ekle. Arka plana geçişteki mevcut gönderim olayı o zaman götürür.

```dart
await Istatistik.ekle(mekanId: mekan.id, tip: 'yol_tarifi'); // önce kuyruğa
await launchUrl(haritaUrl, mode: LaunchMode.externalApplication);
```

---

## 4. Sunucu tarafı (bilgi)

- Tekilleştirme: aynı cihaz, aynı mekan ve aynı tip için **30 dakikada tek sayım**. Kullanıcı QR butonuna 5 kez bassa da 1 sayılır. Uygulamada ayrıca tekilleştirme yapmana gerek yok.
- Bilinmeyen `tip` değeri olan olay atlanır, istek yine 200 döner. Bu yüzden eski sunucuyla bile uygulama bozulmaz.
- Yanıt: `{ "kabul": n, "atlanan": m }`.

## 5. Test

| Adım | Beklenen |
|---|---|
| Arama yap, sonuçlarda 1 sn bekle | İstekte `tip: "liste"`, `kaynak: "arama"` olayları |
| Detayda QR menüyü aç | `tip: "qr"` olayı |
| Detayda yol tarifine bas, harita uygulamasını seç | Harita açılmadan önce `tip: "yol_tarifi"` kuyrukta, arka plana geçişte gönderildi |
| Aynı mekanda QR'a 30 dk içinde tekrar bas | Sunucu `atlanan` sayar, Pro'da sayı artmaz |
| Pro → Gezgah Raporları → Günlük | Listeleme, Tıklanma, QR Tıklama, Yol Tarifi kartları artıyor |
