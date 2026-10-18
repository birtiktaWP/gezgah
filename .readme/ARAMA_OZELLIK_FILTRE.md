# `/arama` — Mekan özellikleriyle arama ve filtreleme

**Durum:** Backend ⏳ bekleniyor · App ✅ hazır (bkz. §3)
**Base URL:** `https://api.gezgah.com/rest` · İlgili kod: `api/rest/` (`src/Controllers/...`, `src/Helpers.php`, `MekanController::summary()`)

---

## 1) Amaç

Uygulamanın arama ekranında mekan özellikleri (Teras, Bahçe, Şömine, Oyun Kafe, Fasıl…)
hem **filtre** olarak seçilebilmeli hem de **metinle aranabilmeli** ("bahçe" yazınca
bahçeli mekanlar gelmeli). Bugün aramada yalnız filtreler (Wifi, Otopark, Alkol…)
süzülebiliyor; özellikler ne aranıyor ne süzülüyor.

---

## 2) Filtre ve özellik farkı

| | `filtreler` | `ozellikler` |
|---|---|---|
| Kayıt tipi | `type='filtre'` | `type='ozellik'` |
| Mekana bağlantı | meta `filtre_{id}=1` | meta `restoran_ozellik` |
| Örnek | Wifi, Otopark, Alkol, Vale | Teras, Bahçe, Şömine, Oyun Kafe, Fasıl |
| Yanıt alanı | `filtre_ids` | `ozellik_ids` |
| `/arama` bugün | `filtreler=` ile süzülüyor (AND) | desteklenmiyor |

---

## 3) Uygulamanın artık gönderdiği

- **Parametre:** `ozellikler`
- **Değer:** sıralı, virgüllü özellik id listesi → `ozellikler=12,40` (`filtreler=` ile aynı format)
- **Ne zaman:** yalnız kullanıcı en az bir özellik seçtiyse. Seçim yoksa parametre hiç gönderilmez.
- **Nereye:** `GET /arama`, hem `tab=mekan` hem `tab=yemek`; ilk sayfa ve sonraki sayfalar (`page=2…`) dahil. `filtreler=` ile birlikte gelebilir.
- **Tip:** yalnız `type=mekan` iken. Plaj / mesire / otopark aramasında özellik seçimi gösterilmiyor (bkz. §4.4).
- **Özellik listesi kaynağı:** `GET /filtreler?type=restoran` → `meta.ozellikler`.
- **Eşleşme etiketi:** uygulama sonuç kaydındaki `eslesen_ozellikler` dizisini okur ve satırda "Özellik: Bahçe" gösterir. Alan yoksa hiçbir şey göstermez.
- **Geriye uyum:** parametre yok sayılırsa uygulama bozulmaz, sadece süzülmemiş liste görünür.

Örnek istek (uygulamadan):

```
GET /arama?q=kahve&tab=mekan&page=1&limit=20&type=mekan&sort=distance&lat=41.01&lng=28.97&filtreler=109&ozellikler=12,40
```

---

## 4) Gerekli backend değişiklikleri

> Örneklerdeki id'ler (12, 40, 109, 45, 123) temsilidir.

### 4.1) `/arama` → `ozellikler=` parametresi (zorunlu)

- `tab=mekan` ve `tab=yemek` için geçerli.
- **AND:** seçilen tüm özellikler mekanda olmalı.
- SQL: `filtreler=` süzmesinin yanında, `restoran_ozellik` üzerinde her id için `EXISTS`. ES yolu varsa orada da aynı terim süzmesi; iki yol aynı sonucu vermeli.
- `tab=yemek`: süzme, ürünün ait olduğu mekanın özelliklerine göre.
- `total` / `pages` filtreli kümeye ait olmalı.
- `meta.ozellikler`: uygulanan id'leri döner.
- Parametre yok / boş / geçersizse davranış bugünküyle birebir aynı.

```
GET /arama?q=kahve&tab=mekan&type=mekan&page=1&limit=20&ozellikler=12
GET /arama?q=kahve&tab=mekan&filtreler=109&ozellikler=12,40      # AND
GET /arama?q=pizza&tab=yemek&ozellikler=12&page=2
```

```json
"meta": { "page": 1, "limit": 20, "total": 37, "pages": 2, "filtreler": [109], "ozellikler": [12, 40] }
```

