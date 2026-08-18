---
name: design-qa
description: Autonomous testing + fixing loop for the procedural T-shirt design engine. Generates a large design sample, runs automated QA (render-defect + KB graphic-design-rule checks) to find poor designs, fixes the recipe-confirmable ones and improves the generator, validates with regression, and uses on-device pixel capture for render-layer issues. Use to test/improve design quality, find bad designs, or verify a generator change.
---

# Skill: design-qa

The reusable loop that keeps Roavvy's procedural design engine producing
professional, on-brand T-shirt designs. It scales past manual eyeballing:
**identify poor designs automatically → replace with improved ones → verify.**

Workspace: `design_studio/` (studio) + `design_studio/knowledge_base/` (the design
bar: philosophy, 58 rules, family catalogue). Engine:
`apps/mobile_flutter/lib/features/merch/design_engine/procedural/`.

---

## The loop

```
1. SAMPLE   generate a large deterministic batch (hundreds of recipes)
2. QA       recipe_qa.py → flag render-defect + KB design-rule violations
3. DIAGNOSE pick the highest-count systematic pattern (not one-off images)
4. FIX      change the generator (family spec / DNA / priors / _construct)
5. VERIFY   analyze + regression (must stay green) + re-run QA (violations drop)
6. PIXELS   for render-layer/ambiguous findings, on-device capture + render_qa.py
7. RECORD   experiment + roadmap + baseline (REGEN if intended tradeoff)
```

## Commands

Reliable, headless (recipe level — hundreds of samples):
```
cd apps/mobile_flutter
# large sample (8 contexts × N seeds × 8):
BATCH_SEEDS=15 EXPERIMENT_LABEL=qasweep \
  flutter test test/features/merch/design_engine/procedural/batch_generate.dart
# automated QA over it:
python3 ../../design_studio/tools/recipe_qa.py \
  ../../design_studio/generated_batches/batch_v0.1.0_qasweep/batch.json
# arbiter after any generator change (tolerance 0.03 meanQuality, diversity -1):
flutter test test/features/merch/design_engine/procedural/regression_test.dart
# accept an intended, reviewed change as the new baseline:
REGEN_BASELINE=1 flutter test .../procedural/regression_test.dart
flutter analyze lib/features/merch/design_engine/procedural/
```

Pixel truth (render-layer issues — needs a booted simulator, run in the user's
terminal; ~4 min cached build). See `design_studio/tools/LANE_A2_ONDEVICE_CAPTURE.md`:
```
flutter drive --driver=test_driver/design_render_capture_driver.dart \
  --target=integration_test/device/design_render_capture_test.dart -d <sim-id>
design_studio/tools/decode_device_capture.sh
python3 design_studio/tools/render_qa.py design_studio/generated_batches/rendered_device
```

## The QA tools
- **`recipe_qa.py`** — scans a recipe batch, flags patterns encoded from confirmed
  findings: render-defects (`TILE-REPEAT`/E-005, `CUTOUT-UNDERFILL`/E-006,
  `FRAGMENT-RISK`/E-007) + KB design rules (`FLAG-CLASH`/R-FLAG-01,
  `CRAMPED`/R-NEG-01, `DENSITY-MISMATCH`/R-MERCH-02, `LOW-QUALITY`). Add a new rule
  by extending `flags_for()`.
- **`render_qa.py`** — pixel QA over rendered PNGs: coverage%/centroid/blank →
  flags `BLANK`/`TINY`/`OFF-CENTER`. Calibrates the recipe patterns against truth.

## The discipline (do NOT skip — it prevents false fixes)
1. **Fix only what the RECIPE confirms** headless (e.g. rowCount, layoutMode,
   flag/colour treatment, density). A defect that's only visible in pixels and
   whose recipe looks correct is **render-layer → defer to on-device**, don't guess.
   (This is what caught a sub-agent's false "already fixed" on E-006.)
2. **Keep a fix only if regression stays green** AND the QA violation count drops.
   The analytic scorer is blind to many render params (Δ0.000 is common and fine).
3. **Protect diversity.** Don't drive a rule to 0 if it means converging every
   design on one look (e.g. leave ~25% multi-flag variety). The KB's anti-
   convergence mandate outranks a lower violation count.
4. **Systematic over specific** — target patterns that recur across families/
   contexts (recipe_qa aggregates by family), never one bad image.
5. **Record every change:** experiment note + `reports/optimization_roadmap.md`
   decision log; regenerate the baseline only for an intended, documented tradeoff.

## Known tuning surfaces (where fixes go)
- `composition_family.dart` — `kCompositionFamilies` (count ranges, masks,
  layoutModes, density/scope weights).
- `procedural_generator.dart` — `_construct` (flag/colour treatment, hero, rows),
  `_pickDensity`, `_pickPrintStyle`.
- `design_dna.dart` — `kRoavvyDesignDnaDefault` (family affinity, target bands).
- `quality_model.dart` — scorer weights + sub-scores.

## Reference
- Framework + latest results: `design_studio/reports/render-qa-framework-2026-08-18.md`
- Roadmap + open items (E-006, E-008): `design_studio/reports/optimization_roadmap.md`
- Design rules the QA encodes: `design_studio/knowledge_base/design_rules.md`
- Studio protocol: `design_studio/OPTIMIZATION_STUDIO.md`
