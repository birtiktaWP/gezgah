# Bildirimler

Bildirimler iki kaynaktan birleştirilerek sunulur:

1. **`pro-bildirim` postları** — `yzd_posts` içinde `type = 'pro-bildirim'`.
2. **`logs` kayıtları** — `logs.action LIKE '%bildirim%'` olan aktivite satırları.

Sonuç, tarihe göre azalan (en yeni önce) tek listede döner.

> Base URL: `https://api.gezgah.com/rest`

## Okundu durumu (cihaz bazlı)

Bildirimler için ayrı bir "okundu" satırı tutulmaz; bunun yerine her cihazın
**"tümünü okuduğu son zaman"** (`cihaz_tokenlari.bildirim_okundu_at`) saklanır.
Bir bildirim, tarihi bu zamandan **küçük/eşit** ise o cihaz için `okundu`
sayılır. Bu sayede tek bir kolonla, ek tablo olmadan "tümünü okundu" özelliği
sağlanır.

Cihaz tanıma için cihaz token'ı kullanılır (bkz. [CIHAZ_TOKEN.md](CIHAZ_TOKEN.md)).
Token gönderme yolları: `Authorization: Bearer <token>`, `?token=<token>` veya
JSON body `"token"`.

## Endpoint'ler

| Method | Yol | Açıklama |
|--------|-----|----------|
| GET | `/bildirimler` | Bildirim listesi (sayfalı). Cihaz token'ı verilirse `okundu` bilgisi eklenir |
| POST | `/bildirimler/okundu` | Cihazın **tüm** bildirimlerini okundu işaretler |

### `GET /bildirimler`

Query: `page` (vars. 1), `limit` (vars. 20, max 100).

- Cihaz token'ı **verilirse:** her öğede `okundu` (`true`/`false`) döner,
  `meta.okunmamis` okunmamış bildirim sayısını verir.
- Token **verilmezse:** her öğede `okundu` `null` olur, `meta.okunmamis`
  `null` döner (okundu durumu bilinmez).

```bash
# Token ile (okundu bilgisiyle)
curl "https://api.gezgah.com/rest/bildirimler" -H "Authorization: Bearer a1b2c3..."

# Token'sız (okundu = null)
curl "https://api.gezgah.com/rest/bildirimler?page=1&limit=20"
```

Yanıt:

```json
{
  "success": true,
  "data": [
    {
      "kaynak": "log",
      "id": 512,
      "post_id": 1022,
      "baslik": null,
      "mesaj": "Yeni kampanya yayında",
      "tarih": "2026-07-07 14:20:00",
      "islem": "create_pro-bildirim",
      "okundu": false
    },
    {
      "kaynak": "post",
      "id": 990,
      "baslik": "Hoş geldiniz",
      "mesaj": "Gezgah'a hoş geldiniz!",
      "tarih": "2026-06-01",
      "okundu": true
    }
  ],
  "error": null,
  "meta": {
    "page": 1,
    "limit": 20,
    "total": 34,
    "pages": 2,
    "okunmamis": 3,
    "okundu_at": "2026-06-15 09:00:00"
  }
}
```

#### `data[]` alanları

| Alan | Açıklama |
|------|----------|
| `kaynak` | `post` (pro-bildirim) veya `log` (aktivite kaydı) |
| `id` | Kaynak kayıt id'si (`yzd_posts.id` veya `logs.id`) |
| `post_id` | Yalnızca `log` kaynağında: ilgili post id (yoksa `null`) |
| `baslik` | Bildirim başlığı (log kaynağında `null`) |
| `mesaj` | Bildirim metni |
| `tarih` | Bildirim tarihi/zamanı |
| `islem` | Yalnızca `log` kaynağında: `action` değeri |
| `okundu` | Cihaz için okundu mu? Token yoksa `null` |

#### `meta` alanları

| Alan | Açıklama |
|------|----------|
| `page` / `limit` / `total` / `pages` | Sayfalama |
| `okunmamis` | Okunmamış bildirim sayısı (tüm liste üzerinden). Token yoksa `null` |
| `okundu_at` | Cihazın "tümünü okuduğu" son zaman (yoksa `null`) |

### `POST /bildirimler/okundu`

Cihazın tüm bildirimlerini o ana kadar **okundu** işaretler
(`bildirim_okundu_at = NOW()`). Cihaz token'ı zorunludur.

```bash
curl -X POST "https://api.gezgah.com/rest/bildirimler/okundu" \
     -H "Authorization: Bearer a1b2c3..."
```

Yanıt (200):

```json
{
  "success": true,
  "data": {
    "durum": "tumu_okundu",
    "okundu_at": "2026-07-08 10:15:00",
    "okunmamis": 0
  },
  "error": null
}
```

Hatalar: `422` (token eksik), `404` (cihaz bulunamadı / token geçersiz).

## Flutter kullanımı (öneri)

```dart
// Okunmamış rozeti için
Future<int> okunmamisSayisi() async {
  final res = await Api.instance.dio.get('/bildirimler', queryParameters: {'limit': 1});
  return (res.data['meta']['okunmamis'] as int?) ?? 0;
}

// "Tümünü okundu" butonu
Future<void> tumunuOkundu() async {
  await Api.instance.dio.post('/bildirimler/okundu'); // cihaz token'ı interceptor ile eklenir
}
```

## Notlar

- Okundu durumu **cihaz bazlıdır** (cihaz token'ı). Aynı üyenin iki cihazı
  varsa her cihaz kendi okundu durumunu tutar.
- Tek tek "okundu" işaretleme yoktur; özellik "tümünü okundu" olarak tasarlanmıştır.
- Token, `Authorization: Bearer`, `?token=` veya body ile gönderilebilir.
- Cihaz kaydı ve token akışı için bkz. [CIHAZ_TOKEN.md](CIHAZ_TOKEN.md).
