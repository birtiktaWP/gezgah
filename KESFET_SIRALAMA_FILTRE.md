# Gezgah — Gezi Rotaları Keşfet: Sıralama + Filtreleme

Herkese açık rota akışı (`GET /rotalar`) artık **sıralama** ve **filtreleme** destekler.
Geriye dönük uyumludur: parametre verilmezse eski davranış (en yeni önce) çalışır.

- Uç: `GET /rotalar`
- Başlıklar: `X-App-Key: <app_key>` + `Authorization: Bearer <token>` (cihaz veya üye)

---

## 1. Parametreler

| Parametre | Değerler | Açıklama |
|-----------|----------|----------|
| `sort` | `yeni` (varsayılan), `begeni`, `fiyat_artan`, `fiyat_azalan`, `mesafe` | Sıralama |
| `tip` | `restoran`, `mesire`, `plaj` | Rotada bu **tipte en az bir durak** olanlar |
| `ilce` | ilçe id (int) | Rotada bu **ilçede en az bir durak** olanlar |
| `uye_id` | üye id (int) | Yalnız o üyenin herkese açık rotaları |
| `lat`,`lng` | koordinat | `mesafe` sıralaması / `mesafe_m` filtresi için (kullanıcı konumu) |
| `mesafe_m` | metre (int) | Bu mesafeden **yakın** rotalar (lat/lng gerekir) |
| `page`,`limit` | int (limit 1-50, vars. 20) | Sayfalama |

### Sıralama detayları
- **`yeni`** — oluşturulma tarihine göre en yeni üstte.
- **`begeni`** — en çok beğenilen üstte (`begeni_sayisi`).
- **`fiyat_artan` / `fiyat_azalan`** — rotanın duraklarındaki **seçili menü ürünlerinin**
  (`secili_urun`) fiyat toplamına göre. Fiyatlı ürünü olmayan rotalar `rota_fiyat: null`
  olur ve **sona** sıralanır.
- **`mesafe`** — rotanın **ilk durağının** konumu ile verilen `lat/lng` arası mesafeye göre
  (yakın üstte). Konum çözülemeyen rotalar sona düşer. `lat/lng` yoksa `sort` otomatik `yeni` olur.

> Not: `fiyat_*` ve `mesafe` sıralamalarında sunucu, filtreye uyan en fazla **500** rotayı
> değerlendirir (performans sınırı). Filtreleri (`tip`/`ilce`/`uye_id`) daraltmak sonucu netleştirir.

---

## 2. Yanıt

Her öğe standart rota özetine ek olarak şunları içerir:
- `rota_fiyat` (number|null) — seçili ürünlerin fiyat toplamı (yoksa `null`).
- `mesafe_m` (int|null) — kullanıcı konumu verildiyse ilk durağa mesafe (metre), yoksa `null`.
- `begeni_sayisi`, `begendim`, `benim`, `sahip {isim, soyisim, avatar, takip_ediyorum}` (mevcut alanlar).

```json
{
  "success": true,
  "data": [
    {
      "id": 5, "baslik": "Kadıköy Turu", "gorunurluk": "herkese_acik",
      "kapak_gorsel": "https://.../app-rotalar/5-....jpg",
      "durak_sayisi": 3, "begeni_sayisi": 12, "begendim": false, "benim": false,
      "rota_fiyat": 620.0, "mesafe_m": 3525,
      "created_at": "2026-08-16 21:10:00",
      "sahip": { "uye_id": 12, "isim": "Ada", "soyisim": "Yılmaz",
                 "avatar": "https://.../app-avatars/12-....jpg", "takip_ediyorum": true }
    }
  ],
  "meta": {
    "page":1, "limit":20, "total":37, "pages":2, "has_more":true, "next_page":2,
    "sort":"fiyat_artan", "tip":"restoran", "ilce":null
  }
}
```

---

## 3. Örnekler

```
GET /rotalar                                  → en yeni (varsayılan)
GET /rotalar?sort=begeni                      → en çok beğenilen
GET /rotalar?sort=fiyat_artan                 → seçili ürünler toplamı ucuzdan pahalıya
GET /rotalar?sort=fiyat_azalan&tip=restoran   → sadece restoran duraklı, pahalıdan ucuza
GET /rotalar?tip=plaj                          → plaj duraklı rotalar
GET /rotalar?ilce=1101                         → Kadıköy'de durağı olan rotalar
GET /rotalar?sort=mesafe&lat=41.0082&lng=28.9784        → bana en yakın (ilk durak)
GET /rotalar?sort=mesafe&lat=41.0&lng=29.0&mesafe_m=5000 → 5 km içindekiler, yakından uzağa
GET /rotalar?uye_id=12&sort=begeni             → 12 numaralı üyenin en beğenilen rotaları
```

Filtreler ve sıralama birlikte kullanılabilir (ör. `?tip=restoran&sort=fiyat_artan&ilce=1101`).

---

## 4. Notlar

- `rota_fiyat`, durak eklerken seçilen QR menü ürünlerine (`secili_urun` / `qr_id`) dayanır;
  hiç ürün seçilmemiş rotalarda `null`'dır (bkz. `PROFIL_VE_ROTA_URUN.md` §1).
- `mesafe`/`mesafe_m` için mekan koordinatı `kordinat` / `plaj_kordinat` / `mesire_kordinat`
  metalarından okunur; koordinatı olmayan ilk duraklı rotalar mesafesiz (`null`) kalır.
- Bu özellikler yalnız **herkese açık** rotalar için akıştadır; gizli rotalar görünmez.
- Ek tablo/şema değişikliği yoktur (mevcut `app_gezi_rota_mekanlari.qr_id` kullanılır).

---

## 5. Mobil Kullanım

1. Keşfet ekranında bir "Sırala" menüsü: En yeni / En beğenilen / Fiyat (artan-azalan) / Mesafe.
2. "Mesafe" seçilince cihaz konumunu (`lat`,`lng`) parametre olarak gönder.
3. Filtre çipleri: Restoran / Mesire / Plaj (`tip`), İlçe (`ilce`).
4. Kartta `rota_fiyat` (varsa) ve `mesafe_m` (varsa) rozet olarak gösterilebilir.
