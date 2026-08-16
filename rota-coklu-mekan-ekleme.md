# Gezgah — Rotaya Çoklu Mekan/Ürün Ekleme

`POST /uye/rotalar/{id}/mekan` artık **tek** veya **çoklu** durak ekleyebilir. Her durakta
opsiyonel olarak o mekanın QR menüsünden bir ürün (`qr_id`) seçilebilir. Aynı mekan birden
çok kez eklenebilir (farklı ürünlerle → böylece bir mekana birden çok yemek de eklenmiş olur).

- Uç: `POST /uye/rotalar/{id}/mekan` · **[Plus]** · rota sahibi olmalı.
- Başlıklar: `X-App-Key` + `Authorization: Bearer <uye_token>`.

---

## 1. İstek

### Tekli (geriye dönük uyumlu)
```json
{ "post_id": 1064, "qr_id": 5, "yorum": "Latte iç" }
```

### Çoklu
```json
{
  "duraklar": [
    { "post_id": 1064, "qr_id": 5, "yorum": "Latte iç" },
    { "post_id": 1064, "qr_id": 8, "yorum": "Cheesecake dene" },
    { "post_id": 2091, "yorum": "Akşam yemeği" },
    { "post_id": 2091 }
  ]
}
```
- `qr_id` ve `yorum` her durakta opsiyonel.
- Aynı `post_id` birden çok kez verilebilir (aynı mekana farklı ürünler).
- Tek istekte en fazla **50** durak.

---

## 2. Yanıt (201)

```json
{
  "success": true,
  "data": {
    "durum": "eklendi",
    "eklenen_sayisi": 3,
    "eklenen": [
      { "durak_id": 11, "post_id": 1064, "qr_id": 5 },
      { "durak_id": 12, "post_id": 1064, "qr_id": 8 },
      { "durak_id": 13, "post_id": 2091, "qr_id": null }
    ],
    "atlanan": [
      { "post_id": 999999, "neden": "mekan bulunamadı" }
    ],
    "durak_id": null
  }
}
```
- `eklenen` — eklenen durakların listesi (sırayla, rotanın sonuna eklenir).
- `atlanan` — eklenemeyenler ve nedeni (`post_id yok`, `mekan bulunamadı`, `ürün bu mekanın menüsünde yok`).
- `durak_id` — **tek** durak eklendiyse onun id'si (tekli kullanım uyumluluğu); çoklu ise `null`.
- Hiçbiri eklenemezse `422` + `details.atlanan`.

---

## 3. Notlar

- Geçerli duraklar eklenir, geçersizler atlanır (istek tümden reddedilmez) — kısmi başarı `201`.
- `qr_id` verilirse o **mekana ait gerçek ürün** olmalı; değilse o durak `atlanan`a düşer.
- Durak ürün seçimi/güncelleme ayrıntısı: `PROFIL_VE_ROTA_URUN.md`. Sıralama: `POST /uye/rotalar/{id}/sirala`.
- Ürün seçili duraklar rotanın `rota_fiyat` toplamına katkı sağlar (`rota-fiyatlar.md`).
- Şema/tablo değişikliği yok.

---

## 4. Mobil Kullanım

1. Kullanıcı birden çok mekan/ürün seçtiyse hepsini tek `duraklar` dizisiyle gönder (daha az istek).
2. Yanıttaki `atlanan` doluysa kullanıcıya "şu mekanlar eklenemedi" uyarısı göster.
3. Ekleme sonrası rota detayını (`GET /uye/rotalar/{id}`) yeniden çekip güncel sırayı/toplam fiyatı göster.
