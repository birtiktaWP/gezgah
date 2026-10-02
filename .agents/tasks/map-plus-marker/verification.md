# Verification — map-plus-marker (iteration 1)

All commands run from `c:\Users\mail\dev\gezgah`.

## flutter analyze
`flutter analyze` → **No issues found! (ran in 13.2s)**. Exit code 0 (checked via
`cmd /c "flutter analyze >nul 2>&1"` → `$LASTEXITCODE = 0`).
PowerShell showed "Exit Code: 1" when piping `2>&1 | Out-String` only because the
pre-existing `geolocator:windows references geolocator_windows` stderr warning is
wrapped as NativeCommandError; unrelated to this task.

## flutter test
`flutter test` → **All tests passed! (+13)**. Exit code 0 (same `cmd /c` check).
- `test/place_flags_test.dart` (new, 7 tests): parsePlusFlag missing keys / truthy
  (`true,1,"1","true"," TRUE ","evet","yes"`) / falsy (`false,0,"0","",null,"abc"`) /
  fallback keys (`plus`, `isletme_plus`, `plus:{aktif}`) / first non-null key wins;
  ApiPlace cache round-trip keeps `isPlus`, old cache without `is_plus` → false.
- `test/search_params_test.dart` (concurrent search workflow's file, 5 tests) — passed.
- `test/widget_test.dart` (1 test) — passed.

## Touched by this task
- `lib/theme/app_theme.dart` — `AppColors.plus = 0xFFFF7A00`, `AppColors.plus2 = 0xFFE06A00`.
- `lib/data/place_flags.dart` (new) — `parsePlusFlag`.
- `lib/data/api.dart` — only: `import 'place_flags.dart';`, `ApiPlace.isPlus` field +
  ctor param (default false), `'is_plus'` in `toCacheJson`, `isPlus:` in `fromCache` and
  `_parsePlace`. `aramaMekan`/`aramaYemek`/`SearchResult` untouched (other changes in
  `git diff lib/data/api.dart` belong to the concurrent search workflow).
- `lib/screens/map_screen.dart` — `_markerIcon(..., {plus})` cache key
  `'${codePoint}_${active}_$plus'`, `_buildPin(..., {plus})` orange inner circle,
  `_rebuildMarkers` passes `p.isPlus`, zIndex selected 3 / plus 2 / normal 1.
- `test/place_flags_test.dart` (new), `HARITA_PLUS_IKON.md` (new, repo root).

## Not verified
- Visual check on emulator not done (orchestrator owns the running `flutter run`;
  backend doesn't send `is_plus` yet, so all pins currently remain navy as before).
