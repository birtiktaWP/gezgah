# `/yerler` — Mekan kayıtlarında `filtre_ids` eksik (otopark / mesire / plaj filtreleri çalışmıyor)

**Durum:** Backend ✅ tamam · App ✅ tamam (bkz. §8) · 5 Eylül 2026
**Etki (önce):** Otopark, mesire ve plaj listelerinde filtreleme sonuç döndürmüyordu.
**Not:** Restoran (mekan) listelerinde sorun yoktu — orada `filtre_ids` geliyordu.

> Doğrulama: canlı API (`https://api.gezgah.com/rest`), cihaz token'ı ile.
> Otomatik kabul testi: `api/rest/tools/filtre-ids-test.php` → **21/21 geçti**.

---

## 1) Belirti (giderildi)

Otopark listesinde filtre modalinden bir seçenek (ör. "İspark") seçilince liste
`0 mekan (filtreli)` durumuna düşüyordu. Aynı davranış mesire ve plajda da vardı.

Filtre modalindeki seçenekler doğru geliyordu; sorun mekan tarafındaki eşleşme
verisindeydi.

---

## 2) Kök neden

Filtreleme istemci tarafında **AND** mantığıyla yapılıyor: seçilen filtre id'lerinin
hepsi mekanın `filtre_ids` dizisinde olmalı.

`MekanController::summary()` — `/yerler`, `/mekanlar`, `/arama` ve diğer liste
uçlarının **ortak** özet temsili — `filtre_ids` alanını hiç üretmiyordu. Aynı mantık
`KategoriController` ve `AppFavoriController` içinde **birbirinden kopyalanmış**
private metotlar olarak duruyordu; `MekanController`'a hiç eklenmemişti.

Yani veri sağlamdı, yalnız bu temsile taşınmamıştı.

---

## 3) Yapılan değişiklik

### `src/Helpers.php` — iki yeni paylaşımlı yardımcı

| Metot | İş |
|---|---|
| `Helpers::aktifFiltreIdleri(array $metas): array` | `filtre_{id} = '1'` metalarından id dizisi. Değeri `'0'` olan metalar **dahil edilmez** (satır var olsa bile). |
| `Helpers::kordinatOf(array $metas, ?string $type): ?string` | Koordinatı tipten bağımsız bulur. |

Üç controller'daki kopyalar kaldırıldı, hepsi tek kaynağı kullanıyor — uçlar
arasında ayrışma riski ortadan kalktı.

### `MekanController::summary()`

- `filtre_ids` eklendi → **tek noktadan** `/yerler`, `/mekanlar`, `/arama`,
  `/mekanlar/one-cikanlar`, `/mekanlar/yeni`, `/mekanlar/yakin`,
  `/pagination_isletmeler` ve detay `/mekanlar/{id}` düzeldi.
- **Ek bulgu — `kordinat`:** Alan yalnız `kordinat` ve `plaj_kordinat` metalarına
  bakıyordu. Canlı veride koordinat anahtarı tipe göre değişiyor:

  | Tip | Kullanılan meta | Yayında |
  |---|---|---|
  | otopark | `kordinat` (1600/1602) | ✅ zaten geliyordu |
  | plaj | `plaj_kordinat` (79/80) | ✅ zaten geliyordu |
  | **mesire** | `mesire_kordinat` (18) **+** `kordinat` (15/22) | ⚠️ karışık — bir kısmı `null` dönüyordu |
  | muze | — | yayında kayıt yok |

  `Helpers::kordinatOf()` ile tipe özel anahtar önce denenip genel `kordinat`'a
  düşülüyor. (`/harita` ucu bu çözümü `CONCAT(p.type,'_kordinat')` ile zaten yapıyordu.)

### Önbellek

Özet temsil değiştiği için eski Redis kayıtları `filtre_ids` içermiyor. Anahtarlar
sürümlendi (temizlik gerekmez, eski kayıtlar kendiliğinden geçersiz):

`yer:v2:` · `mek:idx:v2:` · `mek:one:v2:` · `mek:pag:v2:` · `mek:yeni:v2:` ·
`mek:yakin:v2:` · `mek:arama:v2:` · `kat:mek:v2:` · `kat:show:v2:`

---

## 4) Doğrulama sonuçları

`php tools/filtre-ids-test.php` (canlı API + veritabanı karşılaştırmalı):

