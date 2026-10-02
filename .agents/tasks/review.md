# Venue özellikleri in search filters and the `/arama` request

The search modal now passes the venue özellikleri list (Teras, Bahçe, Şömine…, `type='ozellik'`) into the shared filter sheet, keeps a separate selection for each tab, and sends it to `/arama` as `ozellikler=<sorted CSV>` on both tabs and on every page. `aramaMekan`/`aramaYemek` take a new optional `List<int>? ozellikler`. It reuses the existing `filtreler` CSV contract through a new `idsCsv` helper and is part of the cache key. The app also reads an optional `eslesen_ozellikler` field from the response and shows an "Özellik: …" line on the result row. `ARAMA_OZELLIK_FILTRE.md` hands the server-side work to the backend team. The change follows the investigation report and plan closely, and `filter_sheet.dart` is unchanged.

Watch for: until the backend ships `ozellikler=`, the filter does nothing. The chip and the active filter button show a selection while the results stay unfiltered (likely). The working tree also has unrelated `is_plus` / Plus-marker edits from a parallel task, mixed into `api.dart` (confirmed).

**Verdict**: APPROVED

## High-level view

The app side copies the existing `filtreler` pattern almost exactly. Özellik selections are kept per tab (`_placeOzellikler`, `_foodOzellikler`), and both tabs share one cached list (`_allOzellikler`) taken from `/filtreler` `meta.ozellikler`. A single `_ensureFilterLists()` now replaces the two duplicated loaders. The özellik group only appears for the `mekan` search type, through `_visibleOzellikler`. Switching type clears both selections and the list. This matches the type mode of the category screen and the fact that `meta.ozellikler` is not filtered by type.

On the wire, the `ozellikler` param appears only when the selection is non-empty, so requests without a selection are the same as before. All four `/arama` call sites send it: the first page and the next pages, on both tabs. `routes_screen.dart` calls `aramaMekan(term, limit: 20)` and still compiles unchanged.

The handoff doc is Turkish and short. It covers the five backend items from the report (the `ozellikler=` param with AND semantics, text matching on özellik/filtre names that ignores Turkish case and accents, `ozellik_ids` in summaries, `meta.ozellikler` filtered by type, and the optional `/kategoriler`/`/yerler` param). It includes example URLs and JSON and has a §3 describing exactly what the app now sends. That section matches the code: the param name, the sorted CSV format, both tabs, pagination, mekan type only, and the `eslesen_ozellikler` label.

The only real gap is release sequencing. The feature looks active in the UI but does nothing until the backend lands.

<details>
<summary>Issues (2)</summary>

1. **Özellik filter is a silent no-op until the backend ships** (non-blocking, likely). Ship this app build after or together with the backend `ozellikler=` support, or accept that for a while selecting "Bahçe" shows a chip but unfiltered results.
2. **Unrelated Plus-marker changes in the same working tree** (non-blocking, confirmed). `api.dart` also carries `isPlus`/`parsePlusFlag` edits, and `place_flags.dart`, `app_theme.dart` and the generated plugin files changed too. When committing, stage this feature on its own, with hunk-level staging for `api.dart`.

</details>

<details><summary>Details</summary>

### Backend dependency and what the user sees meanwhile

The app adds no fallback filtering on its side. If `/arama` ignores `ozellikler`, the user selects Bahçe, sees a "Bahçe" chip and an active filter button, and gets the same unfiltered list (likely; the report says `/arama` does not support the param today and the live API could not be checked). The report and the user both chose "app sends, backend filters". Filtering on `place.ozellikIds` in the app is not a safe stopgap, because it is unverified whether `/arama` returns `ozellik_ids` at all, and filtering would empty the list if it doesn't. So the fix is about release order, not code. The `eslesen_ozellikler` label already does nothing when the field is missing.

### Evidence and a spot-check

`verification.md` records clean `flutter analyze` (whole project) and `flutter test` runs (6 tests, including the new `search_params_test.dart`). The PowerShell exit code 1 comes from the known geolocator_windows stderr noise. The new tests cover `idsCsv` and `matchedByOzellik`. The request and query-param paths in `aramaMekan`/`aramaYemek` are not tested, because the Dio singleton can't be mocked. The timestamps show `api.dart` was written after `verification.md`, by the parallel Plus-marker task. So I re-ran `flutter analyze` on the three touched Dart files only, and it reported `No issues found!`.

### Bundled working-tree changes

`git status` shows several changes outside this feature: `isPlus` on `ApiPlace` (field, cache round trip, `_parsePlace`), the new `lib/data/place_flags.dart`, two Plus colors in `app_theme.dart`, and geolocator_windows removed from the generated Windows plugin files. These come from `.agents/tasks/map-plus-marker/` and the earlier emulator run, not from this coder, and they are not reviewed here. They share `api.dart` with this feature, so committing that file as a whole would mix the two changes. No commits were made (`HEAD` is still `7cf02c3`).

</details>

<details>
<summary>File map</summary>

- `lib/data/api.dart`: `idsCsv` helper; `ozellikler` param and cache-key segment in `aramaMekan`/`aramaYemek`; `SearchResult.matchedOzellikler` + `matchedByOzellik` (also contains unrelated `isPlus` hunks).
- `lib/widgets/search_modal.dart`: özellik state, `_visibleOzellikler`, `_ensureFilterLists`, sheet wiring, the 4 API call sites, chips, filter-button active state, `_changeType` reset, "Özellik: …" result label.
- `test/search_params_test.dart` (new): `idsCsv` and `matchedByOzellik` tests.
- `ARAMA_OZELLIK_FILTRE.md` (new): Turkish backend handoff.
- Unrelated, not reviewed: `lib/theme/app_theme.dart`, `lib/data/place_flags.dart`, `linux/`, `macos/`, `windows/` generated plugin files.

Full diff: `git diff` + `git status` in `c:\Users\mail\dev\gezgah`.

</details>
