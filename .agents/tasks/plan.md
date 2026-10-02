# Implementation Plan — Aramada mekan özellikleri (arama + filtre) ve backend devir dokümanı

Çalışma dizini: `c:\Users\mail\dev\gezgah` (worktree YOK, doğrudan bu dizin). Hiçbir şey commit edilmez.
Kaynak rapor: `c:\Users\mail\dev\gezgah\.agents\tasks\feature-search-filter-investigation.md`.

## Kararlar (kısa gerekçe)

- D1. Parametre adı `ozellikler`, format `filtreler` ile aynı: sıralı, virgüllü id listesi (`3,12,40`), yalnız boş değilse gönderilir. Mevcut `filtreler=` sözleşmesiyle simetrik; backend yok sayarsa liste filtresiz gelir (geriye dönük uyumlu).
- D2. `lib/widgets/filter_sheet.dart` değişmez. `showFilterSheet(..., ozellikler:, selectedOzellikler:)` zaten iki grubu destekliyor.
- D3. Özellik grubu yalnız `_SearchType.mekan` tipinde gösterilir (mesire/otopark/plaj'da gizli). `/filtreler` `meta.ozellikler` tipe göre süzülmüyor ve restoran odaklı; `category_screen.dart` tip modunda da aynı şekilde gizliyor (`_ozellikler = const []`, ~satır 170). Yemekler sekmesi zaten yalnız `mekan` tipinde var, dolayısıyla iki sekme de özellik seçebilir.
- D4. Özellik listesi ayrı uçtan değil, mevcut `HomeRepository.instance.filtreler(type: _filterType)` sonucunun `.ozellikler` alanından gelir; iki sekme `_allFilters` gibi tek bir `_allOzellikler` önbelleğini paylaşır. Seçimler sekme başına ayrı: `_placeOzellikler`, `_foodOzellikler` (mevcut `_placeFilters`/`_foodFilters` kalıbı).
- D5. Virgüllü id üretimi için `api.dart`'a küçük bir top-level `String idsCsv(Iterable<int>? ids)` yardımcı eklenir ve yalnız `aramaMekan`/`aramaYemek` içinde hem `filtreler` hem `ozellikler` için kullanılır (`yerler()` vb. dokunulmaz). Böylece 4 kopya yerine tek kod yolu olur ve birim testi yazılabilir (Dio singleton'u mock'lanamadığı için tek test edilebilir parça bu).
- D6. `SearchResult`'a `matchedOzellikler` (`eslesen_ozellikler`) alanı ve `matchedByOzellik` getter'ı eklenir; alan yoksa `const []`. Sonuç satırında "Menü: …" satırının altına aynı stilde "Özellik: Bahçe, Teras" etiketi gösterilir (yalnız liste doluysa). Backend henüz göndermiyorsa hiçbir şey görünmez.
- D7. Feature decomposition yapılmadı: iş küçük (2 Dart dosyası + 1 test + 1 md); mevcut implement/review döngüsü bu planı uygular.

## Bilinen ortam notları

- `flutter analyze` geolocator_windows ile ilgili stderr uyarıları basar ve PowerShell'de exit code 1 görünebilir; bu gürültüdür. Önemli olan son satır: `No issues found!` ya da listelenen issue'lar. Başlangıç durumu: `flutter analyze lib/data/api.dart lib/widgets/search_modal.dart` → `No issues found!` (bu planlama sırasında çalıştırıldı). Değişiklikten sonra da aynı olmalı.
- Canlı API cihaz token'ı ister (401). Uçtan uca doğrulama yapılamaz; doğrulama = analyzer + testler + kod yolu incelemesi.
- Mevcut testler: yalnız `c:\Users\mail\dev\gezgah\test\widget_test.dart`.

---

- [ ] 1. `api.dart`: `idsCsv` yardımcı, `aramaMekan`/`aramaYemek`'e `ozellikler` parametresi, `SearchResult.matchedOzellikler`.
      Dosya: `c:\Users\mail\dev\gezgah\lib\data\api.dart`
      a) Dosyada `class SearchResult` (~satır 1045) öncesine top-level ekle:
      ```dart
      /// Id listesini API'nin beklediği biçime çevirir: sıralı, virgüllü
      /// (`3,12,40`). Boş/null → '' (parametre hiç gönderilmez).
      String idsCsv(Iterable<int>? ids) {
        if (ids == null || ids.isEmpty) return '';
        return (ids.toList()..sort()).join(',');
      }
      ```
      b) `SearchResult`: `final List<String> matchedOzellikler; // eslesen_ozellikler (ad listesi)` alanı, constructor'da `this.matchedOzellikler = const []`, `matchTypes` yorumunu `// eslesme: "isim" | "menu" | "ozellik"` yap, getter ekle: `bool get matchedByOzellik => matchTypes.contains('ozellik') || matchedOzellikler.isNotEmpty;`
      c) `aramaMekan(...)` (~1778): imzaya `List<int>? ozellikler,` ekle (`filtreler`'in hemen altına). `final fq = ...` bloğunu `final fq = idsCsv(filtreler);` ile değiştir, altına `final oq = idsCsv(ozellikler);`. Önbellek anahtarı: `'$term|$page|$limit|${sort ?? ''}|$fq|$oq|${_coordKey(lat, lng)}|${type ?? ''}'`. `queryParameters`'a `if (fq.isNotEmpty) 'filtreler': fq,` satırının hemen altına `if (oq.isNotEmpty) 'ozellikler': oq,`. `SearchResult(...)` oluşturulan map içinde `matchTypes`'tan sonra:
      ```dart
      matchedOzellikler:
          (j['eslesen_ozellikler'] as List<dynamic>?)
              ?.whereType<String>()
              .toList() ??
          const [],
      ```
      (`as List<dynamic>?` mevcut `eslesen_urunler` kalıbıyla aynı; alan yoksa null → `const []`.)
      d) `aramaYemek(...)` (~1871): aynı şekilde `List<int>? ozellikler,` parametresi, `fq = idsCsv(filtreler)`, `oq = idsCsv(ozellikler)`, anahtar `'$term|$page|$limit|${sort ?? ''}|$fq|$oq|${_coordKey(lat, lng)}'`, sorguya `if (oq.isNotEmpty) 'ozellikler': oq,`.
      e) Doc yorumlarına (aramaMekan/aramaYemek üstü) bir satır ekle: `[ozellikler]` verilirse `ozellikler=` (virgüllü id, AND) gönderilir; sunucu desteklemiyorsa yok sayılır (ARAMA_OZELLIK_FILTRE.md).
      Geriye uyum: tüm yeni parametreler opsiyonel; `routes_screen.dart` (~2467 `aramaMekan(term, limit: 20)`) değişmeden derlenir. `ozellikler` boşken istek URL'i ve davranış eskisinin aynısı (anahtarda sadece fazladan boş `|` segmenti var, bellek içi önbellek olduğu için sorun değil).
      Verify: `flutter analyze lib/data/api.dart lib/screens/routes_screen.dart` (cwd `c:\Users\mail\dev\gezgah`) → `No issues found!`.

