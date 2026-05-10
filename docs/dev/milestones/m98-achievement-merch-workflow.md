# M98 — Achievement-Driven Merch Workflow

**Branch:** `milestone/m98-achievement-merch-workflow`
**Phase:** 21 — Engagement & Gamification
**Depends on:** M96 (preset-driven merch), M97 (gamified stats dashboard)
**Status:** ✅ Complete (2026-05-08).

---

## Goal

Fix the "Make a Tee" / "Create" buttons in the Stats & Achievement Dashboard so they route
into the same modern t-shirt purchase workflow already used by the Memory Pulse feature —
not the legacy `MerchCountrySelectionScreen`.

Extend the existing `PulseMerchOptionScreen` infrastructure so that Memory Pulse and
Achievement-based entry points share one merch pipeline end-to-end: option selection →
mockup preview → order confirmation → Shopify checkout.

---

## Problem Statement

M97 wired two "Make a Tee" entry points in the Stats screen:

| Location | Widget | Button | Current navigation |
|---|---|---|---|
| Achievement Gallery (`_MerchChip`) | `lib/features/stats/widgets/achievement_gallery.dart` | "Make tee" | `MerchCountrySelectionScreen` (old flow) |
| Merch Moments (`_MerchMomentTile`) | `lib/features/stats/widgets/merch_moments_section.dart` | "Create" | `MerchCountrySelectionScreen` (old flow) |

Both navigate to the legacy blank-slate country-selection flow — before presets, before
Printful placement mapping, and before the mandatory `MerchOrderConfirmationScreen` gate.

The Memory Pulse path (via `MemoryRevealSheet` → `PulseMerchOptionScreen`) is the correct
modern flow. This milestone extends that flow to support achievement-based context.

---

## Architecture Decision (ADR-150)

### Core principle

`PulseMerchOption` is already a fully abstract merch option data class containing:
- `codes` — country codes for artwork generation
- `trips` — trip records for stamp generation
- `template` — card template type
- `jitter` / `stampSizeMultiplier` — artwork tuning
- `title` / `description` — display copy

Both Memory Pulse and Achievement entry points will resolve their context into a
`List<PulseMerchOption>` and render them using the same shared widgets. The downstream
pipeline (`LocalMockupPreviewScreen` → `MerchOrderConfirmationScreen` → Shopify) is
completely unchanged.

### Refactoring plan

Extract the shared rendering infrastructure from `pulse_merch_option_screen.dart` into a
new file `merch_option_list_widgets.dart`. The pulse screen imports from the shared file
(behavior unchanged). A new `AchievementMerchOptionScreen` uses the same shared widgets
with achievement-specific option generation.

```
Memory Pulse entry point:
  MemoryRevealSheet → PulseMerchOptionScreen (unchanged)
                         ↓ builds options from HeroImage context
                         ↓ renders via shared MerchOptionCard widgets
                         ↓ user taps → LocalMockupPreviewScreen → ... → checkout

Achievement entry point (new):
  _MerchChip / _MerchMomentTile → AchievementMerchOptionScreen
                                     ↓ reads effectiveVisitsProvider, tripListProvider
                                     ↓ builds options from Achievement context
                                     ↓ renders via shared MerchOptionCard widgets
                                     ↓ user taps → LocalMockupPreviewScreen → ... → checkout
```

---

## Scope

### In

| File | Change |
|---|---|
| `lib/features/merch/merch_option_list_widgets.dart` | **New** — shared rendering widgets extracted from pulse screen |
| `lib/features/merch/pulse_merch_option_screen.dart` | **Modified** — import from shared widgets file; no behavior change |
| `lib/features/merch/achievement_merch_option_screen.dart` | **New** — achievement-context option screen |
| `lib/features/stats/widgets/achievement_gallery.dart` | **Modified** — `_MerchChip` navigates to `AchievementMerchOptionScreen` |
| `lib/features/stats/widgets/merch_moments_section.dart` | **Modified** — `_MerchMomentTile` navigates to `AchievementMerchOptionScreen` |

### Out

- `LocalMockupPreviewScreen` — no changes
- `MerchOrderConfirmationScreen` — no changes
- `MerchOrdersScreen` / Shopify / Printful — no changes
- `pulse_merch_option.dart` — no changes
- `shared_models` package — no changes
- Web — not in scope
- New achievement categories or `kAchievements` entries — not in scope

---

