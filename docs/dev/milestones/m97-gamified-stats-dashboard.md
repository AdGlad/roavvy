# M97 — Gamified Stats & Achievement Dashboard

**Branch:** `milestone/m97-gamified-stats-dashboard`
**Phase:** 21 — Engagement & Gamification
**Depends on:** M86 (stats strip entry), M89 (hero labels), M96 (merch presets)
**Status:** Not started.

---

## Goal

Replace the plain 3-stat panel + flat achievement grid with a fully gamified travel dashboard.
The screen should feel like an iPhone-first achievement app: progress rings, curiosity-first carousels,
and achievement cards that drive merchandise CTAs. Uses `fl_chart` (open-source, no Syncfusion).

---

## Screen Layout

```
StatsScreen (CustomScrollView)
  1. Travel Progress Hero      — PieChart donut ring, country count, tier badge, merch CTA
  2. Next Achievements         — Horizontal carousel, 3 nearest unmet achievements, progress bar
  3. Stats Grid                — Countries / Continents / Regions / Trips cards (4-up grid)
  4. Achievement Gallery       — Tabbed (Countries | Continents | Trips | All), cards with merch CTA
  5. Merch Moments             — Recently unlocked achievements → product suggestions
```

---

## Scope

### In
- `pubspec.yaml` — `fl_chart: ^0.69.0`
- `packages/shared_models/lib/src/achievement.dart` — expand model + `kAchievements` to ~30 achievements
- `packages/shared_models/lib/src/achievement_engine.dart` — evaluate trip count + this-year count
- `lib/core/providers.dart` — add `tripCountProvider`, `thisYearCountryCountProvider`
- `lib/features/stats/stats_screen.dart` — full redesign
- New widget files inside `lib/features/stats/widgets/`

### Out
- Passport stamp achievements (need new Drift table — deferred M98+)
- Streak / check-in achievements (no tracking data — deferred)
- All 100 listed achievements (scope to ~30 trackable ones; remainder deferred)
- Poster / mug / sticker merch types (T-shirt only in M97)
- Web stats page
- New Drift schema changes

---

## Data model changes (ADR-148)

### `AchievementCategory` enum (new)
```dart
enum AchievementCategory { countries, continents, trips, thisYear }
```

### `MerchTriggerType` enum (new)
```dart
enum MerchTriggerType { flagGrid, passportStamp, timeline, country, milestone }
```

### `Achievement` model (extended)
Add three named fields alongside existing `id`/`title`/`description`:
```dart
class Achievement {
  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.progressTarget,
    this.merch,
  });
  final String id;
  final String title;
  final String description;
  final AchievementCategory category;
  final int progressTarget;         // unlock threshold (countries / continents / trips)
  final MerchTriggerType? merch;    // null = no merch suggestion
}
```

### `kAchievements` expansion (~30 achievements)

**Country count** (`progressTarget` = country threshold):
| ID | Title | Target | Merch |
|---|---|---|---|
| `countries_1` | First Stamp | 1 | `country` |
| `countries_3` | Triple Stamp | 3 | — |
| `countries_5` | Frequent Flyer | 5 | `flagGrid` |
| `countries_10` | Seasoned Traveller | 10 | `flagGrid` |
| `countries_15` | Well Travelled | 15 | — |
| `countries_20` | Passport Regular | 20 | `flagGrid` |
| `countries_25` | Globetrotter | 25 | `flagGrid` |
| `countries_30` | Borderless | 30 | — |
| `countries_40` | Horizon Chaser | 40 | `flagGrid` |
| `countries_50` | World Explorer | 50 | `flagGrid` |
| `countries_75` | Pathfinder | 75 | `flagGrid` |
| `countries_100` | Century Club | 100 | `flagGrid` |
| `countries_125` | Grand Tourist | 125 | — |
| `countries_150` | Marathon Traveller | 150 | `flagGrid` |
| `countries_195` | World Complete | 195 | `flagGrid` |

