# M162 — Country Profile: Rich Destination Screen

**Status: Complete**

## Design Vision

Every visited country deserves to feel like opening a destination page — a personal record of time spent, places discovered, and memories made. The current bottom sheet is a utility panel. This milestone replaces it with `CountryProfileScreen`: a full-screen, cinematic profile that makes the user feel proud of what they've explored.

The target emotional response: **"I've actually done all this."**

**No new data is collected.** All content comes from existing Drift tables (`trips`, `region_visits`, `visited_heritage_sites`) and the bundled WHS dataset. This is a presentation and architecture upgrade.

**Prerequisites:** M119 (heritage detection + `HeritageRepository`), M135 (region detection + `CountryRegionMapScreen`).

---

## Architecture Change: Sheet → Full Screen

**Before:** Tapping a visited country opens `CountryDetailSheet` (DraggableScrollableSheet, ~60% height). Detail content is cramped. Parallax, large imagery, and horizontal scrolling are all impossible.

**After:**
- Tapping a **visited** country pushes `CountryProfileScreen` (full `Scaffold` with `CustomScrollView`).
- Tapping an **unvisited** country still shows a lightweight bottom sheet with the "Add to my countries" action.

This single architectural change unlocks the entire design below.

---

## Screen Layout: `CountryProfileScreen`

```
┌─────────────────────────────────────────────┐
│  HERO (200–260 px, parallax on scroll)      │
│  [Best hero photo]              [← Back]    │
│  ──────────────────────────────────────── ↓ │
│  🇯🇵  JAPAN          [continent chip]  [⬆]  │
│  First visited 2018  ·  Last visit 2024      │
├─────────────────────────────────────────────┤
│  PERSONAL NARRATIVE (glass card)            │
│  "You've spent 47 days in Japan across      │
│   3 trips. First adventure: Spring 2018."   │
├─────────────────────────────────────────────┤
│  STATS STRIP (animated count-up)            │
│  [3]      [47]    [284]   [6]    [3]        │
│  Trips    Days    Photos  Rgns   UNESCO     │
├─────────────────────────────────────────────┤
│  EXPLORE REGIONS                            │
│  [Map card with continent gradient]         │
│  ◐  6 of 47 regions explored   [>]          │
├─────────────────────────────────────────────┤
│  UNESCO WORLD HERITAGE                      │
│  3 of 25 sites visited ────●──○──○──        │
│  [Horizontal site cards, gold glow]→→→      │
│  [Unvisited cards dimmed]→→→                │
├─────────────────────────────────────────────┤
│  PHOTOS FROM HERE                           │
│  [□][□][□][□][□]→→→  View all (284)         │
├─────────────────────────────────────────────┤
│  YOUR VISITS                                │
│  │ 2024 ─── Aug–Sep  ·  18 days  ·  88 📷  │
│  │ 2022 ─── Mar      ·  12 days  ·  121 📷 │
│  │ 2018 ─── Nov–Dec  ·  17 days  ·  75 📷  │
│  + Add visit manually                       │
└─────────────────────────────────────────────┘
```

---

## Section Specifications

### 1. Hero

- Uses existing `HeroImageView` asset (best photo from `bestHeroForCountryProvider`).
- Parallax: `SliverAppBar` with `expandedHeight: 240`, `flexibleSpace: FlexibleSpaceBar(background: HeroImageView(...))`. Continent-colour gradient overlay as fallback.
- Collapsed state: shows flag emoji + country name in the `AppBar` title with the continent-accent colour.
- Back button (top left). Share button (top right, see §Share below).
- If no hero photo: full gradient in continent colour with a subtle world-grid `CustomPaint` watermark.

### 2. Personal Narrative Card

A single sentence, glass-card style (`BackdropFilter` blur + semi-transparent background), generated from `CountryStats`:

| Condition | Sentence |
|---|---|
| 1 trip | "You've spent {N} days in {Country}. First and only visit: {Month} {Year}." |
| 2+ trips | "You've spent {N} days in {Country} across {T} trips. First adventure: {Season} {Year}." |
| Manual-only (no dates) | "You've visited {Country} — add trips to see your full story." |
| UNESCO X == Y (all visited) | Append: "You've visited every UNESCO site here." |

Season: Dec–Feb → Winter, Mar–May → Spring, Jun–Aug → Summer, Sep–Nov → Autumn. Based on trip `startedOn` month.

Typography: `bodyLarge`, 16 sp, italic, continent accent colour for the country name inline. Padding: 20 px horizontal, 16 px vertical.

### 3. Stats Strip

Five tiles in an `IntrinsicHeight` `Row` with vertical dividers between them.

