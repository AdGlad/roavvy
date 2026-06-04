# M146 — Annual Travel Story with Merch CTA

## Goal

A full-screen narrative story experience — Spotify Wrapped-style — that presents the
user's year in travel as an animated sequence of reveal cards, ending in a personalised
shirt recommendation. The story is triggered by the Year in Review feature or a
significant achievement, and produces a shareable moment even before the purchase CTA.

---

## Phases & Tasks

### T1 — `TravelStoryData` — year stats aggregation

**New file:** `apps/mobile_flutter/lib/features/merch/travel_story_data.dart`

A data class and builder that aggregates the key stats for a travel story:

```dart
class TravelStoryData {
  const TravelStoryData({
    required this.year,
    required this.countryCodes,
    required this.continentCount,
    required this.tripCount,
    required this.topAchievement,      // most impressive achievement unlocked this year
    required this.identity,            // TravelIdentityInfo
    required this.merchOption,         // PulseMerchOption — best recommendation
    required this.heroCountryCode,     // most-visited or most recent country
  });

  final int year;
  final List<String> countryCodes;
  final int continentCount;
  final int tripCount;
  final Achievement? topAchievement;
  final TravelIdentityInfo identity;
  final PulseMerchOption merchOption;
  final String heroCountryCode;

  static TravelStoryData build({
    required int year,
    required List<EffectiveVisitedCountry> allVisits,
    required List<TripRecord> allTrips,
    required Map<String, DateTime> unlockedAchievements,
  }) { ... }
}
```

The `build()` factory:
- Filters visits and trips to the target `year`.
- Resolves `TravelIdentityInfo.forContext()` from year-specific counts.
- Selects `topAchievement` by merch priority: continent > country milestone > trip.
- Builds `merchOption` using `MerchTemplateRanker.rankFor()` for the year's country set.
- `heroCountryCode`: most recent trip's country code for that year.

### T2 — `TravelStoryScreen` — animated reveal sequence

**New file:** `apps/mobile_flutter/lib/features/merch/travel_story_screen.dart`

Full-screen experience using a `PageView` with `PageController`. Each page is a full
screen card that animates in. The user advances by tapping anywhere or swiping.

**Page sequence:**

```
Page 1: "Your [year] in travel"
         [year in large bold gold]
         [animated globe pulse]
         "Tap to continue"

Page 2: "[N] countries"
         [large animated count-up number]
         [horizontal flag strip of the year's countries]

Page 3: "[N] continents explored"
         [continent highlights on a mini globe render]
         (skip if continentCount == 1)

Page 4: "[Top achievement name]"
         [achievement emoji large]
         "[achievement description]"
         (skip if no achievement this year)

Page 5: "You are a [Identity Name]"
         [identity emoji large, elastic scale-in animation]
         "[identity tagline]"

Page 6 (CTA): "Here is your [year] shirt"
         [MerchOptionFeaturedCard — full screen, no header]
         [Design this shirt] → navigates to LocalMockupPreviewScreen
         [Share this story] → shares a summary card
         [Maybe later] → dismiss
```

Animation per page:
- Entrance: `FadeTransition` + `SlideTransition(Offset(0, 0.05) → Offset.zero)`, 400ms.
- Numbers: `TweenAnimationBuilder` count-up over 800ms.
- Identity emoji: `elasticOut` scale curve (same as `_CelebrationHeader` in M98).

Do not auto-advance — the user controls pacing.

The `TravelStoryScreen` accepts a `TravelStoryData` and is pushed modally
(`fullscreenDialog: true`).

Background: dark navy gradient (`RoavvyColours.backgroundDark` → near-black).
Page indicators: subtle dot row at the bottom.

### T3 — `TravelStorySummaryCard` — shareable image

**New file:** `apps/mobile_flutter/lib/features/merch/travel_story_summary_card.dart`

A `RepaintBoundary`-wrapped widget that renders as a shareable image:

```
┌───────────────────────────────────┐
│  [gradient background]            │
│                                   │
│  [identity emoji  72px]           │
│  Globetrotter                     │
│  2024                             │
│                                   │
│  42 countries · 4 continents      │
│  [small flag strip]               │
│                                   │
│  Roavvy                           │  ← wordmark
└───────────────────────────────────┘
```

Used by the "Share this story" action on Page 6. Export via `RenderRepaintBoundary`
→ `toImage()` → PNG bytes → `Share.shareXFiles()`.

### T4 — Entry points

**Entry point 1: Year in Review banner (map screen / stats screen)**

The existing "Year in Review" feature (M94) should offer "See your travel story" as
a secondary action that opens `TravelStoryScreen`. Build `TravelStoryData` from
current year's data using the providers already loaded on the stats screen.

**Entry point 2: Scan summary screen**

If the scan discovers new countries and pushes the user past a milestone (e.g.
total country count crosses 10, 25, 50), show a "See your travel story" banner
on `ScanSummaryScreen`. Use the all-time data (not year-filtered) for this entry.

**Entry point 3: Achievement unlock (high milestone only)**

For the highest achievement category (50 countries, all 6 continents), the
`_CelebrationHeader` in `AchievementMerchOptionScreen` can offer a "See your full
story" link that pushes `TravelStoryScreen`.

### T5 — Tests

- Unit test: `TravelStoryData.build()` returns correct country count for year filter.
- Unit test: `TravelStoryData.build()` returns correct `heroCountryCode`.
- Widget test: `TravelStoryScreen` renders the correct number of pages for the given data.
- Widget test: Page 6 CTA navigates to `LocalMockupPreviewScreen`.
- Widget test: "Share this story" action on Page 6 calls `MerchShareExporter`.

---

## File Map

```
apps/mobile_flutter/lib/features/merch/
  travel_story_data.dart              NEW  — data aggregation
  travel_story_screen.dart            NEW  — animated story screen
  travel_story_summary_card.dart      NEW  — shareable image widget

apps/mobile_flutter/lib/features/
  [year_in_review or stats screen]    EDIT — "See your travel story" entry
  [scan_summary_screen.dart]          EDIT — milestone story banner

apps/mobile_flutter/test/features/merch/
  travel_story_data_test.dart         NEW  — 2 unit tests
  travel_story_screen_test.dart       NEW  — 3 widget tests
```

---

## ADR-178

**Travel story experience is user-paced, not auto-advancing (M146)**

Decision: `TravelStoryScreen` advances pages on user tap/swipe only, not on a timer.
Auto-advancing (Spotify Wrapped-style) creates anxiety for users who want to read or
linger on a stat. User-paced advances respect the emotional weight of each reveal —
particularly the identity page and the merch CTA page, where pausing and re-reading
is valuable. Auto-advance can always be added later as an opt-in.

Status: Accepted

---

## Definition of Done

- [ ] `TravelStoryData.build()` produces correct year-filtered stats.
- [ ] `TravelStoryScreen` renders all pages in correct sequence with entry animations.
- [ ] Pages are skipped correctly (continent page skipped if count == 1; achievement
      page skipped if no achievement).
- [ ] Page 6 CTA navigates to `LocalMockupPreviewScreen` with the recommended option.
- [ ] "Share this story" generates a PNG summary card and opens the system share sheet.
- [ ] Entry points: Year in Review + Scan Summary + high-milestone Achievement.
- [ ] 5 tests pass.
- [ ] `flutter analyze` — no new warnings.
- [ ] No change to existing Year in Review, scan, or achievement flow behaviour.

**Phase:** 27 — Merch UX
**Depends on:** M145
