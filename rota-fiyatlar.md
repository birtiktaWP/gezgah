# Gezgah — Gezi Rotası Toplam Fiyatı (`rota_fiyat`)

Bir gezi rotasının **toplam fiyatı**, duraklara eklenen **seçili menü ürünlerinin**
(`secili_urun` / `qr_id`) fiyatları toplamıdır. Artık TÜM rota liste ve detay uçlarında döner.

- Alan: `rota_fiyat` (number | null)
- Ürünü seçili durak yoksa → `rota_fiyat: null`.
- Fiyatlar QR menüden (`yzd_qr.price`) alınır; TR/EN biçimli fiyatlar sayıya çevrilir (₺/TL/nokta/virgül temizlenir).

---

## 1. Hangi uçlarda dönüyor?

| Uç | `rota_fiyat` | Not |
|----|:---:|-----|
| `GET /rotalar` (keşfet) | ✅ | Ayrıca `sort=fiyat_artan/fiyat_azalan` ile sıralama |
| `GET /uye/rotalar` (kendi rotalarım) | ✅ | Liste kartında |
| `GET /uye/rotalar/takip-akisi` | ✅ | Takip akışı kartında |
| `GET /uye/profil/{id}` (profil rotaları) | ✅ | Profil rota kartında |
| `GET /uye/rotalar/{id}` (detay) | ✅ | Rota toplamı + her durağın ürün fiyatı |

---

## 2. Liste kartı (örnek)

`GET /rotalar` / `/uye/rotalar` / `/uye/rotalar/takip-akisi` / `/uye/profil/{id}` öğeleri:
```json
{
  "id": 5, "baslik": "Kadıköy Turu", "gorunurluk": "herkese_acik",
  "kapak_gorsel": "https://.../app-rotalar/5-....jpg",
  "durak_sayisi": 3, "begeni_sayisi": 12, "begendim": false,
  "rota_fiyat": 450.0,
  "created_at": "2026-08-16 21:10:00"
}
```
- `rota_fiyat: 450.0` → o rotadaki seçili ürünlerin toplamı (₺). Seçili ürün yoksa `null`.
- (Keşfette ayrıca konum verilirse `mesafe_m` de gelir.)

---

## 3. Detay + mekan (durak) listesi

`GET /uye/rotalar/{id}`:
```json
{
  "success": true,
  "data": {
    "rota": {
      "id": 5, "baslik": "Kadıköy Turu",
      "begeni_sayisi": 12, "begendim": true, "benim": false,
      "rota_fiyat": 450.0,
      "sahip": { "uye_id": 12, "isim": "Ada", "soyisim": "Yılmaz", "avatar": "...", "takip_ediyorum": true },
      "duraklar": [
        {
          "durak_id": 11, "sira": 1, "yorum": "Tatlısı harika",
          "mekan": { "id": 1064, "name": "Favolin", "ilce": "Bakırköy", ... },
          "secili_urun": { "qr_id": 5, "ad": "Cheesecake", "fiyat": "350", "gorsel": "https://qr.gezgah.com/img.php?t=g&f=..." }
        },
        {
          "durak_id": 12, "sira": 2, "yorum": null,
          "mekan": { "id": 2091, "name": "Ada Kahve", ... },
          "secili_urun": { "qr_id": 8, "ad": "Latte", "fiyat": "100", "gorsel": "..." }
        }
      ]
    }
  }
}
```
- `rota.rota_fiyat` = duraklardaki `secili_urun.fiyat` toplamı (350 + 100 = 450).
- Her durakta ürünün tekil fiyatı `secili_urun.fiyat` alanında (string, sayısal).
- Ürünü seçili olmayan durak `secili_urun: null` döner ve toplama katkısı olmaz.

---

## 4. Notlar

- `rota_fiyat` bir **gösterge** toplamdır (kullanıcının seçtiği ürünler); menüdeki tüm ürünlerin
  değil. Kullanıcı durak eklerken/güncellerken ürün seçtikçe toplam güncellenir
  (bkz. `PROFIL_VE_ROTA_URUN.md` — durak ürün seçimi).
- Sayısal alandır (float). İstemci gösterirken `₺` ekleyip biçimlendirebilir (ör. `₺450`).
- Şema değişikliği yok; mevcut `app_gezi_rota_mekanlari.qr_id` + `yzd_qr.price` kullanılır.
- Keşfet fiyat sıralaması: `GET /rotalar?sort=fiyat_artan` / `fiyat_azalan`
  (detay: `KESFET_SIRALAMA_FILTRE.md`).
