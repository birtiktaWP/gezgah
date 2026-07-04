# harita (Harita içerikleri)

Harita ekranı için, **koordinatı tanımlı** mekanları döndüren endpoint.
Harita tüm işaretçileri aynı anda göstereceğinden **sayfalama yoktur**;
eşleşen tüm mekanlar tek yanıtta döner.

> Base URL: `https://api.gezgah.com/rest`

## Endpoint

| Method | Yol |
|--------|-----|
| GET | `/harita` |

### Query parametreleri

| Parametre | Tip | Varsayılan | Açıklama |
|-----------|-----|-----------|----------|
| `kategori` | int | — | Opsiyonel. Yalnızca bu kategoriye ait mekanlar (`post_kategori` içerir). |
| `type` | string | — | Opsiyonel. `restoran` \| `plaj` \| `mesire`. Verilmezse hepsi. |

- Yalnızca `status = 'publish'` ve **koordinatı olan** (`kordinat` veya
  `plaj_kordinat` dolu) mekanlar döner.
- Koordinatı çözülemeyen kayıtlar yanıta eklenmez.
- **Sayfalama yoktur**; kategori/type filtresine uyan tüm mekanlar döner.

## Örnek istekler

```bash
# Tüm haritalanabilir mekanlar
curl "https://api.gezgah.com/rest/harita"

# Kategoriye göre (ör. Restoran = 122)
curl "https://api.gezgah.com/rest/harita?kategori=122"

# Tipe göre
curl "https://api.gezgah.com/rest/harita?type=plaj"
```

## Yanıt formatı

```json
{
  "success": true,
  "data": [
    {
      "id": 1573,
      "type": "restoran",
      "slug": "kirpi-liv-ulus",
      "name": "Kirpi Liv Ulus",
      "thumbnail": null,
      "image": null,
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
      "boylam": 29.026522549773233,
      "adres": "Ulus Ahmet Adnan Saygun cad, Canan Sk., 34340 Beşiktaş/İstanbul",
      "harita_ikon": null
    }
  ],
  "error": null,
  "meta": { "total": 99, "kategori": 122, "type": null }
}
```

### `data[]` alanları

| Alan | Açıklama |
|------|----------|
| `id` | Mekan id'si |
| `type` | `restoran` \| `plaj` \| `mesire` |
| `slug` / `name` | URL dostu ad / ad |
| `thumbnail` / `image` | Öne çıkan görsel (yoksa `null`) |
| `telefon` | İletişim numarası |
| `bolge` | Bölge id'si |
| `sehir` / `ilce` | Bölge id → `ilceler` çözümü |
| `kordinat` | Ham "enlem, boylam" metni |
| `enlem` | Enlem (float) — harita işaretçisi için |
| `boylam` | Boylam (float) — harita işaretçisi için |
| `adres` | Açık adres (`mekan_adres`) |
| `harita_ikon` | Harita işaretçi ikon tipi (ör. `park`, `eczane`; yoksa `null`) |
| `kategori_ids` | Bağlı kategori id'leri |
| `goruntulenme` | Görüntülenme sayacı |

### `meta` alanları

| Alan | Açıklama |
|------|----------|
| `total` | Dönen mekan (işaretçi) sayısı |
| `kategori` | Uygulanan kategori filtresi (yoksa `null`) |
| `type` | Uygulanan tip filtresi (yoksa `null`) |

## Notlar

- `enlem`/`boylam`, `kordinat` metnindeki "lat, lng" değerinden ayrıştırılır.
- Büyük veri: kategori/tip filtresi verilmezse tüm haritalanabilir mekanlar
  döner. İşaretçi sayısını sınırlamak istenirse `kategori` veya `type` ile
  daraltın.
- `harita_ikon` mekan tipine özel işaretçi ikonu seçmek için kullanılabilir
  (ör. otopark, eczane, park).
