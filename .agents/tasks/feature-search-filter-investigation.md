# Arama ve filtrelerde mekan özellikleri — inceleme raporu

## Kısa cevap

Yalnızca backend yetmez, iki tarafta da iş var. App tarafı küçük ve iyi hazırlanmış durumda.

- Filtre bottom sheet'i (`lib/widgets/filter_sheet.dart`) "Özellikler" grubunu zaten destekliyor. Kategori listeleme ekranı bunu kullanıyor.
- Arama ekranı (`lib/widgets/search_modal.dart`) bu desteği kullanmıyor. Arama filtresinde yalnız `type='filtre'` öğeleri (Wifi, Otopark, Alkol…) çıkıyor. `type='ozellik'` öğeleri (Teras, Bahçe, Şömine, Fasıl…) hiç gösterilmiyor ve API'ye gönderilmiyor.
- Metin araması (`/arama?q=`) sunucuda yapılıyor. Dokümana göre yalnız mekan adı ve menü ürün adıyla eşleşiyor. "bahçe" yazınca bahçeli mekanların gelmesi tamamen backend işi.
- Backend kodu bu repoda yok. Dokümanlar PHP kodunun ayrı bir `api/rest/` reposunda olduğunu gösteriyor. Canlı API cihaz token'ı istiyor (401), o yüzden `/arama`'nın özellik parametresini bugün kabul edip etmediğini doğrulayamadım.

## 1) Arama ekranı ve filtre arayüzü

| Ne | Nerede |
|---|---|
| Arama modalı (tam ekran) | `lib/widgets/search_modal.dart` → `showSearchModal`, `_SearchType { mekan, mesire, otopark, plaj }` (satır ~22) |
| Ortak filtre sheet'i | `lib/widgets/filter_sheet.dart` → `showFilterSheet(filters, selected, ozellikler, selectedOzellikler)`, sonuç tipi `FilterResult = ({Set<int> filters, Set<int> ozellikler})` (satır 9-21) |
| Kategori/tip listeleme filtresi | `lib/screens/category_screen.dart` → `_openFilterSheet()` (satır ~343-361) |

Bugün arama ekranındaki filtreler:
- Mekanlar sekmesi: `_placeFilters` (satır ~112) ile seçilir. `_openPlaceFilter()` (satır ~548-574) `HomeRepository.instance.filtreler(type: _filterType)` çağırıyor ve dönen kayıttan yalnız `.filtreler`'i alıyor. `showFilterSheet(context, filters: _allFilters, selected: _placeFilters)` çağrısında `ozellikler` parametresi verilmiyor (satır ~562-563). Bu yüzden sheet'te "Özellikler" grubu çıkmıyor.
- Yemekler sekmesi: `_foodFilters` + `_openFoodFilter()` (satır ~521-546). Aynı durum, yalnız filtreler.
- Sıralama: `_mekanSort` / `_foodSort` (likes, distance, price_asc, price_desc).
- Tip seçici: `_changeType()` (satır ~745-751) tip değişince seçili filtreleri ve `_allFilters`'ı sıfırlıyor.
- Seçili filtre rozetleri: `_filterChips()` (satır ~845) yalnız `_allFilters` içinde arıyor, özellik rozeti göstermiyor.
- `_filterType` (satır ~518-520): `mekan` tipi için `/filtreler?type=restoran` kullanılıyor.

## 2) Arama nasıl çalışıyor: sunucu tarafında

Arama tamamen API üzerinden, istemcide süzme yok.

- `lib/data/api.dart` → `aramaMekan(...)` (satır ~1778-1868): `GET /arama`, parametreler `q`, `tab=mekan`, `page`, `limit`, `type`, `lat`, `lng`, `sort`, `filtreler` (virgüllü, sıralı id listesi), `user_id`. Önbellek anahtarında `filtreler` var, `ozellikler` yok.
- `aramaYemek(...)` (satır ~1871-1948): aynı uç, `tab=yemek`, `type` yok, `filtreler` var.
- Çağıran yer: `search_modal.dart` `_runMekan()` (satır ~256-272), `_runFood()` (satır ~299-315) ve sayfa devamı (satır ~347-358, ~377-387). Hepsi yalnız `filtreler: _placeFilters/_foodFilters` gönderiyor.
- `.readme/ARAMA.md`: eşleşme yalnız `yzd_posts.name` (mekan adı) ve `yzd_qr` ürün adları üzerinde `LIKE '%q%'`. Yanıttaki `eslesme` yalnız `"isim"` ve/veya `"menu"` olabilir. Özellik/filtre adıyla eşleşme yok. Doküman eski (yalnız `q/page/limit` anlatıyor). Kod daha yeni bir sözleşmeyi (`arama-yeni-3.md`, `ARAMA_TIP_BAZLI.md`) referans alıyor ama bu dosyalar bu repoda yok.
- `YERLER_FILTRE_IDS.md` §8, `/arama`'nın `filtreler=` parametresini (AND) kabul ettiğini doğruluyor. `ozellikler` benzeri bir parametreden söz etmiyor.