**Continent count** (`progressTarget` = continent threshold):
| ID | Title | Target | Merch |
|---|---|---|---|
| `continents_2` | Two Worlds | 2 | — |
| `continents_3` | Continental Drift | 3 | `milestone` |
| `continents_4` | Four Corners | 4 | — |
| `continents_5` | Five Continent Traveller | 5 | `milestone` |
| `continents_all` | All Six | 6 | `milestone` |

**Trip count** (`progressTarget` = trip threshold):
| ID | Title | Target | Merch |
|---|---|---|---|
| `trips_1` | First Trip | 1 | — |
| `trips_3` | Regular Traveller | 3 | — |
| `trips_5` | Jet Setter | 5 | `timeline` |
| `trips_10` | Miles Ahead | 10 | `timeline` |
| `trips_25` | Frequent Departure | 25 | `timeline` |
| `trips_50` | Always Moving | 50 | `timeline` |

**This-year country count** (`progressTarget` = countries visited in current calendar year):
| ID | Title | Target | Merch |
|---|---|---|---|
| `year_countries_3` | Year Tripper | 3 | — |
| `year_countries_5` | Year Explorer | 5 | `flagGrid` |
| `year_countries_10` | Big Year | 10 | `flagGrid` |

### `AchievementEngine.evaluate()` signature update
```dart
static Set<String> evaluate(
  List<EffectiveVisitedCountry> visits, {
  int tripCount = 0,
  int thisYearCountryCount = 0,
})
```
Backward-compatible (named optional args with defaults). Callers that do not pass trip/year counts continue to work.

---

## New providers (in `providers.dart`)

```dart
/// Total number of logged trips.
final tripCountProvider = FutureProvider<int>((ref) async {
  final trips = await ref.watch(tripListProvider.future);
  return trips.length;
});

/// Number of distinct countries first seen in the current calendar year.
final thisYearCountryCountProvider = FutureProvider<int>((ref) async {
  final visits = await ref.watch(effectiveVisitsProvider.future);
  final year = DateTime.now().year;
  return visits.where((v) => v.firstSeen.year == year).length;
});
```

---

## UI sections — implementation detail

### 1. Travel Progress Hero (`_TravelProgressHero`)

```
┌─────────────────────────────────────────┐
│  [fl_chart PieChart donut — 2/3 width]  │
│         centre: "42" (bold 48sp)        │
│         subtitle: "countries"           │
│  Tier badge: "Globetrotter"  🌍         │
│  ── 42 / 195 countries visited ──       │
│  [Create your travel tee →]             │
└─────────────────────────────────────────┘
```

- `PieChart` with 2 sections: visited (gold) / remaining (surfaceVariant)
- `centerSpaceRadius` = 56 — big enough to show count
- Tier derived from `kAchievements` (highest unlocked country achievement title)
- CTA: `FilledButton` → `MerchCountrySelectionScreen`

### 2. Next Achievements Carousel (`_NextAchievementsCarousel`)

Horizontal `ListView` of up to 3 nearest unmet achievements sorted by
`(progressTarget - currentProgress)` ascending.

Each card (`_NextAchievementCard`):
```
┌──────────────────────────┐
│  Globetrotter            │
│  25 countries            │
│  ██████░░░░  18/25       │
│  7 more to go            │
│  [Unlocks Flag Grid Tee] │  ← only if merch != null
└──────────────────────────┘
```

Progress drawn with `fl_chart BarChart` (single bar, horizontal, coloured fill).

### 3. Stats Grid (`_StatsGrid`)

2×2 grid of `_StatCard` widgets:
- Countries: `{n} / 195`
- Continents: `{n} / 6`
- Regions: `{n}`
- Trips: `{n}`

Tapping Countries → `CountriesListScreen`. Tapping Regions → `RegionBreakdownSheet`.

### 4. Achievement Gallery (`_AchievementGallery`)

`DefaultTabController` with tabs: Countries | Continents | Trips | All.

Each tab: `SliverList` of `_AchievementRow` widgets.

