# `/harita` — Plus işletme bayrağı (`is_plus`) eksik
**Durum:** Backend ⏳ bekliyor · App ✅ hazır
**Amaç:** Haritada Gezgah Plus işletmeleri turuncu arka planlı özel pinle göstermek.

---

## 1) Sorun
`GET /harita` yanıtındaki `data[]` kayıtlarında işletmenin Plus olup olmadığını
belirten bir alan yok (bkz. `.readme/HARITA.md` alan listesi). App'te bu bilgi
yalnızca detay ekranında, tek tek `GET /rezervasyon/secenekler?mekan_id=` çağrısıyla
(`aktif`) alınabiliyor; yüzlerce pin için bu kullanılamaz.

## 2) App'in çağırdığı uç
| Method | Yol | Parametreler |
|--------|-----|--------------|
| GET | `/harita` | `type` (her zaman gönderilir: `restoran` \| `otopark` \| `mesire` \| `plaj`), `kategori` (opsiyonel, kategori çipi seçiliyse int id) |

Örnek: `/harita?type=restoran`, `/harita?type=restoran&kategori=122`.
Sayfalama yok; tüm kayıtlar tek yanıtta.

## 3) İstek
`/harita` `data[]` içindeki **her kayda** şu alan eklensin:

| Alan | Tip | Açıklama |
|------|-----|----------|
| `is_plus` | boolean | İşletme şu an aktif (süresi dolmamış) Gezgah Plus ise `true`, değilse `false`. |

- Kaynak/mantık: `/rezervasyon/secenekler` yanıtındaki `aktif` ile **aynı** olmalı
  (aynı işletme için iki uç farklı sonuç vermemeli).
- Tercihen ortak özet temsiline (`MekanController::summary()` — `/mekanlar`, `/yerler`,
  `/arama`, `/mekanlar/{id}` vb.) de eklensin; app tüm listelerde aynı parser'ı
  kullandığı için ileride listelerde de rozet gösterilebilir. Zorunlu olan `/harita`.
- `type=otopark` / `mesire` / `plaj` kayıtlarında Plus kavramı yoksa `false` dönülmesi yeterli.

## 4) Örnek yanıt
```json
{
  "success": true,
  "data": [
    {
      "id": 1573,
      "type": "restoran",
      "name": "Kirpi Liv Ulus",
      "enlem": 41.06000044430381,
      "boylam": 29.026522549773233,
      "kategori_ids": [1410, 122],
      "harita_ikon": null,
      "is_plus": true
    }
  ],
  "error": null,
  "meta": { "total": 99, "kategori": 122, "type": "restoran" }
}
```

## 5) App tarafı (hazır)
- `is_plus: true` olan işletmeler haritada **turuncu (`#FF7A00`) arka planlı** pinle,
  beyaz ikonla ve diğer pinlerin üstünde gösterilir (seçiliyken `#E06A00`).
  Pin şekli/boyutu normal pinlerle aynı.
- Alan yoksa `false` kabul edilir → mevcut lacivert pinler; geriye dönük uyumlu.
- Toleranslı okuma: `true`/`false`, `1`/`0`, `"1"`/`"true"` kabul edilir. Alan adı
  olarak `is_plus` önerilir (yedek olarak `plus`, `isletme_plus` de okunur).

## 6) Kabul testi
```bash
curl "https://api.gezgah.com/rest/harita?type=restoran"   # cihaz token'ı ile
```
Bilinen bir Plus işletmede `"is_plus": true`, diğer kayıtlarda `"is_plus": false` olmalı.
