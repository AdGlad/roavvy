# Travel Timeline Refactor — M147–M154

## Context

The travel timeline (`features/travel_timeline/`) exists as a functional first pass:
snake-path `CustomPaint` canvas, emoji flag nodes, achievement milestone nodes.
It works but doesn't match the premium/cinematic bar set by the rest of the app.

This document plans 8 focused milestones to bring the timeline up to product quality.
Each milestone is independently shippable and reviewable.

---

## Sequence overview

| # | Name | Delivers | Depends on |
|---|---|---|---|
| M147 | Foundation fixes | Stable base, correct routing, no layout bugs | — |
| M148 | Premium node visuals | Redesigned trip + achievement nodes | M147 |
| M149 | Year group headers | Temporal context on scroll | M147 |
| M150 | Path & motion | Animated path draw-on, stagger entry | M148, M149 |
| M151 | Trip detail sheet | Tap → detail + actions (map, merch, share) | M148 |
| M152 | Stats header panel | Pinned stats + "Share journey" CTA | M149 |
| M153 | Journey share card | Exportable card from stats header CTA | M152 |
| M154 | Filter & year jump | Continent filter, year index, search | M149, M152 |

---

## M147 — Travel Timeline: Foundation & Routing

**Phase:** 28 — Timeline UX
**Goal:** Stabilise the existing code before visual changes. Fix label overflow, wire up navigation, improve empty state copy, add proper date formatting.

### PM rationale
The current label column is capped at 100 px and clips long country names. The screen also isn't wired into the main shell nav. Fix the floor before building the ceiling.

### Scope

| File | Change |
|---|---|
| `travel_timeline_screen.dart` | `_kLabelWidth` → `Flexible`; date formatter (e.g. "Mar 2024" not just "2024"); clamp label to 3 lines not 2; fix `isLeft` calculation to use `canvasWidth * 0.5` not 0.4 |
| `main_shell.dart` | Add Timeline tab to bottom nav (Journey icon, label "Journey") |
| `go_router` config | Register `/timeline` route pointing at `TravelTimelineScreen` |
| `_EmptyTimeline` | Rewrite copy: "Your journey map starts here. Scan your photos to trace every country you've visited." |

### Tests
- Widget test: empty state renders copy correctly.
- Widget test: label `Flexible` doesn't overflow at 320 px screen width.

---

## M148 — Travel Timeline: Premium Node Visuals

**Phase:** 28 — Timeline UX
**Goal:** Redesign trip and achievement nodes to feel premium and emotionally resonant — flag as hero, scene icon as badge, gold "first visit" star, gradient achievement ring.

### PM rationale
The flag emoji inside a plain circle is functional but flat. The design system says "preview first — visual content over controls." The flag should be the hero of each node, not an afterthought.

### UI design spec

**Trip node (first visit)**
- 68×68 dp circle with a radial gradient fill (primary → primaryContainer)
- SVG flag from `assets/flags/svg/{cc}.svg` at 36×24 dp, centred
- Scene emoji at 13 sp, bottom-left badge position (24×24 dp offset circle, surface color)
- Gold star badge (⭐, 14×14 dp) at top-right, `secondary` color ring
- Label: country name in `labelMedium` bold, month+year in `labelSmall` muted

**Trip node (repeat visit)**
- 56×56 dp circle, `surfaceContainerHighest` fill, `outline` border
- Flag at 28×18 dp, scene badge same as above
- No star badge
- Label: country name `labelSmall` normal weight

**Achievement node**
- 76×76 dp circle, animated gradient ring (secondary → tertiary, 3 dp, dashed)
- Achievement emoji at 32 sp centred
- Glow: `BoxShadow` with secondary color, `blurRadius: 20, spreadRadius: 2`
- Label: achievement title in `labelMedium` bold secondary, "N countries" in `labelSmall`

### Scope

| File | Change |
|---|---|
| `travel_timeline_screen.dart` | `_TripNode`, `_AchievementNode`, `_NodeCircle` redesigned per spec |
| `travel_timeline_screen.dart` | New `_SceneBadge` widget; new `_FirstVisitBadge` widget |
| `_kNodeRadius` | 34.0 (first visit), 28.0 (repeat); `_kAchievementRadius` → 38.0 |

### Tests
- Widget test: first-visit node renders star badge; repeat-visit does not.
- Widget test: achievement node renders emoji at correct size.

---

## M149 — Travel Timeline: Year Group Headers

**Phase:** 28 — Timeline UX
**Goal:** Insert year header items between year groups in the timeline. "2024 · 8 countries · 3 continents" floating card anchored to the snake path.

### PM rationale
With 40+ trips on a long timeline, users lose temporal context while scrolling. Year headers give the "I remember that year" moment and make the timeline scannable.

### UI design spec

