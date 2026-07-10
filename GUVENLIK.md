# Güvenlik (API Sertleştirme)

Bu doküman Gezgah API'sinin güvenlik katmanlarını, yapılandırmasını ve mobil
uygulamanın (APK) tersine mühendisliğe karşı nasıl sertleştirileceğini anlatır.

> **Gerçekçi beklenti:** İstemci son kullanıcının cihazında çalıştığı için hiçbir
> önlem API'yi %100 "kırılamaz" yapmaz. Amaç, saldırganın maliyetini yükseltmek,
> otomatik/toplu kötüye kullanımı engellemek ve kolay yolları (tarayıcıdan URL
> açma, basit curl) kapatmaktır. Güvenlik **katmanlıdır**; tek bir önleme güvenme.

---

## 1. Tehdit modeli

| Tehdit | Açıklama |
|--------|----------|
| Açık URL'ler | Endpoint'ler kimlik doğrulamasız herkese açıktı; tarayıcı/curl ile çekilebiliyordu. |
| APK'yı açma (reverse engineering) | Saldırgan APK'yı decompile edip endpoint'leri, anahtarları ve akışı çözebilir. |
| Token/anahtar çalma | Gömülü statik anahtarlar APK'dan çıkarılabilir. |
| Replay | Yakalanan bir isteğin tekrar gönderilmesi. |
| Bot/scraping | Otomatik toplu veri çekme, sahte cihaz kaydı. |

---

## 2. Uygulanan katmanlar (sunucu tarafı)

İstek akışı `index.php` → `Guard::check()` → router şeklindedir. Guard,
dispatch'ten **önce** çalışır ve şu sırayı uygular:

1. **Açık yollar (`open_paths`):** `/` ve `/health` hiçbir kontrol istemez.
2. **Uygulama anahtarı (`X-App-Key`):** `app_key` ayarlıysa her istek (cihaz
   kaydı dahil) bu header'ı doğru göndermek zorundadır. `hash_equals` ile
   sabit-zamanlı karşılaştırılır.
3. **HMAC istek imzası:** `require_signature = true` ise `X-Timestamp`,
   `X-Nonce`, `X-Signature` doğrulanır (aşağıda).
4. **Erişim token'ı:** `require_token = true` ise `Authorization: Bearer <token>`
   zorunludur. Token; ya bir **cihaz token'ı** (`cihaz_tokenlari`) ya da bir
   **kullanıcı token'ı** (`yzd_users.hash`) olmalıdır. `no_token_paths`
   (ör. `/cihaz/kayit`) bu adımdan muaftır — token'ı orada üretiriz.

Yani **normal akış:** App ilk açılışta `POST /cihaz/kayit` (token muaf, ama
app_key/imza tabi) ile bir cihaz token'ı alır; sonraki tüm istekleri
`Authorization: Bearer <cihaz_token>` ile yapar. Kullanıcı giriş yaparsa isteğe
bağlı olarak kullanıcı token'ı da kullanılabilir.

### HMAC imza şeması

İmza tabanı (string):

```
METHOD\nPATH\nTIMESTAMP\nNONCE\nsha256(BODY)
```

- `METHOD`: büyük harf HTTP yöntemi (GET, POST...).
- `PATH`: sondaki `/` atılmış yol (ör. `/mekanlar`).
- `TIMESTAMP`: Unix saniye. Sunucu `signature_ttl` (vars. 300 sn) penceresi
  dışındaki istekleri reddeder (replay koruması).
