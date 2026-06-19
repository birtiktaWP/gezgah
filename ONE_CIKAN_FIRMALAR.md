# Öne Çıkan Firmalar Endpoint'i

Anasayfa vitrini / "öne çıkanlar" bölümü için hazırlanan endpoint dokümanı.
`yzd_postmetas` tablosunda `one_cikan_firma = 1` olarak işaretlenmiş yayındaki
mekanları döner.

---

## Endpoint

```
GET https://api.gezgah.com/rest/one-cikan-firmalar
```

| Özellik | Değer |
|---------|-------|
| Method | `GET` |
| Auth | Gerekmez (public) |
| Kaynak | `yzd_posts` + `yzd_postmetas` (`one_cikan_firma = '1'`) |
| Sadece | `status = publish` olan kayıtlar |

### Query parametreleri

| Parametre | Tip | Varsayılan | Açıklama |
|-----------|-----|------------|----------|
| `type` | string | (hepsi) | `restoran`, `plaj` veya `mesire`. Verilmezse üç tip de gelir. |
| `page` | int | `1` | Sayfa numarası. |
| `limit` | int | `20` | Sayfa başına kayıt (maks `100`). |

> Geçersiz `type` verilirse **422** döner.

---

## Yanıt

Standart zarf yapısı. `data` bir mekan listesidir; `meta` sayfalama bilgisidir.

```json
{
  "success": true,
  "data": [
    {
      "id": 1022,
      "type": "restoran",
      "slug": "resto-han-kebap",
      "name": "Resto Han Kebap",
      "description": null,
      "thumbnail": null,
      "status": "publish",
      "date": "2025-10-16",
      "telefon": "5537029512",
      "bolge": "35",
      "kordinat": "41.05761760878448, 28.98115121092372",
      "goruntulenme": 0,
      "kategori_ids": [123, 122]
    }
  ],
  "meta": { "page": 1, "limit": 20, "total": 5, "pages": 1 },
  "error": null
}
```

### Alan açıklamaları

| Alan | Açıklama |
|------|----------|
| `id` | Mekan (post) id. Detay için `/mekanlar/{id}`. |
| `type` | `restoran` / `plaj` / `mesire`. |
| `slug` | URL dostu ad. |
| `name` | Mekan adı (Türkçe karakterler düzeltilmiş). |
| `telefon` | İletişim numarası (yoksa `null`). |
| `bolge` | İlçe/bölge id'si (`/ilceler` ile eşleşir). |
| `kordinat` | `"enlem, boylam"` (haritada gösterim için). |
| `kategori_ids` | Kategori id listesi (`/kategoriler`). |
| `goruntulenme` | Görüntülenme sayacı. |

---

## Flutter kullanımı

> `Api` istemcisi için bkz. **FLUTTER_API_GUIDE.md** (tek Dio singleton).

```dart
/// Öne çıkan mekanları getirir (anasayfa vitrini).
Future<List<dynamic>> oneCikanFirmalar({
  String? type,          // 'restoran' | 'plaj' | 'mesire' | null (hepsi)
  int page = 1,
  int limit = 20,
}) async {
  final res = await Api.instance.dio.get(
    '/one-cikan-firmalar',
    queryParameters: {
      if (type != null) 'type': type,
      'page': page,
      'limit': limit,
    },
  );
  final body = res.data as Map<String, dynamic>;
  if (body['success'] == true) {
    return body['data'] as List<dynamic>;
  }
  throw Exception(body['error']?['message'] ?? 'Öne çıkanlar alınamadı');
}
```

### Örnek istekler

```bash
# Tüm öne çıkan mekanlar
curl "https://api.gezgah.com/rest/one-cikan-firmalar"

# Sadece öne çıkan restoranlar
curl "https://api.gezgah.com/rest/one-cikan-firmalar?type=restoran&limit=10"
```

---

## Performans notları

- Liste **az sayıda** kayıt döndürür (vitrin); yine de `limit` ile küçük tut.
- Sonuç sık değişmez → uygulamada **kısa süreli cache** (ör. 10–15 dk) yeterli.
- Görselleri `cached_network_image` ile göster; liste kartında mekanın
  thumbnail'i için gerekiyorsa `/mekanlar/{id}` detayından `galeri` çek
  (vitrin kartı sade tutulacaksa sadece `name` + `kordinat` yeterli).
- Anasayfada bu çağrıyı diğer bağımsız çağrılarla (kategoriler, bildirimler)
  `Future.wait` ile **paralel** yap.

## Veri tarafı (nasıl işaretlenir)

Bir mekanı öne çıkarmak için ilgili post'a şu meta eklenir/güncellenir:

```sql
-- post_id: öne çıkarılacak mekanın id'si
INSERT INTO yzd_postmetas (post_id, meta_key, meta_value)
VALUES (:post_id, 'one_cikan_firma', '1');
```

`meta_value` `'1'` ise listede görünür; başka değer (veya kayıt yoksa) görünmez.
