# Implementation Plan — Haritada Plus işletmeler için turuncu marker

## Findings (from exploration)

- Map screen: `lib/screens/map_screen.dart`. Markers are built in `_rebuildMarkers()` →
  `_markerIcon(IconData, bool active)` (cache `Map<String, BitmapDescriptor> _iconCache`,
  key `'${icon.codePoint}_$active'`) → `_buildPin(icon, active)`: canvas-drawn round pin
  (shadow, white border `3*ratio`, inner circle `AppColors.primary` / `AppColors.primary2`
  when selected, white Material glyph from `_iconForPlace(p)`), `BitmapDescriptor.bytes`,
  `imagePixelRatio: 3`. No clustering; visible-region subset capped at `_maxMarkers = 220`.
  `zIndexInt: isSel ? 2 : 1`. (`route_map_screen.dart` has its own numbered pins — out of scope.)
- Data: `HomeRepository.harita({kategori, type})` in `lib/data/api.dart` → `GET /harita`
  → `_parsePlace(Map)` → `ApiPlace` (class in `lib/data/api.dart`, not models.dart).
  `ApiPlace` is also cached via `toCacheJson()` / `ApiPlace.fromCache()`. `_parsePlace` is
  shared by every list endpoint, so a new field parsed there flows everywhere for free.