- `NONCE`: her istekte üretilen rastgele değer (opsiyonel ama önerilir).
- `BODY`: ham istek gövdesi (GET'te boş string).

İmza: `HMAC_SHA256(base, signing_secret)` (hex). Header: `X-Signature`.

Sunucu aynı tabanı yeniden üretip `hash_equals` ile karşılaştırır.

> **Not:** Bu sürümde nonce, kalıcı olarak saklanmaz; replay koruması zaman
> penceresine dayanır. Daha katı koruma için nonce'ları kısa TTL'li bir depoda
> (ör. Redis) tutup tekrar kullanımı engelleyin.

---

## 3. Yapılandırma

`config/config.php` → `security` bloğu (ortam değişkenleriyle override edilir):

| Ayar | Env | Varsayılan | Açıklama |
|------|-----|-----------|----------|
| `require_token` | `REQUIRE_TOKEN` | `true` | Bearer token zorunlu mu |
| `app_key` | `APP_KEY` | `''` (kapalı) | `X-App-Key` beklenen değer |
| `require_signature` | `REQUIRE_SIGNATURE` | `false` | HMAC imza zorunlu mu |
| `signing_secret` | `SIGNING_SECRET` | `''` | HMAC gizli anahtarı |
| `signature_ttl` | `SIGNATURE_TTL` | `300` | İmza zaman penceresi (sn) |
| `open_paths` | — | `['/', '/health']` | Kontrolsüz yollar |
| `no_token_paths` | — | `['/cihaz/kayit']` | Token'sız ama app_key/imza tabi yollar |

**Önerilen üretim ortam değişkenleri:**

```bash
APP_DEBUG=false
REQUIRE_TOKEN=true
APP_KEY=<uzun-rastgele-deger>
REQUIRE_SIGNATURE=true
SIGNING_SECRET=<uzun-rastgele-gizli-anahtar>
```

> `signing_secret` ve `app_key` değerlerini kaynak koda **gömmeyin**;
> sunucuda ortam değişkeni olarak verin. `.htaccess` zaten `config/`, `src/`,
> `.md`, `.sql` gibi dosyalara web erişimini kapatır.

---

## 4. İstemci (Flutter/Dio) tarafı

`Dio` interceptor ile her isteğe başlıkları otomatik ekleyin:

```dart
class _SecurityInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions o, RequestInterceptorHandler h) async {
    // 1) Uygulama anahtarı (derleme zamanı --dart-define ile gelmeli)
    o.headers['X-App-Key'] = const String.fromEnvironment('APP_KEY');

    // 2) Cihaz token'ı (ilk açılışta /cihaz/kayit ile alınır, güvenli depoda)
    final token = await Api.instance.token;
    if (token != null) o.headers['Authorization'] = 'Bearer $token';

    // 3) HMAC imza
    final ts = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
    final nonce = _randomNonce();
    final bodyStr = o.data == null ? '' : jsonEncode(o.data);
    final base = '${o.method.toUpperCase()}\n${o.path}\n$ts\n$nonce\n${sha256Hex(bodyStr)}';
    o.headers['X-Timestamp'] = ts;
    o.headers['X-Nonce'] = nonce;
    o.headers['X-Signature'] = hmacSha256Hex(base, _signingSecret);

    h.next(o);
  }
}
```

- `APP_KEY` ve imza sırrını **koda düz metin** koymayın; `--dart-define` veya
  native (NDK/Keystore) katmanında tutun. Yine de bunlar istemcide olduğu için
  tek başına yeterli değildir — asıl güç **Play Integrity / App Check** ile gelir
  (bkz. bölüm 5).

---

## 5. APK'nın çözülmesine karşı (asıl savunma)

Statik anahtarlar decompile ile çıkarılabilir. Gerçek koruma, **isteğin gerçek,
değiştirilmemiş uygulamadan ve gerçek bir cihazdan geldiğini** sunucuya
kanıtlamaktır.

### 5.1 Google Play Integrity API (önerilen)

- Uygulama, `/cihaz/kayit` çağrısından hemen önce Play Integrity'den bir
  **integrity token** alır ve isteğe ekler.
- Sunucu bu token'ı Google'ın API'siyle doğrular: uygulama imzası (paket +
  sertifika özeti) beklenen mi, cihaz/uygulama bütünlüğü tamam mı.
- Sadece doğrulanan isteklere cihaz token'ı verilir. Böylece sahte/değiştirilmiş
  APK'lar veya emülatör/otomasyon botları cihaz token'ı **alamaz**.
- Entegrasyon noktası: `CihazController::register()` içinde, token üretmeden
  önce `integrity_token` doğrulaması ekleyin (Google Play Integrity sunucu
  doğrulaması).

### 5.2 Firebase App Check (alternatif/ek)

- Play Integrity (Android) ve DeviceCheck/App Attest (iOS) sağlayıcılarını
  soyutlar. İstemci App Check token'ı üretir, sunucu doğrular.

### 5.3 İstemci sertleştirme

