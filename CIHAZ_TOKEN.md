# Cihaz Token (Device Token) Sistemi

Mobil uygulama **ilk açılışta** bir access token üretir (veya sunucudan alır),
bunu cihaz bilgileriyle birlikte API'ye gönderir. Sunucu bu token'ı
`cihaz_tokenlari` tablosunda saklar ve cihazı bu token üzerinden tanır.
Kullanıcı **üyelik girişi** yaptığında ilgili cihaz satırı `user_id` ile
güncellenerek cihaz ile üye ilişkilendirilir.

Bu token, giriş yapılmadan (anonim) da çalışır; böylece bildirim okundu
durumu gibi cihaza özel bilgiler üyelik olmadan da tutulabilir.

> Base URL: `https://api.gezgah.com/rest`

## Tablo: `cihaz_tokenlari`

LIVE veritabanında tek seferlik migration ile oluşturulur:

```bash
php rest/tools/migrate_cihaz_tokenlari.php
```

| Kolon | Tip | Açıklama |
|-------|-----|----------|
| `id` | INT UNSIGNED, PK, AUTO_INCREMENT | Kayıt id'si |
| `token` | VARCHAR(64), UNIQUE | Cihaz access token'ı (64 hex karakter) |
| `user_id` | INT UNSIGNED, NULL | İlişkili üye (`yzd_users.id`); giriş yapılmadıysa `NULL` |
| `platform` | VARCHAR(20), NULL | `ios` \| `android` |
| `device_model` | VARCHAR(255), NULL | Cihaz modeli (ör. "iPhone 14", "SM-S911B") |
| `os_version` | VARCHAR(50), NULL | İşletim sistemi sürümü |
| `app_version` | VARCHAR(50), NULL | Uygulama sürümü |
| `device_uuid` | VARCHAR(255), NULL | Cihazın benzersiz id'si (opsiyonel) |
| `push_token` | VARCHAR(255), NULL | FCM/APNs push token'ı (opsiyonel) |
| `bildirim_okundu_at` | TIMESTAMP, NULL | Cihazın tüm bildirimleri okuduğu son zaman (bkz. [BILDIRIMLER.md](BILDIRIMLER.md)) |
| `last_seen_at` | TIMESTAMP, NULL | Cihazın en son görüldüğü zaman |
| `created_at` | TIMESTAMP | Oluşturulma |
| `updated_at` | TIMESTAMP | Son güncelleme (otomatik) |

İndeksler: `token` (benzersiz), `user_id`, `device_uuid`.

## Akış

1. **İlk açılış:** App bir token üretir (ör. `uuid` + rastgele) ve güvenli
   depoda (Keychain/Keystore) saklar. Sonra `POST /cihaz/kayit` ile token'ı ve
   cihaz bilgisini gönderir. Token gönderilmezse **sunucu üretir** ve yanıtta
   döner; app bu token'ı saklamalıdır.
2. **Cihaz tanıma:** Sonraki açılışlarda app aynı token'ı gönderir; kayıt
   güncellenir (upsert) ve `last_seen_at` yenilenir.
3. **Üyelik girişi:** Kullanıcı giriş/kayıt yaptığında cihaz üye ile
   ilişkilendirilir. İki yol vardır:
   - `POST /auth/login` veya `POST /auth/register` body'sine `device_token`
     eklenirse otomatik ilişkilendirilir.
   - Ya da ayrıca `POST /cihaz/uye-baglama` çağrılır.

## Endpoint'ler

| Method | Yol | Açıklama |
|--------|-----|----------|
| POST | `/cihaz/kayit` | Cihazı kaydeder/günceller (token + cihaz bilgisi) |
| POST | `/cihaz/uye-baglama` | Cihaz satırını üye (`user_id`) ile ilişkilendirir |
| GET | `/cihaz/me` | Token'a göre cihaz kaydını döner (cihaz tanıma) |

Token'ı gönderme yolları (kayıt hariç): `Authorization: Bearer <token>`,
`?token=<token>` veya JSON body'de `"token"`.

### `POST /cihaz/kayit`

İstek gövdesi (tüm alanlar opsiyonel; `token` yoksa sunucu üretir):

```json
{
  "token": "a1b2c3...",
  "device_uuid": "550e8400-e29b-41d4-a716-446655440000",
  "platform": "android",
  "device_model": "SM-S911B",
  "os_version": "14",
  "app_version": "1.0.0",
  "push_token": "fcm_token_...",
  "user_id": 2
}
```

