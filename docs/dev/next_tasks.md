# M45 — Passport Stamp Realism Upgrade

**Milestone:** 45
**Phase:** Phase 15 — Visual Design Upgrade
**Architecture:** ADR-097
**Status:** Complete

---

## Goal

Make passport stamps look physically authentic — ink simulation, pressure distortion, 15 stamp style templates, realistic typography with arc text and sublabels, aging effects, and rare artefacts.

## Scope

**Included:**
- `StampStyle` enum (15 styles replacing the previous 4-shape StampShape)
- `StampNoiseGenerator` — procedural blotchy ink-wear opacity mask
- `StampShapeDistorter` — vertex jitter for geometric imperfection
- `StampTypographyPainter` — condensed typography, monospaced dates, arc text, baseline jitter
- `StampInkPalette` — 12 vibrant ink colour families
- `StampAgeEffect` — 4 aging levels (fresh/aged/worn/faded)
- `RareArtefactEngine` — ghost, partial stamp, ink blob, smudge, correction stamp
- `StampPainter` — full 15-style `CustomPainter` with offscreen `PictureRecorder` pipeline
- `PassportLayoutEngine` — soft-grid placement, temporal ordering, edge clipping
- `PassportStampsCard` — card template widget using the new engine

**Excluded:**
- Flag Heart card (M46)
- Sound effects

---

## Tasks

### Task 156 — StampStyle enum + StampInkPalette + StampAgeEffect + StampRenderConfig + StampData model
- [x] Deliverable: `passport_stamp_model.dart` with all types and factories
- [x] Tests: `passport_stamp_model_test.dart`

### Task 157 — StampNoiseGenerator
- [x] Deliverable: `stamp_noise_generator.dart`
- [x] Tests: `stamp_noise_generator_test.dart`

### Task 158 — StampShapeDistorter
- [x] Deliverable: `stamp_shape_distorter.dart`
- [x] Tests: `stamp_shape_distorter_test.dart`

### Task 159 — StampTypographyPainter
- [x] Deliverable: `stamp_typography_painter.dart`
- [x] Tests: `stamp_typography_painter_test.dart`

### Task 160 — RareArtefactEngine
- [x] Deliverable: `rare_artefact_engine.dart`
- [x] Tests: `rare_artefact_engine_test.dart`

### Task 161 — StampPainter (15-style CustomPainter)
- [x] Deliverable: `stamp_painter.dart`
- [x] Tests: `stamp_painter_test.dart`

### Task 162 — PassportLayoutEngine + PassportStampsCard integration
- [x] Deliverable: `passport_layout_engine.dart`; `passport_stamp_model.dart` updated; `card_templates.dart` updated
- [x] Tests: `passport_layout_engine_test.dart` updated
- [x] flutter analyze clean; all 85 card tests pass

---

## Dependencies

All tasks sequential (each builds on the previous).

## Risks / open questions

None outstanding — milestone complete.