## File 1 — `lib/features/merch/merch_option_list_widgets.dart` (new)

Extract the following from `pulse_merch_option_screen.dart`, making them public:

### Sealed list-item types

```dart
sealed class MerchOptionListItem {}

class MerchOptionHeaderItem extends MerchOptionListItem {
  MerchOptionHeaderItem(this.label);
  final String label;
}

class MerchOptionEntry extends MerchOptionListItem {
  MerchOptionEntry(this.option);
  final PulseMerchOption option;
}

class MerchOptionCustomiseEntry extends MerchOptionListItem {
  MerchOptionCustomiseEntry({required this.template, required this.label});
  final CardTemplateType template;
  final String label;
}
```

### Auto-tune helpers (currently private static methods on `PulseMerchOptionScreen`)

```dart
/// Auto-tunes jitter + size for passport templates based on stamp count
/// (trips × 2 for entry+exit, or trips × 1 for entryOnly).
({double jitter, double size}) autoTuneStamps(int stampCount) { ... }

/// Auto-tunes jitter + size for grid / flags / timeline based on country count.
({double jitter, double size}) autoTuneCodes(int codeCount) { ... }

/// Aspect ratio for the back-card artwork: landscape (3:2) for grid/timeline,
/// portrait (2:3) for passport.
double backCardAspectRatio(CardTemplateType template) { ... }

/// Shared template-to-label mapping.
String templateLabel(CardTemplateType t) { ... }
```

### Widget: `MerchOptionSectionHeader`

Direct rename of `_SectionHeader`. Displays the group label ("PASSPORT", "FLAGS", "TOUR DATES").

### Widget: `MerchOptionCard`

Direct rename + visibility change of `_OptionCard` / `_OptionCardState`.

Constructor: `MerchOptionCard({required PulseMerchOption option, required List<String> allCodes})`

Behaviour is identical: renders two shirt mockup thumbnails (back + front), shows title /
description / template chip, navigates to `LocalMockupPreviewScreen` on tap.

### Widget: `MerchOptionCustomCard`

Direct rename of `_CustomOptionCard`, simplified: only `template` and `label` are needed
(the original `hero`, `allTrips`, `allCodes` params were unused in the `onTap` body — it
only ever pushes `CardEditorScreen(templateType: template)`).

```dart
class MerchOptionCustomCard extends StatelessWidget {
  const MerchOptionCustomCard({required this.template, required this.label});
  final CardTemplateType template;
  final String label;
  // onTap → CardEditorScreen(templateType: template)
}
```

---

## File 2 — `pulse_merch_option_screen.dart` (modified)

Replace every private `_SectionHeader`, `_OptionCard`, `_CustomOptionCard`, `_ListItem`,
`_HeaderItem`, `_OptionItem`, `_CustomiseItem`, `_autoTuneStamps`, `_autoTuneCodes`,
`_backCardAspectRatio`, `_templateLabel` usage with the imported shared equivalents.

The public API surface (`PulseMerchOptionScreen` constructor, its parameters, behaviour)
is **unchanged**. Memory Pulse flow is regression-proof.

---

## File 3 — `lib/features/merch/achievement_merch_option_screen.dart` (new)

### Constructor

```dart
class AchievementMerchOptionScreen extends ConsumerWidget {
  const AchievementMerchOptionScreen({
    super.key,
    required this.achievement,
  });

  final Achievement achievement;
```

The screen reads `effectiveVisitsProvider` and `tripListProvider` itself. The caller only
passes the `Achievement` object, keeping the call sites in the stats widgets simple.

### Option generation

Options are built by `_buildItems(Achievement, List<EffectiveVisitedCountry>, List<TripRecord>)`.

#### Country scope resolution

| Achievement category | Resolved codes | Resolved trips |
|---|---|---|
| `countries` (target = 1) | First visited country (earliest `firstSeen`) | All trips to that country |
| `countries` (target ≤ 25) | First `progressTarget` countries by `firstSeen` | All trips to those countries |
| `countries` (target > 25) | All visited countries | All trips |
| `continents` | All visited countries | All trips |
| `trips` | Countries from the first `progressTarget` trips (by `startedOn`) | First `progressTarget` trips |
| `thisYear` | Countries with `firstSeen.year == currentYear` | Trips from current year |

#### Option groups

For each template group (Passport, Flags, Tour Dates), generate:

**Option A — achievement-scoped**