- [ ] 2. Birim testi ekle (adım 1'e bağlı).
      Dosya (yeni): `c:\Users\mail\dev\gezgah\test\search_params_test.dart`
      `import 'package:flutter_test/flutter_test.dart';` + `import 'package:gezgah/data/api.dart';`. Testler:
      - `idsCsv(null)` ve `idsCsv(const [])` → `''`
      - `idsCsv([40, 3, 12])` → `'3,12,40'`; `idsCsv({7})` (Set) → `'7'`
      - `SearchResult(place: <ApiPlace>, matchTypes: ['ozellik']).matchedByOzellik` → true; `matchedOzellikler: ['Bahçe']` → true; varsayılan → false ve `matchedOzellikler` boş.
      `ApiPlace` örneği: `const ApiPlace(id: 1, name: 'Test', image: '')` (constructor ~satır 953; required alanlar yalnız `id`, `name`, `image`).
      Verify: `flutter test test/search_params_test.dart` → tüm testler geçer.

- [ ] 3. `search_modal.dart`: özellik state'i, filtre sheet'ine özellik grubu, API'ye gönderim, rozetler, buton aktifliği, tip değişimi, eşleşme etiketi (adım 1'e bağlı).
      Dosya: `c:\Users\mail\dev\gezgah\lib\widgets\search_modal.dart`
      a) State (~satır 110-112, `_placeFilters`/`_allFilters` yanına):
      ```dart
      final Set<int> _foodOzellikler = {}; // seçili özellik id'leri (yemek)
      final Set<int> _placeOzellikler = {}; // seçili özellik id'leri (mekan)
      List<Filter> _allOzellikler = const []; // /filtreler meta.ozellikler
      ```
      Ve `_filterType` getter'ının yanına:
      ```dart
      /// Özellikler (Teras, Bahçe…) restoran odaklıdır ve `/filtreler`
      /// `meta.ozellikler` tipe göre süzülmez → yalnız `mekan` tipinde gösterilir
      /// (kategori ekranındaki tip modu davranışıyla aynı).
      List<Filter> get _visibleOzellikler =>
          _type == _SearchType.mekan ? _allOzellikler : const [];
      ```
      b) Yeni yardımcı `_ensureFilterLists()` (`_openFoodFilter` üstüne) — iki open metodundaki kopya yükleme bloğunun yerine:
      ```dart
      /// Filtre + özellik listelerini (tip bazlı) bir kez çeker.
      Future<void> _ensureFilterLists() async {
        if (_allFilters.isNotEmpty || _allOzellikler.isNotEmpty) return;
        final f = await HomeRepository.instance.filtreler(type: _filterType);
        _allFilters = f.filtreler;
        _allOzellikler = f.ozellikler;
      }
      ```
      Not: tip değişimi sırasında yarış olmaması için mevcut davranış korunur (mevcut kod da await sonrası atama yapıyor); ek koruma gerekmez.
      c) `_openFoodFilter()` ve `_openPlaceFilter()`: yükleme bloğunu `await _ensureFilterLists();` yap. Boşluk kontrolü `if (_allFilters.isEmpty && _visibleOzellikler.isEmpty)` olsun (snackbar metni aynı: 'Filtre bulunamadı'). Sheet çağrısı:
      ```dart
      final result = await showFilterSheet(context,
          filters: _allFilters,
          selected: _placeFilters,            // food: _foodFilters
          ozellikler: _visibleOzellikler,
          selectedOzellikler: _placeOzellikler); // food: _foodOzellikler
      ```
      Sonuç uygulamada filtrelere ek olarak `_placeOzellikler..clear()..addAll(result.ozellikler)` (food için `_foodOzellikler`), sonra mevcut `_runMekan`/`_runFood` tetiklemesi aynen.
      d) API çağrıları — 4 yer, `filtreler:` satırının hemen altına:
      - `_runMekan()` (~256) ve `_loadMorePlaces()` (~347): `ozellikler: _placeOzellikler.toList(),`
      - `_runFood()` (~299) ve `_loadMoreFoods()` (~377): `ozellikler: _foodOzellikler.toList(),`
      e) `_filterChips` (~845): imzayı `Widget _filterChips(Set<int> filters, Set<int> ozellikler, VoidCallback onChanged)` yap. `category_screen.dart` `_selectedChips()` (~742-770) kalıbıyla `({int id, String name, bool ozellik})` kayıt listesi kur: önce `_allFilters` içinden `filters.contains`, sonra `_visibleOzellikler` içinden `ozellikler.contains`. Liste boşsa `SizedBox.shrink()`. Mevcut erken çıkış (`selected.isEmpty || _allFilters.isEmpty`) kaldırılır, çünkü liste boşluğu kontrolü yeter. Rozet görünümü (Container/Row/Text/AppSvgIcon xmark, padding `fromLTRB(20, 0, 20, 8)`) birebir korunur; `onTap`: `setState(() => c.ozellik ? ozellikler.remove(c.id) : filters.remove(c.id)); onChanged();` (if/else ile yaz, `setState` callback'i bool döndürmesin).
      Çağıranlar:
      - `_placesTab()`: `_filterChips(_placeFilters, _placeOzellikler, () { final term = _query.trim(); if (term.length >= 2) _runMekan(term); })`
      - `_foodsTab()`: `_filterChips(_foodFilters, _foodOzellikler, () { ... _runFood(term); })`
      Doc yorumunu "Seçili filtre ve özellikleri…" olarak güncelle.
      f) Filtre butonu aktifliği: `_placeToolbar()` → `active: _placeFilters.isNotEmpty || _placeOzellikler.isNotEmpty`; `_foodToolbar()` → `active: _foodFilters.isNotEmpty || _foodOzellikler.isNotEmpty`.
      g) `_changeType()` (~745): `setState` içinde `_placeOzellikler.clear(); _foodOzellikler.clear(); _allOzellikler = const [];` ekle (mevcut `_placeFilters.clear()` vb. yanına). Doc yorumuna "ve özellikler" ekle.
      h) `_resultTile()` (~1196): `if (r.matchedProducts.isNotEmpty) ...[...]` bloğunun hemen altına aynı stil/yapıda:
      ```dart
      if (r.matchedOzellikler.isNotEmpty) ...[
        const SizedBox(height: 4),
        Text('Özellik: ${r.matchedOzellikler.take(3).join(', ')}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppColors.primary)),
      ],
      ```
      Tüm yeni kullanıcı metinleri Türkçe ('Özellik: …'); sheet'teki 'Filtreler'/'Özellikler' başlıkları zaten filter_sheet.dart'ta.
      Verify: `flutter analyze lib/widgets/search_modal.dart lib/data/api.dart` → `No issues found!`. Kod yolu kontrolü: 4 `aramaMekan`/`aramaYemek` çağrısının hepsinde `ozellikler:` var; `_changeType` üç özellik state'ini sıfırlıyor; mesire/otopark/plaj'da `_visibleOzellikler` boş olduğundan sheet'te "Özellikler" grubu ve özellik rozeti çıkmaz.

