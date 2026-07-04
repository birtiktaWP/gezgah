# Arama geçmişi & popüler aramalar

Kullanıcıların yaptığı aramalar `arama_gecmisi` tablosunda saklanır (arama
terimi + kullanıcı id'si + tarih). Bu veriden **en çok aranan kelimeler**
üretilir.

> Base URL: `https://api.gezgah.com/rest`

## Tablo: `arama_gecmisi`

LIVE veritabanında tek seferlik migration ile oluşturulur:

```bash
php rest/tools/migrate_arama_gecmisi.php
```

| Kolon | Tip | Açıklama |
|-------|-----|----------|
| `id` | INT UNSIGNED, PK, AUTO_INCREMENT | Kayıt id'si |
| `user_id` | INT UNSIGNED, NULL | Arayan kullanıcı (`yzd_users.id`); anonim ise `NULL` |
| `term` | VARCHAR(255) | Arama terimi (kullanıcının yazdığı orijinal hali) |
| `term_normalized` | VARCHAR(255) | Gruplama için normalize edilmiş hali (trim + küçük harf) |
| `created_at` | TIMESTAMP | Arama tarihi (otomatik) |

İndeksler: `term_normalized`, `created_at`, `user_id`.

## Arama nasıl kaydedilir?

`GET /arama` çağrısında arama otomatik olarak `arama_gecmisi`'ne eklenir.

- Yalnızca **ilk sayfa** (`page = 1`) isteğinde kaydedilir; sayfalama sırasında
  aynı arama tekrar sayılmaz.
- İsteğe bağlı `user_id` parametresi gönderilirse kullanıcıyla ilişkilendirilir;
  gönderilmezse `NULL` (anonim) olarak saklanır.
- Kayıt hatası arama akışını bozmaz (sessizce geçilir).

```bash
# Kullanıcı ile
curl "https://api.gezgah.com/rest/arama?q=burger&user_id=2"
# Anonim
curl "https://api.gezgah.com/rest/arama?q=burger"
```

## Endpoint: `GET /populer-aramalar`

En çok aranan kelimeleri döner (varsayılan **6**).

### Query parametreleri

| Parametre | Tip | Varsayılan | Açıklama |
|-----------|-----|-----------|----------|
| `limit` | int | 6 | Kaç kelime dönsün (min 1, max 20) |
| `days` | int | — | Yalnızca son N günün aramaları. Verilmezse tüm zamanlar. |

Kelimeler `term_normalized` üzerinden gruplanır (büyük/küçük harf farkı
birleştirilir), arama sayısına göre azalan sıralanır. Eşitlikte en son
aranan öne gelir. Gösterilen `term`, o gruptaki bir örnek yazımdır.

### Örnek istekler

```bash
curl "https://api.gezgah.com/rest/populer-aramalar"
curl "https://api.gezgah.com/rest/populer-aramalar?limit=6&days=30"
```

### Yanıt formatı

```json
{
  "success": true,
  "data": [
    { "term": "kahve",  "count": 2 },
    { "term": "burger", "count": 2 },
    { "term": "pizza",  "count": 1 }
  ],
  "error": null,
  "meta": { "limit": 6, "days": null, "count": 3 }
}
```

| Alan | Açıklama |
|------|----------|
| `data[].term` | Arama kelimesi (örnek yazım) |
| `data[].count` | Toplam arama sayısı |
| `meta.limit` | İstenen kelime sayısı |
| `meta.days` | Filtre uygulanan gün aralığı (yoksa `null`) |
| `meta.count` | Dönen kelime sayısı |

## Notlar

- Normalize işlemi `trim` + `mb_strtolower` (UTF-8) ile yapılır; "Kahve" ve
  "kahve" tek kelime olarak sayılır.
- Kişiye özel arama geçmişi gerekirse `arama_gecmisi` tablosu `user_id` ve
  `created_at` içerdiğinden kolayca sorgulanabilir (ayrı endpoint eklenebilir).