Uses the resolved `codes` + `trips` from the table above.

```
title:  "{templateLabel} — {scopeTitle}"
desc:   "{scopeDescription}"
```

Where `scopeTitle` / `scopeDescription` vary by achievement:

| Achievement | scopeTitle | scopeDescription |
|---|---|---|
| countries_1 | "{CountryName} Stamp" | "Your first country" |
| countries_N (N≤25) | "First {N} Countries" | "Your first {N} countries" |
| countries_N (N>25) | "{N} Countries" | "{N}-country milestone" |
| continents_N | "{N} Continents" | "Countries across {N} continents" |
| trips_N | "{N} Trips" | "All your logged trips" |
| year_countries_N | "{year} Travels" | "{N} countries visited in {year}" |

**Option B — all-time collection** (only when `allVisits.length > resolvedCodes.length`)

```
title:  "{templateLabel} — World Collection"
desc:   "{total} countries across all your travels"
codes:  allVisits codes
trips:  allTrips
```

**Customise row** (one per group)

```dart
MerchOptionCustomCard(template: template, label: 'Customise {templateLabel}')
```

#### Stamp auto-tuning

Use the shared `autoTuneStamps` / `autoTuneCodes` functions from
`merch_option_list_widgets.dart`.

### Screen subtitle

```dart
String _subtitle(Achievement a, List<EffectiveVisitedCountry> visits) =>
    switch (a.category) {
      AchievementCategory.countries when a.progressTarget == 1 =>
        'Celebrating your first country',
      AchievementCategory.countries =>
        'Celebrating ${a.progressTarget} countries visited',
      AchievementCategory.continents =>
        'Celebrating ${a.progressTarget} continents explored',
      AchievementCategory.trips =>
        'Celebrating ${a.progressTarget} trips logged',
      AchievementCategory.thisYear =>
        'Celebrating ${a.progressTarget} countries in ${DateTime.now().year}',
    };
```

### Loading / error states

The screen uses `ref.watch` on `effectiveVisitsProvider` and `tripListProvider`.
- While loading: show centred `CircularProgressIndicator`.
- On error: show simple error message with retry button.
- On data: build and render items.

### Visual style

Match `PulseMerchOptionScreen` exactly:
- `backgroundColor: const Color(0xFF0D1B2A)`
- `AppBar` title: `'Your travel shirt ideas'`
- `foregroundColor: Colors.white`

---

## File 4 — `achievement_gallery.dart` (modified)

### Before

`_MerchChip` navigates to `MerchCountrySelectionScreen`:

```dart
onPressed: () => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (_) => const MerchCountrySelectionScreen(),
  ),
),
```

### After

Navigate to `AchievementMerchOptionScreen`:

```dart
onPressed: () => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (_) => AchievementMerchOptionScreen(achievement: achievement),
  ),
),
```

`_MerchChip` already holds `achievement` as a field, so no signature changes are needed.

Remove import of `merch_country_selection_screen.dart`; add import of
`achievement_merch_option_screen.dart`.

---

## File 5 — `merch_moments_section.dart` (modified)

### Before

`_MerchMomentTile` navigates to `MerchCountrySelectionScreen`:

```dart
onPressed: () => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (_) => const MerchCountrySelectionScreen(),
  ),
),
```

### After

```dart
onPressed: () => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (_) => AchievementMerchOptionScreen(achievement: achievement),
  ),
),
```

`_MerchMomentTile` already holds `achievement` as a field, so no signature changes needed.

Remove import of `merch_country_selection_screen.dart`; add import of
`achievement_merch_option_screen.dart`.

---

## Option generation — worked examples

### Example 1: countries_1 ("First Stamp", MerchTriggerType.country)

User's first country: France (FR). One trip to France.

```
resolvedCodes = ['FR']
resolvedTrips = [<France trip>]

Passport group:
  [0] Passport — France Stamp          codes=['FR'] trips=[<France trip>]
  [1] Passport — World Collection      codes=['FR','IT','ES',...] trips=[all]  (if >1 country)
  [2] Customise Passport

Flags group:
  [0] Flags — France Stamp             codes=['FR'] trips=[<France trip>]
  [1] Flags — World Collection         (if >1 country)
  [2] Customise Flags

Tour Dates group:
  [0] Tour Dates — France Stamp        codes=['FR'] trips=[<France trip>]
  [1] Tour Dates — World Collection    (if >1 country)
  [2] Customise Tour Dates

subtitle: "Celebrating your first country"
```

