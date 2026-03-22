# M26 — Phase 11 Slice 4: Timeline Scrubber + Scan Reveal

**Planner:** 2026-03-22
**Branch:** `milestone/m26-timeline-scan-reveal`

---

## Goal

The map becomes a time machine. Users can drag a scrubber to any year and see exactly which countries they had visited by then. The first scan becomes a discovery moment: new countries animate onto a mini-map one-by-one before the country list appears.

---

## Scope

**Included:**

- `yearFilterProvider` (`StateProvider<int?>`) — shared filter state; null = no filter (all time).
- `filteredEffectiveVisitsProvider` — `FutureProvider` that applies the year filter against trip `startedOn` dates (fallback to `firstSeen` year for countries with no trip records).
- `countryVisualStatesProvider` updated to honour `yearFilterProvider` — when active, derives visual states from the filtered visit set instead of the full set.
- `earliestVisitYearProvider` — `FutureProvider<int?>` returning the minimum trip `startedOn` year across all trips (for computing the scrubber range).
- `TimelineScrubberBar` widget — shown at the bottom of `MapScreen` above `StatsStrip`; appears when filter is active; `Slider` (discrete year steps), year label, clear button; toggled from the `PopupMenuButton` overflow menu.
- `ScanRevealMiniMap` widget — embedded in `ScanSummaryScreen` State A (new countries found); fixed height 180px flutter_map; shows all countries grey; discovered countries pop in one-by-one via a repeating `Timer` (400ms interval); respects `MediaQuery.disableAnimations`.

**Excluded:**

- Opacity-animated polygon reveal (smooth fade per country) — too complex for flutter_map's batch PolygonLayer; instant pop-in is acceptable.
- Trip count depth colouring respecting the year filter — `countryTripCountsProvider` continues to use all trips regardless of filter (historical trip count is displayed accurately).
- City-level detection (separate milestone).
- Social ranking (deferred indefinitely).
- Timeline scrubber on web map (mobile-only for this milestone).

---

## Tasks

### Task 97 — `yearFilterProvider` + `filteredEffectiveVisitsProvider` + `earliestVisitYearProvider`

**Deliverable:**

In `lib/core/providers.dart`:

1. `yearFilterProvider = StateProvider<int?>(_ => null)` — null means "show all".
2. `earliestVisitYearProvider = FutureProvider<int?>` — loads all trips via `tripRepositoryProvider`; returns `trips.map((t) => t.startedOn.year).reduce(min)`, or null if no trips.
3. `filteredEffectiveVisitsProvider = FutureProvider<List<EffectiveVisitedCountry>>` — when `yearFilterProvider` is null, returns same as `effectiveVisitsProvider`; when set to year Y, filters by: keep country if it has at least one trip with `startedOn.year <= Y`, OR (no trips and `firstSeen != null` and `firstSeen!.year <= Y`).

In `lib/features/map/country_visual_state.dart`:

4. `countryVisualStatesProvider` updated to watch `yearFilterProvider`; when active, derives its visit map from `filteredEffectiveVisitsProvider` instead of `effectiveVisitsProvider`. `recentDiscoveriesProvider` continues to be overlaid on top (newly-discovered state is always shown regardless of year filter).

**Acceptance criteria:**

- `filteredEffectiveVisitsProvider` with year=2015 and a user with trips to FR (2015), JP (2020), DE (2010) returns FR and DE only.
- `filteredEffectiveVisitsProvider` with null returns identical results to `effectiveVisitsProvider`.
- `countryVisualStatesProvider` with year filter active shows `unvisited` for countries with all trips after the filter year.
- `earliestVisitYearProvider` returns null when no trips exist.
- Unit tests cover all filter scenarios above.
- `flutter analyze` zero issues.

---

### Task 98 — `TimelineScrubberBar` widget + `MapScreen` wiring

**Deliverable:**

1. `TimelineScrubberBar` widget (`lib/features/map/timeline_scrubber_bar.dart`):
   - `ConsumerWidget`; shows only when `yearFilterProvider != null`.
   - `Slider` with `min = earliestYear.toDouble()`, `max = DateTime.now().year.toDouble()`, `divisions = max - min`, `value = yearFilter.toDouble()`.
   - Label above slider: "Showing countries visited by [year]".
   - Clear `TextButton` (or "✕" icon) that sets `yearFilterProvider` to null.
   - Wraps in a semi-transparent amber-tinted `Card` (consistent with amber theme).
   - Respects `SafeArea` at bottom.

