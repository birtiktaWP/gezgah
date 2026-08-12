# /mekanlar/{id} — Tüm Yer Tipleri İçin Detay

Detay ucu artık **restoran dışı yerlerin** (otopark, müze, mesire, plaj) detayını da döndürür.

- **Uç:** `GET /rest/mekanlar/{id}`
- **Taban URL:** `https://api.gezgah.com/rest`
- **Kimlik doğrulama:** `Authorization: Bearer <cihaz_token>` (diğer uçlarla aynı)

## Kabul edilen tipler
`restoran`, `plaj`, `mesire`, **`otopark`**, **`muze`**

> `muze` şu an veritabanında kayıt içermiyor (ileriye dönük olarak kabul edilir).
> Bu tiplerden olmayan / yayında olmayan / bulunmayan id → `404`.

## Nasıl çalışır (kaynak)
| Tip | Kaynak |
|-----|--------|
| restoran, plaj, mesire | **Elasticsearch cache-aside** (detay ES'te saklı; yoksa DB'den kurulup ES'e yazılır, 300 sn tazelik + düzenlemede yenilenir) |
| otopark, muze | **Doğrudan MySQL** (ES index'inde olmadığından; gereksiz ES çağrısı yapılmaz) |

Her istekte **listeleme / tıklama sayaçları** taze okunur (kaynak fark etmez).

## Kapsam / sınır
Genişletme **yalnızca detaya** özeldir. Aşağıdakiler değişmedi ve otopark'ları listeye karıştırmaz:
- `GET /mekanlar` (liste) → yalnız `mekan_types` (restoran/plaj/mesire)
- `GET /harita`, `GET /mekanlar/yakindakiler`, kategori mekan uçları
- Restoran dışı yerlerin **listesi** için: `GET /yerler?type=otopark|muze|mesire|plaj`

## Örnek
```
GET /rest/mekanlar/4613
Authorization: Bearer <token>
```
```json
{
  "success": true,
  "data": {
    "id": 4613,
    "type": "otopark",
    "name": "Zeytinburnu Sahil Cep Otoparkı",
    "slug": "...",
    "thumbnail": "https://.../uploads/...jpg",
    "image": "https://.../uploads/...jpg",
    "sehir": "İstanbul",
    "ilce": "Zeytinburnu",
    "kordinat": "40.99,28.90",
    "adres": "...",
    "kategoriler": [],
    "ozellikler": [],
    "filtreler": [],
    "galeri": [],
    "menu": [],
    "calisma_saatleri": [],
    "listeleme": 0,
    "tiklama": 1
  }
}
```
> Not: otopark/müze için `menu`, `ozellikler`, `calisma_saatleri` gibi alanlar
> genelde boş döner (bu tiplerde ilgili veri bulunmaz) — alanlar yine mevcuttur.

## Canlı doğrulama
```
/mekanlar/<otopark_id> -> 200, type: otopark
/mekanlar/<plaj_id>    -> 200, type: plaj    (ES yolu)
/mekanlar/<restoran_id>-> 200                (regresyon yok)
```

## Değişen dosya
- `api/rest/src/Controllers/MekanController.php`
  - `detailTypesInClause()` (mekan_types + otopark/muze)
  - `show()` ve `buildDetailPayload()` bu tip setini kullanır; ES yalnız restoran/plaj/mesire için.
