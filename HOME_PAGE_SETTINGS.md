# home_page_settings

Ana sayfadaki dinamik alanların (kısayollar, kategori vitrinleri vb.)
yapılandırmasını tutan tablo. Her satır bir "alan"ı temsil eder; alanın
içeriği `settings` kolonunda JSON olarak saklanır.

Tablo, LIVE veritabanında (`rest/config/config.php` bilgileriyle) harici
migration scripti üzerinden oluşturulur:

```bash
php rest/tools/migrate_home_page_settings.php
```

Script idempotent'tir: tekrar çalıştırmak tabloyu bozmaz, `section_key`
benzersiz olduğu için örnek satırları günceller.

## Şema

| Kolon | Tip | Açıklama |
|-------|-----|----------|
| `id` | INT UNSIGNED, PK, AUTO_INCREMENT | Satır kimliği |
| `section_key` | VARCHAR(100), UNIQUE | Alanın benzersiz anahtarı (kodda referans) |
| `title` | VARCHAR(255), NULL | Alan başlığı (arayüzde görünen) |
| `settings` | LONGTEXT (JSON) | Alanın içerik yapılandırması (JSON) |
| `sort_order` | INT, default 0 | Ana sayfadaki gösterim sırası |
| `status` | TINYINT(1), default 1 | 1 = aktif, 0 = pasif |
| `created_at` | TIMESTAMP | Oluşturulma zamanı |
| `updated_at` | TIMESTAMP | Son güncelleme (otomatik) |

> Not: `settings` kolonu `LONGTEXT` olarak tanımlıdır (MySQL/MariaDB uyumu için).
> Uygulama tarafında `json_encode` / `json_decode` ile okunur/yazılır.

