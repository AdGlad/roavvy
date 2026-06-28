# M150 — Rarest Visits Badge

**Branch:** `milestone/m150-rarest-visits`
**Phase:** 22 — Stats Depth
**Depends on:** M147
**Status:** Complete (2026-06-28)

---

## Goal

Users discover which of their visited countries are the rarest to visit globally, shown as a "brag badge" card — rewarding adventurous travellers who go off the beaten path.

---

## Screen Layout

```
RarestVisitsCard (inline on Stats screen, after NextAchievementsCarousel)
  Header: "Off the Beaten Path"
  Subheader: "Your rarest destinations"
  Row of up to 3 country cards (horizontal scroll if more):
    - Flag emoji + country name
    - Rarity tier badge: "Ultra Rare" / "Rare" / "Uncommon"
    - "Only ~X% of travellers visit" label
  Footer: "Rarity Explorer" achievement nudge if user has 2+ ultra-rare
```

---

## Scope

### In
- `packages/shared_models/lib/src/country_rarity.dart` — `kCountryRarity: Map<String, double>` (0.0–1.0, lower = rarer). Static bundled data, no network.
- `lib/features/stats/widgets/rarest_visits_card.dart` — card widget
- Rarity tiers: Ultra Rare (< 0.05), Rare (0.05–0.20), Uncommon (0.20–0.45); Common countries not shown
- Show top 3 rarest visited countries by rarity score
- Card hidden if user has no Uncommon-or-rarer countries

### Out
- Network-sourced rarity data (static bundled map only)
- More than top 5 displayed
- Rarity as an achievement unlock trigger (deferred)

---

## Acceptance Criteria

- [ ] Given a user who has visited France and Tuvalu, Tuvalu appears in the rarest card, France does not.
- [ ] Given a user with only common countries, the card is not shown.
- [ ] Rarity tier labels (Ultra Rare / Rare / Uncommon) display correctly based on score thresholds.
- [ ] Card shows at most 3 countries; if more qualify, show the 3 rarest.

---

## Technical Notes

- `kCountryRarity` is a `Map<String, double>` keyed by ISO 3166-1 alpha-2 code. Values sourced from UNWTO tourist arrival data, normalised to 0–1. Bundled as a Dart const — no JSON parsing.
- Countries with no rarity data default to 0.5 (average) — do not appear in rare list.
- Rarity display text: `"Only ~${(score * 100).toStringAsFixed(1)}% of travellers visit"` — round to nearest 0.5%.
- Approximately 40 countries qualify as Ultra Rare (< 0.05), ~80 as Rare.

---

## Dependencies

- Depends on: M147
- Blocks: nothing

---

## Definition of Done

- [ ] `flutter analyze` — no new issues.
- [ ] Unit test: `rarestVisited([...])` returns countries sorted by ascending rarity score, filtered to < 0.45.
- [ ] `current_state.md` updated.
