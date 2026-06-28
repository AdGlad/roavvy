# M155 — Continent Completion Callout

**Branch:** `milestone/m155-continent-completion-callout`
**Phase:** 22 — Stats Depth
**Depends on:** M147
**Status:** Complete (2026-06-28)

---

## Goal

A prominent, continent-coloured nudge card shows the user exactly how many countries remain to complete their nearest continent — more urgent and actionable than the achievement carousel, with a direct map entry point.

---

## Screen Layout

```
ContinentCompletionCard (inline on Stats screen, between NextAchievementsCarousel and AchievementTimeline)
  Continent gradient card (matches continent colour scheme)
  Continent emoji + "Almost there in [Continent]"
  Large: "X countries to go"
  Mini flag row: up to 5 remaining country flags (greyscale)
  Progress bar: visited / total
  "X / Y countries · Z% complete"
  CTA: "See on map" → ContinentExplorerScreen
```

---

## Scope

### In
- `lib/features/stats/widgets/continent_completion_card.dart` — card widget
- Selection logic: pick the continent where `(total - visited)` is smallest AND `visited > 0` (user has started it)
- If multiple continents tied on remaining, prefer the one with the higher absolute visited count
- Mini flag row: up to 5 remaining countries shown as greyscale flag emoji
- `kCountryContinent` + per-continent totals drive the computation
- "See on map" navigates to `ContinentExplorerScreen`
- Card hidden if: no continent is > 0% started, OR user has completed all 6 continents

### Out
- Multiple continent cards
- "Claim continent" achievement from this card (use existing achievement carousel)
- Web version

---

## Acceptance Criteria

- [ ] Given Europe 38/44 and Asia 5/48, card shows Europe (6 remaining < 43 remaining).
- [ ] Given no continent has been started (countryCount == 0), card is hidden.
- [ ] Given all 6 continents are complete, card is hidden.
- [ ] Mini flag row shows up to 5 greyscale flags of remaining countries in the chosen continent.
- [ ] Progress bar animates from 0 to actual fraction on first render.
- [ ] "See on map" navigates to ContinentExplorerScreen.

---

## Technical Notes

- Build `Map<String, List<String>>` of continent → remaining country codes using `kCountryContinent`.
- `kCountryNames` for tooltip / accessibility labels on flag emojis.
- Greyscale flag: `ColorFiltered(colorFilter: ColorFilter.matrix([...greyscale...]))` wrapping flag `Text`.
- Continent totals + colours: extract shared constants from `TravelProgressHero._rings` and `ContinentExplorerScreen._continentColors` into `roavvy_colours.dart` or a new `continent_constants.dart` — avoids duplication.
- If remaining > 5 flags to show, display first 5 alphabetically + "+N more" label.

---

## Dependencies

- Depends on: M147
- Blocks: nothing
- Note: M151 (Deepest Region) and M155 both surface continent data — implement shared continent utilities together to avoid duplication.

---

## Definition of Done

- [ ] `flutter analyze` — no new issues.
- [ ] Unit test: `nearestContinent(counts, totals)` picks correct continent for various scenarios.
- [ ] `current_state.md` updated.
