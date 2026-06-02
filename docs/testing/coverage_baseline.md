# Coverage Baseline — T1

**Date recorded:** 2026-06-02
**Flutter version:** Flutter 3.41.9 (channel stable, 2026-04-29)
**Test files:** 92 test files across `test/`
**Test count:** all passing, 3 skipped (year-grouping tests skipped; see T1.2 notes)

## Overall coverage: 35.1%

| Layer | Files | Lines covered | Lines total | Coverage |
|---|---|---|---|---|
| Business logic (`features/`) | ~150 | 6,730 | 19,087 | 35.3% |
| Service / repository (`data/` + `core/`) | ~38 | 1,815 | 5,297 | 34.3% |
| **Overall** | **188** | **8,575** | **24,434** | **35.1%** |

_Widget/UI coverage is not broken out separately; it is included in the `features/` row._

## Notes

### Pre-existing analyze warnings (30 total, 0 errors)

`flutter analyze` reports 30 pre-existing issues, none of which are errors:

- **Warnings (15):** unused fields, unused declarations, unused imports, unused local variables — concentrated in `card_templates.dart`, `local_mockup_preview_screen.dart`, `landing_page.dart`.
- **Info (15):** `use_build_context_synchronously`, `deprecated_member_use` (`withOpacity`, `activeColor`), `unnecessary_import`, `prefer_final_fields` — scattered across features.

None of these were introduced in milestone T1.

### Fixes applied in T1.2

| Issue | Classification | Fix |
|---|---|---|
| `CustomCarousel` assertion crash (fewer than 5 trips) | Class A — application defect | Dynamic `sideCount = ((count-1)÷2).clamp(0,2)` in `journal_screen.dart` |
| Year grouping tests (3) | Class B — wrong expectations (UI redesigned) | Skipped with documented reason; T4 will add carousel coverage |
| Trip row content tests (6) | Class E — `pumpAndSettle` timeout from spring physics | Replaced with `pump(300ms)`; updated assertions for carousel card design |

### Coverage targets from ADR-158

| Risk tier | Target | Current |
|---|---|---|
| Business logic | 85% | 35.3% |
| Service / repository | 70% | 34.3% |
| Widget / UI | 40% | (included above) |

Coverage is below target across all layers — as expected for a first baseline before the T2–T4 test-writing milestones.

### Anomalously low areas

- `local_mockup_preview_screen.dart` — 3,000+ line UI file with very little coverage; expected, complex rendering logic.
- `card_templates.dart` — large generator file; existing tests cover ~35%.

### Drift "multiple databases" warning

Many tests instantiate `RoavvyDatabase` directly per test case without calling `driftRuntimeOptions.dontWarnAboutMultipleDatabases = true`. This is a pre-existing warning (not a failure) and will be addressed in T3.
