# M151 — Deepest Region Callout

**Branch:** `milestone/m151-deepest-region`
**Phase:** 22 — Stats Depth
**Depends on:** M147
**Status:** Backlog

---

## Goal

A focused callout card tells the user which continent they've explored most deeply (highest % of countries visited), showing the completion percentage and exactly how many countries remain — motivating them to finish it.

---

## Screen Layout

```
DeepestRegionCard (inline on Stats screen, after StatsGrid)
  Continent colour gradient card
  Header: continent emoji + continent name
  "Your most explored continent"
  Large: "X / Y countries  ·  Z%"
  Animated progress bar (continent colour)
  Body: "X more to complete [Continent]"
  CTA button: "Explore [Continent]" → ContinentExplorerScreen filtered to that continent
```

---

## Scope

### In
- `lib/features/stats/widgets/deepest_region_card.dart` — card widget
- Compute deepest continent: for each continent, `visitedInContinent / totalInContinent` → pick highest fraction
- Uses same `kCountryContinent` + per-continent totals as `TravelProgressHero`
- Gradient background matches continent colour from `ContinentExplorerScreen`
- Animated `TweenAnimationBuilder` progress bar
- "Explore" CTA navigates to `ContinentExplorerScreen`
- Card hidden if user has visited 0 countries

### Out
- Sub-continental region depth (deferred — needs region data from M157+)
- Multiple continent cards
- Web version

---

## Acceptance Criteria

- [ ] Given visits across multiple continents, the card shows the continent with the highest completion percentage.
- [ ] Given a tie in percentage, prefer the continent with more absolute countries visited.
- [ ] Progress bar animates from 0 to actual fraction on first render.
- [ ] "Explore" button navigates to ContinentExplorerScreen.
- [ ] Card is hidden when countryCount == 0.

---

## Technical Notes

- Per-continent totals (same as `TravelProgressHero._rings`): Africa 54, Asia 48, Europe 44, North America 23, Oceania 14, South America 12.
- Compute `continentCounts` from `effectiveVisitsProvider` using `kCountryContinent`.
- Deepest = `max(continentCounts[c]! / total[c])` across all continents.
- Continent colour map: identical to `_continentColors` in `continent_explorer_screen.dart` — extract to shared constant in `roavvy_colours.dart`.

---

## Dependencies

- Depends on: M147
- Blocks: nothing

---

## Definition of Done

- [ ] `flutter analyze` — no new issues.
- [ ] Unit test: `deepestContinent(counts, totals)` returns correct continent for various inputs including ties.
- [ ] `current_state.md` updated.
