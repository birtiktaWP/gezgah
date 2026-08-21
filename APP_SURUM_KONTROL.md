# Uygulama Sürüm Kontrolü — Zorunlu / Opsiyonel Güncelleme

Mobil uygulama açılışta bu ucu çağırır; **yeni sürüm** varsa ana ekranda modal gösterir ve
kullanıcıyı App Store / Google Play'e yönlendirir. Sürüm **minimum desteklenen** sürümün
altındaysa **zorunlu** (kapatılamaz) güncelleme akışı çalışır.

Taban URL: `https://api.gezgah.com/rest`

## Ortak Başlıklar
| Başlık | Değer |
|---|---|
| `X-App-Key` | `ba9db8d2c420adbaeed122fe53c15e878fbcc67b55ba41cd` (zorunlu) |
| `Authorization` | `Bearer <cihaz veya üye token>` (opsiyonel) |

> Kimlik gerekmez; cihaz token'ı yeterli. Sonuç kısa süre (ör. 5–10 dk) Redis'te cache'lenebilir.

Yanıt zarfı: `{ "success": bool, "data": ..., "error": ..., "meta": ... }`

---

## Uç

```
GET /uygulama-surum?platform=ios&surum=1.0.4&build=32
```

### Sorgu parametreleri
| Param | Zorunlu | Açıklama |
|---|---|---|
| `platform` | ✓ | `ios` \| `android`. Hangi mağaza sürümü/linki döneceğini belirler. |
| `surum` | – | İstemcinin **marketing sürümü** (ör. `1.0.4`). Sunucu karşılaştırıp `guncelleme_var` / `zorunlu` hesaplar. |
| `build` | – | İstemci **build numarası** (ör. `32`). `surum` eşitse build ile ayrım yapılır. |

> `surum`/`build` gönderilmezse sunucu yalnız `son_surum` / `min_surum` / `store_url` döner; karşılaştırmayı istemci yapabilir. **Önerilen:** istemci sürümünü gönderir, sunucu bayrakları hesaplar (istemci mantığı minimum kalır).

---

## Yanıt (200)

```json
{
  "success": true,
  "data": {
    "platform": "ios",
    "guncelleme_var": true,
    "zorunlu": false,
    "son_surum": "1.1.0",
    "son_build": 40,
    "min_surum": "1.0.4",
    "min_build": 30,
    "store_url": "https://apps.apple.com/app/id6782167355",
    "baslik": "Yeni sürüm hazır",
    "mesaj": "Yeni özellikler ve iyileştirmeler için güncelle.",
    "notlar": ["Yorum beğenileri", "İşletme yorumları", "Hata düzeltmeleri"]
  }
}
```

### Alan açıklamaları
| Alan | Tip | Açıklama |
|---|---|---|
| `platform` | string | Yankılanan platform. |
| `guncelleme_var` | bool | İstemci sürümü `son_surum`/`son_build`'den **eski** mi → modal göster. `surum` verilmezse sunucu `false` dönebilir (istemci hesaplar). |
| `zorunlu` | bool | İstemci sürümü `min_surum`/`min_build`'in **altında** mı → **kapatılamaz** modal, tek buton "Güncelle". |
| `son_surum` | string | Mağazadaki en güncel marketing sürümü (ör. `1.1.0`). |
| `son_build` | int | En güncel build numarası. |
| `min_surum` | string | Desteklenen **en düşük** marketing sürümü; bunun altındakiler zorunlu güncellenir. |
| `min_build` | int | En düşük build numarası (surum eşitse ayrım için). |
| `store_url` | string | Platforma göre mağaza linki (iOS App Store / Google Play). "Güncelle" bunu açar. |
| `baslik` | string | Modal başlığı (backend'den yönetilir). |
| `mesaj` | string | Modal açıklama metni. |
| `notlar` | string[] | Opsiyonel "yenilikler" maddeleri (modelde madde madde gösterilebilir). |

---

## Sürüm Karşılaştırma Kuralı (sunucu)
1. Önce **marketing sürümü** (`surum`) semantik karşılaştırılır (`1.1.0` > `1.0.4`).
2. Marketing sürümleri **eşitse** `build` numarasına bakılır.
3. `zorunlu` = (istemci sürümü < `min_surum`) **veya** (eşit sürümde istemci build < `min_build`).
4. `guncelleme_var` = (istemci sürümü < `son_surum`) **veya** (eşit sürümde istemci build < `son_build`).
5. `surum`/`build` gelmezse `guncelleme_var` ve `zorunlu` `false` döner (istemci alanlarla kendi kararını verir).

> Sürüm metinleri `major.minor.patch` biçiminde beklenir; eksik parçalar `0` sayılır (`1.1` → `1.1.0`).

---

## Yapılandırma (backend)
Platform bazlı değerler bir ayar tablosunda/config'de tutulur; yeni build yayınlanınca yalnız bu değerler güncellenir:

| Anahtar | Örnek |
|---|---|
| `ios_son_surum` / `ios_son_build` | `1.1.0` / `40` |
| `ios_min_surum` / `ios_min_build` | `1.0.4` / `30` |
| `ios_store_url` | `https://apps.apple.com/app/id6782167355` |
| `android_son_surum` / `android_son_build` | `1.1.0` / `40` |
| `android_min_surum` / `android_min_build` | `1.0.4` / `30` |
| `android_store_url` | `https://play.google.com/store/apps/details?id=com.gezgah.gezgah` |
| `baslik` / `mesaj` / `notlar` | Modal metinleri (platform ortak veya ayrı) |

- `store_url` gönderilmezse istemci varsayılan mağaza linkine düşer (iOS App Store id / Android package id).
- Ayarlar boşsa (henüz doldurulmadıysa) uç `guncelleme_var=false`, `zorunlu=false` dönmeli (uygulama uyarı göstermez, fail-safe).

---

## Mobil Akış (uygulama)
1. Açılışta `package_info_plus` ile mevcut `surum` + `build` alınır.
2. `GET /uygulama-surum?platform=<ios|android>&surum=<x>&build=<y>` çağrılır.
3. `zorunlu == true` → **kapatılamayan** modal (geri tuşu / dışarı dokunma kapalı; tek buton **Güncelle**).
4. `guncelleme_var == true && !zorunlu` → **Güncelle / Daha sonra** modalı (günde en fazla 1 kez gösterilecek şekilde yerelde throttle).
5. **Güncelle** → `store_url` `url_launcher` ile açılır (dış tarayıcı/mağaza).
6. Ağ hatası / `success=false` → sessiz geç (uygulama normal açılır).

---

## Özet Endpoint Listesi
| Metot | Yol | Açıklama |
|---|---|---|
| GET | `/uygulama-surum` | Platform + istemci sürümüne göre güncelleme durumu (zorunlu/opsiyonel) + mağaza linki |

## Teknik Notlar
- Redis cache 5–10 dk (mağaza sürümü sık değişmez).
- Sürüm karşılaştırması sunucuda yapılır; istemci yalnız bayraklara ve metinlere bakar.
- Zorunlu güncelleme yalnız **kritik** durumlarda kullanılmalı (min_surum'u dikkatli yönet); aksi halde eski cihazlarda kullanıcı kilitlenebilir.
