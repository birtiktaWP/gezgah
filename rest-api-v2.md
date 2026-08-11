# Gezgah REST API — v2 (Mobil App Entegrasyon Notları)

Bu belge, `api.gezgah.com/rest/` altındaki mobil uygulama API'sinde yapılan
**güvenlik, performans ve mantık iyileştirmelerini** ve bunların mobil app
tarafını nasıl etkilediğini özetler. Ayrıntılı uç dokümanları `rest/*.md`
dosyalarındadır; bu belge v2 değişikliklerine ve entegrasyon davranışına odaklanır.

- **Base URL:** `https://api.gezgah.com/rest/`
- **Sunucu yolu:** `/home/gezgah/public_html/api/rest`
- **Format:** JSON (istek gövdesi ve yanıt)
- **Kimlik:** `Authorization: Bearer <token>`

---

## 1. Yanıt Zarfı (değişmedi)

Tüm yanıtlar standart zarf ile döner:

```json
{ "success": true, "data": { }, "error": null, "meta": { } }
```

Hata:

```json
{ "success": false, "data": null, "error": { "message": "…", "details": { } } }
```

- `meta` yalnızca sayfalı/listeli uçlarda bulunur (`page`, `limit`, `total`, `pages`, `has_more`, `next_page`).
- HTTP durum kodu her zaman anlamlıdır (200/201/401/403/404/409/422/429/500).

---

## 2. Kimlik ve Token Akışı

### 2.1 Cihaz token'ı (device token)
İlk açılışta cihaz kaydı yapılır; dönen token tüm public uçlara erişim sağlar.

```
POST /cihaz/kayit
Body: { "platform": "...", "device_model": "...", "os_version": "...", "app_version": "...", "device_uuid": "...", "push_token": "..." }
→ { token, ... }
```

