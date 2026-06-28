# M149 — Travel Heatmap Calendar

**Branch:** `milestone/m149-travel-heatmap`
**Phase:** 22 — Stats Depth
**Depends on:** M147
**Status:** Complete (2026-06-28)

---

## Goal

Users see a GitHub-style contribution heatmap of their entire travel history — rows = years, columns = months — coloured by continent, so patterns like "I travel every summer" or "I had a 3-year gap" are immediately obvious.

---

## Screen Layout

```
TravelHeatmapCard (inline on Stats screen, below StatsGrid)
  Header: "Travel History"
  Subheader: "X months with travel since YYYY"
  Grid: years (rows) x months (cols), cell = continent colour or empty
  Legend: 6 continent colour dots + "No travel" dot
  Tap cell: tooltip — "Mar 2022 · France, Italy"
```

---

## Scope

### In
- `lib/features/stats/widgets/travel_heatmap_card.dart` — inline card widget
- `TravelHeatmapPainter` — `CustomPainter` for the month grid
- Cell data: for each (year, month), list of countries visited that month → pick dominant continent colour; if multiple continents, use the first alphabetically
- Tap interaction: `GestureDetector` on cells → `Tooltip` or small overlay showing countries
- Legend row below grid
- Entry point: inline on Stats screen between StatsGrid and DailyChallengeCard

### Out
- Week-level granularity (month is sufficient given data sparsity)
- Editing trips from heatmap
- Web version

---

## Acceptance Criteria

- [ ] Given visits across multiple years, heatmap rows span from earliest visit year to current year.
- [ ] Given a month with visits in Europe and Asia, the cell shows Europe colour (alphabetical tiebreak).
- [ ] Given an empty month, the cell is rendered in the theme's `surfaceContainerHighest` colour.
- [ ] Given the user taps a non-empty cell, a tooltip/overlay lists the countries visited that month.
- [ ] Legend correctly maps all 6 continent colours.

---

## Technical Notes

- Data source: `effectiveVisitsProvider` gives `List<EffectiveVisitedCountry>` with `firstSeen` date.
- Build a `Map<(int year, int month), List<String> countryCodes>` from visits.
- `TravelHeatmapPainter`: grid of rounded rectangles, 12 columns (months), N rows (years).
- Cell size: ~24×20px with 3px gap. Total width fits inside card padding.
- Continent colours: same map as `ContinentExplorerScreen._continentColors`.
- Scroll: if > 6 years, wrap grid in horizontal `SingleChildScrollView`.

---

## Dependencies

- Depends on: M147
- Blocks: nothing

---

## Definition of Done

- [ ] `flutter analyze` — no new issues.
- [ ] Unit test: given a list of visits, heatmap data builder produces correct (year, month) → continent map.
- [ ] `current_state.md` updated.
