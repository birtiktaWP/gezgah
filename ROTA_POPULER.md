# Popüler Gezi Rotaları — En Çok Etkileşim Alan Top N

En çok **etkileşim** alan herkese açık gezi rotalarını döndürür.
**Etkileşim = beğeni sayısı + yorum sayısı.** Foto (kapak), sahip bilgisi ve
sayaçlar dahil özet kayıtlar döner.

> Taban URL: `https://api.gezgah.com/rest`

## Ortak Başlıklar
| Başlık | Değer |
|---|---|
| `X-App-Key` | `ba9db8d2c420adbaeed122fe53c15e878fbcc67b55ba41cd` (zorunlu) |
| `Authorization` | `Bearer <cihaz_veya_uye_token>` (zorunlu) |

> Üye token'ı ile çağrılırsa `begendim` ve `sahip.takip_ediyorum` kişiye göre dolar;
> cihaz token'ı ile çağrılırsa bunlar `false` / `null` gelir.

Yanıt zarfı: `{ "success": bool, "data": [...], "error": ..., "meta": {...} }`

---

## Endpoint

| Metot | Yol |
|---|---|
| GET | `/rotalar/populer` |

### Query parametreleri
| Param | Zorunlu | Varsayılan | Açıklama |
|---|---|---|---|
| `limit` | Hayır | 10 | Kaç rota (min 1, **max 50**). |

- Yalnız **herkese açık** (`gorunurluk='herkese_acik'`) ve sahibi aktif rotalar döner.
- Sıralama: **etkileşim (beğeni + yorum) azalan**; eşitlikte en yeni önce.

### Örnek istek
```
GET /rotalar/populer?limit=10
X-App-Key: <app_key>
Authorization: Bearer <token>
```

---

## Yanıt
```json
{
  "success": true,
  "data": [
    {
      "id": 5,
      "baslik": "Betinin Yolları",
      "aciklama": "Sahil boyu kahve rotası",
      "gorunurluk": "herkese_acik",
      "yorumlar_acik": true,
      "kapak_gorsel": "https://.../uploads/....jpg",
      "kapak_post_id": 1063,
      "durak_sayisi": 4,
      "begeni_sayisi": 2,
      "yorum_sayisi": 3,
      "etkilesim": 5,
      "goruntulenme": 128,
      "gosterim": 540,
      "created_at": "2026-08-10 12:00:00",
      "updated_at": "2026-08-20 09:30:00",
      "begendim": false,
      "benim": false,
      "rota_fiyat": 480.0,
      "sahip": {
        "uye_id": 87,
        "isim": "Ahmet",
        "soyisim": "Yılmaz",
        "avatar": "https://.../avatar.jpg",
        "takip_ediyorum": false
      }
    }
  ],
  "meta": { "limit": 10, "total": 3, "sort": "etkilesim" }
}
```

### `data[]` alanları
| Alan | Tip | Açıklama |
|---|---|---|
| `id` | int | Rota id'si. Detay için `GET /uye/rotalar/{id}`. |
| `baslik` / `aciklama` | string | Rota başlığı / açıklaması. |
| `kapak_gorsel` | string? | **Foto** — rota kapak görseli (yoksa `null`). |
| `kapak_post_id` | int? | Kapak olarak seçilen mekan post id'si (varsa). |
| `durak_sayisi` | int | Rotadaki durak sayısı. |
| `begeni_sayisi` | int | Beğeni sayısı. |
| `yorum_sayisi` | int | Yorum sayısı. |
| **`etkilesim`** | int | **Sıralama skoru = `begeni_sayisi + yorum_sayisi`.** |
| `goruntulenme` / `gosterim` | int | Detay görüntülenme / listede gösterim sayacı. |
| `rota_fiyat` | number? | Rotadaki seçili ürünlerin toplam fiyatı (yoksa `null`). |
| `begendim` | bool | İstek yapan üye bu rotayı beğenmiş mi. |
| `benim` | bool | Rota istek yapan üyeye mi ait. |
| `sahip` | object | Rota sahibi: `uye_id, isim, soyisim, avatar, takip_ediyorum`. |

`meta`: `limit`, `total` (dönen kayıt), `sort` (`"etkilesim"`).

---

## Notlar
- Bu uç **özet** döndürür (kapak foto + sayaçlar + sahip). Rotanın tam **durak listesi**
  (mekanlar, ürünler, foto galerisi) için rota id ile `GET /uye/rotalar/{id}` çağrılır.
- `begendim` / `sahip.takip_ediyorum` yalnız **üye token'ı** ile anlamlıdır.
- Liste çağrısı, sahibinin kendisi olmayan rotalar için `gosterim` (impression) sayacını artırır.
- Sıralama ve sayımlar MySQL'de yapılır (Elasticsearch kullanılmaz); rota hacmi için yeterli.

## Backend (referans)
- Model: `GeziRota::populer($limit)` — herkese açık rotalar, `ORDER BY (begeni_sayisi + yorum_sayisi) DESC, created_at DESC`.
- Controller: `GeziRotaController::populer()` — mevcut akış temsili (`akisMap`) + `etkilesim` alanı.
