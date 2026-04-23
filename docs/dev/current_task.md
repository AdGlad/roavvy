# Active Task: M75 — Inline T-Shirt Config UX (Remove "More" Tab)
Branch: milestone/m75-inline-tshirt-config

## Goal
Remove the "More" bottom sheet from the Design Your T-Shirt screen and bring all
product configuration inline — visible, scrollable, and immediately interactive
on the main screen. No hidden navigation. No duplicate controls.

## Scope
In: `local_mockup_preview_screen.dart` layout + widget refactor; remove `_showOptionsSheet`
    and `_buildCompactStrip`; add `_buildInlineConfigPanel`; poster path gets same treatment.
Out: Printful API; card templates; card editor; web; scan; map; new packages.

## UX Direction (ADR-127)
- Mockup: `Expanded` (fills available space above config panel).
- Config panel: t-shirt only. `ConstrainedBox(maxHeight: 280)` + `SingleChildScrollView` —
  always visible, scrollable for overflow. Never hidden behind navigation.
- Sections: Colour + Flip button row, Size, Front design, Back design,
  Ribbon mode (conditional), Stamp colour (conditional, passport template only).
- No Product type section. No Card design section. No poster path changes.
- Colour swatches stay circle-swatch style (M58-04). Flip button moves into colour section header.
- Stamp colour picker (M64) moves from compact strip into panel (conditional).
- `_SegmentedPicker` and `_ColourSwatchRow` reused unchanged.
- No modal, no navigation, no "More" button, no duplicate colour picker.

## Tasks
- [x] T1 — Delete `_buildCompactStrip` and `_showOptionsSheet` (and callers)
- [x] T2 — Build `_buildInlineConfigPanel`: t-shirt sections only — Colour+Flip, Size, Front design, Back design, Ribbon (conditional), Stamp colour (conditional)
- [x] T3 — Update `build()` body layout: Expanded(mockup) + inline panel
- [x] T4 — Move Flip button into colour section header row of the panel
- [x] T5 — Move passport stamp colour picker (`_buildStampColorPicker`) into panel (conditional on template)
- [x] T6 — `flutter analyze` clean; removed outdated tests; deleted dead code (`_onTemplateChanged`, `_templateChanged`, `_InlineReconfirmationBanner`)

## ✅ Complete (2026-04-22)

## Acceptance Criteria
- "More" button is gone
- No duplicate colour controls
- All product config visible inline on main screen
- Preview updates instantly on every config change
- Flip front/back accessible without opening any modal
- `flutter analyze` reports no new issues
- All existing tests pass

## Risks
| Risk | Mitigation |
|---|---|
| Config panel too tall on small phones | `ConstrainedBox(maxHeight: 280)` + scroll |
| Poster path breaks (no shirt) | Panel conditioned on `_isTshirt` per-section |
| Stamp colour picker lost | Moved to panel; shown only when `_template == passport && _isTshirt` |
| `_buildCompactStrip` referenced in tests | Update tests to expect new panel layout |
