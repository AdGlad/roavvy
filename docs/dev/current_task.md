# Active Task: M74 — Passport Stamp Randomisation, Country Selection & T-Shirt Fixes
Branch: milestone/m74-passport-stamp-country-control

## Goal
Improve Passport Stamp and T-Shirt design experience: randomised stamp placement, country
include/exclude within year range, dynamic title, front ribbon independence, and fix the
critical front/back toggle regression from M73.

## Scope
In: stamp layout randomisation; country multi-select on card editor; dynamic title; front
ribbon all/selected mode; fix front/back toggle in local mockup.
Out: Printful API changes; card templates; poster; web; scan; map.

## Tasks
- [x] T1 — Fix front/back toggle regression — `local_mockup_preview_screen.dart`
- [x] T2 — Randomise stamp placement (remove entry/exit top-bottom bias) — `passport_layout_engine.dart`
- [x] T3 — Country multi-select in card editor — `card_editor_screen.dart`
- [x] T4 — Dynamic title update from country selection — `card_editor_screen.dart`
- [x] T5 — Front ribbon mode: all-time vs year-selection — `local_mockup_preview_screen.dart` + `card_editor_screen.dart`

## ✅ Complete (2026-04-21)

## Risks
| Risk | Mitigation |
|---|---|
| Stamp shuffle breaks determinism expected by tests | Same seed used for shuffle; layout is still deterministic, just different |
| Country deselect + title re-render causes jank | Title generation called per-toggle; AI call is async and doesn't block UI |
| `allCodes` param changes LocalMockupPreviewScreen constructor | Updated both call sites (card_editor_screen + card_generator_screen) + test |