| Tile | Value | Label |
|---|---|---|
| Trips | `tripCount` | "Trips" |
| Days | `totalDays` | "Days" |
| Photos | `totalPhotos` | "Photos" |
| Regions | `visitedRegions` | "Regions" |
| UNESCO | `visitedHeritageSites` | "UNESCO" |

**Count-up animation:** Each number animates from 0 to its final value over 800 ms using a `CurvedAnimation(curve: Curves.easeOut)`. Stagger: each tile starts 80 ms after the previous.

Number typography: 28 sp, `FontWeight.w800`, continent accent colour.
Label typography: 11 sp, `FontWeight.w500`, `onSurfaceVariant`.

Show `—` if `totalDays == 0` (manual trips without dates). Show `—` for Photos if no photo evidence.

### 4. Region Map Card

Full-width tappable card, height 100 px.

**Left half:** A `CustomPaint` canvas drawing the visited/unvisited region polygons at small scale (reuse polygon data already in memory — draw as tiny scaled shapes, not a real map tile). Continent-colour fill for visited regions. This is a decorative thumbnail, not interactive.

**Right half:**
```
◐  6 of 47 regions visited
   Explore the regional map →
```

The `◐` is a `CustomPaint` half-filled circle (progress arc) in continent colour showing `visitedRegions / totalRegions` fraction.

Hidden entirely if `totalRegions == 0`.

Tap → `Navigator.push(CountryRegionMapScreen(countryCode: isoCode))`.

### 5. UNESCO Heritage Sites

**Section header:**
```
UNESCO World Heritage Sites
3 of 25 visited
```

Progress dots row: a horizontal strip of small circles — filled gold for visited, outline grey for unvisited. Maximum 20 dots shown (if Y > 20, show first 20 with a "+N more" label). This gives instant visual scan of completion.

**Horizontal scrolling site cards** (`ListView.builder`, `scrollDirection: Axis.horizontal`, card width: 200 px, height: 160 px):

Visited card:
```
╔══════════════════════════════╗  ← Gold border (2 px) + subtle gold glow
║  [Cultural / 🏛]   1983      ║
║                              ║
║  Mount Fuji                  ║
║                              ║
║  ◉ 0.8 km  ·  Strong match  ║
╚══════════════════════════════╝
```

Unvisited card (same layout, greyed out, no distance row):
```
╔══════════════════════════════╗  ← Border: `outline` colour, 50% opacity
║  [Natural / 🌿]    1993      ║
║                              ║
║  Shiretoko                   ║
║                              ║
║  Not yet visited             ║
╚══════════════════════════════╝
```

Category colours:
- Cultural: amber `#F2C94C` (Roavvy Gold)
- Natural: mint `#2ED8B6` (Roavvy Mint)
- Mixed: coral `#FF6B6B` (Roavvy Coral)

Category icon top-left of card. Inscription year top-right, small, `onSurfaceVariant`.

Visited cards come first; unvisited cards follow in the same horizontal scroll (not a separate collapsed section — always visible, but visually distinct).

Tap visited card → `HeritageDetailSheet(site: ...)`.
Tap unvisited card → same sheet (name, location, category — no personal data shown).

Hide entire section if `totalHeritageSites == 0`.

**All-visited celebration:** If `visitedHeritageSites == totalHeritageSites`, replace the progress dots with a gold trophy badge row: `🏆 You've visited all UNESCO sites in [Country]`. Apply a brief confetti burst on first view (use `_hasShownCelebration` local flag stored in widget state, reset per screen open).

### 6. Photos From Here

A horizontal photo strip: `ListView.builder` with `scrollDirection: Axis.horizontal`, photo size 100×100 px, gap 4 px. Shows up to 20 photos. Rounded corners (8 px). Loads from `visitRepositoryProvider.loadAssetIds(isoCode)`.

"View all (N) →" text button at the end of the strip that pushes `PhotoGalleryScreen(assetIds: allIds)`.

Hidden if `totalPhotos == 0`.

### 7. Your Visits (Timeline)

A vertical timeline. Each trip:

```
│
●  Aug–Sep 2024
│  18 days  ·  88 photos  [Edit]
│
●  Mar 2022
│  12 days  ·  121 photos  [Edit]
│
●  Nov–Dec 2018 ← FIRST VISIT badge
   17 days  ·  75 photos  [Edit]
```

The timeline line: 2 px wide, continent accent colour, runs through `●` markers.
First visit: small gold "FIRST VISIT" chip next to the year.
Most recent trip: small blue "MOST RECENT" chip.

Long-press on a trip card → existing delete confirmation dialog (unchanged).
`[Edit]` icon button → existing `TripEditSheet`.
"+ Add visit manually" text button below the last trip.

---

## Share Action

Share button (top-right of `AppBar`, `Icons.ios_share`):