- Plus flag: does NOT exist on places. `.readme/HARITA.md` documents `/harita` `data[]`
  fields (id, type, slug, name, thumbnail, image, telefon, bolge, sehir, ilce, kordinat,
  enlem, boylam, adres, harita_ikon, kategori_ids, goruntulenme) — no plus/premium flag.
  The only per-business "Plus" signal in the app is `RezervasyonSecenekler.aktif` from
  `GET /rezervasyon/secenekler?mekan_id=` (models.dart: "aktif false ise işletme Gezgah Plus
  değildir"), fetched one place at a time on the detail screen — unusable for hundreds of
  markers. `AppUser.isPlus` / `PlusInfo` is the *member* subscription, unrelated.
  No list tile / detail page shows a business Plus badge today (nothing to reuse).
  "Sponsorlu" (home/search settings id lists) is a different concept; do not conflate.
- Colors: `lib/theme/app_theme.dart` `AppColors` has no orange (primary navy `0xFF120C63`,
  star `0xFFFFC24B`, closing `0xFFE0533D`). Decision: add `AppColors.plus = Color(0xFFFF7A00)`
  and `AppColors.plus2 = Color(0xFFE06A00)` (darker, for the selected state — mirrors the
  primary/primary2 pair).
- Tooling: Flutter, `flutter_lints` (analysis_options.yaml). Tests in `test/` (only
  `widget_test.dart` today). Commands: `flutter analyze`, `flutter test`, run from
  `c:\Users\mail\dev\gezgah`. No AGENTS.md / steering / CONTRIBUTING in the repo.
- Conclusion: map data does NOT include a plus flag → app side is implemented against a
  proposed field `is_plus`, and a backend request doc `HARITA_PLUS_IKON.md` IS needed.

## Constraints (must follow)

- Work directly in `c:\Users\mail\dev\gezgah` (no worktree). Do NOT git commit.
- A concurrent workflow is editing `lib/data/api.dart` (`aramaMekan` / `aramaYemek`, the
  `/arama` search code, `SearchResult`, and lines just after the `ApiPlace` class) and
  `lib/widgets/search_modal.dart`, and creates `ARAMA_OZELLIK_FILTRE.md`. Do NOT touch
  `search_modal.dart` or `ARAMA_OZELLIK_FILTRE.md`. In `api.dart`, make only small targeted
  `str_replace` edits inside `ApiPlace` (field/ctor/toCacheJson/fromCache), one line in
  `_parsePlace`, and one import line — never rewrite the file, never touch
  `aramaMekan`/`aramaYemek`/`SearchResult`. Re-read the exact snippet right before each edit
  because the file changes underneath.
- All workflow artifacts only under `c:\Users\mail\dev\gezgah\.agents\tasks\map-plus-marker\`
  (never `.agents\tasks\` root files like plan.md/review.json there).
- Backward compatibility: if `is_plus` is absent, `isPlus == false` and every marker renders
  byte-identical to today (same cache key semantics, same colors, same zIndex).

## Decisions

- Flag parsing lives in a NEW file `lib/data/place_flags.dart` (top-level
  `bool parsePlusFlag(Map<String, dynamic> j)`), so the api.dart diff stays tiny and the
  logic is unit-testable (`_parsePlace` is private). Accepted keys, first non-null wins:
  `is_plus`, `plus`, `isletme_plus`. Truthy values: `true`, num `!= 0`, strings
  `"1"`, `"true"`, `"yes"`, `"evet"` (trim, case-insensitive); a Map value (e.g.
  `plus: {aktif: true}`) is truthy if its `aktif` is truthy. Everything else → false.
- Model: `ApiPlace.isPlus` (bool, default false), persisted in cache JSON as `is_plus`.
  `Place` / `toPlace()` unchanged (no consumer needs it yet).
- Marker: same shape/size/border/shadow/glyph; only the inner circle color changes to
  `AppColors.plus` (selected: `AppColors.plus2`). Cache key becomes
  `'${icon.codePoint}_${active}_$plus'`, so each (icon, selected, plus) combo is drawn once.
  zIndex: selected 3, plus 2, normal 1 (selected keeps top; plus above regular pins).
  Non-plus output is identical to today's pin.

## Steps

- [ ] 1. Add the orange Plus colors to the theme.
      Add `static const Color plus = Color(0xFFFF7A00); // Plus işletme (harita pini)` and
      `static const Color plus2 = Color(0xFFE06A00); // seçili Plus pini` to `AppColors`.
      Files: `lib/theme/app_theme.dart`
      Verify: `flutter analyze lib/theme/app_theme.dart` — no issues.

- [ ] 2. Create the tolerant flag parser + unit tests.
      New file with Turkish doc comment (project style) implementing `parsePlusFlag` per the
      Decisions section (private `_truthy(dynamic v)` helper handling bool/num/String/Map).
      New test file covering: missing keys → false; `is_plus: true/1/"1"/"true"/" TRUE "/"evet"`
      → true; `is_plus: false/0/"0"/""/null/"abc"` → false; fallback key `plus: 1` and
      `isletme_plus: "true"` → true; `plus: {"aktif": true}` → true, `{"aktif": false}` → false;
      `is_plus: false` with `plus: true` → false (first non-null key wins).
      Files: `lib/data/place_flags.dart`, `test/place_flags_test.dart`
      Verify: `flutter test test/place_flags_test.dart` — all pass.

- [ ] 3. Propagate `isPlus` through `ApiPlace` (small targeted edits in api.dart; depends on 2).
      a) Add `import 'place_flags.dart';` after `import 'models.dart';`.
      b) In `class ApiPlace`: add field after `customIcon` with doc comment
         `/// Gezgah Plus işletme mi (`is_plus`). Haritada turuncu pinle gösterilir. Alan
         gelmezse false (HARITA_PLUS_IKON.md).` → `final bool isPlus;`; ctor param
         `this.isPlus = false,` after `this.customIcon = '',`.
      c) `toCacheJson()`: add `'is_plus': isPlus,` after `'custom_ikon': customIcon,`.
      d) `ApiPlace.fromCache`: add `isPlus: parsePlusFlag(j),` after the `customIcon:` line
         (old caches without the key → false).
      e) `_parsePlace`: add `isPlus: parsePlusFlag(j),` right after
         `customIcon: (j['custom_ikon'] as String?)?.trim() ?? '',`.
      Extend `test/place_flags_test.dart` with an `ApiPlace` cache round-trip test
      (`ApiPlace(id:1,name:'x',image:'',isPlus:true)` → `toCacheJson` → `fromCache` keeps
      `isPlus == true`; a map without `is_plus` → false).
      Files: `lib/data/api.dart`, `test/place_flags_test.dart`
      Verify: `flutter test test/place_flags_test.dart` passes; `flutter analyze lib/data`
      reports no new issues in api.dart/place_flags.dart (if the concurrent workflow has
      in-progress errors in its own code, note them but do not fix them).

