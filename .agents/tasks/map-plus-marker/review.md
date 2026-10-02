# Orange map pin for Gezgah Plus businesses

The map now draws Gezgah Plus businesses with an orange pin. Shape, size, white border, shadow and white category glyph match the existing navy pins. `ApiPlace` gains `isPlus` (default `false`). A new `parsePlusFlag` helper fills it from `is_plus`, with `plus` and `isletme_plus` as fallback keys. It accepts bool, non-zero numbers, `"1"`/`"true"`/`"yes"`/`"evet"`, and `{aktif: true}`. `GET /harita` doesn't send a Plus flag today, so the coder also added `HARITA_PLUS_IKON.md` for the backend team. Until the backend ships the field, every pin stays navy, so rendering doesn't change.

Watch for: nobody has seen an orange pin on a device yet, because the backend doesn't send the field (confirmed, non-blocking). The working tree mixes this change with the concurrent search-filter work in `api.dart` and with unrelated generated plugin-registrant edits, so commits need hunk-level staging (confirmed, non-blocking).

**Verdict**: APPROVED

## High-level view

The flag rides on the shared place parser. `_parsePlace` is used by `/harita` and every other summary endpoint, and it now sets `isPlus` through `parsePlusFlag`. The disk cache (`toCacheJson`/`fromCache`) round-trips it, and an old cache entry without the key reads as `false`. If any field is missing or unrecognised, `isPlus` is false, so absent data can never turn a pin orange by mistake.

On the map, `_markerIcon` adds `plus` to its cache key (`codePoint_active_plus`). That means at most four bitmaps per glyph (normal, selected, plus, plus+selected), each built once and reused. `_buildPin` changes only the inner fill: `AppColors.plus` `#FF7A00` normally, `AppColors.plus2` `#E06A00` when selected. This mirrors the existing `primary`/`primary2` pairing. Plus pins get z-index 2, between normal pins (1) and the selected pin (3), so they stay visible in dense clusters.

The concurrency rules hold. `search_modal.dart` and `ARAMA_OZELLIK_FILTRE.md` contain no Plus-related edits. This task's `api.dart` edits are the import, the field, the constructor param, the cache key/read, and the `_parsePlace` line, all outside `aramaMekan`/`aramaYemek`. The other `api.dart` hunks (`idsCsv`, `SearchResult.matchedOzellikler`, `ozellikler` params) match step by step the search workflow's own plan in `.agents/tasks/plan.md`.

`.readme/HARITA.md` lists no Plus field and no existing code reads one, so `HARITA_PLUS_IKON.md` is needed. It covers what was asked for: the endpoint (`GET /rest/harita` with `type`/`kategori`), the field (`is_plus`, boolean, on every `data[]` record), example JSON, the app behaviour, and a `curl` acceptance check.

<details>
<summary>Issues (3)</summary>

1. **No on-device check of the orange pin** (non-blocking, confirmed). The backend doesn't send `is_plus` yet, so the new `_buildPin` branch has never rendered. Before release, check it on the emulator once with a temporarily forced `isPlus: true`, or after the backend ships the field.
2. **Mixed hunks in `api.dart`** (non-blocking, confirmed). This task's `isPlus` hunks sit next to the search workflow's `idsCsv`/`ozellikler` hunks. Use hunk-level staging so each feature can be committed or reverted on its own.
3. **Unrelated generated plugin-registrant changes** (non-blocking, confirmed). Files under `windows/`, `linux/` and `macos/` changed, most likely from a `flutter pub get`/build run. Neither feature needs them, so leave them out of the commit or commit them separately.

</details>

<details>
<summary>Details</summary>

### Tolerant parsing and the fallback keys

```
/harita data[] ──► _parsePlace(j) ──► ApiPlace(isPlus: parsePlusFlag(j))
                                           │
home_store disk cache ◄── toCacheJson ─────┤ 'is_plus': bool
                      ──► fromCache ───────┘ parsePlusFlag(j)
                                           │
MapScreen._rebuildMarkers ──► _markerIcon(glyph, selected, plus:) ──► _iconCache
```

`parsePlusFlag` takes the first non-null value among `is_plus`, `plus` and `isletme_plus`, so an explicit `is_plus: false` overrides a stray truthy `plus`. The backend doc asks for `is_plus` only and lists the other keys as tolerated fallbacks, so there is one clear contract. The `{aktif: ...}` object form mirrors how `/rezervasyon/secenekler` reports Plus status. The doc asks the backend to derive `is_plus` from the same source so the map and the detail screen can't disagree.

### Test coverage

`test/place_flags_test.dart` covers the parser's value matrix, the key precedence, and the cache round-trip, including old caches without the key. Per `verification.md`, `flutter analyze` is clean and `flutter test` passes all 13 tests.

Not tested: the `_buildPin` Plus branch and the z-index ordering. Neither has a widget test, and neither has been checked visually.

</details>

<details>
<summary>Files changed</summary>

- `lib/data/place_flags.dart` (new): `parsePlusFlag` tolerant reader.
- `lib/data/api.dart`: `ApiPlace.isPlus` field and constructor param, cache write/read, `_parsePlace` wiring. The other hunks belong to the search workflow.
- `lib/screens/map_screen.dart`: Plus-aware icon cache key, orange inner fill, Plus z-index tier.
- `lib/theme/app_theme.dart`: `AppColors.plus` / `AppColors.plus2`.
- `test/place_flags_test.dart` (new): parser and cache tests.
- `HARITA_PLUS_IKON.md` (new, repo root): Turkish backend request for `is_plus` on `/harita`.

Full diff: `git diff -- lib/data/api.dart lib/screens/map_screen.dart lib/theme/app_theme.dart` plus the untracked files above.

</details>