- `POST /cihaz/kayit` **token gerektirmez** (kendisi token üretir).
- Diğer tüm uçlar için `Authorization: Bearer <token>` gereklidir (cihaz veya üye token'ı).

### 2.2 Üye token'ı (app_uyeler — parolalı)
```
POST /uye/kayit    Body: { isim, soyisim, email, telefon, parola, ulke_kodu?, cinsiyet?, dogum_gunu?, ilce_id?, device_token? }
POST /uye/giris    Body: { ulke_kodu, telefon, parola, device_token? }
GET  /uye/me
POST /uye/guncelle
POST /uye/sifre-degistir  Body: { eski_parola, yeni_parola }
POST /uye/cikis
```

### 2.3 🔴 YENİ: Çoklu-cihaz oturum (multi-device)
**Önemli değişiklik.** Önceden kullanıcı başına **tek** token vardı; yeni cihazdan
giriş, eski cihazın oturumunu düşürüyordu. Artık:

- Her **giriş** (login) için **yeni bir token** üretilir; **eski cihazların token'ları geçerli kalır.**
- **Çıkış** (`/uye/cikis`, `/auth/logout`) yalnızca **o cihazın** token'ını iptal eder; diğer cihazlar etkilenmez.
- **Parola değişimi** güvenlik gereği **tüm cihazların** oturumunu düşürür; yanıt yeni bir `token` döner — app bunu saklamalı.

**App tarafı yapılması gereken:**
- Her cihazda kendi token'ını sakla ve kullan.
- `/uye/sifre-degistir` sonrası dönen **yeni `token`** ile eskisini değiştir (yoksa 401 alırsın).
- Geriye dönük uyumludur: mevcut token'lar çalışmaya devam eder.

---

## 3. 🔴 KIRICI OLABİLECEK DEĞİŞİKLİK: Favoriler (yetki/IDOR düzeltmesi)

### Eski `/favoriler` (yzd_users) — davranış değişti
Önceden `user_id` parametresi ile **herhangi bir kullanıcının** favorilerine
erişilebiliyordu (güvenlik açığı). Artık:

- Kullanıcı **her zaman token'dan** çözülür.
- `user_id` gövdede/query'de **gönderilebilir ama** yalnızca token sahibiyle
  **eşleşirse** kabul edilir; farklıysa **403** döner.
- Bu uç artık **geçerli bir kullanıcı token'ı** ister (yoksa **401**).

```
GET    /favoriler?type=restoran        (user_id opsiyonel; gönderilirse token ile eşleşmeli)
POST   /favoriler   Body: { post_id }  (user_id opsiyonel)
DELETE /favoriler   Body: { post_id }  (user_id opsiyonel)
```

**App tarafı yapılması gereken:**
- `user_id` göndermeye gerek yok; sadece token yeterli. Gönderirsen kendi id'n olmalı.
- Giriş yapmamış kullanıcı için bu uç 401 döner.

### Üye favorileri `/uye/favoriler` (app_uyeler) — önerilen
Token'dan çözülen, sayfalı ("daha fazla yükle") favori ucu. `user_id` yok.

```
GET    /uye/favoriler?page=1&limit=20
POST   /uye/favoriler    Body: { post_id }
DELETE /uye/favoriler    Body: { post_id }
```

---

## 4. 🟠 YENİ: Hız Sınırı (Rate Limiting) — 429

Kötüye kullanım/bot/brute-force koruması eklendi (Redis tabanlı; sunucuda Redis
yoksa uygulanmaz).

- **Genel:** IP başına varsayılan **600 istek / 60 sn**.
- **Kimlik uçları** (`/auth/login`, `/auth/register`, `/uye/giris`, `/uye/kayit`, `/uye/sifre-degistir`, `/cihaz/kayit`): IP başına **30 istek / 60 sn**.
- Aşımda **HTTP 429** ve `{ "error": { "message": "Çok fazla…" } }` döner.

**App tarafı yapılması gereken:**
- 429 alınca kullanıcıya "biraz sonra tekrar deneyin" göster, kısa bir backoff uygula.
- Gereksiz/tekrarlı istekleri (özellikle login denemeleri ve poll'ler) sınırla.
- Limitler sunucu tarafında ayarlanabilir; paylaşımlı mobil operatör IP'leri (CGNAT)
  için cömert tutuldu.

---

## 4b. 🟢 YENİ: Redis Yanıt Önbelleği (read cache)

Ağır **okuma** uçları artık Redis'te yanıt önbelleğine alınır (qr menü cache
mantığıyla aynı). Sunucuda Redis yoksa doğrudan DB'den çalışır (fail-open,
davranış korunur). Anahtar öneki: `gzapi:resp:`.

| Uç | TTL | Anahtar |
|----|-----|---------|
| `/mekanlar/{id}` (detay: menü+galeri+metalar) | 180 sn | `mek:detay:{id}` |
| `/harita` (sayfalamasız, ağır) | 300 sn | `mek:harita:*` |
| `/mekanlar` (liste) | 120 sn | `mek:idx:*` |
| `/pagination_isletmeler` | 120 sn | `mek:pag:*` |
| `/one-cikan-firmalar` | 300 sn | `mek:one:*` |
| `/mekanlar/yeni-eklenenler` · `/yakindakiler` | 300 sn | `mek:yeni:*` · `mek:yakin:*` |
| `/arama` | 120 sn | `mek:arama:*` |
| `/kategoriler` · `/kategoriler/{id}` · `/{id}/mekanlar` | 300–600 sn | `kat:*` |
| `/etkinlikler[/{id}]` | 300 sn | `etk:*` |
| `/ilceler` · `/filtreler` | 3600 · 1800 sn | `il:*` · `flt:*` |
| `/home-page-settings` · `/search-page-settings` | 600 sn | `hp:*` |