## 3) Model ve özellik verisi: hazır

- `lib/data/models.dart` `Place.ozellikIds` (satır ~27) var: mekanın özellik id'leri (`restoran_ozellik`).
- `lib/data/api.dart` `ApiPlace.ozellikIds` (satır ~938-941). `_parsePlace` ve diğer parse'lar `ozellik_ids` alanını okuyor (satır ~1414, ~2283, ~2480). Alan gelmezse `[]` oluyor. Arama sonuçları da `_parsePlace` ile parse ediliyor (satır ~1837). `/arama` yanıtının `ozellik_ids` içerip içermediğini doğrulayamadım.
- Detay: `PlaceDetail.ozellikler` (`List<OzellikItem>`, models.dart satır ~1262, `OzellikItem` satır ~1367). `detail_screen.dart`'ta "Olanaklar" bölümünde önce özellikler, sonra filtreler listeleniyor (satır ~582-585, ~1443-1448).
- Tüm özelliklerin listesi: ayrı bir uç yok ama `GET /filtreler?type=` yanıtında `meta.ozellikler` var. `api.dart` `filtreler()` (satır ~1449-1480) bunu `({filtreler, ozellikler})` olarak döndürüyor. Kod yorumuna göre (category_screen.dart satır ~145-147) `meta.ozellikler` tipe göre süzülmüyor ve restoran odaklı.

İki kavramı ayırmak gerekiyor (`.readme/MEKAN_DETAY.md` "Özellikler vs. Filtreler"):
- `filtreler` (`type='filtre'`, meta `filtre_{id}=1`): Otopark, Wifi, Alkol, Vale… Bunlar aramada zaten filtrelenebiliyor.
- `ozellikler` (`type='ozellik'`, meta `restoran_ozellik`): Teras, Bahçe, Şömine, Oyun Kafe, Fasıl… Bunlar aramada ne aranabiliyor ne filtrelenebiliyor.

## 4) Mevcut özellik filtresi gönderimi

- Arama: hiçbir yerde özellik parametresi gönderilmiyor. `aramaMekan`/`aramaYemek` imzasında `ozellikler` yok.
- Kategori modu (`/kategoriler/{id}`): özellik seçimi var (`_ozellikler`, `_selectedOzellikler`, satır ~61-63, ~195). Süzme istemcide yapılıyor (`_matchesFilters`, satır ~323-329, `p.ozellikIds` üzerinde AND). Sunucuya gönderilmiyor. Bu, `YERLER_FILTRE_IDS.md` §8'deki sayfalama sorununa açık: eşleşme listenin derinlerindeyse `_fillFilteredResults` (en fazla 5 ek sayfa) sonunda "sonuç yok" çıkabilir.
- Tip modu (`/yerler?type=`): özellik grubu bilerek gizli (`_ozellikler = const []`, satır ~170).
- UI: `filter_sheet.dart`'ta "Filtreler" / "Özellikler" grup başlıkları ve satırları hazır. Arama ekranı yalnızca `ozellikler` listesini vermiyor.

## 5) Backend konumu ve dokümanlar

- Bu repoda sunucu kodu yok, sadece Flutter. `c:\Users\mail\dev` altında da PHP backend bulunamadı (`gezgah_pro` de bir Flutter projesi).
- Base URL: `https://api.gezgah.com/rest`. Backend dosya yolları dokümanlarda `api/rest/src/Controllers/MekanController.php`, `api/rest/src/Helpers.php` vb. olarak geçiyor (`YERLER_FILTRE_IDS.md` §6).
- Dokümanlar: `.readme/*.md` (ARAMA, FILTRELER, MEKAN_DETAY, FLUTTER_API_GUIDE, SEARCH_PAGE_SETTINGS…) ve kökte `YERLER_FILTRE_IDS.md`. OpenAPI/Swagger yok, AGENTS.md yok.
- Kodda geçen `KATEGORI_OZELLIK_FILTRE.md`, `FILTRELER_TIP_BAZLI.md`, `ARAMA_TIP_BAZLI.md`, `arama-yeni-3.md` bu repoda yok, backend reposunda olmalı.
- Canlı doğrulama: `GET /filtreler?type=restoran` cihaz token'sız 401 döndü. Token almak canlıda cihaz kaydı oluşturacağı için denemedim. Bu yüzden `/arama`'nın özellik parametresi veya özellik adıyla eşleşme desteği doğrulanmadı. Mevcut dokümanlara göre ikisi de yok.

## 6) Sonuç: yapılacaklar

### Backend (zorunlu, bu repo dışında)

