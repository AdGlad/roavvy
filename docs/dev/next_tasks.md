# M97 — Gamified Stats & Achievement Dashboard

Branch: milestone/m97-gamified-stats-dashboard

## Goal

Replace the plain 3-stat panel + flat achievement grid on the Stats tab with a fully gamified travel dashboard: `fl_chart` PieChart donut progress ring, next-achievements carousel, tabbed achievement gallery with merch CTAs, and a Merch Moments section.

## Scope

In:
- `pubspec.yaml` (fl_chart: ^0.69.0)
- `packages/shared_models/lib/src/achievement.dart` (expand model + kAchievements to ~30)
- `packages/shared_models/lib/src/achievement_engine.dart` (trip + thisYear evaluation)
- `packages/shared_models/test/achievement_engine_test.dart` (regression + new tests)
- `lib/core/providers.dart` (tripCountProvider, thisYearCountryCountProvider)
- `lib/features/stats/stats_screen.dart` (full redesign)
- `lib/features/stats/widgets/travel_progress_hero.dart` (new)
- `lib/features/stats/widgets/next_achievements_carousel.dart` (new)
- `lib/features/stats/widgets/achievement_gallery.dart` (new)
- `lib/features/stats/widgets/merch_moments_section.dart` (new)

Out:
- Passport stamp / streak achievements (no Drift data — deferred)
- Poster/mug/sticker merch types (T-shirt only in M97)
- Web stats page
- New Drift schema changes

## Tasks

- [ ] **T1 — fl_chart dependency + Achievement model expansion**
  - **Files:** `pubspec.yaml`, `packages/shared_models/lib/src/achievement.dart`
  - **Deliverable:** `fl_chart: ^0.69.0` in pubspec; `AchievementCategory` + `MerchTriggerType` enums; `Achievement` model gains `category`, `progressTarget`, `merch?`; `kAchievements` expanded to ~30 entries (country/continent/trip/thisYear categories); existing 8 IDs unchanged.

- [ ] **T2 — AchievementEngine + new providers**
  - **Files:** `packages/shared_models/lib/src/achievement_engine.dart`, `packages/shared_models/test/achievement_engine_test.dart`, `lib/core/providers.dart`
  - **Deliverable:** `evaluate()` gains named optional `tripCount` + `thisYearCountryCount` params; evaluates all ~30 achievements; `tripCountProvider` + `thisYearCountryCountProvider` added to providers.dart.

- [ ] **T3 — Travel Progress Hero**
  - **Files:** `lib/features/stats/widgets/travel_progress_hero.dart` (new)
  - **Deliverable:** `_TravelProgressHero` widget: `fl_chart` `PieChart` donut (gold visited / surface remaining), centre country count (48sp bold), tier badge (highest unlocked country achievement title), "Create your travel tee" `FilledButton` → `MerchCountrySelectionScreen`.

- [ ] **T4 — Next Achievements Carousel**
  - **Files:** `lib/features/stats/widgets/next_achievements_carousel.dart` (new)
  - **Deliverable:** Horizontal `ListView` of up to 3 nearest unmet achievements sorted by `(progressTarget - currentProgress)` ascending; each card shows title, `LinearProgressIndicator` progress strip, "{n} more to go", optional merch teaser chip. (fl_chart is reserved for hero PieChart only — ADR-148.)

- [ ] **T5 — Achievement Gallery (tabbed)**
  - **Files:** `lib/features/stats/widgets/achievement_gallery.dart` (new)
  - **Deliverable:** `DefaultTabController` with tabs Countries / Continents / Trips / All; unlocked rows show gold accent + trophy + unlock date + merch CTA chip; locked rows dimmed with `LinearProgressIndicator`.

- [ ] **T6 — Merch Moments section**
  - **Files:** `lib/features/stats/widgets/merch_moments_section.dart` (new)
  - **Deliverable:** `_MerchMomentsSection` showing up to 3 most-recently-unlocked merch-eligible achievements with CTA navigating to `LocalMockupPreviewScreen` via `_presetFor()` helper; section absent when no eligible unlocks.

- [ ] **T7 — StatsScreen redesign**
  - **Files:** `lib/features/stats/stats_screen.dart`
  - **Deliverable:** `StatsScreen` refactored to `CustomScrollView` with 5 sliver sections: Progress Hero, Next Achievements, Stats Grid (2×2: countries/continents/regions/trips), Achievement Gallery, Merch Moments. Existing `AchievementsScreen` entry point preserved.

- [ ] **T8 — Analyze clean**
  - **Files:** All touched files
  - **Deliverable:** `flutter analyze 2>/tmp/analyze.txt; tail /tmp/analyze.txt` reports zero issues.
