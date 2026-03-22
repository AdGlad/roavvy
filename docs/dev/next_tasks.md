# M23 — Phase 11 Slice 2: Region Progress + Rovy

**Planner:** 2026-03-22
**Branch:** `milestone/m23-region-progress-rovy`

---

## Goal

Users see region completion progress on the map at a glance. Rovy provides contextual encouragement. The "one more country" nudge drives re-engagement.

---

## Scope

**Included:**
- `RegionChipsMarkerLayer` — floating progress chips on map at region centroids (zoom-gated ≥ 4)
- `TargetCountryLayer` — solid amber border + breathing fill on "1-away" countries
- `RegionDetailSheet` — bottom sheet with visited/unvisited country list per region
- `RovyBubble` + `rovyMessageProvider` + trigger wiring at 5 event sites

**Excluded:**
- Custom sub-continental overlays (Scandinavia, Benelux, etc.)
- Milestone cards
- Social ranking
- Rovy SVG/PNG asset (placeholder circle used)
- Firestore sync for region progress data

---

## Tasks

### Task 86 — `Region` enum + `RegionProgressNotifier` ✅ Done

**Status:** Already implemented and committed on main.

**Deliverable:**
- `Region` enum (6 values) in `packages/shared_models/lib/src/region.dart`
- `RegionProgressData` data class + `computeRegionProgress()` + `kRegionCentroids` + `regionProgressProvider` in `apps/mobile_flutter/lib/features/map/region_progress_notifier.dart`

**Acceptance criteria:** ✅ All met. Task 86 is complete.

---

### Task 87 — `RegionChipsMarkerLayer` 🔄 In Progress

**Deliverable:**
- `apps/mobile_flutter/lib/features/map/region_chips_marker_layer.dart`
- Wired into `apps/mobile_flutter/lib/features/map/map_screen.dart`

**Acceptance criteria:**
- `ConsumerStatefulWidget` that returns a `MarkerLayer`
- Chips only visible when map zoom ≥ 4.0 (watch `MapCamera` from `FlutterMapState`)
- Each marker: 80×40 chip showing "N/M [Region]" with arc progress ring via `CustomPainter`
- Arc fraction = `visitedCount / totalCount`; full ring shows an amber checkmark when complete
- Chip style: white background, amber border (2px), small text (11sp), `BorderRadius.circular(20)`
- Tapping a chip opens `RegionDetailSheet` for that region (requires Task 88 sheet)
- Wired into `FlutterMap.children` in `map_screen.dart`
- Widget tests in `test/features/map/region_chips_marker_layer_test.dart`:
  - Renders empty `MarkerLayer` (no chips) when zoom < 4
  - Renders one chip per region when zoom ≥ 4
  - Chip text reflects visitedCount / totalCount

**Dependencies:** Task 86 (complete).

**Risks:** `MapCamera` / `FlutterMapState` access pattern — use `MapCamera.of(context)` or listen to `MapController` stream; verify API with existing flutter_map version.

---

### Task 88 — `TargetCountryLayer` + `RegionDetailSheet`

**Deliverable:**
- `apps/mobile_flutter/lib/features/map/target_country_layer.dart`
- `apps/mobile_flutter/lib/features/map/region_detail_sheet.dart`
- Both wired into `map_screen.dart`

**Acceptance criteria:**

`TargetCountryLayer`:
- `ConsumerStatefulWidget` with `AnimationController` (2400ms, repeat reverse)
- Tween: opacity 0.10 → 0.25 (breathing amber fill)
- Watches `regionProgressProvider` + `polygonsProvider`
- Target countries = ISO codes in regions where `remaining == 1 && visitedCount > 0` (derived from `kCountryContinent`)
- Renders as `PolygonLayer`: `borderColor: Color(0xFFFFB300)`, `borderStrokeWidth: 2.5`, fill = amber with animated opacity
- In reduced-motion mode: static opacity 0.175 (midpoint)
- **No** `CustomPainter`; **no** dashed borders
- Wired into `FlutterMap.children` in `map_screen.dart`