### Example 2: countries_5 ("Frequent Flyer", MerchTriggerType.flagGrid)

User has visited 12 countries. First 5 by firstSeen: FR, IT, ES, DE, PT.

```
resolvedCodes = ['FR','IT','ES','DE','PT']
resolvedTrips = all trips where countryCode ∈ resolvedCodes

Passport group:
  [0] Passport — First 5 Countries     codes=['FR','IT','ES','DE','PT']
  [1] Passport — World Collection      codes=[all 12] trips=[all]
  [2] Customise Passport

Flags group: (same pattern)
Tour Dates group: (same pattern)

subtitle: "Celebrating 5 countries visited"
```

### Example 3: trips_10 ("Miles Ahead", MerchTriggerType.timeline)

User has 22 trips total. First 10 trips cover: FR, IT, ES, DE, PT, GR, HR, NL, BE, CH.

```
resolvedTrips = first 10 trips (by startedOn)
resolvedCodes = unique country codes from those 10 trips

Passport group:
  [0] Passport — 10 Trips              codes=[10 countries]  trips=[10 trips]
  [1] Passport — World Collection      (if allCodes.length > resolvedCodes.length)
  [2] Customise Passport

Tour Dates group: (same pattern, timeline template is primary)
Flags group: (same pattern)

subtitle: "Celebrating 10 trips logged"
```

### Example 4: year_countries_5 ("Year Explorer", MerchTriggerType.flagGrid)

User visited 5 countries in 2025: FR, IT, ES, PT, GR.

```
resolvedCodes = countries with firstSeen.year == 2025
resolvedTrips = trips with startedOn.year == 2025

Passport group:
  [0] Passport — 2025 Travels          codes=[5 countries] trips=[2025 trips]
  [1] Passport — World Collection      (if allCodes.length > 5)
  [2] Customise Passport

Flags group: (same pattern)
Tour Dates group: (same pattern)

subtitle: "Celebrating 5 countries in 2025"
```

### Example 5: continents_3 ("Continental Drift", MerchTriggerType.milestone)

User has visited countries on 3 continents. Total: 18 countries.

```
resolvedCodes = all 18 visited countries
resolvedTrips = all trips

Passport group:
  [0] Passport — 3 Continents         codes=[all 18] trips=[all]
  (no separate "World Collection" — resolvedCodes IS allCodes)
  [1] Customise Passport

Flags group: (same pattern)
Tour Dates group: (same pattern)

subtitle: "Celebrating 3 continents explored"
```

---

## Acceptance criteria

1. Tapping "Make tee" in `_MerchChip` (Achievement Gallery) pushes `AchievementMerchOptionScreen`.
2. Tapping "Create" in `_MerchMomentTile` (Merch Moments) pushes `AchievementMerchOptionScreen`.
3. `AchievementMerchOptionScreen` displays a grouped list of shirt options appropriate for the achievement.
4. Tapping a shirt option navigates to `LocalMockupPreviewScreen` with the correct artwork bytes, codes, trips, template, and aspect ratio.
5. The full downstream pipeline (mockup → confirmation checkbox → Shopify) is unchanged.
6. The existing Memory Pulse "Print on a t-shirt" path via `PulseMerchOptionScreen` is unaffected.
7. `MerchCountrySelectionScreen` is no longer imported by `achievement_gallery.dart` or `merch_moments_section.dart`.
8. `flutter analyze` passes with no new warnings.

---

## ADR-150 summary

**Decision:** Extract shared rendering infrastructure from `PulseMerchOptionScreen` into
`merch_option_list_widgets.dart`. Create `AchievementMerchOptionScreen` as a sibling
screen that generates `PulseMerchOption` items from achievement context and renders them
using the shared widgets. Memory Pulse path is unchanged. Both paths converge at
`LocalMockupPreviewScreen`.

**Rationale:** `PulseMerchOption` is already a fully abstract merch option that captures
all rendering parameters. The only thing that differs between the two entry points is how
the option list is constructed. Extracting the rendering layer avoids duplication while
keeping the business logic clearly separated.

**Consequences:** `pulse_merch_option_screen.dart` changes its internal implementation
(private → shared widgets) but its public API and behaviour are unchanged. Tests covering
`PulseMerchOptionScreen` remain valid.