Generates and shares a text summary:
```
🇯🇵 Japan — My Roavvy Story

3 trips  ·  47 days  ·  284 photos
6 regions explored
3 of 25 UNESCO World Heritage Sites visited

Track your travels: roavvy.app
```

Uses existing `Share.share()` (the `share_plus` package already in the project).

---

## Unvisited Country: Bottom Sheet (unchanged)

When tapping an unvisited country the existing lightweight bottom sheet still appears:
- Country name
- "You haven't visited [Country] yet"
- If the country has WHS: "Home to X UNESCO World Heritage Sites" (data from lookup service)
- "Add to my countries" filled button

This keeps the unvisited flow fast and non-intrusive. No full-screen push for unvisited.

---

## Motion & Animation

| Moment | Animation |
|---|---|
| Screen enters | Hero image fades in; content sections stagger up (40 px translateY, opacity 0→1), 60 ms interval per section |
| Stats strip | Numbers count up 0→value, 800 ms, `Curves.easeOut`, staggered 80 ms per tile |
| Heritage cards | Slide in from right on section entering viewport (`VisibilityDetector` or `SliverFillViewport`) |
| All-UNESCO celebration | 1.5 s confetti burst (existing confetti system) on first open |
| Photo strip | Subtle fade-in, no count-up |
| Timeline | Dots animate in top-to-bottom with 100 ms interval |

All animations use existing `AnimationController` patterns. No new packages required.

---

## Computed Values: `CountryStats`

```dart
class CountryStats {
  final int tripCount;
  final int totalDays;
  final int totalPhotos;
  final int visitedRegions;
  final int totalRegions;
  final int visitedHeritageSites;
  final int totalHeritageSites;
  final int? firstVisitYear;
  final int? lastVisitYear;
  final DateTime? firstTripStart;   // for season calculation
  final bool allSitesVisited;       // visitedHeritageSites == totalHeritageSites && totalHeritageSites > 0

  String get narrativeText { ... }  // generated sentence
}
```

---

## Phases & Tasks

### T1 — `WorldHeritageLookupService`: public country accessor

```dart
static List<WorldHeritageSite> sitesForCountry(String countryCode) =>
    List.unmodifiable(_index[countryCode] ?? const []);
```

### T2 — `CountryStats` value class + narrative generator

`features/map/country_stats.dart`

- `CountryStats.compute(...)` factory: sums days, photos, derives first/last year and season.
- `narrativeText` getter: selects the appropriate sentence template.
- `allSitesVisited` bool.

### T3 — `CountryDetailNotifier`

`features/map/country_detail_notifier.dart` — Riverpod `AsyncNotifier`:

Parallel `Future.wait`:
- `TripRepository.loadByCountry(isoCode)`
- `RegionRepository.loadByCountry(isoCode)`
- `HeritageRepository.loadByCountry(isoCode)`
- `visitRepositoryProvider.loadAssetIds(isoCode)` (for photo strip)

Computes `CountryStats`, `unvisitedSites`, exposes all data.

### T4 — `CountryProfileScreen` (new full-screen route)

`features/map/country_profile_screen.dart`

`CustomScrollView` with `SliverAppBar` (hero) + `SliverList` of sections. Wires `CountryDetailNotifier`. Accepts `isoCode`, `visit` (nullable), `onAdd` (nullable, for sheet only).

Stagger animation controller: `_staggerController` with 7 intervals (one per section). Starts on `initState` after notifier loads.

### T5 — Map tap routing update

`features/map/` — wherever the country tap handler currently calls `showModalBottomSheet(CountryDetailSheet(...))`:

- If `visit != null`: `Navigator.of(context).push(MaterialPageRoute(builder: (_) => CountryProfileScreen(...)))`.
- If `visit == null`: keep existing bottom sheet (unvisited flow).

The `CountryDetailSheet` file is retained for the unvisited state but its visited-country code is removed.

### T6 — `_NarrativeCard` widget

Glass card: `ClipRRect` → `BackdropFilter(filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10))` → `Container(color: Colors.white.withValues(alpha: 0.12))` → narrative text. Continent-colour italic span for the country name.

### T7 — `_StatsStrip` widget with count-up

Row of 5 `_StatTile` widgets. Each tile has its own `AnimationController` (created in strip, disposed in strip). Stagger via `Future.delayed(Duration(milliseconds: 80 * index))` before starting controller.

`_StatTile` uses `AnimatedBuilder` to display `(value * animation.value).round()`.

### T8 — `_RegionMapCard` widget

`CustomPaint` thumbnail of country polygons (scaled to card bounds). Progress arc (`◐`). Continent gradient background. Tap → push `CountryRegionMapScreen`.

Polygon thumbnail: scale all vertices to fit a ~100×80 px canvas. Draw visited in continent colour, unvisited in `Colors.white.withValues(alpha: 0.2)`.