1. `/arama` (hem `tab=mekan` hem `tab=yemek`) için `ozellikler=<virgüllü id>` parametresi. `filtreler=` ile aynı sözleşme olmalı: AND mantığı, SQL'de `EXISTS` ile `restoran_ozellik` üzerinde süzme (ES yolu varsa orada da). `total`/`pages` filtreli kümeye ait olmalı, `meta.ozellikler` uygulananları döndürmeli.
2. `/arama?q=` metin eşleşmesine özellik adları (`type='ozellik'`) ve filtre adları (`type='filtre'`) eklenmeli. Örneğin "bahçe" yazınca Bahçe özelliği olan mekanlar gelmeli. Yanıtta `eslesme` içinde `"ozellik"` değeri ve isteğe bağlı `eslesen_ozellikler: ["Bahçe"]` dönmeli. Türkçe karakter/harf duyarsızlığı (ç/c, ş/s, İ/i) burada önemli.
3. `/arama` özet kayıtlarında `ozellik_ids` dönmeli. `filtre_ids` `MekanController::summary()` ile geliyor, `ozellik_ids`'in de aynı yerden geldiği doğrulanmalı.
4. `/filtreler?type=` yanıtında `meta.ozellikler` tipe göre süzülmeli. Plaj/mesire/otopark için anlamlı özellik yoksa boş dönmeli. Bu, app'te tip modunda özelliklerin gizlenmesini gereksiz kılar.
5. Önerilir: `/kategoriler/{id}` (ve `/yerler`) için de `ozellikler=` parametresi. Böylece kategori ekranındaki istemci tarafı süzmenin sayfalama sorunu kalkar.

Parametre adı olarak `filtreler=` ile simetrik olduğu için `ozellikler=` öneriyorum. Bu, backend ile netleştirilmesi gereken bir sözleşme.

### Frontend (bu repo)

1. `lib/data/api.dart`: `aramaMekan` ve `aramaYemek`'e `List<int>? ozellikler` parametresi eklenmeli. Sorguya `if (oq.isNotEmpty) 'ozellikler': oq` girmeli ve önbellek anahtarına (`_mekanCache` / `_yemekCache` key) eklenmeli. İsteğe bağlı: `SearchResult`'a `eslesen_ozellikler` parse'ı ve `matchedByOzellik` getter'ı.
2. `lib/widgets/search_modal.dart`:
   - `_allOzellikler`, `_placeOzellikler`, `_foodOzellikler` state'leri eklenmeli.
   - `_openPlaceFilter` / `_openFoodFilter` içinde `filtreler()` sonucunun `.ozellikler`'i de saklanmalı. `showFilterSheet`'e `ozellikler:` ve `selectedOzellikler:` verilmeli, sonuçtaki `result.ozellikler` uygulanmalı.
   - `_runMekan`/`_runFood` ve iki sayfa-devamı çağrısında `ozellikler:` gönderilmeli.
   - `_filterChips` özellik rozetlerini de göstermeli ve kaldırabilmeli (category_screen'deki `_selectedChips` kalıbı, satır ~742-770).
   - Filtre butonunun aktiflik durumu (`_sfBtn(active: …)`) özellik seçimini de kapsamalı.
   - `_changeType` özellik seçimini de temizlemeli. Backend özellikleri tipe göre süzmedikçe `mekan` dışındaki tiplerde özellik grubu gizlenmeli (category_screen'deki gibi).
   - İsteğe bağlı: `_resultTile`'da (satır ~1196, "Menü: …" satırının yanında) "Özellik: Bahçe" eşleşme etiketi.
3. `lib/widgets/filter_sheet.dart`: değişiklik gerekmiyor.
4. İsteğe bağlı: `lib/screens/category_screen.dart`'ta backend 5. maddeyi yaparsa kategori modunda `ozellikler=` sunucuya gönderilip istemci süzmesi kaldırılabilir (`_serverFiltered` mantığının genişletilmesi).

Not: Metin aramasında özellik adlarıyla eşleşme (backend 2. madde) için app'te ek iş yok. `q` zaten olduğu gibi gönderiliyor. Sadece eşleşme etiketini göstermek isteğe bağlı.

### Kapsam tahmini

- Zorunlu app değişikliği: 2 dosya (`lib/data/api.dart`, `lib/widgets/search_modal.dart`). Yaklaşık 60-120 satır, mevcut `filtreler` kalıbının kopyası.
- İsteğe bağlı: `lib/screens/category_screen.dart` (sunucu süzmesi), `SearchResult` eşleşme etiketi.
- Doğrulama: `flutter analyze` ve `flutter test`. Şu an yalnız `test/widget_test.dart` var, arama için test yok. Uçtan uca doğrulama için backend `ozellikler=` desteği yayında olmalı ve emülatörde Arama → Mekanlar → Filtrele → "Özellikler" grubu → seçim → sonuç listesi denenmeli.
- Sıra: önce backend sözleşmesi (parametre adı + `eslesme` değeri). App değişikliği paralel yapılabilir. Parametre sunucu tarafından yok sayılırsa liste filtrelenmeden gelir, yani geriye dönük uyumlu.
