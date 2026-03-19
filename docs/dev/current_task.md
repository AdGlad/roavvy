# Current Task — Task 46: Region count + region list in country detail sheet

**Milestone:** 16
**Phase:** 6 — Geographic Depth (Mobile)

## Why

With `RegionVisit` records now being persisted after each scan (Task 45), this task surfaces that data in the UI: `CountryDetailSheet` shows how many sub-national regions the user has visited in a country, with a tap-to-expand list of region names.

## Acceptance criteria

- [x] `kRegionNames` map in `lib/core/region_names.dart`: ISO 3166-2 → English name; fallback to code if absent
- [x] `CountryDetailSheet` reads `regionRepositoryProvider`; loads regions on open; shows "X region(s) visited" row (hidden when 0)
- [x] Tapping the row expands an inline alphabetically-sorted list of region names
- [x] Unknown ISO codes fall back to displaying the raw code
- [x] Duplicate regions across trips counted once (unique region codes)
- [x] `dart analyze` reports zero issues
- [x] 5 new widget tests in `country_detail_sheet_test.dart`

## Status: COMPLETE

## Files changed

- `apps/mobile_flutter/lib/core/region_names.dart` — new; `kRegionNames` map (~400 entries)
- `apps/mobile_flutter/lib/features/map/country_detail_sheet.dart` — region section added; `_regionsFuture` + `_regionsExpanded` state
- `apps/mobile_flutter/test/features/map/country_detail_sheet_test.dart` — `_wrap` updated; `_regionRepoWith` + `_region` helpers; 5 new region tests; inline `ProviderScope` updated

## Dependencies

Task 45 (RegionRepository, inferRegionVisits, regionRepositoryProvider).