```sql
CREATE TABLE IF NOT EXISTS home_page_settings (
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

## Alan tipleri (`settings.type`)

### 1. `shortcut` — Hızlı erişim / kısayol satırı

Ana sayfadaki üst yatay kısayol alanı. Her öğe bir kategori kısayolunu ve
gösterilecek ikonu tutar. (Not: eskiden listenin başında bulunan `id: 0`
"Tümü" öğesi kaldırıldı; alan doğrudan kategori kısayolları ile başlar.)

**section_key:** `tumu`

```json
{
  "type": "shortcut",
  "layout": "horizontal_scroll",
  "items": [
    { "id": 138,  "name": "Eczane",        "icon": "💊", "active": false },
    { "id": 62,   "name": "Otopark",       "icon": "🅿️", "active": false },
    { "id": 139,  "name": "Müze",          "icon": "🏛️", "active": false },
    { "id": 140,  "name": "Mesire",        "icon": "🌳", "active": false },
    { "id": 1081, "name": "Kahvaltı",      "icon": "🍳", "active": false },
    { "id": 128,  "name": "Tatlı & Fırın", "icon": "🍰", "active": false },
    { "id": 129,  "name": "Fast Food",     "icon": "🍔", "active": false },
    { "id": 1254, "name": "Balık",         "icon": "🐟", "active": false },
    { "id": 1199, "name": "Çay Bahçesi",   "icon": "🍵", "active": false }
  ]
}
```

Alan açıklamaları:

| Alan | Açıklama |
|------|----------|
| `items[].id` | Kategori post id'si (`yzd_posts.id`) |
| `items[].name` | Kısayolda görünen etiket |
| `items[].icon` | İkon (emoji veya SVG string olarak da tutulabilir) |
| `items[].active` | Varsayılan seçili sekme |
| `layout` | Gösterim biçimi (ör. `horizontal_scroll`) |

> İkon alanına emoji yerine SVG markup da yazılabilir; arayüz string'i
> olduğu gibi basar.

### 2. `kategori_secim` — Öne çıkan kategoriler

Ana sayfada öne çıkarılacak kategorilerin id'leri saklanır. Kategoriler
sistemde `yzd_posts` içinde `type = 'kategori'` olarak tutulur. Tabloda yalnızca
id listesi saklanır; API yanıtında bu id'ler isim/ikon ile **çözülerek**
`categories` alanı olarak da döner (bkz. API bölümü).

**section_key:** `one_cikan_kategoriler`

```json
{
  "type": "kategori_secim",
  "layout": "grid",
  "category_ids": [1081, 129, 128, 1254, 1199, 122, 123, 130, 1101, 1096]
}
```

Örnekteki 10 id:

| id | Kategori | id | Kategori |
|----|----------|----|----------|
| 1081 | Kahvaltı | 122 | Restoran |
| 129 | Fast Food | 123 | Dünya Mutfağı |
| 128 | Tatlı & Fırın | 130 | Meyhane |
| 1254 | Balık | 1101 | Bar & Kokteyl |
| 1199 | Çay Bahçesi | 1096 | Türk Mutfağı |

| Alan | Açıklama |
|------|----------|
| `category_ids` | Seçili kategori id'leri (`yzd_posts.id`, `type='kategori'`) dizisi |
| `layout` | Gösterim biçimi (ör. `grid`) |

### 3. `restoran_secim` — Sponsorlu restoranlar

Ana sayfada öne çıkarılacak sponsorlu restoranların id'leri saklanır.
Restoranlar sistemde `yzd_posts` içinde `type = 'restoran'` olarak tutulur.
Sadece id listesi saklanır; isim/görsel/konum gibi bilgiler restoran
kaydından okunur.

**section_key:** `sponsorlu_restoranlar`

```json
{
  "type": "restoran_secim",
  "layout": "horizontal_scroll",
  "restaurant_ids": [2, 1063, 1080, 1099]
}
```

Örnekteki id'ler:

| id | Restoran |
|----|----------|
| 2 | Gezgah Kafe |
| 1063 | Vanilpuff |
| 1080 | Smoklingrill |
| 1099 | Swanky İstanbul |

| Alan | Açıklama |
|------|----------|
| `restaurant_ids` | Sponsorlu restoran id'leri (`yzd_posts.id`, `type='restoran'`) dizisi |
| `layout` | Gösterim biçimi (ör. `horizontal_scroll`) |

### 4. `etkinlik_secim` — Sponsorlu etkinlikler

Ana sayfada öne çıkarılacak sponsorlu etkinliklerin id'leri saklanır.
Etkinlikler sistemde ayrı bir tabloda (`yzd_etkinlik`) tutulur. Sadece id
listesi saklanır; isim/görsel/tarih gibi bilgiler etkinlik kaydından okunur.

**section_key:** `sponsorlu_etkinlikler`

```json
{
  "type": "etkinlik_secim",
  "layout": "horizontal_scroll",
  "event_ids": [1, 2]
}
```

Örnekteki id'ler:

| id | Etkinlik |
|----|----------|
| 1 | DJ Performansı |
| 2 | test |

| Alan | Açıklama |
|------|----------|
| `event_ids` | Sponsorlu etkinlik id'leri (`yzd_etkinlik.id`) dizisi |
| `layout` | Gösterim biçimi (ör. `horizontal_scroll`) |

## Mevcut kayıtlar

| section_key | title | sort_order | type |
|-------------|-------|-----------|------|
| `tumu` | _(boş)_ | 1 | shortcut |
| `one_cikan_kategoriler` | Öne Çıkan Kategoriler | 2 | kategori_secim |
| `sponsorlu_restoranlar` | Sponsorlu Restoranlar | 3 | restoran_secim |
| `sponsorlu_etkinlikler` | Sponsorlu Etkinlikler | 4 | etkinlik_secim |

## API: Ana sayfa yapılandırmasını çekme

Tablodaki alanlar REST üzerinden JSON olarak döner. `settings` alanı decode
edilmiş (parse edilmiş) halde gelir, yani mobil app doğrudan kullanabilir.

> Base URL: `https://api.gezgah.com/rest`

| Method | Yol | Açıklama |
|--------|-----|----------|
| GET | `/home-page-settings` | Aktif tüm alanları `sort_order`'a göre döner |
| GET | `/home-page-settings/{key}` | Tek alanı `section_key` ile döner (ör. `tumu`) |

### `GET /home-page-settings`

```bash
curl "https://api.gezgah.com/rest/home-page-settings"
```

```json
{
  "success": true,
  "data": [
    {
      "section_key": "tumu",
      "title": "",
      "sort_order": 1,
      "settings": {
        "type": "shortcut",
        "layout": "horizontal_scroll",
        "items": [
          { "id": 138,  "name": "Eczane",        "icon": "💊", "active": false },
          { "id": 62,   "name": "Otopark",       "icon": "🅿️", "active": false },
          { "id": 139,  "name": "Müze",          "icon": "🏛️", "active": false },
          { "id": 140,  "name": "Mesire",        "icon": "🌳", "active": false },
          { "id": 1081, "name": "Kahvaltı",      "icon": "🍳", "active": false },
          { "id": 128,  "name": "Tatlı & Fırın", "icon": "🍰", "active": false },
          { "id": 129,  "name": "Fast Food",     "icon": "🍔", "active": false },
          { "id": 1254, "name": "Balık",         "icon": "🐟", "active": false },
          { "id": 1199, "name": "Çay Bahçesi",   "icon": "🍵", "active": false }
        ]
      }
    }
    // ... diğer alanlar (kahvalti_sokak_tatli, sponsorlu_restoranlar, ...)
  ],
  "error": null,
  "meta": { "count": 4 }
}
```

