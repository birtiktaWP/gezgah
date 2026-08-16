# Gezgah Mobil API — Üyelik + Gezgah Plus (IAP) Kılavuzu

Bu doküman mobil API'deki **tek üyelik sistemi** (`app_uyeler`), yapılan **3 güvenlik
iyileştirmesi** ve yeni **Gezgah Plus** (₺199.99/yıl, IAP) sistemini anlatır.

Taban URL: `https://api.gezgah.com/rest/`
Kimlik: `Authorization: Bearer <token>` (üye veya cihaz token'ı).

---

## 1. Genel Mimari

- **Tek üyelik sistemi**: `app_uyeler` tablosu. Giriş anahtarı **ülke kodu + telefon + parola**.
  Eski `yzd_users` tabanlı `/auth/*` ve `/favoriler` uçları **kaldırıldı**.
- Oturum token'ları: `app_uye_tokenlari` (çoklu cihaz) + geriye dönük `app_uyeler.token`.
- Cihaz (push/bildirim): `cihaz_tokenlari`; `user_id` = **app_uyeler.id**.
- Güvenlik kapısı `Guard`: `X-App-Key` → HMAC imza (ops.) → token (cihaz **veya** üye) → rate-limit (Redis).

---

## 2. Yapılan 3 Güvenlik İyileştirmesi

### 2.1. Telefon SMS OTP doğrulaması (kayıt)
Kayıt artık telefon doğrulaması ister. Akış:

1. `POST /uye/kayit-kod-gonder` → telefona 6 haneli SMS kodu (Verimor). Kod Redis'te **5 dk** TTL.
2. `POST /uye/kayit` → gövdeye `kod` eklenir; sunucu doğrular, hesabı açar.

- Flood koruması: numara başına **60 sn** bekleme + **saatte 5** kod; kod başına **5** hatalı deneme.
- SMS altyapısı: Verimor (`yzd_metas.verimor_username/password`). **Not:** SMS şu an TR (+90) numaralara gider.
- Redis zorunlu (OTP durumsuz). Redis yoksa kayıt uçları `503` döner.

### 2.2. Token TTL + kayan pencere (rotasyon)
- Token geçerlilik: **180 gün** (`AppUye::TOKEN_TTL_DAYS`), her istekte `last_seen_at` yenilenir (kayan pencere).
- Süresi geçen token'lar `byToken` içinde **~%2 olasılıkla** otomatik temizlenir (cron gerekmez).
- Parola değişiminde tüm token'lar düşürülür (mevcut davranış korunur).

### 2.3. Uygulama anahtarı (X-App-Key) — **AÇIK (canlı)**
`Guard` app_key katmanı **etkin**. `/` ve `/health` dışındaki TÜM isteklerde geçerli
`X-App-Key` başlığı zorunludur; göndermeyen istek `401 "Uygulama anahtarı geçersiz."` alır.

**Aktif anahtar (mobil app bu değeri göndermeli):**
```
X-App-Key: ba9db8d2c420adbaeed122fe53c15e878fbcc67b55ba41cd
```

- Bu bir **client secret DEĞİLDİR** (APK/IPA'dan çıkarılabilir). Amacı otomatik bot/script
  trafiğini elemektir; asıl güvenlik token (+ opsiyonel HMAC imza) katmanındadır.
- Anahtarı değiştirmek/geri almak (sunucuda, `config/config.php` — scp ile değil, sed ile):
  ```bash
  # Yeni anahtar üret ve yaz
  KEY=$(openssl rand -hex 24)
  sed -i "s#'app_key' => getenv('APP_KEY') ?: '[^']*',#'app_key' => getenv('APP_KEY') ?: '$KEY',#" \
    /home/gezgah/public_html/api/rest/config/config.php
  echo "$KEY"
  # Devre dışı bırakmak için değeri boşalt: ... ?: '',
  ```
- Daha güçlü koruma: `security.require_signature=true` + `signing_secret` ile HMAC istek
  imzası (istemci `X-Timestamp`+`X-Nonce`+`X-Signature` üretir). Anahtar tek başına yetmez.

**Flutter — Dio interceptor örneği** (tüm isteklere app-key + bearer; 401→login):
```dart
const kAppKey = 'ba9db8d2c420adbaeed122fe53c15e878fbcc67b55ba41cd';

dio.interceptors.add(InterceptorsWrapper(
  onRequest: (options, handler) {
    options.headers['X-App-Key'] = kAppKey;
    final token = TokenStore.read();          // güvenli depodan (flutter_secure_storage)
    if (token != null) options.headers['Authorization'] = 'Bearer $token';
    handler.next(options);
  },
  onError: (e, handler) {
    if (e.response?.statusCode == 401) {
      // token süresi/oturum düştü -> giriş ekranına yönlendir
    }
    handler.next(e);
  },
));
```

---

## 3. Kimlik / Üyelik Uçları

### 3.1. Kayıt kodu gönder
`POST /uye/kayit-kod-gonder`
```json
{ "ulke_kodu": "+90", "telefon": "5551234567" }
```
Yanıt: `{ "gonderildi": true, "sms": true }` (meta.gecerlilik_sn=300).
Hatalar: `409` (telefon zaten kayıtlı), `429` (çok deneme), `503` (Redis yok).

### 3.2. Kayıt
`POST /uye/kayit`
```json
{
  "isim": "Ada", "soyisim": "Yılmaz",
  "email": "ada@example.com",
  "ulke_kodu": "+90", "telefon": "5551234567",
  "parola": "sifre123",
  "kod": "482913",
  "cinsiyet": "kadin", "dogum_gunu": "1998-05-20", "ilce_id": 1101,
  "device_token": "<cihaz_token opsiyonel>"
}
```
Yanıt `201`: `{ "token": "...", "uye": { ... } }`
Zorunlu: isim, soyisim, email, telefon, parola, **kod**. Şehir sabit **34** (İstanbul).

### 3.3. Giriş
`POST /uye/giris`
```json
{ "ulke_kodu": "+90", "telefon": "5551234567", "parola": "sifre123", "device_token": "..." }
```
Yanıt: `{ "token": "...", "uye": { ... } }` · Hata: `401` (telefon/parola).

### 3.4. Diğer
- `GET /uye/me` → `{ "uye": {...} }` (avatar + plus dahil).
- `POST /uye/guncelle` → kısmi profil güncelleme (isim, soyisim, email, telefon, ulke_kodu, cinsiyet, dogum_gunu, ilce_id).
- `POST /uye/sifre-degistir` `{ eski_parola, yeni_parola }` → yeni token döner (diğer oturumlar düşer).
- `POST /uye/cikis` → bu cihazın oturumunu kapatır.

**Üye nesnesi** (`uye`):
```json
{
  "id": 12, "isim": "Ada", "soyisim": "Yılmaz", "email": "...", "telefon": "...",
  "ulke_kodu": "+90", "cinsiyet": "kadin", "dogum_gunu": "1998-05-20",
  "sehir": 34, "ilce_id": 1101, "ilce": "Kadıköy",
  "avatar": "https://gezgah.com/uploads/app-avatars/12-ab12cd34ef.jpg",
  "plus": { "aktif": true, "bitis": "2027-08-16 12:00:00" },
  "status": 1, "son_giris_at": "...", "created_at": "..."
}
```

---

## 4. Gezgah Plus (₺199.99 / yıl — IAP)

Plus paketi şunları açar: **avatar yükleme**, **gezi rotaları** (sıralı mekan + yorum), **Kedy**.
Ödeme **In-App Purchase** ile (App Store / Google Play). Backend makbuzu store ile **doğrular**.

### 4.1. Durum
`GET /uye/plus/durum`
```json
{ "plus": {
  "aktif": false, "bitis": null, "kalan_gun": null,
  "platform": null, "product_id": null,
  "urun": { "fiyat": "199.99", "para": "TRY", "periyot": "yillik",
            "ios": "gezgah_plus_yillik", "android": "gezgah_plus_yillik" },
  "ozellikler": ["avatar","gezi_rotalari","kedy"]
}}
```

### 4.2. Satın alma doğrulama
Uygulama IAP satın almasını tamamlayınca makbuzu buraya gönderir:

`POST /uye/plus/dogrula`
- iOS: `{ "platform": "ios", "receipt": "<base64 appStoreReceipt>" }`
- Android: `{ "platform": "android", "purchase_token": "<token>", "product_id": "gezgah_plus_yillik" }`

Başarılı: `{ "durum": "plus_aktif", "plus": {...}, "uye": {...} }`
Hata: `402` (makbuz doğrulanamadı), `401` (üye değil).

Doğrulama akışı:
- **Apple**: `verifyReceipt` (prod; `21007` → sandbox). `latest_receipt_info`'dan en geç `expires_date` alınır. `bundle_id` doğrulanır.
- **Google**: Service account → OAuth2 (RS256 JWT) → `purchases.subscriptions.get`; `expiryTimeMillis` alınır.
- Doğrulanamazsa **Plus verilmez** (fail-safe). Kayıt: `app_plus_abonelikler` (upsert) + `app_uyeler.plus_*`.

### 4.3. IAP yapılandırması — `config/iap.php`
Bu dosya deploy edilebilir; **gizli anahtarları ortam değişkeniyle** vermeniz önerilir.
Doldurmanız gerekenler:

| Ayar | Kaynak |
|------|--------|
| `apple.bundle_id` | Uygulamanızın bundle id (ör. `com.gezgah.app`) |
| `apple.shared_secret` | App Store Connect → App → **App-Specific Shared Secret** |
| `google.package_name` | Play paket adı |
| `google.service_account_file` VEYA `client_email`+`private_key` | Play Console → Setup → **API access** → Service account JSON (androidpublisher yetkisi) |
| `plus.product_id_ios/android` | Store'da tanımlı ürün kimlikleri |

> Service account JSON'u sunucuya koyarsanız (ör. `config/google-service-account.json`),
> web'den erişilemeyecek şekilde koruyun (dizin listelemeyi kapatın / .htaccess deny).

**Test modu:** `iap.php` içinde `trust_client=true` (env `IAP_TRUST_CLIENT=true`) ise store
doğrulaması yapılmadan istemcinin verdiği `expires_at` kabul edilir — **yalnız geliştirme**,
üretimde **false** bırakın.

---

## 5. Avatar (Plus'a özel)

- `POST /uye/avatar` — gövde: `{ "avatar": "data:image/jpeg;base64,..." }` (veya çıplak base64),
  ya da multipart `avatar` dosyası. Görsel **512×512** merkez-kare JPEG'e dönüştürülüp saklanır.
  Yanıt: `{ "avatar": "https://.../app-avatars/12-....jpg", "durum": "yuklendi" }`.
  Kısıt: JPEG/PNG/WEBP, ≤4MB. **Plus gerekli** (yoksa `403 plus_gerekli`).
- `DELETE /uye/avatar` — avatarı kaldırır (Plus şartı yok).
- Depolama: `/home/gezgah/public_html/uploads/app-avatars` → `https://gezgah.com/uploads/app-avatars`.

---

## 6. Gezi Rotaları (Plus'a özel yazma)

Sıralı mekan listesi + her durakta yorum + **kapak görseli**. Okuma serbest; **oluşturma/düzenleme Plus ister**.

| Metot | Uç | Açıklama |
|------|----|----------|
| GET | `/rotalar` | **Keşfet akışı** — herkese açık rotalar (sahip bilgisiyle) |
| GET | `/uye/rotalar` | Üyenin KENDİ rotaları (gizli dahil) |
| POST | `/uye/rotalar` | Rota oluştur `{baslik, aciklama?, gorunurluk?}` **[Plus]** |
| GET | `/uye/rotalar/{id}` | Rota detayı (sıralı mekanlar + yorumlar + sahip) |
| POST | `/uye/rotalar/{id}/guncelle` | Rota bilgisi güncelle **[Plus]** |
| DELETE | `/uye/rotalar/{id}` | Rota sil |
| POST | `/uye/rotalar/{id}/mekan` | Sona mekan ekle `{post_id, yorum?}` **[Plus]** |
| POST | `/uye/rotalar/{id}/mekan/guncelle` | Durak yorumu güncelle `{durak_id, yorum}` **[Plus]** |
| DELETE | `/uye/rotalar/{id}/mekan` | Durak sil `{durak_id}` |
| POST | `/uye/rotalar/{id}/sirala` | Durakları sırala `{sira:[durak_id,...]}` **[Plus]** |
| POST | `/uye/rotalar/{id}/kapak` | **Kapak görseli yükle** (base64/multipart) **[Plus]** |
| DELETE | `/uye/rotalar/{id}/kapak` | Kapak görselini kaldır |

- `gorunurluk`: `gizli` (varsayılan) veya `herkese_acik`.
- Rota özetinde `kapak_gorsel` (URL veya null) döner. Detayda her durak: `{ durak_id, sira, yorum, mekan: {ozet} }`; silinmiş mekan `{silinmis:true}`. Detayda ayrıca `sahip` ve `benim` (bool) döner.

### 6.1. Keşfet akışı — `GET /rotalar`
Herkese açık (`gorunurluk=herkese_acik`) rotaları listeler. **En yeni en üstte** (created_at DESC).

Query: `?uye_id=` (opsiyonel — sadece o üyeninkiler) · `?page=` · `?limit=` (1-50, vars. 20).
Görünürlük farkı: **yalnız `herkese_acik` rotalar** bu akışta görünür; `gizli` rotalar yalnız sahibinin
`/uye/rotalar` listesinde görünür.

Yanıt (her öğe rota özeti + **sahip** bilgisi):
```json
{
  "success": true,
  "data": [
    {
      "id": 5, "baslik": "Kadıköy Turu", "aciklama": "...",
      "gorunurluk": "herkese_acik",
      "kapak_gorsel": "https://gezgah.com/uploads/app-rotalar/5-ab12cd34ef.jpg",
      "durak_sayisi": 4,
      "created_at": "2026-08-16 21:10:00", "updated_at": "...",
      "sahip": { "uye_id": 12, "isim": "Ada", "soyisim": "Yılmaz",
                 "avatar": "https://gezgah.com/uploads/app-avatars/12-....jpg" }
    }
  ],
  "meta": { "page":1, "limit":20, "total":37, "pages":2, "has_more":true, "next_page":2, "uye_id":null }
}
```
- Belirli üyenin herkese açık rotaları: `GET /rotalar?uye_id=12`.
- Tümü (akış): `GET /rotalar`.
- Kimlik: cihaz **veya** üye token'ı yeterli (üye olmak şart değil; içerik herkese açık).

### 6.2. Kapak görseli — `POST /uye/rotalar/{id}/kapak`  [Plus]
Body: `{ "kapak": "data:image/jpeg;base64,..." }` (veya çıplak base64) ya da multipart `kapak` dosyası.
Görsel **1200×750 (16:10)** merkez-kırpma ile JPEG'e dönüştürülüp saklanır.
Yanıt: `{ "durum":"yuklendi", "kapak_gorsel":"https://gezgah.com/uploads/app-rotalar/5-....jpg" }`.
Kısıt: JPEG/PNG/WEBP, ≤6MB. Kaldırma: `DELETE /uye/rotalar/{id}/kapak`.
Depolama: `/home/gezgah/public_html/uploads/app-rotalar` → `https://gezgah.com/uploads/app-rotalar`.

Örnek — rota oluştur + kapak + iki durak:
```
POST /uye/rotalar            { "baslik": "Kadıköy Turu", "gorunurluk": "herkese_acik" }  -> { rota: { id: 5 } }
POST /uye/rotalar/5/kapak    { "kapak": "data:image/jpeg;base64,..." }                    -> { kapak_gorsel: "..." }
POST /uye/rotalar/5/mekan    { "post_id": 1064, "yorum": "Kahve" }                        -> { durak_id: 11 }
POST /uye/rotalar/5/mekan    { "post_id": 2091, "yorum": "Akşam yemeği" }
POST /uye/rotalar/5/sirala   { "sira": [12, 11] }
GET  /rotalar                                                                             -> keşfet akışında görünür
```

---

## 7. Kedy (Plus'a özel)

- `POST /kedy` ve `GET /kedy/gecmis` artık **yalnız aktif Plus üyesi** içindir.
- Üye değilse: `403 { plus_gerekli, giris_gerekli }`. Plus yoksa: `403 { plus_gerekli }`.
- Hız sınırı: üye başına dakikada 20 istek.

---

## 8. Veritabanı Şeması

Migration: `php rest/tools/migrate_plus_uyelik.php` (idempotent).

> Medya (avatar + rota kapak) dizin/URL ayarları `config/uploads.php`'dedir (IAP'tan ayrı, deploy edilebilir).

- `app_uyeler` (+ eklenenler): `avatar`, `plus_expires_at`, `plus_platform`, `plus_product_id`, `plus_last_verified_at`.
- `app_uye_tokenlari`: `id, uye_id, token(uniq), created_at, last_seen_at`.
- `app_plus_abonelikler`: `id, uye_id, platform, product_id, transaction_id, expires_at, status, environment, raw, created_at, updated_at` — UNIQUE(platform, transaction_id).
- `app_gezi_rotalari`: `id, uye_id, baslik, aciklama, gorunurluk, kapak_post_id, kapak_gorsel, created_at, updated_at`.
- `app_gezi_rota_mekanlari`: `id, rota_id, post_id, sira, yorum, created_at`.

---

## 9. Durum Kodları

| Kod | Anlam |
|-----|-------|
| 200/201 | Başarılı |
| 401 | Token yok/geçersiz veya kimlik hatalı |
| 402 | IAP makbuzu doğrulanamadı |
| 403 | Yetki yok / Plus gerekli (`plus_gerekli`) |
| 409 | Çakışma (telefon/e-posta zaten kayıtlı) |
| 422 | Doğrulama hatası (eksik/geçersiz alan; `need_code`, `code_wrong`) |
| 429 | Çok fazla istek (rate-limit / OTP flood) |
| 503 | Doğrulama servisi (Redis) kullanılamıyor |

---

## 10. Flutter Entegrasyon Notları

1. **Kayıt**: `kayit-kod-gonder` → SMS kodu → `kayit` (kod ile). Dönen `token`'ı güvenli sakla.
2. Tüm korumalı isteklerde `Authorization: Bearer <token>`.
3. **IAP**: `in_app_purchase` paketiyle satın al → makbuzu `POST /uye/plus/dogrula` ile doğrula →
   `GET /uye/plus/durum` ile UI'ı güncelle. Uygulama açılışında ve satın alma "restore"da tekrar doğrula.
4. `403 plus_gerekli` gelen özelliklerde Plus satın alma ekranına yönlendir.
5. **X-App-Key zorunlu (canlı):** tüm isteklere `X-App-Key` başlığını ekle (bkz. §2.3), yoksa `401` alırsın.
```