2. `MapScreen` changes:
   - Add `TimelineScrubberBar` to the `Stack` above `StatsStrip` (positioned at `Alignment.bottomCenter` inside a `Column` with `StatsStrip`).
   - Add "Filter by year" `PopupMenuItem` to `_MapMenuAction` enum and `PopupMenuButton`; tapping it sets `yearFilterProvider` to `DateTime.now().year` (activates the scrubber at "all years").
   - Show "Filter by year" menu item only when `earliestVisitYearProvider` resolves to a year < `DateTime.now().year` (i.e. user has historical trip data spanning more than one year).

**Acceptance criteria:**

- Dragging the scrubber to 2018 causes `yearFilterProvider` to hold 2018; countries with all trips after 2018 show as grey on the map.
- Tapping "Clear" resets the map to all countries visited.
- Scrubber is not shown when no visits exist or when `earliestVisitYearProvider` is null.
- Widget test: `TimelineScrubberBar` renders label with current year; tapping clear calls `ref.read(yearFilterProvider.notifier).state = null`.
- `flutter analyze` zero issues.

---

### Task 99 — `ScanRevealMiniMap` widget

**Deliverable:**

`lib/features/scan/scan_reveal_mini_map.dart`:

- `ScanRevealMiniMap` (`ConsumerStatefulWidget`): takes `newCodes: List<String>`.
- Layout: `SizedBox(height: 180)` containing a `FlutterMap` with `interactionOptions: InteractionOptions(flags: InteractiveFlag.none)` (no user interaction), `initialCenter: LatLng(20, 0)`, `initialZoom: 1.8`.
- Layers: one `PolygonLayer` for all unvisited countries (grey, `_kUnvisitedFill`, same constants as `CountryPolygonLayer`), one `PolygonLayer` for revealed countries (amber, `_kVisitedFill`).
- On `initState`: if `MediaQuery.disableAnimationsOf(context)` — add all `newCodes` to `_revealed` immediately; else start a `Timer.periodic(400ms)` that pops one code from a queue into `_revealed` and calls `setState`. Stop timer when queue is empty.
- Clean up timer in `dispose`.

Integrated into `ScanSummaryScreen._NewDiscoveriesState`:
- Add `ScanRevealMiniMap(newCodes: widget.newCodes)` as the first item in the `ListView` (before the hero count block), wrapped in `Padding(EdgeInsets.only(bottom: 16))`.
- Only added when `widget.newCodes.length >= 2` (single new country is already celebrated via `DiscoveryOverlay`).

**Acceptance criteria:**

- Mini-map is visible in State A when 2+ new countries discovered.
- Countries appear one-by-one in order; all revealed after `newCodes.length × 400ms`.
- With `MediaQuery.disableAnimations = true`, all countries appear immediately (no timer).
- Map is non-interactive (no pan/zoom).
- `flutter analyze` zero issues.
- Widget test: with `disableAnimations = true`, all `newCodes` countries are rendered as amber polygons without tapping anything.

---

## Dependencies

| Task | Depends on |
|---|---|
| 97 | `tripRepositoryProvider` (existing), `effectiveVisitsProvider` (existing) |
| 98 | Task 97 (`yearFilterProvider`, `filteredEffectiveVisitsProvider`, `earliestVisitYearProvider`) |
| 99 | `polygonsProvider` (existing), `newCodes` list passed from `ScanSummaryScreen` |

Tasks 97 and 99 can be implemented in parallel. Task 98 requires Task 97.

---

## Risks / Open Questions

1. **`countryVisualStatesProvider` dual-source complexity** — The provider currently watches `effectiveVisitsProvider` directly. Switching to `filteredEffectiveVisitsProvider` requires care: both providers must be watched (for dependency tracking) but only the filtered one should be used when the filter is active. The Architect must confirm the watch pattern before Task 97 is coded.

2. **`ScanRevealMiniMap` embedded `FlutterMap` performance** — Embedding a flutter_map inside a `ListView` (inside `ScanSummaryScreen`) may cause layout issues. The mini-map must have a fixed height (not `Expanded`). Use `NeverScrollableScrollPhysics` on the inner map if needed. Test on device.

3. **Year filter and `countryTripCountsProvider`** — Depth colouring deliberately ignores the year filter (shows lifetime trip count). This is a design decision: depth colouring reflects lifetime engagement, not historical state. Document clearly in UI (consider showing a note "Colour shows lifetime visits" when filter is active).

4. **Manually-added countries with no trip records** — These have `firstSeen = null` and no `TripRecord`. The year filter will exclude them (no evidence to date them). This is the correct conservative behaviour — we cannot confirm when they were visited.
