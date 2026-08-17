# Automated Render-QA Framework + Large-Sample Sweep (2026-08-18)

*Extends the autonomous testing/fixing loop from hand-eyeballed handfuls to
**hundreds of samples, auto-triaged**. Two reusable QA tools + a widened sampling
harness, applied to a 960-design sweep. All analyze-clean, regression green.*

## Why two tools (the hard constraint)
The host `CardImageRenderer` is too flaky headless to rasterise a large sample
(the widened host capture rendered only **2/24** — large-set contexts with dozens
of flags fail/timeout). So the loop scales two ways:

| Tool | Source | Reliability | What it catches |
|---|---|---|---|
| **`render_qa.py`** (pixel-QA) | rendered PNGs (on-device / host) | ground-truth but small sample | blank / tiny / off-center **on real pixels** |
| **`recipe_qa.py`** (recipe-QA) | recipe batch (`batch_generate`) | **hundreds, deterministic, headless** | render-defect **patterns** the pixels proved |

Pixel-QA calibrates the patterns; recipe-QA scales them. Together they cover far
more designs than manual review.

## The tools
- **`design_studio/tools/render_qa.py [batch_dir …]`** — decodes each PNG (pure
  stdlib), computes opaque **coverage %**, **centroid offset**, **bbox fill**,
  joins the recipe manifest, flags `BLANK` / `TINY(<12%)` / `OFF-CENTER(>0.16)`,
  aggregates by family. Writes `render_qa.json`.
- **`design_studio/tools/recipe_qa.py [batch.json]`** — scans a recipe batch and
  flags patterns encoded from the confirmed pixel findings:
  `TILE-REPEAT` (E-005), `CUTOUT-UNDERFILL` (E-006), `FRAGMENT-RISK` (E-007),
  `LOW-QUALITY`. Aggregates by family; writes `/tmp/recipe_qa.json`.
- **Widened sampling:** `batch_generate` now takes `BATCH_SEEDS`/`BATCH_PERRUN`
  (env) → e.g. 15 seeds × 8 contexts × 8 = **960 designs**; `render_capture` takes
  `RENDER_CONTEXTS`/`RENDER_SEEDS`/`RENDER_PERCTX` for chunked pixel sweeps.

## Run it
```
# large recipe sample + auto-QA (reliable, headless):
cd apps/mobile_flutter && BATCH_SEEDS=15 EXPERIMENT_LABEL=qasweep \
  flutter test test/features/merch/design_engine/procedural/batch_generate.dart
python3 design_studio/tools/recipe_qa.py design_studio/generated_batches/batch_v0.1.0_qasweep/batch.json

# pixel-QA on any rendered batch (on-device preferred):
python3 design_studio/tools/render_qa.py design_studio/generated_batches/rendered_device
```

## Results — 960-design sweep (8 contexts × 15 seeds × 8)

**Before this session's fixes** the same patterns were widespread; **after**
(E-005, E-006, F1, E-007 all in) the recipe-QA flags **0/960**:

| Defect pattern | Flagged /960 |
|---|---|
| TILE-REPEAT (E-005 single-flag grid) | **0** ✅ |
| CUTOUT-UNDERFILL (E-006 montage cutout) | **0** ✅ |
| FRAGMENT-RISK (E-007 dominantAccent) | **0** ✅ (was 5 before this fix) |
| LOW-QUALITY (<0.50) | **0** |
| **total** | **0 / 960** |

Per-family mean quality stayed healthy (singleHero 0.883 → repetitionField 0.699);
regression Δ 0.000 across all 8 contexts.

## New defect found by pixel-QA (open, needs on-device confirm)
- **`typographicIntegration` renders near-blank** — pixel-QA flagged
  `several-countries_typographicIntegration_2` at **0.4% coverage (BLANK)**. Same
  class as pre-fix `statementCount`: a type-led family whose typography template
  renders a small name-list, not a hero, so on a dark garment it's nearly empty.
  F1's `statementHero` covers only `statementCount`, not this family. → logged
  **E-008**; confirm on a fresh on-device capture before fixing (discipline: the
  0.4% is from the pre-F1 capture; recheck first).

## E-007 (this session's fix)
`dominantAccent` scattered 2 flags into fragmented quadrants under `montage`+circle+
small (5/960). Fix: `layoutModes` montage→`[treemap]` (weighted hero+accent tiles —
what the family wants; montage is the same scatter culprit as E-006). analyze clean,
regression Δ0.000, recipe-QA FRAGMENT-RISK 5→0.

## The loop, now automated
find (pixel-QA / recipe-QA over a large sweep) → confirm pattern → fix the
recipe-confirmable ones → re-sweep → verify 0 → log render-layer/ambiguous ones
(E-008) for on-device. Re-runnable any time via the two commands above.