- **Kod karıştırma (obfuscation):** Android R8/ProGuard + `flutter build apk
  --obfuscate --split-debug-info=...`. Sınıf/metod adlarını okunmaz yapar.
- **TLS sertifika sabitleme (certificate pinning):** Dio + `dio_certificate_pinning`
  veya native pinning. Proxy (Charles/Burp) ile trafiğin izlenmesini/oynanmasını
  zorlaştırır.
- **Sadece HTTPS:** HTTP'yi tümden kapatın; cleartext trafiğe izin vermeyin
  (`android:usesCleartextTraffic="false"`).
- **Root/jailbreak & emülatör tespiti:** Şüpheli ortamlarda uyarı/limit.
- **Debug/hook tespiti:** Frida/Xposed gibi araçlara karşı kontroller (kısmi fayda).
- **Sır saklama:** Anahtarları `strings.xml`/Dart sabiti yerine NDK (C/C++) veya
  Android Keystore/iOS Keychain'de tutun; yine de "gizlenebilir ama silinemez"
  ilkesini unutmayın.

---

## 6. Ek sunucu önlemleri (önerilen)

- **Rate limiting:** Token/IP başına istek sınırı (ör. Nginx `limit_req`,
  Cloudflare, veya uygulama içinde sayaç tablosu). Sahte cihaz kaydı ve
  scraping'i yavaşlatır.
- **WAF / CDN:** Cloudflare vb. ile bot yönetimi, coğrafi/oran kuralları.
- **HTTPS + HSTS:** Zorunlu.
- **CORS:** Şu an `*` (public). Yalnızca uygulama kullanacaksa gerçek web
  origin'i yoksa CORS'u kısmak tarayıcı tabanlı kötüye kullanımı azaltır
  (native app CORS'tan etkilenmez).
- **Loglama & anomali tespiti:** Anormal hacim/oran, 401 patlamaları izlensin.
- **En az yetki:** DB kullanıcısına yalnızca gereken izinler; ayrı ok-yaz
  hesapları.
- **Token yaşam döngüsü:** Gerekiyorsa cihaz/kullanıcı token'larına son kullanma
  ve yenileme (rotate) ekleyin.

---

## 7. Devreye alma adımları (öneri)

1. `php rest/tools/migrate_cihaz_tokenlari.php` çalıştır (cihaz tablosu).
2. Ortam değişkenlerini ayarla: `REQUIRE_TOKEN=true`, `APP_KEY=...`,
   `APP_DEBUG=false`.
3. Uygulamayı güncelle: ilk açılışta `/cihaz/kayit`, sonra tüm isteklerde
   `Authorization: Bearer <token>` + `X-App-Key`.
4. İstikrarlı olduğunda `REQUIRE_SIGNATURE=true` + `SIGNING_SECRET` aç; app'te
   HMAC imza üretimini devreye al.
5. Play Integrity / App Check doğrulamasını `/cihaz/kayit`'e ekle.
6. Rate limiting + WAF + sertifika sabitleme + obfuscation'ı tamamla.

---

## 8. Hızlı kontrol listesi

- [ ] `REQUIRE_TOKEN=true`, `APP_DEBUG=false` (üretim).
- [ ] `APP_KEY` ayarlı ve app'te `--dart-define` ile geliyor.
- [ ] `/cihaz/kayit` dışındaki tüm istekler Bearer token gönderiyor.
- [ ] `REQUIRE_SIGNATURE=true` + `SIGNING_SECRET` (istemci hazır olunca).
- [ ] Play Integrity/App Check ile cihaz kaydı korunuyor.
- [ ] HTTPS zorunlu, sertifika sabitleme aktif.
- [ ] APK obfuscation (R8 + Flutter `--obfuscate`).
- [ ] Rate limiting / WAF devrede.
- [ ] `config/`, `src/`, `.md`, `.sql` web'den erişilemiyor (`.htaccess`).

---

## İlgili dokümanlar

- Cihaz token akışı: [CIHAZ_TOKEN.md](CIHAZ_TOKEN.md)
- Bildirim okundu (cihaz bazlı): [BILDIRIMLER.md](BILDIRIMLER.md)
- Genel API: [README.md](README.md) · Flutter: [FLUTTER_API_GUIDE.md](FLUTTER_API_GUIDE.md)
