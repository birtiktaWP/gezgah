# Üye Kayıt & Giriş (App Üyesi — Parolalı)

Uygulama üyeleri için **parolalı** kayıt/giriş akışı. Kayıt ve giriş ayrı
endpoint'lerdir. Parola `password_hash` (bcrypt) ile hash'lenerek saklanır;
asla düz metin tutulmaz veya API yanıtında dönmez.

Veri `app_uyeler` tablosunda tutulur. **Şehir her zaman 34 (İstanbul)**; ilçe,
`ilceler` tablosunun `id`'sini referanslar (bkz. `GET /ilceler`).

> Base URL: `https://api.gezgah.com/rest`

## Önce cihaz token'ı gerekir

Tüm korumalı endpoint'ler gibi `/uye/*` de bir erişim token'ı ister
(`Authorization: Bearer <token>`). Uygulama ilk açılışta `POST /cihaz/kayit`
ile bir **cihaz token'ı** alır ve `/uye/kayit` / `/uye/giris`'i bu token ile
çağırır (bkz. [CIHAZ_TOKEN.md](CIHAZ_TOKEN.md), [GUVENLIK.md](GUVENLIK.md)).

Kayıt/giriş başarılı olunca dönen **üye token'ı** da geçerli bir erişim
token'ıdır; `/uye/me` gibi üyeye özel isteklerde bu token kullanılır.

## Tablo: `app_uyeler`

Tek seferlik migration ile oluşturulur (idempotent; `parola` kolonunu mevcut
tabloya da ekler):

```bash
php rest/tools/migrate_app_uyeler.php
```

| Kolon | Tip | Zorunlu | Açıklama |
|-------|-----|:------:|----------|
| `id` | INT UNSIGNED, PK | — | Üye id'si |
| `isim` | VARCHAR(100) | ✅ | Ad |
| `soyisim` | VARCHAR(100) | ✅ | Soyad |
| `email` | VARCHAR(190), UNIQUE | ✅ | E-posta (giriş anahtarı) |
| `telefon` | VARCHAR(20) | ✅ | Cep telefonu (yalnızca rakam saklanır) |
| `parola` | VARCHAR(255) | ✅ (kayıtta) | bcrypt hash (`password_hash`) |
| `ulke_kodu` | VARCHAR(8) | — | Ülke kodu, telefondan ayrı (vars. `+90`) |
| `cinsiyet` | VARCHAR(20) | — | `erkek` \| `kadin` \| `diger` |
| `dogum_gunu` | DATE | — | Doğum günü (`YYYY-AA-GG`) |
| `sehir` | SMALLINT | — | **Her zaman 34** (İstanbul plaka) |
| `ilce_id` | INT UNSIGNED | — | `ilceler.id` (İstanbul ilçesi) |
| `token` | VARCHAR(64), UNIQUE | — | Üye erişim token'ı |
| `status` | TINYINT | — | 1 = aktif |
| `son_giris_at` | TIMESTAMP | — | Son giriş zamanı |
| `created_at` / `updated_at` | TIMESTAMP | — | Oluşturma / güncelleme |

**Kayıt zorunlu alanları: `isim`, `soyisim`, `email`, `telefon`, `parola`.**
Diğerleri opsiyoneldir. Parola en az **6** karakter olmalı.

## Endpoint'ler

| Method | Yol | Açıklama |
|--------|-----|----------|
| POST | `/uye/kayit` | Yeni hesap oluşturur (parola ile). Email varsa `409` |
| POST | `/uye/giris` | E-posta + parola ile giriş |
| GET | `/uye/me` | Üye token'ına göre profil |
| POST | `/uye/guncelle` | Profil bilgilerini günceller (kısmi, giriş yapmış üye) |
| POST | `/uye/sifre-degistir` | Mevcut parolayı değiştirir (giriş yapmış üye) |
| POST | `/uye/cikis` | Token'ı geçersiz kılar |

### `POST /uye/kayit`

İstek başlığı: `Authorization: Bearer <cihaz_token>`