- [ ] 4. Orange Plus marker in the map (depends on 1 and 3).
      In `lib/screens/map_screen.dart`:
      - `_markerIcon(IconData icon, bool active, {bool plus = false})`: key
        `'${icon.codePoint}_${active}_$plus'`, call `_buildPin(icon, active, plus: plus)`;
        update the `_iconCache` comment ("codePoint + seçili + Plus durumuna göre").
      - `_buildPin(IconData icon, bool active, {bool plus = false})`: inner circle color
        `plus ? (active ? AppColors.plus2 : AppColors.plus) : (active ? AppColors.primary2 : AppColors.primary)`;
        nothing else changes (size, border, shadow, glyph). Update doc comment to mention
        the orange Plus variant.
      - `_rebuildMarkers()`: `final icon = await _markerIcon(_iconForPlace(p), isSel, plus: p.isPlus);`
        and `zIndexInt: isSel ? 3 : (p.isPlus ? 2 : 1),`.
      Files: `lib/screens/map_screen.dart`
      Verify: `flutter analyze lib/screens/map_screen.dart` — no issues.

- [ ] 5. Write the backend request doc in the repo root (Turkish, style of
      `YERLER_FILTRE_IDS.md`): title `# /harita — Plus işletme bayrağı (is_plus) eksik`;
      Durum: Backend ⏳ bekliyor · App ✅ hazır. Sections: (1) İstek — `/harita` `data[]`
      her kayda `is_plus: true|false` (boolean) eklensin; (2) Kaynak — işletmenin Gezgah
      Plus durumu, `/rezervasyon/secenekler` `aktif` ile aynı kaynak/mantık (aktif, süresi
      dolmamış Plus); (3) Tercihen ortak özet temsiline (`MekanController::summary()` — `/mekanlar`,
      `/yerler`, `/arama`, `/mekanlar/{id}` vb.) de eklensin ki listelerde de kullanılabilsin;
      (4) Örnek JSON (HARITA.md örneğine `"is_plus": true`); (5) App tarafı davranış —
      turuncu (`#FF7A00`) arka planlı pin, beyaz ikon, diğer pinlerin üstünde; alan yoksa
      false kabul edilir, geriye dönük uyumlu; tolerated formats (bool, 1/0, "1"/"true");
      (6) Kabul testi — `curl "https://api.gezgah.com/rest/harita?type=restoran"` (cihaz
      token'ıyla) yanıtında bilinen bir Plus işletmede `is_plus: true`, diğerlerinde `false`.
      Do not edit `.readme/HARITA.md` (backend doc mirror; backend updates it).
      Files: `HARITA_PLUS_IKON.md` (new, repo root). Do not touch `ARAMA_OZELLIK_FILTRE.md`.
      Verify: file exists and renders (markdown only; no build impact).

- [ ] 6. Full verification.
      Run from `c:\Users\mail\dev\gezgah`: `flutter analyze` and `flutter test`.
      Expected: no analyzer issues in files this task touched (`app_theme.dart`,
      `place_flags.dart`, `api.dart` ApiPlace/_parsePlace lines, `map_screen.dart`,
      `test/place_flags_test.dart`); all tests pass (existing `widget_test.dart` + new).
      Any failure originating from the concurrent search work (search_modal.dart / aramaMekan)
      is reported, not fixed. Record results in
      `c:\Users\mail\dev\gezgah\.agents\tasks\map-plus-marker\verification.md`.
      Optional manual check (not required): temporarily force `isPlus` true for one place in
      a debug run to see the orange pin; revert before finishing.

## Gaps / assumptions

- Backend field name is not yet agreed; app accepts `is_plus` (primary), `plus`,
  `isletme_plus`. Until backend ships it, all pins stay navy (no visible change) — expected.
- Orange `#FF7A00` is a proposal (no brand orange exists in the theme).