**Side-effect'ler önbellekten bağımsız çalışır:** `/mekanlar/{id}` tıklama ve
`/pagination_isletmeler` listeleme sayaçları her istekte (ziyaretçi dedup'lı)
işlenir; liste sayaçları taze okunur, detaydaki sayaç değerleri TTL boyunca
sabit kalabilir (kabul edilebilir). `/arama` geçmişi her ilk-sayfa isteğinde loglanır.

**Kişiye özel uçlar önbelleğe ALINMAZ:** `auth/*`, `uye/*`, `favoriler`,
`cihaz/*`, `bildirimler` (token'a/kullanıcıya bağlı).

**Tazelik:** İşletme/kategori/ayar verisi pro/erp'den düzenlenir; değişiklik en
geç TTL kadar gecikmeyle yansır (mekan verisi 2–3 dk, referans veri daha uzun).
Anında yansıma gerekirse düzenleme anında ilgili `gzapi:resp:mek:detay:{id}`
anahtarını silen bir invalidation eklenebilir.

**App tarafı:** Ek bir şey yapmaya gerek yok; yanıtlar aynı, sadece daha hızlı.

---

## 5. 🟢 Arama Davranışı (performans)

`GET /arama?q=...&page=&limit=` artık FULLTEXT index kullanır (hızlı).

- En az **2 karakter** gerekir (değişmedi).
- **3+ harfli** terimlerde FULLTEXT **kelime-başı (prefix)** eşleşmesi yapılır
  (ör. `kah` → "kahve", "kahvaltı"). Kısa terimlerde eski `LIKE` davranışı korunur.
- Restoran adı **ve** menü/yemek adı üzerinde arar; sonuçta `eslesme` (`isim`/`menu`)
  ve `eslesen_urunler` alanları döner.

**Not:** Kelime-ortası eşleşme (ör. `ahve` → "kahve") artık uzun terimlerde
gelmeyebilir; kelime başından arama önerilir.

Popüler aramalar: `GET /populer-aramalar?limit=6&days=`.

---

## 6. Hata/Detay Sızıntısı Düzeltmesi (güvenlik)

- Üretimde **5xx** hatalarında iç detay (DB host, dosya yolu, stack) **artık istemciye dönmez**; genel mesaj döner. Gerçek neden sunucu loguna yazılır.
- **4xx** (doğrulama, çakışma vb.) mesajları anlamlı ve app'e görünür kalır.

**App tarafı:** 500 durumunda kullanıcıya genel bir hata gösterin; ayrıntı beklemeyin.

---

## 7. Uç Listesi (özet)

| Yöntem | Yol | Kimlik | Açıklama |
|--------|-----|--------|----------|
| GET | `/health` | — | Sağlık kontrolü |
| POST | `/cihaz/kayit` | — | Cihaz token'ı üretir |
| POST | `/cihaz/uye-baglama` | token | Cihazı üye ile ilişkilendirir |
| GET | `/cihaz/me` | token | Cihaz bilgisi |
| POST | `/auth/register` `/auth/login` | token* | yzd_users kimlik |
| GET | `/auth/me` · POST `/auth/logout` | token | — |
| POST | `/uye/kayit` `/uye/giris` | token* | app_uyeler kimlik |
| GET | `/uye/me` · POST `/uye/guncelle` `/uye/sifre-degistir` `/uye/cikis` | token | — |
| GET/POST/DELETE | `/uye/favoriler` | üye token | Üye favorileri (sayfalı) |
| GET/POST/DELETE | `/favoriler` | kullanıcı token | Eski favoriler (token'dan user) |
| GET | `/mekanlar` | token | Filtre: type, kategori, bolge, q, page, limit |
| GET | `/mekanlar/yeni-eklenenler` | token | Son eklenenler |
| GET | `/mekanlar/yakindakiler` | token | Koordinatlı havuz (mesafe app'te) |
| GET | `/mekanlar/{id}` | token | Detay (+ menü, galeri, filtreler) |
| GET | `/pagination_isletmeler` | token | Sayfalı işletme listesi |
| GET | `/harita` | token | Koordinatlı mekanlar (sayfalamasız) |
| GET | `/arama` · `/populer-aramalar` | token | Arama |
| GET | `/one-cikan-firmalar` | token | Öne çıkanlar |
| GET | `/kategoriler` · `/kategoriler/{id}` · `/kategoriler/{id}/mekanlar` | token | Kategoriler |
| GET | `/etkinlikler` · `/etkinlikler/{id}` | token | Etkinlikler |
| GET | `/bildirimler` · POST `/bildirimler/okundu` | token | Bildirimler |
| GET | `/ilceler` · `/filtreler` | token | Referans veri |
| GET | `/home-page-settings[/{key}]` · `/search-page-settings[/{key}]` | token | Sayfa yapılandırması |

\* `/cihaz/kayit` dışında tüm uçlar `Bearer` token ister. Yeni kullanıcı akışı:
**önce** `POST /cihaz/kayit` → token → sonra `register`/`login`.

---

## 8. Sunucu Notları (backend)

- **DB bağlantısı** artık `localhost` (uzak/public IP yerine) — gecikme ve
  internete açık MySQL riski giderildi.
- **Sayaçlar** (`listeleme`/`tiklama`): aynı ziyaretçi (IP) kısa sürede tekrar
  saymaz (tıklama 1 saat, listeleme 30 dk dedup) — Redis yoksa eski davranış.
- **Uygulama anahtarı (X-App-Key) ve HMAC imza:** kod hazır, config ile
  (`APP_KEY`, `REQUIRE_SIGNATURE`) opsiyonel. Devreye alınırsa app ilgili
  header'ları göndermek zorundadır (koordineli açılmalı).

### Opsiyonel migration (performans)
FULLTEXT index'leri (arama hızı için):

```
php rest/tools/migrate_search_fulltext.php
```

Idempotent; index yoksa arama otomatik `LIKE`'a düşer (yani zorunlu değildir).

### Yüklenecek dosyalar
Hedef: `/home/gezgah/public_html/api/rest/`

- `index.php`, `config/config.php`
- `src/Auth.php`, `src/AppUye.php`, `src/Cache.php` *(yeni)*, `src/Guard.php`
- `src/Controllers/AuthController.php`
- `src/Controllers/FavoriController.php`
- `src/Controllers/MekanController.php`
- `src/Controllers/KategoriController.php`
- `src/Controllers/EtkinlikController.php`
- `src/Controllers/IlceController.php`
- `src/Controllers/FiltreController.php`
- `src/Controllers/HomePageController.php`
- `tools/migrate_search_fulltext.php` *(yeni, opsiyonel)*

Migration gerektirmez: `app_user_tokenlari` / `app_uye_tokenlari` ilk giriş/kayıtta
otomatik oluşur. Redis yanıt önbelleği için de ekstra kurulum yoktur.

---

## 9. v2 Değişiklik Özeti (changelog)

1. **Güvenlik:** `/favoriler` IDOR düzeltildi — kullanıcı token'dan çözülür, `user_id`'ye güvenilmez.
2. **Güvenlik:** 5xx hata detayları artık istemciye sızmıyor.
3. **Güvenlik/Performans:** DB host `localhost`.
4. **Özellik:** Çoklu-cihaz oturum (login artık diğer cihazları düşürmez; parola değişimi hepsini düşürür).
5. **Güvenlik:** IP başına rate limiting (429) — genel + kimlik uçları.
6. **Performans:** Sayaçlarda ziyaretçi bazlı dedup (bot şişirmesi ve yazma yükü azaldı).
7. **Performans:** Aramada FULLTEXT (kısa terimlerde LIKE fallback).
8. **Performans:** Redis yanıt önbelleği — tüm ağır okuma uçları (detay, harita,
   listeler, kategoriler, referans veri) Redis'ten servis edilir (fail-open).
