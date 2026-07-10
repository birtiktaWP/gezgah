# Gezgah API

`gezgah_v3` veritabanı için framework'süz (vanilla) PHP REST API.
Şema analizi için bkz. **[DATABASE.md](DATABASE.md)**.

Mekan listeleme, kategoriler, etkinlikler, favoriler ve bildirimler endpoint'lerini sunar.

## Gereksinimler

- PHP 7.4+ (üretim sunucusu PHP 8.4 — kod her ikisiyle de uyumlu)
- `pdo_mysql` ve `mbstring` eklentileri
- MySQL / MariaDB (gezgah_v3 dump'ı import edilmiş)

## Kurulum

1. Veritabanını oluştur ve dump'ı **utf8mb4** ile import et:

   ```sql
   CREATE DATABASE gezgah_v3 CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
   ```
   ```bash
   mysql -u root -p gezgah_v3 < gezgah_v3.sql
   ```

2. Bağlantı bilgilerini `config/config.php` içinde düzenle veya ortam
   değişkeni olarak ver: `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASS`,
   `MEDIA_BASE_URL`, `APP_DEBUG`.

3. Geliştirme sunucusunu başlat (kök dizinde, router modunda):

   ```bash
   php -S 127.0.0.1:8000 index.php
   ```

   Üretimde tüm proje klasörünü `/rest/` altına yükle; istekler
   `https://api.gezgah.com/rest/<endpoint>` adresine gider. Temiz URL için
   `.htaccess` (mod_rewrite) hazırdır ve `config/`, `src/`, `bootstrap.php`,
   `.sql`/`.md` gibi hassas dosyalara web erişimini kapatır.

## Proje yapısı

```
gezgah-api/   (sunucuda /rest/ klasörü)
├── index.php                  # front controller + rotalar
├── .htaccess                  # temiz URL + güvenlik (Apache)
├── bootstrap.php              # autoloader + init
├── config/config.php          # DB + uygulama ayarları
└── src/
    ├── Database.php           # PDO sarmalayıcı
    ├── Response.php           # JSON yanıt zarfı
    ├── Router.php             # regex router
    ├── Helpers.php            # parametre + mojibake yardımcıları
    ├── Auth.php               # token yardımcıları
    ├── PostRepository.php     # posts/postmetas ortak okuma
    └── Controllers/
        ├── AuthController.php
        ├── CihazController.php
        ├── MekanController.php
        ├── KategoriController.php
        ├── EtkinlikController.php
        ├── FavoriController.php
        ├── BildirimController.php
        └── IlceController.php
```

## Endpoint'ler

> Base URL: `https://api.gezgah.com/rest`

| Method | Yol | Açıklama |
|--------|-----|----------|
| GET | `/health` | Sağlık kontrolü |
| POST | `/auth/register` | Kayıt. Body: `{ "name", "lastname", "email", "phone", "password", "gender" }` → `{ token, user }` |
| POST | `/auth/login` | Giriş. Body: `{ "email", "password" }` → `{ token, user }` |
| GET | `/auth/me` | Mevcut kullanıcı. Header: `Authorization: Bearer <token>` |
| POST | `/auth/logout` | Token'ı geçersiz kılar. Header: `Authorization: Bearer <token>` |
| POST | `/cihaz/kayit` | Cihaz kaydı (ilk açılış). Body: `{ token?, device_uuid?, platform?, device_model?, os_version?, app_version?, push_token?, user_id? }` → `{ token, device }`. Bkz. [CIHAZ_TOKEN.md](CIHAZ_TOKEN.md) |
| POST | `/cihaz/uye-baglama` | Cihazı üye ile ilişkilendirir. Body: `{ token?, user_id }` (token Bearer da olabilir) |
| GET | `/cihaz/me` | Token'a göre cihaz kaydı. Header: `Authorization: Bearer <token>` |
| GET | `/mekanlar` | Mekan listesi. Query: `type` (restoran\|plaj\|mesire, vars. restoran), `kategori` (id), `bolge`, `q` (arama), `page`, `limit` (max 100) |
| GET | `/mekanlar/yeni-eklenenler` | Son eklenen restoranlar (SQL). Query: `limit` (vars. 10, max 50) |
| GET | `/mekanlar/yakindakiler` | Konumu olan restoran havuzu (SQL). Mesafe sıralaması **mobil app** tarafında yapılır. Query: `limit` (vars. 100, max 500) |
| GET | `/mekanlar/{id}` | Mekan detayı: meta, çalışma saatleri, özellikler, galeri |
| GET | `/pagination_isletmeler` | İşletmeleri (restoran) sayfalı listeler (15/sayfa). Query: `page`, `limit` (max 50), `q`. Bkz. [PAGINATION_ISLETMELER.md](PAGINATION_ISLETMELER.md) |
| GET | `/one-cikan-firmalar` | Öne çıkan mekanlar (`one_cikan_firma = 1`). Query: `type`, `page`, `limit` |
| GET | `/harita` | Harita içerikleri: koordinatlı mekanlar (sayfalamasız). Query: `kategori`, `type`. Her item enlem/boylam/adres/görsel ile. Bkz. [HARITA.md](HARITA.md) |
| GET | `/arama` | Restoran adı + menü/yemek adı araması (LIKE). Query: `q` (zorunlu, min 2), `page`, `limit` (max 100), `user_id` (opsiyonel, geçmişe kaydeder). Bkz. [ARAMA.md](ARAMA.md) |
| GET | `/populer-aramalar` | En çok aranan kelimeler (vars. 6). Query: `limit` (max 20), `days`. Bkz. [ARAMA_GECMISI.md](ARAMA_GECMISI.md) |
| GET | `/search-page-settings` | Arama sayfası yapılandırması (sponsorlu restoranlar). Bkz. [SEARCH_PAGE_SETTINGS.md](SEARCH_PAGE_SETTINGS.md) |
| GET | `/search-page-settings/{key}` | Tek arama sayfası alanı (`section_key`) |
| GET | `/kategoriler` | Öne çıkan kategoriler (home_page_settings → `one_cikan_kategoriler`, kayıtlı sırayla) + her birinin mekan sayısı. Yapılandırma yoksa tüm kategoriler döner. |
| GET | `/kategoriler/{id}` | Kategori detayı: bilgi + restoranlar (sayfalı) + alt kategoriler + sabit restoran. Bkz. [KATEGORI_LISTELEME.md](KATEGORI_LISTELEME.md) |
| GET | `/kategoriler/{id}/mekanlar` | Kategoriye ait mekanlar (sayfalı) |
| GET | `/etkinlikler` | Etkinlikler. Query: `status` (vars. 1), `upcoming` (1), `boss`, `page`, `limit` |
| GET | `/etkinlikler/{id}` | Etkinlik detayı |
| GET | `/favoriler?user_id=` | Kullanıcının favorileri (`type` ile filtre) |
| POST | `/favoriler` | Favori ekle. Body: `{ "user_id": 2, "post_id": 2 }` |
| DELETE | `/favoriler` | Favori sil. Body: `{ "user_id": 2, "post_id": 2 }` |
| GET | `/bildirimler` | Bildirimler (pro-bildirim postları + logs). Cihaz token'ı verilirse `okundu` bilgisi eklenir. Bkz. [BILDIRIMLER.md](BILDIRIMLER.md) |
| POST | `/bildirimler/okundu` | Cihazın tüm bildirimlerini okundu işaretler. Token: `Authorization: Bearer <token>`. Bkz. [BILDIRIMLER.md](BILDIRIMLER.md) |
| GET | `/ilceler` | İlçe/bölge listesi. Query: `sehir`, `kita` |
| GET | `/filtreler` | Filtre listesi (id, isim, slug, ikon). Query: `type` (restoran\|plaj\|mesire\|otopark\|etkinlik). Bkz. [FILTRELER.md](FILTRELER.md) |

### Yanıt formatı

```json
{
  "success": true,
  "data": [ ... ],
  "meta": { "page": 1, "limit": 20, "total": 311, "pages": 16 },
  "error": null
}
```

Hata:

```json
{ "success": false, "data": null, "error": { "message": "..." } }
```

## Örnek istekler

```bash
# Kayıt ol
curl -X POST "https://api.gezgah.com/rest/auth/register" \
     -H "Content-Type: application/json" \
     -d '{"name":"Ali","lastname":"Veli","email":"ali@example.com","phone":"5550001122","password":"sifre123"}'

# Giriş yap (token al)
curl -X POST "https://api.gezgah.com/rest/auth/login" \
     -H "Content-Type: application/json" \
     -d '{"email":"ali@example.com","password":"sifre123"}'

# Mevcut kullanıcı
curl "https://api.gezgah.com/rest/auth/me" -H "Authorization: Bearer <TOKEN>"

curl "https://api.gezgah.com/rest/mekanlar?type=restoran&page=1&limit=10"
curl "https://api.gezgah.com/rest/mekanlar/yeni-eklenenler?limit=10"
curl "https://api.gezgah.com/rest/mekanlar/yakindakiler"
curl "https://api.gezgah.com/rest/mekanlar/2"
curl "https://api.gezgah.com/rest/kategoriler"
curl "https://api.gezgah.com/rest/etkinlikler?upcoming=1"
curl "https://api.gezgah.com/rest/favoriler?user_id=2&type=restoran"
curl -X POST "https://api.gezgah.com/rest/favoriler" \
     -H "Content-Type: application/json" \
     -d '{"user_id":2,"post_id":2}'
```

> Yerel geliştirmede base URL `http://127.0.0.1:8000` olur (örn.
> `http://127.0.0.1:8000/mekanlar`).

## Kimlik doğrulama akışı

1. `POST /auth/register` veya `POST /auth/login` → `token` döner.
2. Token, `yzd_users.hash` kolonunda saklanır (kullanıcı başına tek token).
3. Korumalı isteklerde `Authorization: Bearer <token>` gönderilir.
4. `POST /auth/logout` token'ı temizler.

Parolalar `password_hash()` (bcrypt) ile saklanır; mevcut `$2y$...` hash'leriyle
uyumludur. Yeni kayıtlar `type = app` (config: `app_user_type`) ile oluşturulur.

## Notlar

- **Karakter kodlaması:** Dump çift kodlanmış (mojibake). `Helpers::fixText()`
  metin alanlarını otomatik onarmaya çalışır; yine de DB'yi utf8mb4 ile import
  etmek en sağlıklısıdır.
- **Kimlik doğrulama:** Okuma endpoint'leri herkese açıktır. Favori işlemleri
  mobil app kullanıcısının `user_id`'si (= `yzd_users.id`) ile çalışır ve bu
  id `yzd_users` tablosuna göre doğrulanır (aktif kullanıcı). Canlı ortamda
  token tabanlı auth (login → token) eklenmesi önerilir.
- **"mekan" tipi:** Veritabanında literal `type='mekan'` yoktur; gezilebilir
  mekanlar `restoran`, `plaj` ve `mesire` tipleridir (bkz. DATABASE.md).
