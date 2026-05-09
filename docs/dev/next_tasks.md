# M102 — Achievement-Aware Merchandise Context System

Branch: milestone/m102-achievement-aware-merchandise-context-system

## Goal

Extend `MerchContext` and `AchievementEngine` so achievements generate merchandise
options that are scoped precisely to the relevant travel data:
- Continent-explorer achievements generate options using only countries in that continent.
- Region achievements (Mediterranean, Southeast Asia) filter to the sub-region.
- Passport stamp milestones generate passport-first option lists.
- Continent-explorer + region achievements added to `kAchievements` with evaluation
  logic in `AchievementEngine`.

Existing purchase workflow, Memory Pulse path, and checkout flow are NOT touched.

## Scope

**In:**
- `packages/shared_models/lib/src/achievement.dart` — add `continentScope`, `regionScope` fields; new continent/region/passport achievements
- `packages/shared_models/lib/src/continent_subregion_map.dart` (new) — `kCountrySubRegion` for Mediterranean + SoutheastAsia
- `packages/shared_models/lib/src/achievement_engine.dart` — evaluate new achievements
- `packages/shared_models/lib/shared_models.dart` — export new file
- `apps/mobile_flutter/lib/features/merch/merch_context.dart` — filter codes by `continentScope`/`regionScope`; passport-priority ordering; new `_buildContinentExplorerItems`, `_buildRegionItems`, `_buildPassportMilestoneItems`
- `docs/architecture/decisions/_index.md` — ADR-152
- `docs/dev/backlog_active.md` — add M102 entry
- `docs/dev/current_state.md` — update

**Out:**
- `achievement_gallery.dart` / `next_achievements_carousel.dart` stats display accuracy
  (continent-explorer progress shows "N continents" — cosmetically imperfect; stat display
  improvement deferred to post-M102)
- `AchievementCategory` enum changes (no new values; avoids exhaustive switch cascade)
- `LocalMockupPreviewScreen`, `MerchOrderConfirmationScreen`, Printful, Shopify
- Web, Android
- `pulse_merch_option_screen.dart` (untouched)

## Tasks

- [x] 1. Add `continentScope` / `regionScope` fields to `Achievement` + `kCountrySubRegion` data
  - **File:** `packages/shared_models/lib/src/achievement.dart`, new `continent_subregion_map.dart`
  - **Deliverable:** `Achievement` gains two optional `String?` fields; `kCountrySubRegion` maps alpha-2 codes to sub-region keys ('Mediterranean', 'SoutheastAsia'); new continent-explorer achievements (Europe/Asia/Africa/NorthAmerica/SouthAmerica/Oceania), region achievements (Mediterranean, SoutheastAsia), and passport stamp milestones added to `kAchievements`
  - **Acceptance:** `kAchievements` compiles; existing IDs unchanged; new fields default null on existing achievements

- [x] 2. Update `AchievementEngine` to evaluate new achievements
  - **File:** `packages/shared_models/lib/src/achievement_engine.dart`
  - **Deliverable:** Per-continent country counts (`europeCount`, `asiaCount`, `africaCount`, `northAmericaCount`, `southAmericaCount`, `oceaniaCount`) and per-region country counts (mediterraneanCount, southeastAsiaCount) computed from `visits`; passport stamp milestones evaluated from `tripCount * 2`; new IDs returned in unlocked set
  - **Acceptance:** Evaluate returns `continent_europe_5` when ≥5 European countries visited; returns `region_mediterranean` when ≥5 Mediterranean countries visited; returns `passport_10` when tripCount * 2 ≥ 10

- [x] 3. Export `kCountrySubRegion` from shared_models barrel
  - **File:** `packages/shared_models/lib/shared_models.dart`
  - **Deliverable:** `export 'src/continent_subregion_map.dart'` added
  - **Acceptance:** `import 'package:shared_models/shared_models.dart'` exposes `kCountrySubRegion`

- [x] 4. Update `MerchContext` for continent/region/passport scope
  - **File:** `apps/mobile_flutter/lib/features/merch/merch_context.dart`
  - **Deliverable:**
    - `_resolveCodes` for `AchievementCategory.continents` checks `achievement.continentScope`; if set, filters `allVisits` to only countries in that continent via `kCountryContinent`; if `achievement.regionScope` is set, filters via `kCountrySubRegion`
    - `buildItems()` detects `continentScope != null` → `_buildContinentExplorerItems()`; `regionScope != null` → `_buildRegionItems()`; existing category branch for non-scoped continent achievements unchanged
    - `merch == MerchTriggerType.passportStamp` on trip achievements → `_buildPassportMilestoneItems()` (passport template listed first)
    - `_resolveTrips` correspondingly filtered when `continentScope`/`regionScope` set
  - **Acceptance:** `MerchContext.fromAchievement(achievement: europeExplorer, ...)` produces codes only from Europe; region achievement produces only Mediterranean codes; passport milestone achievement generates passport-leading options

- [x] 5. `flutter analyze` — 0 new warnings
  - **Deliverable:** `flutter analyze 2>/tmp/m102_analyze.txt && tail -5 /tmp/m102_analyze.txt` output shows no new issues

## Dependencies

- M100 complete (MerchContext base layer, 4 template groups) ✅
- `kCountryContinent` available in shared_models ✅
- No new packages required

## Risks

| Risk | Mitigation |
|---|---|
| Continent-explorer achievement progress shows `continentCount` (wrong) in `_AchievementRow` | Accepted; stat display accuracy deferred; achievement still unlocks correctly |
| `continentScope` / `regionScope` filter yields empty `codes` (user has no visited countries in region) | `_addGroup` already guards `if (codes.isNotEmpty)` before adding option entries |
| Passport milestone achievement overlaps with existing trip achievements in same Trips tab | Different IDs, different `merch` type, different titles — coexist harmlessly |
| `kCountrySubRegion` coverage — user visits unlisted country in sub-region | Missing entries silently excluded from filter; user sees fewer options, not a crash |
