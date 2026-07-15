# Ana Sayfa Veri Sorunu — Devir Notu

> **✅ ÇÖZÜLDÜ (2026-07):** Sunucuda `cihaz_tokenlari` tablosu artık mevcut;
> `POST /cihaz/kayit` **201** dönüyor ve dönen token ile korumalı endpoint'ler
> **200** veriyor (canlı doğrulandı). Ayrıca istemci tarafına **401 otomatik
> onarımı** eklendi (bkz. `GUVENLIK.md §4.2`): cihazda bu dönemden kalma bayat
> bir token olsa bile ilk istekte otomatik yenilenir; uygulamayı silmeye gerek
> yoktur. Aşağıdaki notlar tarihsel kayıt olarak bırakılmıştır.

## İstemcide yaptıklarım (Flutter) — tamam
- **Cihaz token hazırlık kapısı**: `/cihaz/kayit` hariç her istek, cihaz token'ı
  hazır olana kadar bekliyor (`lib/data/api.dart` → `_SecurityInterceptor`).
- **Kayıt açılışta koşulsuz başlıyor**: `main()` içinde dedup'lı
  `DeviceService.ensureRegistered()` (`lib/data/device_service.dart`,
  `lib/main.dart`). İlk açılışta kaydın atlanması hatası giderildi.
- Ayrıntı: `GUVENLIK.md §4.1`.
- `flutter analyze` temiz.

## Buna rağmen gelmeyenler (ekran görüntüsü)
- **Kategoriler, Sponsorlu Restoranlar, Yeni Eklenenler, Öne Çıkan Etkinlikler → BOŞ.**
- **Yakındakiler** → sadece mock veri (Çiya Sofrası / Forno İtalyan); API hata
  verince fallback devreye giriyor.
- Kısayollar (Eczane, Otopark…) geliyor çünkü statik, API gerektirmez.
- Yani API'den hiçbir korumalı veri gelmiyor.

## Kök neden = SUNUCU (canlı API'de doğrulandı)
```
GET  /rest/            -> 200  (açık yol çalışıyor)
GET  /rest/kategoriler -> 401  {"error":{"message":"Geçerli bir erişim token'ı gerekli."}}
POST /rest/cihaz/kayit -> 500
     SQLSTATE[42S02]: Base table or view not found: 1146
     Table 'gezgah_v3.cihaz_tokenlari' doesn't exist
```
- Sunucu `require_token=true`: token'sız her endpoint **401**.
- Ama `cihaz_tokenlari` tablosu **yok** → `/cihaz/kayit` **500** → istemci geçerli
  token **alamıyor** → tüm korumalı endpoint'ler 401 → ana sayfa boş.

## Sunucuda yapılması gerekenler
1. **Migration çalıştır**: `php rest/tools/migrate_cihaz_tokenlari.php`
   (LIVE DB: `gezgah_v3`). Tablo şeması: `CIHAZ_TOKEN.md`.
2. Doğrula: `POST /cihaz/kayit` **201** dönüp token üretmeli; dönen token ile
   `GET /kategoriler` **200** olmalı.
3. `APP_DEBUG=false` yap — şu an 500 gövdesinde tam stack trace + dosya yolu
   (`/home/gezgah/public_html/api/rest/src/Database.php`) sızıyor (`GUVENLIK.md §3`).

> Özet: İstemci hazır; sorun sunucuda eksik `cihaz_tokenlari` tablosu. Tablo
> oluşturulunca ana sayfadaki tüm alanlar dolacak.