### 4.2) `/arama?q=` → özellik ve filtre adlarında metin eşleşmesi (zorunlu)

- Bugün eşleşme yalnız mekan adı ve menü ürün adı üzerinde. Özellik adları (`type='ozellik'`) ve filtre adları (`type='filtre'`) da eklenmeli: `q=bahçe` → Bahçe özelliği olan mekanlar.
- **Türkçe büyük/küçük harf ve aksan duyarsız:** ç/c, ş/s, ı/i, İ/i, ğ/g, ö/o, ü/u. `bahce`, `BAHÇE`, `Bahçe` aynı sonucu vermeli; `somine` → Şömine, `fasil` → Fasıl.
- Not: MySQL `utf8mb4_*_ci` collation'ları ı/i'yi eşitlemez. `q`'yu ve adları PHP'de aynı normalize fonksiyonundan geçirin (`mb_strtolower` + harf haritası) ya da normalize edilmiş bir arama kolonu kullanın.
- Yanıt: `eslesme` dizisine `"ozellik"` (filtre adı eşleşmesinde `"filtre"`) eklenmeli; `eslesen_ozellikler` eşleşen özelliklerin görünen adlarını (orijinal yazım) dönmeli.
- Öneri: isim eşleşmesi sıralamada önde kalsın.

```json
{
  "id": 123,
  "name": "Örnek Kafe",
  "sehir": "İstanbul",
  "ilce": "Kadıköy",
  "filtre_ids": [109],
  "ozellik_ids": [12, 40],
  "eslesme": ["ozellik"],
  "eslesen_urunler": [],
  "eslesen_ozellikler": ["Bahçe"],
  "mesafe_m": 850
}
```

### 4.3) `/arama` özet kayıtlarında `ozellik_ids` (zorunlu)

- Her kayıtta `ozellik_ids` (int dizisi) dönmeli; `filtre_ids` ile aynı yerden (`MekanController::summary()`).
- `tab=yemek`'te ürünün `mekan` nesnesinde de.

### 4.4) `/filtreler?type=` → `meta.ozellikler` tipe göre (zorunlu)

- Bugün `meta.ozellikler` tipe göre süzülmüyor, restoran odaklı. Tipe göre süzülmeli; plaj / mesire / otopark için anlamlı özellik yoksa `[]`.
- Bu yapılınca uygulama diğer tiplerde de özellik grubunu açabilir.

```
GET /filtreler?type=restoran  →  "meta": { "ozellikler": [ { "id": 12, "name": "Bahçe", "slug": "bahce", "icon": "<svg…>" } ] }
GET /filtreler?type=plaj      →  "meta": { "ozellikler": [] }
```

### 4.5) `/kategoriler/{id}` ve `/yerler` → `ozellikler=` (önerilir)

- Aynı sözleşme (virgüllü id, AND, `total`/`pages` filtreli küme).
- Gerekçe: kategori ekranı özellikleri bugün istemcide, yalnız yüklenen sayfalarda süzüyor. Eşleşmeler listenin derinlerindeyse en fazla 5 ek sayfa sonra "sonuç yok" çıkabiliyor (`YERLER_FILTRE_IDS.md` §8'deki sorunun aynısı).

```
GET /kategoriler/45?page=1&limit=20&ozellikler=12
```

---

## 5) Doğrulama listesi (backend)

- [ ] `ozellikler=X` ile dönen her kaydın `ozellik_ids`'i X'i içeriyor (uyumsuz = 0).
- [ ] İki id verildiğinde AND uygulanıyor.
- [ ] Filtreli `total` ≤ filtresiz `total`; `pages` buna göre.
- [ ] `q=bahce`, `q=BAHÇE`, `q=Bahçe` aynı sonucu veriyor; Bahçe'li mekanlar geliyor, `eslesme` içinde `"ozellik"`, `eslesen_ozellikler` içinde `"Bahçe"` var.
- [ ] `tab=yemek&ozellikler=X` yalnız X özellikli mekanların ürünlerini döndürüyor.
- [ ] Parametresiz istek eskisiyle birebir aynı.

---

## 6) Açık konu

Parametre adı (`ozellikler`) ve `eslesme` değeri (`"ozellik"`) sözleşmedir. Değiştirilecekse
uygulama ekibine bildirilmeli; uygulama bugün bu adlarla gönderiyor/okuyor.
