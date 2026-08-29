# Kayan Yazı (Marquee) — ERP Reklam Sayfası

Panelde **Reklam Ayarları > Kayan Yazı** kartında yönetilen, sırayla gösterilmek
üzere tutulan kısa duyuru metinleri. Süre/tarih kavramı **yoktur**; metin listede
olduğu sürece yayındadır.

> Panel: `https://erp.gezgah.com/reklam.html`
> API tabanı: `https://erp-api.gezgah.com`

---

## Veri modeli

Tek satırlık global panel ayarı; diğer reklam yerleşimleriyle **aynı JSON** içinde.

| Yer | Değer |
|---|---|
| Tablo | `pro_reklam` (tek satır: `ORDER BY id ASC LIMIT 1`) |
| Kolon | `data` (LONGTEXT, JSON) |
| Anahtar | `marquee` |
| Tip | `string[]` — düz metin dizisi |

```json
{
  "marquee": ["Yeni sezon kahvaltı mekanları eklendi", "Plaj rehberi yayında"],
  "homeVenue": [],
  "mapFeature": [{ "venue": "...", "duration": "1 Hafta", "addedAt": 1756000000000 }],
  "searchVenues": [],
  "searchInputVenues": [],
  "events": [],
  "categoryPin": []
}
```

Dizideki **sıra anlamlıdır** — panelde sürükle-bırak ile değiştirilir ve
gösterim sırası olarak kabul edilir.

> Not: Aynı sayfadaki **Öne Çıkan Kategoriler** alanı `pro_reklam`'da değil,
> `home_page_settings > one_cikan_kategoriler` satırındadır. Kayan yazı ile
> karıştırılmamalı.

---

## Uçlar

Her ikisi de oturum ister (`erp_session` çerezi). Yetki: `reklam` modülü
(`GET` → `read`, `POST` → `edit`); ana admin muaf.

### Okuma

| Metot | Yol |
|---|---|
| GET | `/ads` |

```json
{
  "ok": true,
  "settings": {
    "marquee": ["Yeni sezon kahvaltı mekanları eklendi"],
    "homeVenue": [], "mapFeature": [], "searchVenues": [],
    "searchInputVenues": [], "events": [], "categoryPin": []
  },
  "homeCategories": [{ "id": 1081, "name": "Kahvaltı" }]
}
```

`marquee` her zaman dizi döner (kayıt yoksa `[]`).

### Yazma

| Metot | Yol |
|---|---|
| POST | `/ads/save` |

`Content-Type: application/json` zorunludur (basit CSRF önlemi; başka bir içerik
türü `415` döner).

```json
{
  "settings": {
    "marquee": ["Birinci duyuru", "İkinci duyuru"],
    "homeVenue": [], "mapFeature": [], "searchVenues": [],
    "searchInputVenues": [], "events": [], "categoryPin": []
  }
}
```

**DİKKAT — kısmi kayıt yoktur.** `POST /ads/save` gövdedeki `settings`'i
tamamının yerine yazar (replace). `marquee` gönderilmezse **boşaltılır**.
Panel bu yüzden her kaydetmede tüm bölümleri birlikte yollar. Yalnız kayan
yazıyı güncelleyecek bir istemci, önce `GET /ads` ile mevcut ayarları alıp
üzerine yazmalıdır.

Yanıt, temizlenmiş `settings`'i geri döndürür.

### Sunucu tarafı temizlik

`marquee` öğeleri için uygulanan kurallar (`AdsController::save`):

| Kural | Davranış |
|---|---|
| `trim` | Baş/son boşluklar atılır |
| `strip_tags` | HTML etiketleri silinir (XSS yüzeyi bırakılmaz) |
| Boş öğe | Listeye alınmaz |
| Dizi değilse | `marquee` boş diziye düşer |
| Uzunluk sınırı | **Yok** — istemci tarafında sınırlamak gerekir |

İşlem `logs` tablosuna `reklam_kaydet` olarak yazılır.

---

## Panel davranışı (`erp/assets/js/reklam.js`)

- Kart, sağ kolonda (`form-side`) `data-section="marquee"` ile durur.
- Ekleme: input + **Ekle** butonu ya da `Enter`.
- Sıralama: satırlar `draggable`; bırakıldığında dizi yeniden kurulur.
- Kaldırma: satırdaki `×`.
- Önizleme: liste boş değilse kartın altında öğeler `   •   ` ile birleştirilip
  `#marqueePreview` içinde gösterilir.
- Kaydetme, sayfadaki tek **Ayarları Kaydet** butonuyla yapılır — eklemek/silmek
  tek başına kalıcı değildir.

---

## Kedy (yapay zeka) erişimi

`kedy/lib/Tools.php` aynı kaydı okur/yazar:

- `list_ad_placements` → yanıtında `marquee` dizisi de döner.
- Yerleşim yazma araçları (`set_ad_placement`, `remove_ad_placement`) yalnız
  mekan bölümlerini değiştirir; **kayan yazıyı değiştirmez.**

Kedy ile panel aynı satıra yazdığı için, biri kaydettikten sonra diğerinde
sayfa yenilenmeden eski değer görünebilir.

---

## Mobil uygulama tarafı — henüz uç YOK

Kayan yazıyı okuyan bir mobil API ucu **bulunmuyor**. `api/rest` içinde
`pro_reklam` hiç okunmuyor; ana sayfa yapılandırması `home_page_settings`
üzerinden gidiyor. Yani şu an bu metinler yalnız panelde ve Kedy'de görünür.

Uygulamada göstermek istenirse önerilen en küçük eklenti:

| Metot | Yol | Yanıt |
|---|---|---|
| GET | `/kayan-yazilar` | `data: string[]` |

```json
{ "success": true, "data": ["Birinci duyuru", "İkinci duyuru"], "meta": { "total": 2 } }
```

- Kaynak: `pro_reklam.data` → `marquee`.
- Önbellek: Redis `resp:marquee`, 300 sn; ERP kaydettiğinde `AdsController`
  içinden `gzapi:resp:marquee` silinerek anında tazelenir (kategorilerde
  kurulan desenin aynısı).
- Diğer mobil uçlar gibi `X-App-Key` + `Bearer` ister.

Bu uç eklenmediği sürece panelde girilen kayan yazının uygulamada karşılığı
olmayacaktır.

---

## Doğrulama (canlı)

```bash
# Mevcut değer
curl -s -b 'erp_session=<token>' https://erp-api.gezgah.com/ads

# Yalnız kayan yazıyı güncellerken: önce oku, sonra üzerine yaz
```

Şu anki durum: `pro_reklam.marquee` **boş** (`[]`) — panelde henüz metin
girilmemiş.