`RegionDetailSheet`:
- Top-level function `showRegionDetailSheet(BuildContext context, RegionProgressData data, List<EffectiveVisitedCountry> visits)`
- Uses `showModalBottomSheet`
- Header: region display name + "N of M countries"
- Callout: "You need X more to complete [Region]" (hidden when `isComplete`)
- Body: visited section (country names with ✓) + unvisited section (country names with ○)
- Country names from `kCountryNames` map (ISO code fallback)
- Countries scoped to region via `kCountryContinent`

Tests in `test/features/map/target_country_layer_test.dart`:
- Renders empty `PolygonLayer` when no regions are 1-away
- Renders polygon layer when a region has `remaining == 1 && visitedCount > 0`

**Dependencies:** Task 86 (complete). Task 87 wires chip-tap to call `showRegionDetailSheet`.

---

### Task 89 — `RovyBubble` + `rovyMessageProvider` + trigger wiring

**Deliverable:**
- `apps/mobile_flutter/lib/features/map/rovy_bubble.dart`
- Trigger wiring in `apps/mobile_flutter/lib/features/scan/scan_summary_screen.dart`
- `RovyBubble()` added as `Positioned` child in `map_screen.dart`

**Acceptance criteria:**

`rovy_bubble.dart` contains:
- `RovyTrigger` enum: `newCountry, regionOneAway, milestone, postShare, caughtUp`
- `RovyMessage` class: `{ final String text; final RovyTrigger trigger; final String? emoji; }`
- `rovyMessageProvider`: `StateProvider<RovyMessage?>((_) => null)`
- `RovyBubble` widget: `ConsumerStatefulWidget`, `Positioned(bottom: 120, right: 16)`
  - Avatar: 48px circle, amber border (2px), white background, "R" text centred (placeholder)
  - Speech bubble: extends left from avatar, max 180px wide, white bg, `BorderRadius.circular(12)`, drop shadow, amber right-pointing triangle pointer
  - Auto-dismiss: `Timer(Duration(seconds: 4), ...)` started when message non-null
  - Tap-to-dismiss clears provider state to null
  - `AnimatedSwitcher` wrapping bubble+avatar; child uses `ScaleTransition` (0.0 → 1.0, 200ms)
  - Only one bubble visible at a time

Trigger wiring:
- In `ScanSummaryScreen._handleDone()` / `_NothingNewState`: set Rovy message via `ref.read(rovyMessageProvider.notifier)`
  - New country found: `RovyMessage(text: 'New country unlocked!', trigger: RovyTrigger.newCountry, emoji: '🌍')`
  - Zero-new-country scan: `RovyMessage(text: 'All caught up!', trigger: RovyTrigger.caughtUp, emoji: '✅')`
  - Region 1-away detected (check `regionProgressProvider` after scan): `RovyMessage(text: 'So close! One more country in [Region]', trigger: RovyTrigger.regionOneAway)`
  - 10th country milestone (visited count crosses 10): `RovyMessage(text: '10 countries explored!', trigger: RovyTrigger.milestone, emoji: '🏆')`

Tests in `test/features/map/rovy_bubble_test.dart`:
- Bubble not visible when `rovyMessageProvider` is null
- Bubble visible with correct text when message set
- Tap dismisses bubble (provider reset to null)

**Dependencies:** Task 88 (for `regionProgressProvider` region-1-away check wiring).

---

## Build Order

```
Task 86 ✅  ──►  Task 87  ──►  Task 88  ──►  Task 89
```

Implement in order: 87 → 88 → 89.

---

## Risks

1. **`MapCamera` zoom access** — use `MapCamera.of(context)` from `flutter_map`; wrap `RegionChipsMarkerLayer` content in a `LayoutBuilder` or `Builder` within the FlutterMap children. Verify API before implementing Task 87.
2. **`TargetCountryLayer` visual treatment** — solid amber border + breathing fill only. No `CustomPainter`, no dashed borders. Confirmed in ADR.
3. **Rovy asset dependency** — placeholder circle + "R" text only. No SVG dependency.
4. **`rovyMessageProvider` timing** — Rovy trigger must be set after navigation pops back to map screen so the bubble is visible on the map.