### T9 — `_HeritageSitesSection` widget

Progress dots row. Horizontal `ListView` of `_HeritageSiteCard` widgets.
`_HeritageSiteCard`: `Container` with `BoxDecoration(border: Border.all(color: ..., width: 2), borderRadius: ..., boxShadow: [BoxShadow(color: goldColor.withValues(alpha: 0.3), blurRadius: 8)])` for visited state.
All-visited confetti trigger.

### T10 — `_PhotoStrip` widget

`SizedBox(height: 100)` + `ListView.builder(scrollDirection: Axis.horizontal)`. Photo tiles use existing photo asset loading pattern. "View all" button at end of list.

### T11 — `_VisitTimeline` widget

`Column` of `_TimelineEntry` widgets. Each: a `Row` with a left column (line + dot) and right column (date range, duration, photo count, edit button). First/most-recent chips as `Container` with rounded corners, Roavvy Gold / Roavvy Blue background.

### T12 — Share action

`_shareCountryStory(CountryStats stats, String isoCode, String name)` — builds the text block, calls `Share.share(...)`. Connected to `AppBar` action button.

### T13 — Unvisited bottom sheet enhancement

Add to the unvisited bottom sheet: "Home to X UNESCO World Heritage Sites" line (from `WorldHeritageLookupService.sitesForCountry`) if X > 0. One-line change to existing sheet.

### T14 — Tests

`test/features/map/country_stats_test.dart`:
- `totalDays` sums correctly across trips
- `narrativeText` uses "1 trip" singular correctly
- `narrativeText` selects correct season from month
- `allSitesVisited` true when counts match, false when Y == 0
- `firstVisitYear` picks earliest trip

`test/features/map/country_detail_notifier_test.dart`:
- Loads three repos in parallel (mock repos)
- `unvisitedSites` = allSites minus visitedSites by siteId
- `stats.allSitesVisited` propagated correctly

---

## File Map

```
apps/mobile_flutter/lib/
  features/heritage/
    world_heritage_lookup_service.dart      EDIT — add sitesForCountry()

  features/map/
    country_stats.dart                      NEW  — value class + narrative
    country_detail_notifier.dart            NEW  — AsyncNotifier
    country_profile_screen.dart             NEW  — full-screen profile
    country_detail_sheet.dart               EDIT — remove visited branch; unvisited only + WHS hint
    [map tap handler file]                  EDIT — route visited → CountryProfileScreen

  core/providers.dart                       EDIT — countryDetailNotifierProvider

apps/mobile_flutter/test/features/map/
  country_stats_test.dart                   NEW
  country_detail_notifier_test.dart         NEW
```

---

## ADRs

- **ADR-009 (revised):** `CountryProfileScreen` is a full push route, not a bottom sheet. The rich content (parallax hero, horizontal scrolls, timeline, animations) is incompatible with a sheet. Unvisited countries retain the lightweight sheet for fast "Add" access.
- **ADR-010:** All UNESCO content sourced from `WorldHeritageLookupService` (offline, bundled). No Firestore or network call.
- **ADR-011:** `CountryStats` computed on load; not persisted. Three small Drift queries + one lookup service call.
- **ADR-012:** Polygon thumbnail in `_RegionMapCard` is a decorative scaled render of the existing in-memory polygon data. It is not a real map tile and requires no additional packages.
- **ADR-013:** Count-up animations use `AnimationController` per tile; all controllers disposed in the strip widget's `dispose()`. No animation packages added.

---

## Definition of Done

- [x] Tapping a visited country pushes `CountryProfileScreen` (full screen); unvisited still shows bottom sheet
- [x] Hero image with parallax scroll; continent gradient fallback; collapsed AppBar shows flag + name
- [x] Share button generates country story text and opens system share sheet
- [x] Narrative card shows correct sentence for 1-trip, multi-trip, and manual-only cases
- [x] Stats strip: all 5 tiles animate count-up; `—` shown for missing days/photos
- [x] Region map card: progress arc correct; hidden for countries with no region data; tap opens `CountryRegionMapScreen`
- [x] UNESCO section: progress dots correct count; horizontal scroll shows visited (gold border) and unvisited (dimmed) cards in same list
- [x] All-visited state: trophy message shown
- [x] Heritage section hidden for countries with no WHS
- [x] Photo strip shows up to 20 photos; "View all" pushes `PhotoGalleryScreen`; strip hidden if no photos
- [x] Trip timeline shows first-visit and most-recent chips; edit/delete unchanged
- [x] Unvisited bottom sheet shows WHS count hint if country has sites
- [x] `CountryStats` tests pass (14/14)
- [x] Zero new `flutter analyze` warnings
- [x] `CountryDetailSheet` retains only unvisited-country code; visited path removed
- [x] Docs updated; `index_docs.py` run
