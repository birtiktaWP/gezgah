# Üye Mekan Favorileri

Giriş yapmış uygulama üyesinin (app_uyeler) mekan favorilerini yönetir:
ekleme, çıkarma ve **"daha fazla yükle" (sonsuz kaydırma)** sayfalı listeleme.

Favoriler **üyeye** bağlıdır ve **üye token'ı** ile erişilir; cihaz token'ı
yeterli değildir (üye girişi gerekir).

> Base URL: `https://api.gezgah.com/rest`

## Kimlik doğrulama

Tüm uçlar `Authorization: Bearer <uye_token>` ister. `uye_token`,
`POST /uye/giris` veya `POST /uye/kayit` yanıtındaki token'dır
(bkz. [UYE_LOGIN.md](UYE_LOGIN.md)). Üye token'ı gönderilmezse `401`.

## Tablo: `app_favoriler`

Tek seferlik migration ile oluşturulur:

```bash
php rest/tools/migrate_app_favoriler.php
```

| Kolon | Tip | Açıklama |
|-------|-----|----------|
| `id` | INT UNSIGNED, PK | Favori kaydı id'si |
| `uye_id` | INT UNSIGNED | Üye (`app_uyeler.id`) |
| `post_id` | INT UNSIGNED | Mekan (`yzd_posts.id`) |
| `created_at` | TIMESTAMP | Eklenme zamanı |

`(uye_id, post_id)` **benzersizdir** → aynı mekan iki kez eklenmez.

## Endpoint'ler

| Method | Yol | Açıklama |
|--------|-----|----------|
| GET | `/uye/favoriler` | Üyenin favori mekanları (sayfalı) |
| POST | `/uye/favoriler` | Favoriye ekler. Body: `{ post_id }` |
| DELETE | `/uye/favoriler` | Favoriden çıkarır. Body: `{ post_id }` |

Yalnızca mekan (`restoran`, `plaj`, `mesire`) tipleri favorilenebilir.

### `POST /uye/favoriler`

```json
{ "post_id": 1597 }
```

Yanıt — yeni eklendiyse **201**, zaten favorideyse **200**:

```json
{
  "success": true,
  "data": { "post_id": 1597, "favori_id": 12, "durum": "eklendi", "favoride": true },
  "error": null
}
```

`durum`: `eklendi` | `zaten_favoride`.

Hatalar: `401` (üye token'ı yok), `404` (yayında mekan bulunamadı),
`422` (`post_id` eksik).

### `DELETE /uye/favoriler`

```json
{ "post_id": 1597 }
```

Yanıt (200):

```json
{
  "success": true,
  "data": { "post_id": 1597, "durum": "silindi", "favoride": false },
  "error": null
}
```

`durum`: `silindi` (kayıt vardı) | `bulunamadi` (zaten yoktu). İki durumda da
`200` döner (idempotent çıkarma).

### `GET /uye/favoriler` — sayfalı liste

Query: `page` (vars. 1), `limit` (vars. 20, min 1, max 50). Favoriler **en son
eklenen önce** (favori id DESC) sıralanır.

```bash
curl "https://api.gezgah.com/rest/uye/favoriler?page=1&limit=20" \
     -H "Authorization: Bearer <uye_token>"
```

Yanıt:

```json
{
  "success": true,
  "data": [
    {
      "id": 1597,
      "type": "restoran",
      "slug": "upperist",
      "name": "Upperist",
      "description": null,
      "thumbnail": "https://gezgah.com/uploads/....jpg",
      "image": "https://gezgah.com/uploads/....jpg",
      "status": "publish",
      "date": "2026-07-09",
      "telefon": "05345753175",
      "bolge": "13",
      "sehir": "Istanbul",
      "ilce": "Beyoğlu",
      "kordinat": "41.036, 28.986",
      "filtre_ids": [98, 101, 107],
      "favori_id": 12,
      "favori_tarih": "2026-07-15 16:40:00",
      "favoride": true
    }
  ],
  "error": null,
  "meta": {
    "page": 1,
    "limit": 20,
    "total": 3,
    "pages": 1,
    "has_more": false,
    "next_page": null
  }
}
```

#### "Daha fazla yükle" mantığı

- `meta.has_more` `true` ise devam eden sayfa vardır; `meta.next_page` bir
  sonraki sayfa numarasını verir.
- İstemci listenin sonuna gelince `next_page` ile tekrar çağırır; `has_more`
  `false` (ve `next_page` `null`) olana kadar sürdürür.

```dart
int page = 1;
bool hasMore = true;
final items = <Mekan>[];

Future<void> dahaFazlaYukle() async {
  if (!hasMore) return;
  final res = await Api.instance.dio.get('/uye/favoriler',
      queryParameters: {'page': page, 'limit': 20});
  items.addAll((res.data['data'] as List).map(Mekan.fromJson));
  hasMore = res.data['meta']['has_more'] as bool;
  page = (res.data['meta']['next_page'] as int?) ?? page;
}
```

#### `data[]` alanları

Kategori mekan listesiyle aynı mekan özeti + favori alanları:

| Alan | Açıklama |
|------|----------|
| `id, type, slug, name, description, thumbnail, image, status, date` | Mekan temel alanları |
| `telefon` | `restoran_gsm` |
| `bolge` | Bölge id'si |
| `sehir` / `ilce` | Bölge id → `ilceler` çözümü |
| `kordinat` | "enlem, boylam" metni |
| `filtre_ids` | Aktif filtre id'leri (`/filtreler` ile eşleşir) |
| `favori_id` | Favori kaydı id'si |
| `favori_tarih` | Favoriye eklenme zamanı |
| `favoride` | Her zaman `true` (favori listesi) |

## Notlar

- Bu uçlar yeni **app_uyeler** üyeliği içindir (token tabanlı). Eski
  `GET/POST/DELETE /favoriler` ise `yzd_users` + `user_id` param tabanlıdır ve
  ayrı çalışır.
- Silme **idempotenttir**: olmayan favoriyi silmek de `200` döner.
- Detay sayfasında "favoride mi?" bilgisi için üye giriş yapmışsa
  `POST /uye/favoriler` (zaten_favoride) veya listeyle eşleştirme kullanılabilir;
  gerekirse ayrı bir "durum" ucu eklenebilir.

## İlgili dokümanlar

- Üye giriş/kayıt: [UYE_LOGIN.md](UYE_LOGIN.md)
- Mekan detayı: [MEKAN_DETAY.md](MEKAN_DETAY.md)
- Filtreler: [FILTRELER.md](FILTRELER.md)