### `GET /home-page-settings/{key}`

```bash
curl "https://api.gezgah.com/rest/home-page-settings/tumu"
```

```json
{
  "success": true,
  "data": {
    "section_key": "tumu",
    "title": "",
    "sort_order": 1,
    "settings": { "type": "shortcut", "layout": "horizontal_scroll", "items": [ ... ] }
  },
  "error": null
}
```

> Not: Yalnızca `status = 1` (aktif) alanlar `/home-page-settings` listesinde
> döner. `settings` içindeki `type` alanına göre app doğru bileşeni render eder
> (bkz. yukarıdaki alan tipleri).

### Çözülmüş (resolved) alanlar

Tabloda yalnızca id listeleri saklanır, ancak API yanıtında bu id'ler gerçek
kayıtlara **çözülerek** ek alanlar olarak eklenir. Böylece app ek istek atmadan
doğrudan isim/ikon kullanabilir:

| type | Ham alan | Çözülmüş alan | İçerik |
|------|----------|---------------|--------|
| `kategori_secim` | `category_ids` | `categories` | `{ id, name, slug, icon }` |
| `restoran_secim` | `restaurant_ids` | `restaurants` | `{ id, name, slug, sehir, ilce, thumbnail }` |
| `etkinlik_secim` | `event_ids` | `events` | `{ id, name, date, time, image }` |

Çözülmüş listeler, kaydedilen id sırasını korur.

> **Şehir/ilçe kaynağı:** Mekanların şehir/ilçe bilgisi postmeta'da adıyla
> tutulmaz; bölge id'si (`restoran_bolge` / `plaj_bolge` / `mesire_bolge`)
> `ilceler` tablosu (`sehir_ad`, `ilce_ad`) ile eşleştirilerek `sehir` ve
> `ilce` alanları üretilir. Bu alanlar mekan içeren tüm endpoint'lerde
> (`/mekanlar`, `/mekanlar/yeni-eklenenler`, `/mekanlar/yakindakiler`,
> `/pagination_isletmeler`, `/one-cikan-firmalar`, `/mekanlar/{id}`,
> `/kategoriler/{id}/mekanlar`) ve sponsorlu restoranların çözülmüş
> listesinde bulunur.

`GET /home-page-settings/one_cikan_kategoriler` örneği:

```json
{
  "success": true,
  "data": {
    "section_key": "one_cikan_kategoriler",
    "title": "Öne Çıkan Kategoriler",
    "sort_order": 2,
    "settings": {
      "type": "kategori_secim",
      "layout": "grid",
      "category_ids": [1081, 129, 128, 1254, 1199, 122, 123, 130, 1101, 1096],
      "categories": [
        { "id": 1081, "name": "Kahvaltı",      "slug": "kahvalti",     "icon": null },
        { "id": 129,  "name": "Fast Food",     "slug": "fast-food",    "icon": null },
        { "id": 128,  "name": "Tatlı & Fırın", "slug": "tatli-firin",  "icon": null }
        // ... toplam 10 kategori
      ]
    }
  },
  "error": null
}
```

> `icon`, kategorinin `kategori_svg_icon` metasından gelir; tanımlı değilse
> `null` döner.

## Kullanım (PHP)

```php
use Gezgah\Database;

// Aktif alanları sıraya göre çek
$sections = Database::all(
    "SELECT * FROM home_page_settings WHERE status = 1 ORDER BY sort_order"
);

foreach ($sections as $section) {
    $settings = json_decode($section['settings'], true);

    if ($settings['type'] === 'shortcut') {
        foreach ($settings['items'] as $item) {
            // $item['id'], $item['name'], $item['icon']
        }
    }

    if ($settings['type'] === 'kategori_secim') {
        $ids = $settings['category_ids']; // [1081, 129, 128, 1254, 1199, ...] (10 adet)
        // yzd_posts'tan bu id'lere ait kategori isim/ikonlarını çek
    }

    if ($settings['type'] === 'restoran_secim') {
        $ids = $settings['restaurant_ids']; // [2, 1063, 1080, 1099]
        // yzd_posts'tan bu id'lere ait restoran bilgilerini çek
    }

    if ($settings['type'] === 'etkinlik_secim') {
        $ids = $settings['event_ids']; // [1, 2]
        // yzd_etkinlik'ten bu id'lere ait etkinlik bilgilerini çek
    }
}
```

## Yeni alan ekleme

1. Benzersiz bir `section_key` belirle.
2. `settings` JSON'unu uygun `type` ile hazırla.
3. Migration scriptine satır ekleyip tekrar çalıştır ya da doğrudan
   `INSERT ... ON DUPLICATE KEY UPDATE` ile ekle.

