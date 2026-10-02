# Verification — aramada mekan özellikleri

Iteration 1 (review.json yoktu). Hepsi `c:\Users\mail\dev\gezgah` içinde çalıştırıldı. Commit yapılmadı.

## Komutlar ve sonuçlar

| Komut | Sonuç |
|---|---|
| `flutter analyze` (tüm proje) | `No issues found! (ran in 13.4s)`. PowerShell exit code 1, sebebi bilinen geolocator_windows stderr gürültüsü (plan.md'de not edilmiş); issue yok. |
| `flutter test` (tüm testler) | `00:02 +6: All tests passed!` — `test/search_params_test.dart` 5 test + `test/widget_test.dart` 1 test. Exit code 1 yine aynı stderr gürültüsünden. |
| `ARAMA_OZELLIK_FILTRE.md` UTF-8 kontrolü (`[Text.Encoding]::UTF8.GetString(...).Contains("Şömine")`) | `True` |
| `Select-String lib/widgets/search_modal.dart "ozellikler: _(place\|food)Ozellikler"` | 6 eşleşme = 4 API çağrısı (`_runMekan`, `_loadMorePlaces`, `_runFood`, `_loadMoreFoods`) + 2 `selectedOzellikler:` (iki sheet çağrısı) |

## Değişen / eklenen dosyalar

- `lib/data/api.dart`: top-level `idsCsv()`; `SearchResult.matchedOzellikler` (`eslesen_ozellikler`, yoksa `const []`) + `matchedByOzellik`; `aramaMekan`/`aramaYemek`'e `List<int>? ozellikler`, `if (oq.isNotEmpty) 'ozellikler': oq`, cache key'lerine `$oq`.
- `lib/widgets/search_modal.dart`: `_placeOzellikler`/`_foodOzellikler`/`_allOzellikler` state; `_visibleOzellikler` (yalnız `_SearchType.mekan`); `_ensureFilterLists()`; iki filter sheet'e özellik grubu ve sonuç uygulama; 4 API çağrısında `ozellikler:`; `_filterChips(filters, ozellikler, onChanged)` özellik rozetleri; filtre butonu aktifliği özellikleri kapsıyor; `_changeType` özellik state'ini sıfırlıyor; `_resultTile`'da "Özellik: …" etiketi.
- `test/search_params_test.dart` (yeni): `idsCsv` ve `SearchResult.matchedByOzellik` testleri.
- `ARAMA_OZELLIK_FILTRE.md` (yeni, kök): backend devir dokümanı.
- `lib/widgets/filter_sheet.dart`: değişmedi.

Not: `git status`'ta görünen `linux/`, `macos/`, `windows/` generated plugin dosyaları bu iş kapsamında elle değiştirilmedi (flutter pub get / önceki emülatör çalıştırması kaynaklı).

## Kod yolu incelemesi (uçtan uca test yapılamadı: canlı API cihaz token'ı istiyor)

- Özellik seçimi yoksa `idsCsv` `''` döner → `ozellikler` parametresi gönderilmez; istek parametreleri eskisiyle aynı.
- Seçim varsa sıralı virgüllü id dört `/arama` çağrısının hepsinde gider (ilk sayfa + sayfa devamı, iki sekme).
- Cache key'leri `$oq` içeriyor → farklı özellik seçimi farklı cache girdisi.
- Mesire/otopark/plaj: `_visibleOzellikler` boş → sheet'te "Özellikler" grubu ve özellik rozeti yok; tip değişimi seçimi temizlediği için bu tiplerde parametre gitmez.
- `_ensureFilterLists` ilk açılışta `filtreler()` sonucundan hem filtre hem özellik listesini alır; `_changeType` iki listeyi de sıfırlar → yeni tip için tekrar çekilir.
- `routes_screen.dart` `aramaMekan(term, limit: 20)` çağrısı değişmeden derleniyor (yeni parametre opsiyonel; analyzer temiz).
- Backend `ozellikler`'i yok sayarsa liste süzülmeden gelir; `eslesen_ozellikler` yoksa etiket görünmez.