- [ ] 4. Backend devir dokümanını yaz (adımlardan bağımsız; adım 1/3'teki gerçek parametre adı/formatıyla tutarlı olmalı).
      Dosya (yeni): `c:\Users\mail\dev\gezgah\ARAMA_OZELLIK_FILTRE.md` — UTF-8, Türkçe, PHP backend ekibine yönelik, kısa. Stil referansı: kökteki `c:\Users\mail\dev\gezgah\YERLER_FILTRE_IDS.md` (§8 aynı `filtreler=` sözleşmesini anlatıyor: virgüllü id, AND, SQL `EXISTS`, `/mekanlar` ES yolunda `filter.term.filtreler`, `meta.filtreler` uygulananları döner, parametre yoksa davranış aynı). Bölümler:
      1. Amaç (2-3 cümle): Uygulamada arama ekranında ve filtrelerde mekan özellikleri (Teras, Bahçe, Şömine, Fasıl…) aranabilmeli ve filtrelenebilmeli. Base URL `https://api.gezgah.com/rest`; ilgili kod `api/rest/` (ör. `src/Controllers/...`, `src/Helpers.php`, `MekanController::summary()`).
      2. Filtre vs. özellik: tablo — `filtreler`: `type='filtre'`, meta `filtre_{id}=1`, örn. Wifi/Otopark/Alkol/Vale, yanıt alanı `filtre_ids`, aramada bugün `filtreler=` ile süzülüyor. `ozellikler`: `type='ozellik'`, meta `restoran_ozellik`, örn. Teras/Bahçe/Şömine/Oyun Kafe/Fasıl, yanıt alanı `ozellik_ids`, aramada bugün ne aranıyor ne süzülüyor.
      3. Uygulamanın artık gönderdiği (bu sürümden itibaren): parametre `ozellikler`, değer sıralı virgüllü id (`ozellikler=3,12`), yalnız kullanıcı en az bir özellik seçtiyse; `GET /arama` hem `tab=mekan` hem `tab=yemek`, ilk sayfa ve sonraki sayfalar (`page=`) dahil; `filtreler=` ile birlikte gelebilir; yalnız `type=mekan` (veya type yok) iken gönderilir, plaj/mesire/otopark'ta özellik seçimi gösterilmiyor. Özellik listesi `GET /filtreler?type=restoran` → `meta.ozellikler`'den alınıyor. Parametre yok sayılırsa uygulama bozulmaz, sadece süzülmemiş liste görünür. Ayrıca uygulama yanıttaki `eslesen_ozellikler` dizisini okuyup sonuç satırında "Özellik: Bahçe" gösteriyor; alan yoksa hiçbir şey göstermiyor.
      4. Gerekli backend değişiklikleri (numaralı, her biri kabul kriteriyle):
         (1) `/arama` `ozellikler=` — tab=mekan ve tab=yemek; AND (seçilen tüm özellikler mekanda olmalı); SQL'de `restoran_ozellik` üzerinde `EXISTS` (filtreler ile aynı yerde, ES yolu varsa orada da aynı terim süzmesi, iki yol aynı sonucu vermeli); `total`/`pages` filtreli kümeye ait; `meta.ozellikler` uygulanan id'leri döner; parametre yok/boş/geçersizse davranış aynı. tab=yemek'te süzme ürünün ait olduğu mekanın özelliklerine göre. Örnek istekler: `GET /arama?q=kahve&tab=mekan&type=mekan&page=1&limit=20&ozellikler=12`, `GET /arama?q=kahve&tab=mekan&filtreler=109&ozellikler=12,40` (AND), `GET /arama?q=pizza&tab=yemek&ozellikler=12&page=2`. Örnek `meta` JSON: `{"page":1,"limit":20,"total":37,"pages":2,"filtreler":[109],"ozellikler":[12,40]}`.
         (2) `/arama?q=` metin eşleşmesi özellik adlarında (ve filtre adlarında) da yapılmalı: "bahçe" → Bahçe özelliği olan mekanlar. Türkçe büyük/küçük harf ve aksan duyarsız (ç/c, ş/s, ı/i, İ/i, ğ/g, ö/o, ü/u): `bahce`, `BAHÇE`, `Bahçe` aynı sonucu; `somine` → Şömine; `fasil` → Fasıl. Not: MySQL `utf8mb4_*_ci` collation'ları ı/i'yi eşitlemez; q'yu ve adları PHP'de aynı normalize fonksiyonundan geçirmek (mb_strtolower + harf haritası) ya da normalize edilmiş bir arama kolonu önerilir. Yanıtta `eslesme` dizisine `"ozellik"` (filtre adı eşleşmesinde `"filtre"`) eklenmeli ve `eslesen_ozellikler: ["Bahçe"]` (görünen ad, orijinal yazım) dönmeli. İsim eşleşmesi sıralamada önde kalmalı (öneri). Örnek kayıt JSON: `{"id":123,"name":"…","sehir":"…","ilce":"…","filtre_ids":[109],"ozellik_ids":[12,40],"eslesme":["ozellik"],"eslesen_urunler":[],"eslesen_ozellikler":["Bahçe"],"mesafe_m":850}`.
         (3) `/arama` özet kayıtlarında `ozellik_ids` (int dizisi) dönmeli (`filtre_ids` ile aynı yerden, `MekanController::summary()`); tab=yemek'te `mekan` nesnesinde de.
         (4) `GET /filtreler?type=` → `meta.ozellikler` tipe göre süzülmeli; plaj/mesire/otopark'ta anlamlı özellik yoksa `[]`. Örnek: `GET /filtreler?type=restoran` → `meta.ozellikler: [{"id":12,"name":"Bahçe","slug":"bahce","icon":"<svg…>"}]`; `GET /filtreler?type=plaj` → `meta.ozellikler: []`. (Bu yapılınca uygulama diğer tiplerde de özellik grubunu açabilir.)
         (5) Önerilir: `/kategoriler/{id}` ve `/yerler` için de `ozellikler=` (aynı sözleşme). Gerekçe: kategori ekranı bugün özellikleri istemcide, yalnız yüklenen sayfalarda süzüyor; eşleşmeler listenin derinlerindeyse en fazla 5 ek sayfa sonra "sonuç yok" çıkabiliyor (YERLER_FILTRE_IDS.md §8'deki sorunun aynısı). Örnek: `GET /kategoriler/45?page=1&limit=20&ozellikler=12`.
      5. Kısa doğrulama listesi (backend için): ozellikler=X ile dönen her kaydın `ozellik_ids`'i X'i içeriyor (uyumsuz = 0); iki id AND; `total` filtresiz totalden küçük/eşit; `q=bahce` Bahçe'li mekanları getiriyor ve `eslesme` içinde `ozellik` var; parametresiz istek eskisiyle birebir aynı.
      6. Açık konu: parametre adı (`ozellikler`) ve `eslesme` değeri (`"ozellik"`) sözleşmedir; değiştirilecekse uygulama ekibine bildirilmeli.
      Örnek id'ler (12, 40, 109, 45, 123) temsili olduğunu bir notla belirt. Dolgu yok; YERLER_FILTRE_IDS.md'deki gibi başlık + kısa madde + kod bloğu.
      Verify: dosya `c:\Users\mail\dev\gezgah\ARAMA_OZELLIK_FILTRE.md` UTF-8 açılıyor (Türkçe karakterler bozuk değil: `Get-Content -Encoding UTF8` ile kontrol); bölüm 3'teki parametre adı/formatı adım 1'deki koda (`'ozellikler': oq`, `idsCsv`) ve gönderim yerlerine (adım 3d) birebir uyuyor.

- [ ] 5. Son doğrulama (tüm adımlara bağlı).
      Komutlar (cwd `c:\Users\mail\dev\gezgah`):
      - `flutter analyze` → dokunulan dosyalarda (`lib/data/api.dart`, `lib/widgets/search_modal.dart`, `test/search_params_test.dart`) yeni error/warning/info yok. Proje genelinde önceden var olan issue'lar varsa bunlar dışında yeni issue çıkmamalı.
      - `flutter test` → `widget_test.dart` ve `search_params_test.dart` geçer.
      Kod yolu incelemesi (end-to-end mümkün değil, API cihaz token'ı istiyor): `ozellikler` boşken `/arama` istek parametreleri değişmemiş; seçiliyken `ozellikler=<sıralı id>` 4 çağrının hepsinde gidiyor; önbellek anahtarı özellik seçimine göre ayrışıyor; mesire/otopark/plaj'da özellik grubu ve rozeti yok; tip değişince özellik seçimi temizleniyor.
      Geçici dosya bırakma; commit yapma.