```json
{
  "isim": "Ayşe",
  "soyisim": "Kaya",
  "email": "ayse@example.com",
  "telefon": "0555 111 22 33",
  "parola": "gizli123",
  "ulke_kodu": "+90",
  "cinsiyet": "kadin",
  "dogum_gunu": "1992-03-08",
  "ilce_id": 3,
  "device_token": "<opsiyonel: cihazı bu üye ile ilişkilendir>"
}
```

- `parola`: en az 6 karakter. Hash'lenerek saklanır.
- `telefon`: her biçim kabul; sunucu **yalnızca rakamları** saklar
  (`0555 111 22 33` → `05551112233`), 7–15 hane olmalı.
- `ulke_kodu`: `+90` / `90` → `+90`'a normalize edilir (telefondan ayrı).
- `cinsiyet`: yalnızca `erkek` / `kadin` / `diger`.
- `dogum_gunu`: `YYYY-AA-GG` geçerli tarih.
- `ilce_id`: `GET /ilceler`'den bir İstanbul ilçesi id'si. Şehir zaten 34.

Yanıt (**201**):

```json
{
  "success": true,
  "data": {
    "token": "5627aaec...b6daca",
    "uye": {
      "id": 2, "isim": "Ayşe", "soyisim": "Kaya", "email": "ayse@example.com",
      "telefon": "05551112233", "ulke_kodu": "+90", "cinsiyet": "kadin",
      "dogum_gunu": "1992-03-08", "sehir": 34, "ilce_id": 3, "ilce": "Ataşehir",
      "status": 1, "son_giris_at": "2026-07-13 23:04:48", "created_at": "2026-07-13 23:04:48"
    }
  },
  "error": null
}
```

