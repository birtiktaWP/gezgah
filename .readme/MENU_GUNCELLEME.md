# QR Menü — Son Güncelleme Tarihi (backend)

Uygulamadaki menü sayfasının en üstünde "Son güncelleme: 12 Ekim 2026, 14:30" bandı gösteriliyor. Bu tarih bugün API'de **yok**: `GET /mekanlar/{id}` yanıtındaki `menu[]` kategorilerinde ve ürünlerinde tarih alanı gelmiyor (canlıda #4740 ve #4745 ile kontrol edildi). Alan gelene kadar uygulama bandı **göstermiyor**.

## İstenen alan

`GET /mekanlar/{id}` → `data` içine, `menu` ile aynı seviyeye:

```json
"menu_guncelleme": "2026-10-12 14:30:00"
```

| Kural | Açıklama |
|---|---|
| Değer | Mekanın QR menüsündeki **son değişiklik** zamanı: ürün ya da kategori ekleme, düzenleme (ad, fiyat, açıklama, görsel, içindekiler, kalori), silme, sıralama |
| Saat dilimi | Europe/Istanbul, `YYYY-MM-DD HH:MM:SS`. ISO-8601 (`2026-10-12T11:30:00Z`) de kabul edilir |
| Menü yok / bilinmiyor | `null` ya da alanı hiç göndermeyin. Uydurma tarih (ör. bugünün tarihi) göndermeyin |
| Önbellek | Detay ES/Redis önbelleğindeyse, menü değişince detay da tazelenmeli (aksi halde eski tarih görünür) |

## Nasıl hesaplanabilir

En sağlamı, menü yazan her işlemde (ERP ve Pro'daki menü uçları) mekana ait bir meta'yı güncellemek:

```
yzd_postmetas · meta_key = 'menu_guncelleme' · meta_value = '2026-10-12 14:30:00'
```

Ürün tablosunda `updated_at` varsa alternatif: `MAX(updated_at)` (silme işlemi bunu yakalamaz, bu yüzden meta önerilir).

## Uygulama tarafı (bilgi)

- Okuyan kod: `PlaceDetail.fromJson` → `menuGuncelleme` (`lib/data/models.dart`), gösterim `lib/screens/menu_screen.dart`.
- Gösterim: `12 Ekim 2026, 14:30`. Saat `00:00:00` gelirse yalnız tarih: `12 Ekim 2026`.
- Alan eklendiğinde yeni uygulama sürümü gerekmez; bu sürümden itibaren otomatik görünür.