**Unlocked** row:
- Gold left accent border
- Trophy icon (amber)
- Title + unlock date
- If `merch != null`: small `OutlinedButton` chip → `LocalMockupPreviewScreen`

**Locked** row:
- Dimmed (opacity 0.5)
- Lock icon
- Title + description
- `LinearProgressIndicator` showing current/target

### 5. Merch Moments (`_MerchMomentsSection`)

Shown only when 1+ achievements are unlocked with `merch != null`.

```
Merch Moments
──────────────────────────────────────
[🏆 You unlocked Globetrotter]
  Create a 25 Countries Flag Grid Tee →
──────────────────────────────────────
```

Lists the 3 most-recently-unlocked achievements that have a merch trigger.
CTA navigates to `LocalMockupPreviewScreen` with appropriate `MerchPreset`.

---

## Merch CTA navigation

When a merch CTA is tapped, push `LocalMockupPreviewScreen` with a preset built from:

```dart
MerchPreset _presetFor(MerchTriggerType type) => switch (type) {
  MerchTriggerType.flagGrid      => kMerchPresets.firstWhere((p) => p.id == 'all_time'),
  MerchTriggerType.passportStamp => kMerchPresets.firstWhere((p) => p.id == 'all_time'),
  MerchTriggerType.timeline      => kMerchPresets.firstWhere((p) => p.id == 'this_year'),
  MerchTriggerType.country       => kMerchPresets.first,
  MerchTriggerType.milestone     => kMerchPresets.firstWhere((p) => p.id == 'all_time'),
};
```

---

## ADR-148

**Decision:** Gamified Stats Dashboard replaces the flat `StatsScreen`. Achievement model gains
`category`, `progressTarget`, and optional `MerchTriggerType`. `kAchievements` expands from 8 to ~30
trackable achievements. `AchievementEngine.evaluate()` is extended with named optional params
`tripCount` and `thisYearCountryCount` (backward-compatible). Charts use `fl_chart ^0.69.0`
(open-source, no Syncfusion dependency). Merch CTAs in the achievement gallery and Merch Moments
section navigate to `LocalMockupPreviewScreen` via a `_presetFor()` helper. Achievement IDs already
shipped (`countries_1/5/10/25/50/100`, `continents_3`, `continents_all`) are unchanged.

---

## File changes summary

| File | Change |
|---|---|
| `pubspec.yaml` | Add `fl_chart: ^0.69.0` |
| `packages/shared_models/lib/src/achievement.dart` | Add enums + fields; expand kAchievements |
| `packages/shared_models/lib/src/achievement_engine.dart` | Evaluate trip + this-year counts |
| `lib/core/providers.dart` | Add `tripCountProvider`, `thisYearCountryCountProvider` |
| `lib/features/stats/stats_screen.dart` | Full redesign (5 sections) |
| `lib/features/stats/widgets/travel_progress_hero.dart` | New — PieChart donut + tier |
| `lib/features/stats/widgets/next_achievements_carousel.dart` | New — horizontal carousel |
| `lib/features/stats/widgets/achievement_gallery.dart` | New — tabbed gallery with merch CTAs |
| `lib/features/stats/widgets/merch_moments_section.dart` | New — recently-unlocked merch triggers |
| `packages/shared_models/test/achievement_engine_test.dart` | Add tests for new achievements |

---

## Acceptance criteria

1. `fl_chart` renders donut ring on Stats screen without errors.
2. Country count and tier name correct for 0, 5, 25, and 50 visited countries.
3. Next Achievements carousel shows the 3 nearest unmet achievements in ascending distance order.
4. Achievements gallery tabs (Countries / Continents / Trips / All) each show correct subset.
5. Merch CTA chip appears on unlocked achievements with `merch != null`; absent on others.
6. Merch Moments section absent when zero merch-eligible achievements are unlocked.
7. `AchievementEngine.evaluate()` with default params produces same results as current (regression test).
8. `flutter analyze` reports zero issues.
