# Gezgah — Beğeni + Takip (Sosyal) API Kılavuzu

Gezi rotaları için **beğeni** ve üyeler için **takip** sistemi. Bu iki özellik `UYELIK_PLUS.md`
§6'daki gezi rotalarını genişletir.

- Taban URL: `https://api.gezgah.com/rest/`
- Başlıklar: `X-App-Key: <app_key>` + `Authorization: Bearer <uye_token>`
- Bu uçların tamamı **giriş yapmış üye** ister (app_uyeler). Plus şartı **yoktur** (beğeni/takip ücretsiz).

---

## 1. Beğeni (Rota)

| Metot | Uç | Açıklama |
|------|----|----------|
| POST | `/uye/rotalar/{id}/begen` | Rotayı beğen (idempotent) |
| DELETE | `/uye/rotalar/{id}/begen` | Beğeniyi kaldır |

- Yalnız **sahibi** veya **herkese açık** rota beğenilebilir (gizli başkasının rotası → `403`).
- İki kez beğenmek hata değildir (`durum: "zaten"`).

**POST /uye/rotalar/5/begen** →
```json
{ "durum": "begenildi", "begendim": true, "begeni_sayisi": 12 }
```
`durum`: `begenildi` (yeni) | `zaten` (zaten beğenmişti). **DELETE** →
```json
{ "durum": "kaldirildi", "begendim": false, "begeni_sayisi": 11 }
```

### Rota yanıtlarına eklenen alanlar
Tüm rota listelerinde/detayında artık şunlar döner:
- `begeni_sayisi` (int) — her yerde.
- `begendim` (bool) — isteği yapan üyenin bu rotayı beğenip beğenmediği (liste + detay).

---

## 2. Takip (Üye)

| Metot | Uç | Açıklama |
|------|----|----------|
| POST | `/uye/takip` | Takip et. `{ uye_id }` |
| DELETE | `/uye/takip` | Takibi bırak. `{ uye_id }` |
| GET | `/uye/takip/edilenler` | Kimi takip ediyor. `?uye_id=&page=&limit=` |
| GET | `/uye/takip/edenler` | Takipçiler. `?uye_id=&page=&limit=` |

- `uye_id` verilmezse listeler **giriş yapan üye** için döner; verilirse o üyenin listesi (profil görüntüleme).
- Kendini takip etmek: `422`. Var olmayan üye: `404`. Tekrar takip: `durum: "zaten"`.

**POST /uye/takip** `{ "uye_id": 12 }` →
```json
{ "durum": "takip_edildi", "uye_id": 12, "takip_ediyorum": true, "takipci_sayisi": 34 }
```
**DELETE /uye/takip** `{ "uye_id": 12 }` →
```json
{ "durum": "birakildi", "uye_id": 12, "takip_ediyorum": false, "takipci_sayisi": 33 }
```

**GET /uye/takip/edenler?uye_id=12** (12'nin takipçileri) →
```json
{
  "success": true,
  "data": [
    { "uye_id": 8, "isim": "Ada", "soyisim": "Yılmaz",
      "avatar": "https://.../app-avatars/8-....jpg",
      "takip_ediyorum": true, "tarih": "2026-08-16 21:40:00" }
  ],
  "meta": { "page":1, "limit":20, "total":34, "pages":2, "has_more":true, "next_page":2, "uye_id":12 }
}
```
- Her kayıttaki `takip_ediyorum`: **isteği yapan üyenin** o kişiyi takip edip etmediği (kendisi için `null`).
- `edilenler` aynı yapıda; kişinin takip ETTİKLERİ döner.

---

## 3. Takip Akışı (feed)

`GET /uye/rotalar/takip-akisi?page=&limit=`

Takip ettiğin kişilerin **herkese açık** rotaları, **en yeni en üstte**. Keşfet (`GET /rotalar`)
ile aynı öğe yapısı: rota özeti + `begeni_sayisi` + `begendim` + `sahip {isim, soyisim, avatar, takip_ediyorum}`.

```json
{
  "success": true,
  "data": [
    {
      "id": 5, "baslik": "Kadıköy Turu", "gorunurluk": "herkese_acik",
      "kapak_gorsel": "https://.../app-rotalar/5-....jpg",
      "durak_sayisi": 4, "begeni_sayisi": 12, "begendim": false, "benim": false,
      "created_at": "2026-08-16 21:10:00",
      "sahip": { "uye_id": 12, "isim": "Ada", "soyisim": "Yılmaz",
                 "avatar": "https://.../app-avatars/12-....jpg", "takip_ediyorum": true }
    }
  ],
  "meta": { "page":1, "limit":20, "total":9, "pages":1, "has_more":false, "next_page":null }
}
```

> Keşfet (`GET /rotalar`) ve rota detayı (`GET /uye/rotalar/{id}`) yanıtlarındaki `sahip` bloğuna da
> `takip_ediyorum` eklendi. Böylece akış/kart üzerinde doğrudan "Takip Et" butonu gösterilebilir.

---

## 4. Veritabanı Şeması

Migration: `php rest/tools/migrate_plus_uyelik.php` (idempotent — bu tablolar da dahil).

- `app_rota_begeni`: `id, rota_id, uye_id, created_at` — UNIQUE(`rota_id`,`uye_id`).
- `app_takip`: `id, takip_eden_id, takip_edilen_id, created_at` — UNIQUE(`takip_eden_id`,`takip_edilen_id`).

---

## 5. Durum Kodları

| Kod | Anlam |
|-----|-------|
| 200/201 | Başarılı (201: yeni beğeni/takip oluştu) |
| 401 | Üye girişi gerekli |
| 403 | Gizli rotaya erişim yok (beğeni) |
| 404 | Rota/üye bulunamadı |
| 422 | Geçersiz istek (uye_id yok / kendini takip) |

---

## 6. Mobil Notlar

1. Rota kartında kalp ikonu: `begendim` true/false; POST/DELETE ile toggle et, yanıttaki
   `begeni_sayisi`/`begendim` ile UI'ı güncelle (optimistic update önerilir).
2. Profil ekranında: `GET /uye/takip/edenler?uye_id=X` ve `/edilenler?uye_id=X` ile takipçi/takip
   listeleri + sayıları (`meta.total`).
3. "Takip Et" butonu her yerde `sahip.takip_ediyorum` ile durumlanır; POST/DELETE `/uye/takip`.
4. Ana akış için `GET /uye/rotalar/takip-akisi` (takip edilenlerin rotaları), keşfet için `GET /rotalar`.
```
