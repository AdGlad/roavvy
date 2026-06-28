# M152 — Travel Personality Card

**Branch:** `milestone/m152-travel-personality`
**Phase:** 22 — Stats Depth
**Depends on:** M147
**Status:** Complete (2026-06-28)

---

## Goal

Users are assigned a travel personality archetype based on their actual travel patterns — shareable, fun, and a conversation starter that deepens engagement with their stats.

---

## Screen Layout

```
TravelPersonalityCard (inline on Stats screen, after TravelProgressHero)
  Gradient card (archetype colour)
  Large emoji + archetype name (e.g. "Culture Vulture")
  1-line description
  3 trait chips: e.g. "UNESCO fan" · "Europe specialist" · "Frequent flyer"
  Share button — exports card as PNG
```

---

## Archetypes

| ID | Name | Emoji | Trigger |
|---|---|---|---|
| `heritage_hunter` | Culture Vulture | Art | heritageCount >= 10 |
| `continent_sprinter` | Continent Sprinter | Rocket | continents >= 5 AND countries/continents < 8 |
| `deep_diver` | Deep Diver | Magnifying Glass | 1 continent visited >= 60% complete |
| `hemisphere_hopper` | Hemisphere Hopper | Globe | all 6 continents visited |
| `frequent_flyer` | Frequent Flyer | Plane | tripCount >= 20 |
| `globetrotter` | Globetrotter | Compass | countryCount >= 50 |
| `weekend_warrior` | Weekend Warrior | Backpack | tripCount >= 10 AND countryCount < 15 |
| `pioneer` | Pioneer | Flag | 2+ ultra-rare countries (rarity < 0.05) |
| `explorer` | Explorer | Map | default fallback |

Evaluated top-to-bottom; first match wins.

---

## Scope

### In
- `packages/shared_models/lib/src/travel_personality.dart` — `TravelPersonality` enum + `resolvePersonality()` pure function
- `lib/features/stats/widgets/travel_personality_card.dart` — card widget
- Share CTA: `RenderRepaintBoundary` → PNG → `Share.shareXFiles`
- Inline on Stats screen

### Out
- More than 9 archetypes in v1
- Personality history / changes over time
- Web version

---

## Acceptance Criteria

- [ ] Given a user with heritageCount >= 10, personality resolves to `heritage_hunter`.
- [ ] Given no special pattern, personality resolves to `explorer`.
- [ ] Each archetype has a distinct gradient, emoji, name, and description.
- [ ] Share button exports the card as a PNG via the system share sheet.
- [ ] `resolvePersonality()` is a pure function with 100% unit test coverage.

---

## Technical Notes

- `resolvePersonality()` takes `({int countryCount, int continentCount, int tripCount, int heritageCount, Map<String, int> continentCounts, List<String> visitedIds})` and returns `TravelPersonality`.
- For the `pioneer` archetype, requires `kCountryRarity` from M150. If M150 not yet shipped, skip pioneer check.
- Card gradient: each archetype has a `(Color start, Color end)` pair hardcoded in the widget.
- Ultra-rare check: optional dependency on M150 — guard with null check on `kCountryRarity`.

---

## Dependencies

- Depends on: M147
- Optional: M150 (for pioneer archetype rarity check)
- Blocks: nothing

---

## Definition of Done

- [ ] `flutter analyze` — no new issues.
- [ ] Unit tests: all 9 archetype trigger conditions covered.
- [ ] `current_state.md` updated.