## İlgili API endpoint'leri

Ana sayfa alanlarını besleyen REST endpoint'leri. Tam liste için bkz.
[README.md](README.md).

> Base URL: `https://api.gezgah.com/rest`

| Method | Yol | Açıklama |
|--------|-----|----------|
| GET | `/mekanlar/yeni-eklenenler` | Son eklenen restoranlar (SQL). Query: `limit` (vars. 10, max 50) |
| GET | `/mekanlar/yakindakiler` | Konumu olan restoran havuzu (SQL). Mesafe sıralaması **mobil app** tarafında yapılır. Query: `limit` (vars. 100, max 500) |

### `GET /mekanlar/yeni-eklenenler`

Ana sayfadaki "Yeni Eklenenler" alanını besler. En yeni eklenen restoranları
(`type = 'restoran'`, `status = 'publish'`) `date DESC, id DESC` sırasıyla
döner. Veriler doğrudan SQL'den gelir.

```bash
curl "https://api.gezgah.com/rest/mekanlar/yeni-eklenenler?limit=10"
```

```json
{
  "success": true,
  "data": [
    {
      "id": 1592,
      "type": "restoran",
      "slug": "carsi-et-ve-balik",
      "name": "Çarşı Et ve Balık",
      "thumbnail": null,
      "status": "publish",
      "date": "2026-06-20",
      "telefon": "5314694686",
      "bolge": "1",
      "sehir": "Istanbul",
      "ilce": "Adalar",
      "kordinat": "",
      "goruntulenme": 0,
      "kategori_ids": [1254, 1096, 1053, 122]
    }
  ],
  "error": null,
  "meta": { "limit": 10, "count": 10 }
}
```

### `GET /mekanlar/yakindakiler`

Ana sayfadaki "Yakındakiler" alanını besler.

**Önemli:** Mesafe hesabı ve "en yakın 10" seçimi **SQL/sunucu tarafında
yapılmaz**. Sunucu yalnızca konumu (`kordinat`) tanımlı restoranlardan oluşan
bir havuzu, her kayda `enlem`/`boylam` alanlarını da ekleyerek döner. Mobil
app, cihazın GPS konumuna göre Haversine mesafesini hesaplar ve en yakın 10
restoranı gösterir.

```bash
curl "https://api.gezgah.com/rest/mekanlar/yakindakiler"
```

```json
{
  "success": true,
  "data": [
    {
      "id": 1573,
      "type": "restoran",
      "slug": "kirpi-liv-ulus",
      "name": "Kirpi Liv Ulus",
      "status": "publish",
      "date": "2026-06-18",
      "telefon": "02122654541",
      "bolge": "10",
      "sehir": "Istanbul",
      "ilce": "Beşiktaş",
      "kordinat": "41.06000044430381, 29.026522549773233",
      "goruntulenme": 0,
      "kategori_ids": [1410, 122],
      "enlem": 41.06000044430381,
      "boylam": 29.026522549773233
    }
  ],
  "error": null,
  "meta": {
    "count": 100,
    "not": "Mesafe sıralaması ve en yakın 10 seçimi mobil app tarafında yapılır."
  }
}
```

Mobil app tarafında en yakın 10'u seçme (özet):

```dart
// Haversine ile cihaz konumuna mesafe hesapla, artan sırala, ilk 10'u al.
items.sort((a, b) =>
    distance(deviceLat, deviceLng, a.enlem, a.boylam)
        .compareTo(distance(deviceLat, deviceLng, b.enlem, b.boylam)));
final nearest10 = items.take(10).toList();
```

## Alanların veri kaynağı özeti

| Alan / section_key | Kaynak | Notlar |
|--------------------|--------|--------|
| `tumu` | SQL (`home_page_settings`) | Kısayol + ikon yapılandırması |
| `one_cikan_kategoriler` | SQL (`home_page_settings` + `yzd_posts`) | Seçili 10 kategori id'si (isim/ikon ile çözülür) |
| `sponsorlu_restoranlar` | SQL (`home_page_settings` + `yzd_posts`) | Seçili restoran id'leri |
| `sponsorlu_etkinlikler` | SQL (`home_page_settings` + `yzd_etkinlik`) | Seçili etkinlik id'leri |
| Yeni Eklenenler | SQL (`GET /mekanlar/yeni-eklenenler`) | Son eklenen 10 restoran |
| Yakındakiler | SQL veri + **app tarafı mesafe** (`GET /mekanlar/yakindakiler`) | Sunucu havuz döner, en yakın 10'u app seçer |
