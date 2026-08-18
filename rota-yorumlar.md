# Gezi Rotası — Görünürlük Seçenekleri + Yorumlar

Rota oluştururken/düzenlerken iki seçenek:
1. **Herkes görsün** (`gorunurluk`): `gizli` (varsayılan) veya `herkese_acik`.
2. **Yoruma izin ver** (`yorumlar_acik`): rotaya başka üyeler yorum yapabilsin mi (varsayılan **açık**).

Ayrıca rotalara **yorum yapma / listeleme / silme** uçları eklendi.

Taban URL: `https://api.gezgah.com/rest`

## Ortak Başlıklar
| Başlık | Değer |
|---|---|
| `X-App-Key` | `ba9db8d2c420adbaeed122fe53c15e878fbcc67b55ba41cd` (zorunlu) |
| `Authorization` | `Bearer <uye_token>` |

Yanıt zarfı: `{ "success": bool, "data": ..., "error": ..., "meta": ... }`

---

## 1) Rota Oluşturma — Seçeneklerle

`POST /uye/rotalar`  [Plus]

```json
{
  "baslik": "Boğaz Turu",
  "aciklama": "Sahil boyu keyifli duraklar",
  "gorunurluk": "herkese_acik",
  "yorumlar_acik": true
}
```

- `gorunurluk`: `gizli` | `herkese_acik` (yoksa `gizli`).
- `yorumlar_acik`: `true`/`false` (yoksa `true`). `yorum_acik` / `yorumlara_izin` da kabul edilir. `1/0`, `"evet"/"acik"` gibi değerler de çalışır.

Rota özeti çıktısında bu alanlar döner:
```json
{ "id": 10, "baslik": "Boğaz Turu", "gorunurluk": "herkese_acik", "yorumlar_acik": true, ... }
```

---

## 2) Rota Güncelleme — Seçenekleri Değiştir

`POST /uye/rotalar/{id}/guncelle`  [Plus]

Sadece değiştirilecek alanları gönder:
```json
{ "gorunurluk": "gizli", "yorumlar_acik": false }
```

---

## 3) Yorum Ekle

`POST /uye/rotalar/{id}/yorum`  (giriş yapmış üye)

```json
{ "yorum": "Harika bir rota, teşekkürler!" }
```

Kurallar:
- Rota **gizli** ve sana ait değilse `403`.
- Rotanın `yorumlar_acik` değeri `false` ise `403` (yorumlar kapalı).
- `yorum` boş olamaz, en fazla 1000 karakter (fazlası kırpılır).

Yanıt (201):
```json
{
  "success": true,
  "data": {
    "durum": "eklendi",
    "yorum": {
      "id": 55,
      "yorum": "Harika bir rota, teşekkürler!",
      "created_at": "2026-08-18 16:40:00",
      "uye": { "uye_id": 11, "isim": "Züleyha", "soyisim": "Aydemir", "avatar": null },
      "benim": true,
      "silebilir_mi": true
    },
    "yorum_sayisi": 3
  }
}
```

---

## 4) Yorumları Listele

`GET /uye/rotalar/{id}/yorumlar?page=1&limit=20`  (cihaz veya üye token'ı)

En yeni yorum en üstte, sayfalı. Gizli başkasının rotası için `403`.

```json
{
  "success": true,
  "data": [
    {
      "id": 55,
      "yorum": "Harika bir rota!",
      "created_at": "2026-08-18 16:40:00",
      "uye": { "uye_id": 11, "isim": "Züleyha", "soyisim": "Aydemir", "avatar": "https://..." },
      "benim": false,
      "silebilir_mi": false
    }
  ],
  "meta": {
    "page": 1, "limit": 20, "total": 3, "pages": 1,
    "has_more": false, "next_page": null,
    "yorumlar_acik": true
  }
}
```

- `benim`: yorumu bu kullanıcı mı yazdı.
- `silebilir_mi`: bu kullanıcı yorumu silebilir mi (yorumu yazan **veya** rota sahibi).

---

## 5) Yorum Sil

`DELETE /uye/rotalar/{id}/yorum`  (giriş yapmış üye)

```json
{ "yorum_id": 55 }
```

- Yorumu **yazan üye** veya **rota sahibi** silebilir; başkası `403`.
- Yorum yoksa/rotaya ait değilse `404`.

Yanıt:
```json
{ "success": true, "data": { "durum": "silindi", "yorum_id": 55, "yorum_sayisi": 2 } }
```

---

## Rota Detayında Yorum Sayısı

`GET /uye/rotalar/{id}` çıktısına eklendi:
```json
{ "yorumlar_acik": true, "yorum_sayisi": 3, "begeni_sayisi": 12, ... }
```
Yorum içerikleri detay yanıtında dönmez; liste için ayrı `.../yorumlar` ucunu kullan (sayfalama için).

---

## Özet Endpoint Listesi
| Metot | Yol | Açıklama |
|---|---|---|
| POST | `/uye/rotalar` | Oluştur (`gorunurluk`, `yorumlar_acik`) |
| POST | `/uye/rotalar/{id}/guncelle` | `gorunurluk` / `yorumlar_acik` değiştir |
| POST | `/uye/rotalar/{id}/yorum` | Yorum ekle |
| GET | `/uye/rotalar/{id}/yorumlar` | Yorumları listele (sayfalı) |
| DELETE | `/uye/rotalar/{id}/yorum` | Yorum sil (yazan veya rota sahibi) |

## Teknik Notlar
- Kolon: `app_gezi_rotalari.yorumlar_acik TINYINT(1) DEFAULT 1`.
- Tablo: `app_rota_yorum (id, rota_id, uye_id, yorum, created_at)`.
- Rota silinince yorumları (ve beğenileri) da silinir.