**Year header node**
- Horizontally centred pill: 200×44 dp, `secondaryContainer` fill, 22 dp radius
- Text: `"2024  ·  8 countries  ·  3 continents"` in `labelMedium` bold
- Connects to snake path above and below (same curve logic as trip nodes)

### Scope

| File | Change |
|---|---|
| `travel_timeline_screen.dart` | Add `_YearHeaderItem` to `_TimelineItem` sealed class |
| `travel_timeline_screen.dart` | `_buildTimeline` injects `_YearHeaderItem` at year boundaries |
| `travel_timeline_screen.dart` | `_YearHeaderNode` widget (pill card, no label column) |
| `timeline_painter.dart` | `computeTimelinePositions` maps year headers to `centerX` always |

### Tests
- Unit test: `_buildTimeline` produces year headers at correct boundaries.
- Unit test: two trips in same year → one header.

---

## M150 — Travel Timeline: Path & Motion

**Phase:** 28 — Timeline UX
**Goal:** Animated path draw-on on first load; staggered node entry (scale + fade); path colour shifts by decade (warm → cool gradient along the path length).

### PM rationale
The current static snake path is readable but flat. Animation turns the timeline into a "story being told" — reinforcing the cinematic feel the scan replay established.

### UI design spec

**Path animation**
- On first render: path draws from top→bottom over 1200 ms, `Curves.easeInOut`
- Use `PathMetrics` + `extractPath` driven by an `AnimationController`
- Subsequent renders (scroll restore): skip animation (use `ValueNotifier<bool> _hasAnimated`)

**Node stagger**
- Each node fades in (0→1 opacity) + scales (0.6→1.0) with 40 ms offset per node
- Total stagger window: min(nodes × 40 ms, 800 ms)
- Use `AnimatedBuilder` over a single controller with `Interval` curves

**Path gradient**
- Replace solid `pathColor` with a `Gradient` shader on the paint
- Map path position 0.0→1.0 to a warm→cool sweep:  
  `[Color(0xFFFF8C42), Color(0xFF4FC3F7)]` (orange → sky)

### Scope

| File | Change |
|---|---|
| `timeline_painter.dart` | `pathProgress` param (0.0–1.0); shader gradient paint |
| `travel_timeline_screen.dart` | `_TimelineBody` → `StatefulWidget`; `AnimationController` for path + stagger |
| `travel_timeline_screen.dart` | `_hasAnimated` flag persisted via `PageStorageBucket` |

### Tests
- Widget test: at `pathProgress=0.5` only first half of path is drawn (mock painter).
- Widget test: nodes are invisible at t=0, visible at t=1.

---

## M151 — Travel Timeline: Trip Detail Bottom Sheet

**Phase:** 28 — Timeline UX
**Goal:** Tap any trip node → `DraggableScrollableSheet` with country hero, date range, trip duration, and action row (View on Map · Design a shirt · Share).

### PM rationale
The timeline currently shows but doesn't let users *do* anything. Detail + actions converts the timeline from a display into a navigation hub — fulfilling the design system's "emotionally rewarding + shareable" goal.

### UI design spec

**Sheet layout (collapsed: 40%, expanded: 75% screen height)**
- Hero: full-width flag SVG + country name overlay (bottom-aligned, `displaySmall`)
- Scene emoji as circular badge over flag, bottom-right
- Date row: "12 Mar 2024 → 18 Mar 2024  ·  6 nights"
- If first visit: gold banner "First time in [Country]"
- Repeat count: "Visit #3" label if applicable
- Action row (3 buttons, full-width, spaced):
  - `View on Map` → pops sheet + navigates to map filtered to country
  - `Design a shirt` → pushes to `PulseMerchOptionScreen` for country
  - `Share` → triggers `Share.share` with trip summary text

**Achievement sheet (tap achievement node)**
- Achievement emoji large centred
- Title + description
- "X countries reached" progress context
- Single CTA: "Design your achievement shirt" (→ `AchievementMerchOptionScreen`)

### Scope

| File | Change |
|---|---|
| `travel_timeline_screen.dart` | `_TripNode` + `_AchievementNode` wrapped in `GestureDetector` |
| New: `trip_detail_sheet.dart` | `TripDetailSheet` + `AchievementDetailSheet` |
| `go_router` | Pass `countryCode` query param to map screen for country-filtered view |

### Tests
- Widget test: tapping trip node opens bottom sheet.
- Widget test: sheet shows "First time in [Country]" only for first-visit trips.

---

## M152 — Travel Timeline: Stats Header Panel

**Phase:** 28 — Timeline UX
**Goal:** Non-scrolling header above the timeline: total countries, continents, years travelling, "since YYYY", mini continent strip, "Share your journey" CTA.

### PM rationale
The design system's emotional goal is "I've actually done all this." A sticky header showing aggregate stats delivers that moment before the user even starts scrolling. It also provides the natural entry point for the share flow (M153).

### UI design spec

