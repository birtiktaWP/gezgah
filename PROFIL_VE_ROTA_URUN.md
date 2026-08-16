# Gezgah — Üye Profili + Rota Durağında Menü Ürünü Seçimi

Bu doküman iki yeni özelliği anlatır:
1. Gezi rotası durağına, o mekanın **QR menüsünden ürün** seçebilme.
2. Üyelerin **herkese açık profil** sayfası (bilgiler + rotalar).

- Taban URL: `https://api.gezgah.com/rest/`
- Başlıklar: `X-App-Key: <app_key>` + `Authorization: Bearer <uye_token>`

---

## 1. Rota Durağında Menü Ürünü Seçimi

Bir durağa mekan eklerken (veya sonradan) o mekanın QR menüsünden bir **ürün** bağlanabilir
(örn. "Bu kafede *Cheesecake* dene"). Ürün seçimi opsiyoneldir.

### 1.1. Mekanın menüsünü getir (ürün seçici)
`GET /uye/rotalar/mekan-menu?post_id=<mekan_id>`
```json
{ "success": true, "data": {
  "post_id": 1064,
  "menu": [
    { "kategori_id": 12, "kategori": "Tatlılar", "urunler": [
      { "qr_id": 5, "ad": "Cheesecake", "fiyat": "350", "gorsel": "https://qr.gezgah.com/img.php?t=g&f=..." }
    ]}
  ]
}}
```
Cihaz veya üye token'ı yeterli. Menüsü olmayan mekanda `menu: []`.

### 1.2. Durak eklerken ürün bağla  [Plus]
`POST /uye/rotalar/{id}/mekan`
```json
{ "post_id": 1064, "yorum": "Tatlısı harika", "qr_id": 5 }
```
- `qr_id` opsiyonel; verilirse **o mekana ait gerçek bir ürün** olmalı (değilse `422`).
- Yanıt: `{ "durum": "eklendi", "durak_id": 11 }`.

### 1.3. Durak ürününü/yorumunu güncelle  [Plus]
`POST /uye/rotalar/{id}/mekan/guncelle`
```json
{ "durak_id": 11, "yorum": "yeni not", "qr_id": 8 }
```
- Yalnız `yorum` veya yalnız `qr_id` gönderilebilir.
- `qr_id: 0` (veya 0'dan küçük) → ürün seçimini **temizler**.
- Geçersiz `qr_id` (o mekanda yok) → `422`.

### 1.4. Rota detayında görünüm
`GET /uye/rotalar/{id}` yanıtındaki her durak artık `secili_urun` içerir:
```json
{
  "durak_id": 11, "sira": 1, "yorum": "Tatlısı harika",
  "mekan": { "id": 1064, "name": "Favolin", ... },
  "secili_urun": { "qr_id": 5, "ad": "Cheesecake", "fiyat": "350", "gorsel": "https://qr.gezgah.com/img.php?t=g&f=..." }
}
```
Ürün seçili değilse `secili_urun: null`. (Görsel, QR menüsündeki `img.php` proxy URL'sidir.)

---

## 2. Üye Profili

`GET /uye/profil/{id}?page=&limit=`

Bir üyenin herkese açık profilini ve rotalarını döner.
- **Başkasının profilinde:** yalnız `herkese_acik` rotalar; metrikler herkese açık üzerinden.
- **Kendi profilinde** (`benim=true`): TÜM rotalar (gizli dahil), metrikler tüm rotalar üzerinden.

```json
{
  "success": true,
  "data": {
    "profil": {
      "uye_id": 12,
      "isim": "Ada", "soyisim": "Yılmaz",
      "avatar": "https://gezgah.com/uploads/app-avatars/12-....jpg",
      "rota_sayisi": 8,
      "takipci_sayisi": 134,
      "takip_edilen_sayisi": 57,
      "toplam_begeni": 412,
      "takip_ediyorum": false,
      "benim": false
    },
    "rotalar": [
      {
        "id": 5, "baslik": "Kadıköy Turu", "gorunurluk": "herkese_acik",
        "kapak_gorsel": "https://.../app-rotalar/5-....jpg",
        "durak_sayisi": 4, "begeni_sayisi": 12, "begendim": true,
        "created_at": "2026-08-16 21:10:00", "updated_at": "..."
      }
    ]
  },
  "meta": { "page":1, "limit":20, "total":8, "pages":1, "has_more":false, "next_page":null }
}
```

Alanlar:
- `rota_sayisi` — toplam rota (başkasında herkese açık; kendinde tümü) = `meta.total`.
- `takipci_sayisi` / `takip_edilen_sayisi` — takipçi / takip edilen sayısı.
- `toplam_begeni` — üyenin rotalarına gelen toplam beğeni (başkasında herkese açık rotalar).
- `takip_ediyorum` — isteği yapan üye bu kişiyi takip ediyor mu (kendi profili/anonim → `null`).
- `benim` — profil isteği yapan üyeye mi ait.
- `rotalar[].begendim` — isteği yapan üyenin o rotayı beğenip beğenmediği.

Kimlik: cihaz **veya** üye token'ı yeterli. `takip_ediyorum`/`begendim` yalnız üye token'ıyla dolar.

---

## 3. Şema

Migration: `php rest/tools/migrate_plus_uyelik.php` (idempotent).
- `app_gezi_rota_mekanlari` tablosuna **`qr_id INT NULL`** kolonu eklendi (durağın seçili menü ürünü; `yzd_qr.id`).

Profil için ek tablo yok — mevcut `app_uyeler`, `app_gezi_rotalari`, `app_rota_begeni`, `app_takip` üzerinden hesaplanır.

---

## 4. Durum Kodları

| Kod | Anlam |
|-----|-------|
| 200 | Başarılı |
| 201 | Durak eklendi |
| 401 | Üye/token gerekli (yazma uçları) |
| 403 | Plus gerekli (durak ekleme/güncelleme) / gizli rota |
| 404 | Mekan / rota / üye bulunamadı |
| 422 | Geçersiz istek (qr_id o mekanda yok, post_id eksik vb.) |

---

## 5. Mobil Akış Önerisi

1. Durak eklerken "Menüden ürün seç" → `GET /uye/rotalar/mekan-menu?post_id=` ile menüyü göster,
   seçilen `qr_id`'yi `POST .../mekan` gövdesine ekle.
2. Rota detayında durak kartında `secili_urun` varsa ürün adı/fiyat/görselini rozet olarak göster.
3. Rota kartındaki avatar/isme tıklayınca → `GET /uye/profil/{id}` ile profil sayfasını aç
   (üstte isim/avatar + takipçi/rota/beğeni sayaçları + "Takip Et" butonu (`sahip.takip_ediyorum`
   veya profildeki `takip_ediyorum`), altında rota listesi).
