# filtreler (Filtre sistemi)

Mobil uygulamadaki **filtre butonu** için filtre listesini döndüren endpoint.
Kullanıcı bu listeden filtre(ler) seçer; seçili filtreler daha sonra mekan
listeleme isteklerinde kullanılabilir.

## Filtre sistemi nasıl çalışır?

- **Filtre tanımları:** `yzd_posts` içinde `type = 'filtre'` (toplam 56).
  Her filtrenin meta'sında:
  - `filter_type` → hangi mekan tipine ait (`restoran` \| `plaj` \| `mesire` \| `otopark` \| `etkinlik`)
  - `filtre_ikon` → SVG ikon
- **Mekan başına aktiflik:** Bir mekanın meta'sında `filtre_{id} = 1/0`
  ile o filtrenin aktif olup olmadığı tutulur (ör. `filtre_98 = 1` → Otopark var).

> Base URL: `https://api.gezgah.com/rest`

## Endpoint

| Method | Yol |
|--------|-----|
| GET | `/filtreler` |

### Query parametreleri

| Parametre | Tip | Varsayılan | Açıklama |
|-----------|-----|-----------|----------|
| `type` | string | — | Opsiyonel. `filter_type`'a göre filtreler: `restoran` \| `plaj` \| `mesire` \| `otopark` \| `etkinlik`. Verilmezse tüm filtreler döner. |

> Kategori listeleme sayfası (restoranlar) için genelde `?type=restoran`
> kullanılır.

## Örnek istekler

```bash
# Restoran filtreleri (kategori listeleme filtre butonu)
curl "https://api.gezgah.com/rest/filtreler?type=restoran"

# Tüm filtreler
curl "https://api.gezgah.com/rest/filtreler"
```

## Yanıt formatı

```json
{
  "success": true,
  "data": [
    {
      "id": 98,
      "name": "Otopark",
      "slug": "otopark",
      "type": "restoran",
      "icon": "<svg ...>...</svg>",
      "meta_key": "filtre_98"
    },
    {
      "id": 101,
      "name": "Wifi",
      "slug": "wifi",
      "type": "restoran",
      "icon": "<svg ...>...</svg>",
      "meta_key": "filtre_101"
    }
  ],
  "error": null,
  "meta": { "total": 20, "type": "restoran" }
}
```

### `data[]` alanları

| Alan | Açıklama |
|------|----------|
| `id` | Filtre id'si (`yzd_posts.id`, `type='filtre'`) |
| `name` | Filtre adı (ör. Otopark, Wifi, Alkol) |
| `slug` | URL dostu ad (varsa) |
| `type` | Filtrenin ait olduğu mekan tipi (`filter_type`) |
| `icon` | SVG ikon (tanımlı değilse `null`) |
| `meta_key` | Mekan meta anahtarı (`filtre_{id}`). Bir mekanda bu key `1` ise filtre aktiftir. |

### `meta` alanları

| Alan | Açıklama |
|------|----------|
| `total` | Dönen filtre sayısı |
| `type` | Uygulanan `type` filtresi (yoksa `null`) |

## Restoran filtreleri (referans)

`?type=restoran` çağrısında dönen 20 filtre:

`Rezervasyon (96)`, `Otopark (98)`, `Vale (99)`, `Dijital Menü (100)`,
`Wifi (101)`, `Çocuk Alanı (102)`, `Çalışma Alanı (103)`,
`Toplu Etkinlik (104)`, `Soğutucu (105)`, `Isıtıcı (106)`, `Alkol (107)`,
`Alkolsüz (108)`, `Sigara (109)`, `Sigarasız (110)`, `Evcil Hayvan (111)`,
`Yabancı Dil (112)`, `Nargile (114)`, `Engelsiz (115)`, `Mescit (116)`,
`Çevre Otoparkı (117)`.

## Seçili filtrelerin kullanımı (öneri)

Kullanıcı filtre butonundan filtre(ler) seçtiğinde, uygulama seçili filtre
id'lerini toplar (ör. `98,101,107`). Mekan listeleme endpoint'inde bu id'lere
göre mekanları daraltacak bir `filtre` parametresi ileride eklenebilir
(her seçili `id` için ilgili mekanların `filtre_{id} = 1` olması beklenir).
