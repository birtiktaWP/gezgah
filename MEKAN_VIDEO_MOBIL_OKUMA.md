# Mekan Videoları — Mobil Uygulama Veriyi Nasıl Okuyor

Ek: MEKAN_VIDEO.md. Bu doküman uygulamanın `GET /mekanlar/{id}` yanıtından videoyu **nereden ve hangi kurallarla** okuduğunu anlatıyor. Backend çıktısı buna uyarsa ek mobil değişiklik gerekmez.

## 1. Sorun (Beyaz Bahçe Otel, #4745)

`GET /mekanlar/4745` canlı yanıtı (3 Ekim 2026, uygulamanın kullandığı cihaz token'ı ve X-App-Key ile):

- `data.videolar` alanı **yok**.
- ERP'den yüklenen video `data.galeri[]` içinde geliyor:

```json
{"id":1179527739,"url":"https://pro.gezgah.com/uploads/videos/gezgah_v_2dfe8a4780194c38.mp4",
 "thumbnail":"https://pro.gezgah.com/uploads/videos/gezgah_v_2dfe8a4780194c38.jpg",
 "mime_type":"video/mp4","is_featured":false,"title":"sdsds",
 "poster":"https://pro.gezgah.com/uploads/videos/gezgah_v_2dfe8a4780194c38.jpg","duration":15}
```

- `galeri[]` içinde eski panelden gelen bir video daha var (`id 2895`, `https://gezgah.com/uploads/…mp4`).
- Dosyalara erişim sorunsuz: iki video da Range isteğine `206 video/mp4` dönüyor, dosya imzası (`ftyp`) doğru.

**Sonuç:** Açılış videosu (detaya girince tam ekran, zorunlu) **yalnız `videolar[]`'dan** okunuyor. Alan gelmediği için video oynamıyor. Galerideki "Videolar" sekmesi `galeri[]`'yi de okuduğu için video orada görünür.

## 2. Uygulamanın okuduğu yerler

| Kullanım | Kaynak | Not |
|---|---|---|
| **Açılış videosu** (tam ekran, zorunlu) | Yalnız `videolar[]` | Dizideki **ilk oynatılabilir** öğe. `galeri[]`'ye hiç bakılmaz |
| Galeri > Videolar sekmesi | Önce `videolar[]`, sonra `galeri[]` içindeki videolar | `url`'e göre tekilleştirilir, aynı video iki kez çıkmaz |
| Galeri > Fotoğraflar | `galeri[]` içinde video **olmayan** öğeler | |

Uygulama tarafında detay yanıtı önbelleğe alınmaz. Her detay açılışında istek atılır, yani backend düzelince yeni sürüm gerekmez.

## 3. `videolar[]` — beklenen biçim

```json
"videolar": [
  {
    "file": "gezgah_v_2dfe8a4780194c38.mp4",
    "url": "https://pro.gezgah.com/uploads/videos/gezgah_v_2dfe8a4780194c38.mp4",
    "poster": "https://pro.gezgah.com/uploads/videos/gezgah_v_2dfe8a4780194c38.jpg",
    "title": "sdsds",
    "mime": "video/mp4",
    "size": 2385957,
    "duration": 15,
    "width": 1080,
    "height": 1920,
    "createdAt": "2026-10-03 01:38:25"
  }
]
```

Okuma kuralları (`MekanVideo.fromJson`):

| Alan | Zorunlu | Okuma |
|---|---|---|
| `url` | **Evet** | Boş/yoksa öğe **atılır**. `http` ile başlamıyorsa başına `https://api.gezgah.com` eklenir, yani mutlak URL gönderin |
| `mime` | Hayır | Küçük harfe çevrilir. **Anahtar `mime`**. `mime_type` okunmaz |
| `poster` | Hayır | `null`/boş → ilk kare gösterilir |
| `title` | Hayır | Galeri kartında gösterilir |
| `duration` | Hayır | Sayı ya da sayısal string. Kartta "0:15" olarak gösterilir |
| `width`, `height` | Hayır | Sayı ya da sayısal string, `0` olabilir |
| `size`, `file`, `createdAt` | Hayır | Şu an kullanılmıyor |

Dizi dışındaki değerler (`null`, obje, string) boş liste sayılır. Dizi içinde obje olmayan öğeler atlanır.

### Açılış videosu seçimi

1. `videolar[]` sırası korunur (ERP'deki sıra).
2. `url`'i boş olanlar atlanır.
3. **iOS'ta** `mime = video/webm` ya da `.webm` ile biten URL atlanır.
4. Kalan ilk öğe açılış videosu olur. Hiç kalmazsa açılış videosu yok, detay doğrudan açılır.

Oynatma sırasında: 10 sn içinde başlamazsa ya da 8 sn takılırsa video kendiliğinden kapanır. MOV (HEVC) bazı Android cihazlarda açılmayabilir, bu durumda da kapanır. **Açılış videosu için MP4 (H.264/AAC) kullanın.**

## 4. `galeri[]` içindeki video öğeleri (eski yol)

`GaleriItem.fromJson` yalnız şu anahtarları okur: `id`, `url`, `thumbnail`, `is_featured`, `mime_type`.

- Video sayılma: `mime_type` `video/` ile başlıyorsa. `mime_type` yoksa URL uzantısı (`.mp4 .m4v .mov .webm .3gp .mkv .m3u8`).
- Kapak: `thumbnail`, video URL'inden farklı ve video uzantılı değilse.
- `poster`, `title`, `duration` bu yolda **okunmaz**.
- Bu yoldan gelen video **açılış videosu olmaz**, yalnız galeride görünür.

## 5. Backend'den istenen

1. `GET /mekanlar/{id}` yanıtına `videolar` alanını ekleyin (MEKAN_VIDEO.md §3, `mekanVideolar()`). Video yoksa `[]`, `null` değil.
2. Alan ES/Redis detay önbelleğinden değil, `mekan_videolar` meta'sından **taze** okunmalı. #4745'te galeriye girdiğine göre veri var, ancak `videolar` alanı yanıta hiç eklenmiyor. `show()` içindeki satır eksik ya da yanıt başka bir yoldan (önbellek/ES) dönüyor olabilir.
3. ERP videolarını `galeri[]`'ye de koymaya devam etmek **zorunlu değil**. Uygulama URL'e göre tekilleştirdiği için ikisinde birden olması sorun yaratmaz. MEKAN_VIDEO.md §1'e göre ERP videolarının `galeri[]`'de olmaması bekleniyordu, bunu netleştirin.
4. Eski panel videoları (`gezgah.com/uploads/…mp4`, #2895 gibi) açılış videosu olsun isteniyorsa onlar da `videolar[]`'a eklenmeli. İstenmiyorsa `galeri[]`'de kalabilir.

## 6. Doğrulama

Repoda test betiği var, uygulamanın yaptığı isteği birebir atar (cihaz kaydı + X-App-Key):

```powershell
$env:GEZGAH_APP_KEY = '<X-App-Key>'     # lib/data/app_secrets.dart
php tool/api_video_test.php 4745        # ya da: php tool/api_video_test.php "beyaz bahçe"
```

Beklenen çıktı:

```
videolar: 1 adet
[0] { "url": "https://pro.gezgah.com/uploads/videos/…mp4", "mime": "video/mp4", … }
  video : HTTP 206 | video/mp4 | range: bytes 0-1023/… | mp4/mov(ftyp)
```

Bugünkü çıktı: `[SORUN] Yanıtta 'videolar' alanı YOK`.

Not: `/mekanlar/{id}` her çağrıda `tiklama` sayacını +1 arttırır. Test bunu da tetikler.