Hatalar: `422` (zorunlu alan eksik / geçersiz email/telefon/parola<6/cinsiyet/dogum_gunu/ilce_id),
`409` (e-posta zaten kayıtlı), `401` (cihaz token'ı yok).

### `POST /uye/giris`

İstek başlığı: `Authorization: Bearer <cihaz_token>`

```json
{ "email": "ayse@example.com", "parola": "gizli123" }
```

Yanıt (**200**): kayıt yanıtıyla aynı `{ token, uye }` yapısı. Her girişte
`token` **yenilenir** (önceki token geçersiz olur).

Hatalar: `422` (email/parola eksik), `401` (e-posta veya parola hatalı).

> **Güvenlik:** "kullanıcı yok" ile "parola yanlış" ayrımı yapılmaz; her ikisi
> de `401 "E-posta veya parola hatalı."` döner (e-posta enumeration'a karşı).

### `GET /uye/me`

```bash
curl "https://api.gezgah.com/rest/uye/me" -H "Authorization: Bearer <uye_token>"
```

Yanıt (200): `data.uye` profil objesi. Token geçersizse `401`.

### `POST /uye/guncelle`

İstek başlığı: `Authorization: Bearer <uye_token>` (giriş yapmış üye)

Profil bilgilerini **kısmi** günceller: yalnızca gövdede gönderilen alanlar
değişir, gönderilmeyenler olduğu gibi kalır. Güncellenebilir alanlar:
`isim, soyisim, email, telefon, ulke_kodu, cinsiyet, dogum_gunu, ilce_id`.

- **Şehir** güncellenmez (her zaman 34). **Parola** buradan değişmez
  (bkz. `/uye/sifre-degistir`).
- `email`: format kontrol edilir; başka bir hesapta kullanılıyorsa `409`.
- `telefon`: yalnızca rakama indirgenir (7-15 hane).
- `cinsiyet`, `dogum_gunu`, `ilce_id`: boş string (`""`) veya `null`
  gönderilirse ilgili alan **temizlenir** (null yapılır).
- Diğer doğrulamalar `/uye/kayit` ile aynıdır.

```json
{
  "isim": "Cansu",
  "telefon": "0555 999 88 77",
  "cinsiyet": "kadin",
  "dogum_gunu": "1995-04-20",
  "ilce_id": 6
}
```

Yanıt (**200**): güncellenmiş `{ uye }` objesi (token değişmez).

```json
{
  "success": true,
  "data": {
    "uye": {
      "id": 4, "isim": "Cansu", "soyisim": "Yıldız", "email": "can@example.com",
      "telefon": "05559998877", "ulke_kodu": "+90", "cinsiyet": "kadin",
      "dogum_gunu": "1995-04-20", "sehir": 34, "ilce_id": 6, "ilce": "Bahçelievler",
      "status": 1, "son_giris_at": "…", "created_at": "…"
    }
  },
  "error": null
}
```

Hatalar: `401` (token geçersiz), `409` (e-posta başka hesapta), `422`
(geçersiz alan değeri veya hiç alan gönderilmedi).

### `POST /uye/sifre-degistir`

İstek başlığı: `Authorization: Bearer <uye_token>` (giriş yapmış üye)

```json
{ "eski_parola": "gizli123", "yeni_parola": "yeni45678" }
```

- Mevcut parola doğrulanır. Yeni parola en az 6 karakter olmalı.
- Başarılıysa parola güncellenir ve **token yenilenir** (diğer oturumlar düşer).

Yanıt (200):

```json
{ "success": true, "data": { "durum": "parola_degistirildi", "token": "<yeni_token>" }, "error": null }
```

Hatalar: `401` (token geçersiz veya mevcut parola hatalı), `422` (alan eksik / yeni parola < 6).

### `POST /uye/cikis`

```bash
curl -X POST "https://api.gezgah.com/rest/uye/cikis" -H "Authorization: Bearer <uye_token>"
```

Yanıt (200): `{ "durum": "cikis_yapildi" }`. Token DB'de `NULL` yapılır.

## Örnek akış (curl)

```bash
# 1) Cihaz token'ı al (ilk açılış)
DEV=$(curl -s -X POST https://api.gezgah.com/rest/cihaz/kayit \
      -H "Content-Type: application/json" -d '{"platform":"android"}' | jq -r .data.token)

# 2) Kayıt
curl -X POST https://api.gezgah.com/rest/uye/kayit \
     -H "Authorization: Bearer $DEV" -H "Content-Type: application/json" \
     -d '{"isim":"Ayşe","soyisim":"Kaya","email":"ayse@example.com","telefon":"05551112233","parola":"gizli123","ilce_id":3}'

# 3) Giriş
curl -X POST https://api.gezgah.com/rest/uye/giris \
     -H "Authorization: Bearer $DEV" -H "Content-Type: application/json" \
     -d '{"email":"ayse@example.com","parola":"gizli123"}'

# 4) Profil
curl https://api.gezgah.com/rest/uye/me -H "Authorization: Bearer <uye_token>"
```

## Flutter kullanımı (öneri)

```dart
// Kayıt: isim, soyisim, email, telefon, parola zorunlu. İlçe: GET /ilceler.
Future<void> uyeKayit(Map<String, dynamic> form) async {
  final res = await Api.instance.dio.post('/uye/kayit', data: {
    ...form,
    'device_token': await storage.read(key: 'device_token'),
  });
  await storage.write(key: 'uye_token', value: res.data['data']['token']);
}

// Giriş
Future<void> uyeGiris(String email, String parola) async {
  final res = await Api.instance.dio.post('/uye/giris', data: {'email': email, 'parola': parola});
  await storage.write(key: 'uye_token', value: res.data['data']['token']);
}
```

## Güvenlik notları

- Parolalar **bcrypt** (`password_hash` / `PASSWORD_DEFAULT`) ile saklanır;
  doğrulama `password_verify` ile yapılır. Düz metin parola tutulmaz.
- Parola/veri trafiği yalnızca **HTTPS** üzerinden gitmelidir.
- Login enumeration'a karşı giriş hataları genel mesaj döner.
- Parola değişiminde token yenilenir; eski oturumlar geçersiz olur.
- Kaba kuvvet (brute force) denemelerine karşı **rate limiting** önerilir
  (bkz. [GUVENLIK.md](GUVENLIK.md) §6). İsteğe bağlı: parola sıfırlama için
  SMS/e-posta OTP akışı eklenebilir.

## İlgili dokümanlar

- Cihaz token akışı: [CIHAZ_TOKEN.md](CIHAZ_TOKEN.md)
- Güvenlik katmanları: [GUVENLIK.md](GUVENLIK.md)
- İlçe listesi: `GET /ilceler` — [README.md](README.md)
