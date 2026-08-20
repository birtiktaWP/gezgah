# Gezi Rotası — Yorum Beğeni / Beğenmeme (👍 / 👎)

Rota yorumlarına **beğeni (👍)** ve **beğenmeme (👎)** tepkisi eklendi. Her iki sayı da listede döner.
Bir üye bir yoruma **tek tepki** verir: beğeniyken beğenmemeye (veya tersi) geçince tepki güncellenir.

Taban URL: `https://api.gezgah.com/rest`

## Ortak Başlıklar
| Başlık | Değer |
|---|---|
| `X-App-Key` | `ba9db8d2c420adbaeed122fe53c15e878fbcc67b55ba41cd` (zorunlu) |
| `Authorization` | `Bearer <uye_token>` |

> Tepki işlemleri **giriş yapmış üye** ister. Gizli başkasının rotasındaki yorum için işlem yapılamaz.

Yanıt zarfı: `{ "success": bool, "data": ..., "error": ..., "meta": ... }`

---

## Kurallar (tek tepki mantığı)
- Bir üyenin bir yoruma aynı anda **ya beğenisi ya beğenmemesi** olur; ikisi birden olamaz.
- 👍 iken 👎'ya basılırsa tepki **değişir** (beğeni −1, beğenmeme +1). Tersi de geçerli.
- Aynı tepkiye tekrar basmak sayıyı değiştirmez (`durum: "zaten"`).
- Kaldırma tip-özeldir: 👍 kaldırma yalnız mevcut tepki 👍 ise etkilidir.

---

## 1) Beğen (👍)

`POST /uye/rotalar/{id}/yorum/begen`
```json
{ "yorum_id": 55 }
```
Yanıt:
```json
{
  "success": true,
  "data": {
    "durum": "eklendi",          // eklendi | guncellendi | zaten
    "yorum_id": 55,
    "tepki": "begeni",
    "begendim": true,
    "begenmedim": false,
    "begeni_sayisi": 4,
    "begenmeme_sayisi": 1
  }
}
```

## 2) Beğeniyi Kaldır

`DELETE /uye/rotalar/{id}/yorum/begen`  ·  Body: `{ "yorum_id": 55 }`
```json
{ "success": true, "data": { "durum": "kaldirildi", "yorum_id": 55, "tepki": null, "begendim": false, "begenmedim": false, "begeni_sayisi": 3, "begenmeme_sayisi": 1 } }
```

## 3) Beğenme (👎)

`POST /uye/rotalar/{id}/yorum/begenme`  ·  Body: `{ "yorum_id": 55 }`
```json
{ "success": true, "data": { "durum": "eklendi", "yorum_id": 55, "tepki": "begenmeme", "begendim": false, "begenmedim": true, "begeni_sayisi": 3, "begenmeme_sayisi": 2 } }
```

## 4) Beğenmemeyi Kaldır

`DELETE /uye/rotalar/{id}/yorum/begenme`  ·  Body: `{ "yorum_id": 55 }`
```json
{ "success": true, "data": { "durum": "kaldirildi", "yorum_id": 55, "tepki": null, "begendim": false, "begenmedim": false, "begeni_sayisi": 3, "begenmeme_sayisi": 1 } }
```

---

## 5) Yorum Listesinde Tepki Bilgisi

`GET /uye/rotalar/{id}/yorumlar?page=1&limit=20`

```json
{
  "success": true,
  "data": [
    {
      "id": 55,
      "yorum": "Harika bir rota!",
      "created_at": "2026-08-20 14:10:00",
      "uye": { "uye_id": 11, "isim": "Züleyha", "soyisim": "Aydemir", "avatar": "https://..." },
      "begeni_sayisi": 3,
      "begenmeme_sayisi": 1,
      "tepki": "begeni",        // bu kullanıcının tepkisi: begeni | begenmeme | null
      "begendim": true,
      "begenmedim": false,
      "benim": false,
      "silebilir_mi": false
    }
  ],
  "meta": { "page": 1, "limit": 20, "total": 8, "pages": 1, "has_more": false, "yorumlar_acik": true }
}
```

> Yeni eklenen yorumda tüm sayılar 0, `tepki: null` gelir.

---

## Özet Endpoint Listesi
| Metot | Yol | Açıklama |
|---|---|---|
| POST | `/uye/rotalar/{id}/yorum/begen` | Yorumu beğen (👍) |
| DELETE | `/uye/rotalar/{id}/yorum/begen` | Beğeniyi kaldır |
| POST | `/uye/rotalar/{id}/yorum/begenme` | Yorumu beğenme (👎) |
| DELETE | `/uye/rotalar/{id}/yorum/begenme` | Beğenmemeyi kaldır |
| GET | `/uye/rotalar/{id}/yorumlar` | Yorumlar + `begeni_sayisi` / `begenmeme_sayisi` / `tepki` |

## UX Notu (mobil)
- Her yorumun altında 👍 ve 👎 ikonu + sayıları göster. `tepki` alanına göre aktif ikonu doldur.
- Dokunuşta iyimser güncelleme yap; 👍 iken 👎'ya basılırsa iki sayacı birlikte güncelle (biri −1, diğeri +1). Yanıttaki `begeni_sayisi`/`begenmeme_sayisi` ile senkronla.
- Aktif tepkiye tekrar dokunmak = kaldırma (DELETE) olarak da tasarlayabilirsin (toggle).

## Teknik Notlar
- Tablo: `app_rota_yorum_begeni (id, yorum_id, uye_id, tip, created_at, UNIQUE(yorum_id, uye_id))`. `tip`: `begeni` | `begenmeme`.
- Kişi başına tek satır → tepki değişimi UPDATE ile; tek sorguda tutarlı.
- Yorum silinince tepkileri; rota silinince tüm yorum + tepkileri temizlenir.
- Geriye dönük: eski beğeniler `tip='begeni'` olarak korunur.