| # | Test | Sonuç |
|---|---|---|
| 1 | `/yerler?type=otopark` → `filtre_ids` var | ✅ 20/20 kayıt, alan eksik 0 |
| 2 | `/yerler?type=mesire` → `filtre_ids` var | ✅ 20/20, koordinatsız 0 |
| 3 | `/yerler?type=plaj` → `filtre_ids` var | ✅ 20/20 |
| 4 | `/mekanlar/4613` → `filtre_ids` var | ✅ `[140]` |
| 5 | Detay `filtreler` == liste `filtre_ids` (#4613) | ✅ `[140]` == `[140]` |
| 6 | otopark filtre 140 eşleşme üretiyor | ✅ 500/500 |
| 7 | plaj filtre 1457 eşleşme üretiyor | ✅ 32/80 |
| 8 | mesire filtre 25 eşleşme üretiyor | ✅ 8/22 |
| 9 | otopark 140: **API kümesi == DB kümesi** | ✅ ilk 300'de DB=300, API=300 |
| 10 | plaj 1457: API kümesi == DB kümesi | ✅ DB=32, API=32 |
| 11 | mesire 25: API kümesi == DB kümesi | ✅ DB=8, API=8 |
| 12 | `/arama` sonuçlarında `filtre_ids` var | ✅ eksik 0 |

**6. satır neden şaşırtıcı değil:** `/yerler` `p.id DESC` sıralı döner ve İSPARK
kayıtları en son toplu eklenmiş; en yeni 300 otoparkın tamamında `filtre_140='1'`.
Veritabanı ile birebir karşılaştırıldı (9. satır), hata değil.

---

## 5) Dokümandaki iki hata (düzeltildi)

| Yer | Yazan | Doğrusu |
|---|---|---|
| Bu dokümanın eski 2. bölümü | Detay ucu `filtreler: ["140:İspark"]` (metin dizisi) | Detay ucu **nesne dizisi** döndürür: `[{"id":140,"name":"İspark","slug":"i-spark","icon":"<svg…>"}]` |
| `KATEGORI_OZELLIK_FILTRE.md` | "`/mekanlar` ve `/yerler` özet listesinde `filtre_ids` yer almaz" | Artık **tüm** liste uçlarında yer alır — doküman güncellendi |
| `FILTRELER_TIP_BAZLI.md` (26 Ağu) | "Liste uçları her mekanda `filtre_ids` döndürür" | Artık **doğru** (o tarihte uygulanmamıştı) |

---

## 6) Değişen dosyalar

| Dosya | Değişiklik |
|---|---|
| `api/rest/src/Helpers.php` | `aktifFiltreIdleri()` + `kordinatOf()` eklendi |
| `api/rest/src/Controllers/MekanController.php` | `summary()`: `filtre_ids` eklendi, `kordinat` düzeltildi, 7 önbellek anahtarı sürümlendi |
| `api/rest/src/Controllers/KategoriController.php` | Kopya metot kaldırıldı, `Helpers` kullanıyor; 2 önbellek anahtarı sürümlendi |
| `api/rest/src/Controllers/AppFavoriController.php` | Kopya metot kaldırıldı, `Helpers` kullanıyor |
| `api/rest/KATEGORI_OZELLIK_FILTRE.md` | Alan kapsamı güncellendi |

### Yeni teşhis araçları (CLI, salt okunur)

| Araç | İş |
|---|---|
| `api/rest/tools/filtre-ids-test.php` | Kabul kriterlerini canlı API + DB karşılaştırmasıyla doğrular. `--dump-detay=<id>` ile tek mekanın ham alanlarını döker. |
| `api/rest/tools/meta-anahtarlari.php` | Bir tipte hangi metaların kullanıldığını / kaç kayıtta dolu olduğunu listeler (`--type=`, `--like=`, `--post=`). |

---

## 7) İstemci tarafı — alan parse'ı

`filtre_ids` zaten okunuyordu (alan yoksa `[]`):

- `ApiPlace.filterIds` → `filtre_ids` parse ediliyor.
- `_apiToPlace` → `Place.filterIds`'e taşıyor.

Ancak yalnız bu yeterli olmadı; sayfalı listede süzme sorunu için bkz. §8.
Filtre butonunu gizleme (geçici çözüm) gerekmedi, uygulanmadı.

---

## 8) İKİNCİ KÖK NEDEN — istemci tarafı süzme sayfalı listede çalışmıyor

> `filtre_ids` eklendikten sonra uygulamada **"Açık Otopark" hâlâ sonuç vermedi.**
> Sebep ayrı bir mimari sorun.

### Ölçüm

`php tools/meta-anahtarlari.php --type=otopark --dagilim=filtre_118`

```
yayindaki kayit         : 1602
aktif ('1') kayit       : 828
ILK eslesmenin sirasi   : 665      <-- listenin 665. kaydına kadar HİÇ eşleşme yok
ilk 20   kayitta        : 0 eslesme
ilk 100  kayitta        : 0 eslesme
ilk 300  kayitta        : 0 eslesme
ilk 500  kayitta        : 0 eslesme
```

`/yerler` `p.id DESC` sıralı sayfalanıyor. "Açık Otopark" kayıtları eski (küçük id'li)
olduğu için ilk 664 kayıtta hiç eşleşme yok. İstemci sayfa çekip AND uyguladığı için
ilk eşleşmeyi görmek üzere ~34 sayfa (limit 20) gezmesi gerekiyor; otomatik doldurma
(`_fillFilteredResults`) bundan önce durunca ekranda **"sonuç yok"** çıkıyor.

Karşılaştırma — aynı tipte filtre 140 (İspark) sorunsuz çalışıyordu:

```
ILK eslesmenin sirasi   : 1        <-- ilk sayfada zaten eşleşme var
```

Yani hata "bazı filtrelerde" görünüyordu; belirleyici olan filtrenin veri içindeki
konumu.

### Çözüm: sunucu tarafı filtreleme

`/yerler` ve `/mekanlar` artık `filtreler=` parametresini kabul ediyor — `/arama`
ucundaki sözleşmenin aynısı:

```
GET /yerler?type=otopark&filtreler=118          → total 828
GET /yerler?type=otopark&filtreler=119          → total 67
GET /yerler?type=otopark&filtreler=118,140      → total 0   (AND)
GET /yerler?type=plaj&filtreler=1457            → total 32
GET /mekanlar?type=restoran&filtreler=109,112
```

- Virgüllü id listesi, **AND** mantığı (hepsi aktif olmalı).
- Süzme SQL'de (`EXISTS`) yapılır → `total` ve `pages` **filtreli kümeye** ait olur,
  sayfalama doğru çalışır.
- `/mekanlar` Elasticsearch yolunda `filter.term.filtreler` olarak uygulanır; DB
  fallback'te aynı `EXISTS` koşulu kullanılır (iki yol aynı sonucu verir).
- Yanıtta `meta.filtreler` uygulanan filtreleri döndürür.
- Parametre verilmezse davranış **birebir eskisi gibi** (geriye dönük uyumlu).

### Uygulama tarafı ✅ tamam

`filtreler=` gönderimi eklendi. **Type modu** (otopark/mesire/plaj) sunucu
süzmesine geçti; **kategori modu** (`/kategoriler/{id}`, restoran) o uçta böyle bir
parametre olmadığı için istemci süzmesinde kaldı. Ayrım tek bir bayrakla yapılıyor:

```dart
bool get _serverFiltered => widget.type != null;
```

| Konu | Type modu (sunucu süzer) | Kategori modu (istemci süzer) |
|---|---|---|
| İstek | `/yerler?type=…&page=…&filtreler=118,140` | `/kategoriler/{id}?page=…` |
| `_matchesFilters` | atlanır (gelen kayıt zaten uygun) | AND uygular |
| `_fillFilteredResults` | çalışmaz (gereksiz) | çalışır |
| Sayaç | `meta.total` → "828 mekan (filtreli)" | görünen kayıt sayısı |
| Filtre değişimi | `_load()` → 1. sayfadan yeniden | mevcut kayıtlarda süz + sayfa doldur |

`_loadMore` de `filtreler=` gönderir, yani sonraki sayfalar filtreli kümeden gelir.

### Değişen istemci dosyaları

| Dosya | Değişiklik |
|---|---|
| `lib/data/api.dart` | `yerler(type, {page, limit, filtreler})` — virgüllü id listesi gönderiliyor |
| `lib/screens/category_screen.dart` | `_serverFiltered` bayrağı, `_onFilterChanged()`, `_load`/`_loadMore` filtre gönderimi, sayaç metni |

---

## 9) Doğrulama (canlı API)

`/yerler?filtreler=` uçtan uca doğrulandı — ilk sayfadaki kayıtların `filtre_ids`
alanı istenen filtreyi **birebir** içeriyor (uyumsuz = 0):

| İstek | total | pages | ilk sayfa | uyumsuz |
|---|---|---|---|---|
| `type=otopark` (filtresiz) | 1602 | 81 | 20 | 0 |
| `type=otopark&filtreler=118` | **828** | 42 | 20 | 0 |
| `type=otopark&filtreler=119` | 67 | 4 | 20 | 0 |
| `type=otopark&filtreler=118,140` | 0 | 0 | 0 | 0 (AND doğru) |
| `type=plaj&filtreler=1457` | 32 | 2 | 20 | 0 |
| `type=mesire&filtreler=25` | 8 | 1 | 8 | 0 |

`meta.filtreler` uygulanan id'leri doğru yansıtıyor. §8'deki "Açık Otopark → 828"
beklentisi karşılandı; eşleşmeler artık **ilk sayfada** geliyor (eskiden 665. kayıttan
sonra başlıyordu).

Kalan: cihazda görsel doğrulama (otopark → "Açık Otopark" → 828 mekan (filtreli)).