**Header (fixed, ~120 dp tall)**
- Background: `surface` with subtle gradient to transparent at bottom edge
- Three stat chips in a row:
  - `🌍 47 countries`
  - `🗺️ 6 continents`  
  - `📅 Since 2018`
- Continent strip: 6 small 12×12 dp dots (one per continent), filled if visited
- CTA: `"Share your journey"` → outlined button, full width, bottom of header
- Separator: thin divider between header and scrollable timeline

### Scope

| File | Change |
|---|---|
| `travel_timeline_screen.dart` | `TravelTimelineScreen` body → `Column(header + Expanded(scroll))` |
| New: `_TimelineStatsHeader` | Stat chips, continent dots, share CTA |
| `travel_timeline_screen.dart` | Derive `continentSet` + `sinceYear` from `items` in `data:` branch |

### Tests
- Widget test: header shows correct country count from provider data.
- Widget test: share CTA button is present.

---

## M153 — Travel Timeline: Journey Share Card

**Phase:** 28 — Timeline UX
**Goal:** "Share your journey" CTA renders a `RepaintBoundary` image — a cinematic card showing the snake path miniature, flag parade, and stats — then invokes `share_plus`.

### PM rationale
Shareable moments are the primary virality lever. The scan summary already has a share card (M127); the timeline needs its own persistent version so users can share at any time, not just post-scan.

### UI design spec

**Card (1080×1920 logical px, rendered off-screen)**
- Dark gradient background (`Color(0xFF0D1117)` → `Color(0xFF1A2340)`)
- Roavvy wordmark top-left
- Snake path miniature (re-rendered at small scale using `TimelinePainter`)
- Flag parade: first 20 flags in visit order, 28×20 dp each, slight overlap
- Stats block: "47 countries  ·  6 continents  ·  Since 2018"
- Bottom CTA text: "Track your travels at roavvy.com"

**Export flow**
- User taps "Share your journey" → loading indicator → `RenderRepaintBoundary.toImage(pixelRatio: 3)` → temp file → `Share.shareXFiles`

### Scope

| File | Change |
|---|---|
| New: `journey_share_card.dart` | Off-screen card widget inside `RepaintBoundary` |
| New: `journey_share_exporter.dart` | `JourneyShareExporter.export(items)` async → `XFile` |
| `travel_timeline_screen.dart` | `_TimelineStatsHeader` share CTA calls exporter |

### Tests
- Unit test: exporter produces non-null bytes for a 3-item trip list.

---

## M154 — Travel Timeline: Filter & Year Jump

**Phase:** 28 — Timeline UX
**Goal:** Continent filter chips above the timeline, "First visits only" toggle, and a floating year-jump index so users can jump directly to a year.

### PM rationale
Users with 100+ trips need navigation tools. This is a power-user polish milestone — deliver it last so it doesn't shape the architecture of earlier milestones.

### UI design spec

**Filter bar (below stats header, scrolls with content or pinned TBD)**
- Horizontal chip scroll: `All · Europe · Asia · Americas · Africa · Oceania`
- Toggle chip: `★ First visits only`
- Active chip: `primary` fill, white label
- Inactive chip: `surfaceContainerHighest`, default label

**Year jump (floating right-side index)**
- Thin vertical strip of tappable year labels (`labelSmall`, muted)
- Tap year → `ScrollController.animateTo` to that year's header position
- Only shows if timeline has ≥ 3 distinct years

### Scope

| File | Change |
|---|---|
| `travel_timeline_screen.dart` | `_activeContinent`, `_firstVisitOnly` state; `_filteredItems` derived list |
| `travel_timeline_screen.dart` | `_FilterBar` widget |
| `travel_timeline_screen.dart` | `_YearJumpIndex` widget + `Map<int, double>` year→offset lookup built during layout |
| `timeline_painter.dart` | `computeTimelinePositions` takes filtered item count (no change to API needed) |

### Tests
- Unit test: filtering to "Europe" removes non-European trips from `_filteredItems`.
- Unit test: "first visits only" toggle removes repeat-visit `_TripItem`s.
- Widget test: year jump strip appears only when ≥ 3 distinct years present.

---

## Architecture notes (cross-milestone)

**State management:** All new state stays in `ConsumerStatefulWidget` local to `TravelTimelineScreen`. No new global providers needed until M154 filter state needs to persist across nav (use `PageStorageKey` if that becomes desirable).

**File structure after M154:**
```
features/travel_timeline/
  travel_timeline_screen.dart      (screen + filter state)
  timeline_painter.dart            (path layout + painter)
  country_scene_icons.dart         (unchanged)
  trip_detail_sheet.dart           (M151)
  journey_share_card.dart          (M153)
  journey_share_exporter.dart      (M153)
```

**No new packages needed** — all visuals use existing Flutter primitives, `flutter_svg` (already in tree for flags), and `share_plus` (already a dependency).
