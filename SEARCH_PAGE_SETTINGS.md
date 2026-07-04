# search_page_settings

Arama sayfasındaki dinamik alanların yapılandırmasını tutan tablo.
`home_page_settings` ile **aynı şema ve mantığa** sahiptir; her satır bir "alan"ı
temsil eder ve içeriği `settings` kolonunda JSON olarak saklanır.

Şu an tek alan tanımlıdır: **sponsorlu restoranlar**.

Tablo, LIVE veritabanında (`rest/config/config.php` bilgileriyle) harici
migration scripti üzerinden oluşturulur:

```bash
php rest/tools/migrate_search_page_settings.php
```

Script idempotent'tir: tekrar çalıştırmak tabloyu bozmaz, `section_key`
benzersiz olduğu için satırı günceller.

## Şema

| Kolon | Tip | Açıklama |
|-------|-----|----------|
| `id` | INT UNSIGNED, PK, AUTO_INCREMENT | Satır kimliği |
| `section_key` | VARCHAR(100), UNIQUE | Alanın benzersiz anahtarı |
| `title` | VARCHAR(255), NULL | Alan başlığı |
| `settings` | LONGTEXT (JSON) | Alan içeriği (JSON) |
| `sort_order` | INT, default 0 | Gösterim sırası |
| `status` | TINYINT(1), default 1 | 1 = aktif, 0 = pasif |
| `created_at` | TIMESTAMP | Oluşturulma |
| `updated_at` | TIMESTAMP | Son güncelleme (otomatik) |

```sql
CREATE TABLE IF NOT EXISTS search_page_settings (
    id          INT UNSIGNED NOT NULL AUTO_INCREMENT,
    section_key VARCHAR(100) NOT NULL,
    title       VARCHAR(255) NULL,
    settings    LONGTEXT NOT NULL,
    sort_order  INT NOT NULL DEFAULT 0,
    status      TINYINT(1) NOT NULL DEFAULT 1,
    created_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_section_key (section_key)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

## Alan: `sponsorlu_restoranlar` (`restoran_secim`)

Arama sayfasında öne çıkarılacak sponsorlu restoranların id'leri saklanır.
Restoranlar sistemde `yzd_posts` içinde `type = 'restoran'` olarak tutulur.
Tabloda yalnızca id listesi saklanır; API yanıtında bu id'ler isim/şehir/ilçe
ile **çözülerek** `restaurants` alanı olarak da döner.

**section_key:** `sponsorlu_restoranlar`

```json
{
  "type": "restoran_secim",
  "layout": "horizontal_scroll",
  "restaurant_ids": [2, 933, 1080, 1099]
}
```

Örnekteki id'ler:

| id | Restoran |
|----|----------|
| 2 | Gezgah Kafe |
| 933 | Juste Fried Chicken |
| 1080 | Smoklingrill |
| 1099 | Swanky İstanbul |

## API

> Base URL: `https://api.gezgah.com/rest`

| Method | Yol | Açıklama |
|--------|-----|----------|
| GET | `/search-page-settings` | Aktif tüm arama sayfası alanları (`sort_order`) |
| GET | `/search-page-settings/{key}` | Tek alan (`section_key`, ör. `sponsorlu_restoranlar`) |

`restoran_secim` tipinde `restaurant_ids` gerçek kayıtlara çözülür ve id
sırası korunur.

### `GET /search-page-settings`

```bash
curl "https://api.gezgah.com/rest/search-page-settings"
```

```json
{
  "success": true,
  "data": [
    {
      "section_key": "sponsorlu_restoranlar",
      "title": "Sponsorlu Restoranlar",
      "sort_order": 1,
      "settings": {
        "type": "restoran_secim",
        "layout": "horizontal_scroll",
        "restaurant_ids": [2, 933, 1080, 1099],
        "restaurants": [
          { "id": 2,    "name": "Gezgah Kafe",         "slug": "gezgah-kafe",         "sehir": "Istanbul", "ilce": "Şişli",   "thumbnail": null },
          { "id": 933,  "name": "Juste Fried Chicken", "slug": "juste-fried-chicken", "sehir": "Istanbul", "ilce": "Beyoğlu", "thumbnail": null },
          { "id": 1080, "name": "Smoklingrill",        "slug": "smoklingrill",        "sehir": "Istanbul", "ilce": "Beyoğlu", "thumbnail": null },
          { "id": 1099, "name": "Swanky İstanbul",     "slug": "swanky-istanbul",     "sehir": "Istanbul", "ilce": "Beyoğlu", "thumbnail": null }
        ]
      }
    }
  ],
  "error": null,
  "meta": { "count": 1 }
}
```

## Sponsorlu restoranları güncelleme

`settings.restaurant_ids` dizisini düzenlemek yeterli. En pratik yol
migration scriptindeki `$sponsorluRestoranlar['restaurant_ids']` listesini
değiştirip tekrar çalıştırmaktır; alternatif olarak doğrudan
`UPDATE search_page_settings SET settings = ... WHERE section_key = 'sponsorlu_restoranlar'`.

## Notlar

- Bu tablo `home_page_settings` ile aynı şemayı ve aynı çözümleme (resolve)
  mantığını paylaşır (bkz. [HOME_PAGE_SETTINGS.md](HOME_PAGE_SETTINGS.md)).
- Şehir/ilçe bilgisi bölge id'sinin (`restoran_bolge`) `ilceler` tablosuyla
  eşleştirilmesinden üretilir.