> `user_id` opsiyoneldir; verilir ve geçerli/aktif bir kullanıcıysa cihaz
> hemen o üye ile ilişkilendirilir.

Yanıt (201):

```json
{
  "success": true,
  "data": {
    "token": "a1b2c3...",
    "device": {
      "id": 12,
      "token": "a1b2c3...",
      "user_id": null,
      "platform": "android",
      "device_model": "SM-S911B",
      "os_version": "14",
      "app_version": "1.0.0",
      "device_uuid": "550e8400-e29b-41d4-a716-446655440000",
      "push_token": "fcm_token_...",
      "bildirim_okundu_at": null,
      "last_seen_at": "2026-07-08 10:00:00",
      "created_at": "2026-07-08 10:00:00"
    }
  },
  "error": null
}
```

### `POST /cihaz/uye-baglama`

Üyelik girişinden sonra cihazı üye ile ilişkilendirir.

İstek gövdesi (`token` Bearer header ile de gönderilebilir):

```json
{ "token": "a1b2c3...", "user_id": 2 }
```

Yanıt (200): güncellenmiş `device` objesi (`user_id` dolu).

Hatalar: `422` (token/user_id eksik), `404` (cihaz veya kullanıcı bulunamadı).

### `GET /cihaz/me`

```bash
curl "https://api.gezgah.com/rest/cihaz/me" -H "Authorization: Bearer a1b2c3..."
```

Yanıt (200): `data.device` cihaz kaydı. Token geçersizse `404`.

## Örnek istekler

```bash
# İlk açılış — token'ı sunucuya üret+kaydettir
curl -X POST "https://api.gezgah.com/rest/cihaz/kayit" \
     -H "Content-Type: application/json" \
     -d '{"platform":"android","device_model":"SM-S911B","os_version":"14","app_version":"1.0.0"}'

# App kendi token'ını üretip gönderirse
curl -X POST "https://api.gezgah.com/rest/cihaz/kayit" \
     -H "Content-Type: application/json" \
     -d '{"token":"a1b2c3...","platform":"ios","device_model":"iPhone 14"}'

# Girişte otomatik ilişkilendirme (device_token ile)
curl -X POST "https://api.gezgah.com/rest/auth/login" \
     -H "Content-Type: application/json" \
     -d '{"email":"ali@example.com","password":"sifre123","device_token":"a1b2c3..."}'

# Ayrı çağrı ile ilişkilendirme
curl -X POST "https://api.gezgah.com/rest/cihaz/uye-baglama" \
     -H "Authorization: Bearer a1b2c3..." \
     -H "Content-Type: application/json" \
     -d '{"user_id":2}'
```

## Flutter kullanımı (öneri)

```dart
// 1) İlk açılışta cihaz token'ını al/oluştur ve kaydettir.
Future<String> cihazKayit() async {
  final storage = const FlutterSecureStorage();
  var token = await storage.read(key: 'device_token');

  final res = await Api.instance.dio.post('/cihaz/kayit', data: {
    if (token != null) 'token': token,
    'platform': Platform.isIOS ? 'ios' : 'android',
    'device_model': await deviceModel(),
    'os_version': await osVersion(),
    'app_version': await appVersion(),
  });

  token = res.data['data']['token'] as String;
  await storage.write(key: 'device_token', value: token); // sunucu ürettiyse sakla
  return token;
}

// 2) Girişte device_token gönder -> otomatik ilişkilendir.
await Api.instance.dio.post('/auth/login', data: {
  'email': email, 'password': password,
  'device_token': await storage.read(key: 'device_token'),
});
```

## Notlar

- Token benzersizdir (`UNIQUE`); aynı token ile tekrar `POST /cihaz/kayit`
  çağrısı cihaz bilgilerini **günceller** (upsert), yeni satır açmaz.
- App token'ı bir kez üretip **kalıcı** saklamalıdır; her açılışta yeni token
  üretmek yeni cihaz satırı oluşturur.
- Cihaz token'ı ile üye token'ı (`yzd_users.hash`, bkz. [README.md](README.md))
  farklı şeylerdir. Üye kimlik doğrulaması için `/auth/*` token'ı kullanılır;
  cihaz endpoint'leri cihaz token'ını kullanır.
- Push bildirim göndermek istenirse `push_token` alanı bu tabloda hazır tutulur.
