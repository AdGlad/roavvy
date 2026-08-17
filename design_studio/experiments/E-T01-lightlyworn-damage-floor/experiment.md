# Experiment E-T01 — lightlyWorn damage floor (Torn family)

- **Status:** kept
- **Created:** 2026-08-16
- **Family:** Torn · **KB:** torn-flag-hero mood board; R-TEX-01/03 (visible, design-aware wear), R-VH-01 (bold single hero reads at a glance)
- **Before batch:** committed `generated_batches/torn_v2/` (avg 0.9015) → snapshot `before_batch.json`

## 1. Hypothesis
`lightlyWorn` is the systematically weakest torn family — the three lowest scores
in the whole batch (0.635 / 0.647 / 0.742, mean **0.674**) are all `lightlyWorn`.
Cause: its ranges (`edgeDamage 0.15–0.30`, `maxDepth 0.05–0.10`) yield
`scale = maxTearDepth·edgeWeight·edgeDamageAmount ≈ 0.014`, barely above the
`scale < 0.012 → 0` snap-to-intact threshold in the geometry generator. So most of
its perimeter never tears → removedFraction ≈ **0.48%** (below the scorer's 0.01
"amount" floor) and only **1.3** finger transitions. It barely reads as "torn" at
all, which also fails the KB torn brief ("visible wear", "separated ragged
fingers"). This is a **family-level generator weakness**, not a bad individual
image (all seeds fail identically).

## 2. Expected outcome
- **Improves:** `lightlyWorn` mean 0.674 → ~0.88+ (removedFraction into the 1.5–5%
  "visibly-but-lightly worn" band; finger transitions up as a real torn band
  forms). Lifts the whole batch average and, importantly, its **floor**.
- **Must NOT regress:** every other style (untouched — only the `lightlyWorn`
  spec changes); interiorClean / edgeConcentration must stay 1.0 (maxDepth 0.15 ≪
  the 0.30 penetration cap, so the interior is still never breached).
- **Diversity guard:** `lightlyWorn` stays the **lightest** family (its new
  `edgeDamage 0.28–0.45` / `maxDepth 0.09–0.15` remain below `ragged`'s
  0.35–0.55 / 0.12–0.20), so the light↔heavy spread is preserved, not collapsed.

## 3. Variables changed (2, one family)
| File | Knob | From | To |
|---|---|---|---|
| `torn_recipe.dart` | `kTornFamilies[lightlyWorn].edgeDamage` | (0.15, 0.30) | (0.28, 0.45) |
| `torn_recipe.dart` | `kTornFamilies[lightlyWorn].maxDepth` | (0.05, 0.10) | (0.09, 0.15) |

## 4. Implementation
Edit the `lightlyWorn` `TornFamilySpec` ranges only. No scorer, renderer, or other
family touched. (before→after captured above.)

## 5. Rendered batch
- Regenerate: `cd apps/mobile_flutter && TORN_STUDIO_BATCH=1 flutter test test/features/merch/design_engine/torn/torn_studio_batch_test.dart`
- Output overwrites `generated_batches/torn_v2/` (the "after"); contact sheet
  `torn_v2/index.html`.

## 6. Before / after
| Metric | before | after | Δ |
|---|---|---|---|
| batch avg score | 0.9015 | **0.9215** | +0.0199 |
| lightlyWorn mean | 0.674 | **0.847** | +0.173 |
| lightlyWorn removedFraction | 0.0048 | 0.0151 | +0.0103 (clears 0.01 floor) |
| lightlyWorn fingerTransitions | 1.3 | 4.7 | +3.4 |
| worst design in batch | 0.635 | 0.792 | +0.157 (floor lifted) |
| styles present (diversity) | 8 | 8 | 0 |
| every other style | — | byte-identical | 0 (no regression) |

## 7. Measurements / regression
- **analyze:** clean (`No issues found`).
- **Torn gates green:** `torn_quality_test.dart` + `torn_geometry_generator_test.dart`
  all pass — including "deepRips opens larger missing sections than lightlyWorn"
  (style ordering/diversity preserved) and "a torn family actually removes material".
- **interiorClean / edgeConcentration** min = 1.0 across all 26 designs (interior
  never breached; maxDepth 0.15 ≪ 0.30 cap).
- **Determinism preserved** (same seeds → deterministic recipe from bounded ranges).
- **Other subsystems:** `torn_recipe.dart` is imported only by the torn engine, not
  the procedural composition families, so the procedural regression is unaffected.

## 8. Observations
- The fix worked exactly as hypothesised: raising the damage floor moved
  `lightlyWorn` out of the "barely-torn" degenerate zone (0.48% removed, ~1 finger)
  into a genuinely-but-lightly worn look (1.5% removed, ~5 fingers), lifting the
  whole batch's **floor** (0.635 → 0.792) and mean.
- **Diversity held:** `lightlyWorn` remains the lightest family (removedFraction
  0.0151 vs heaviest heavyEdgeDamage 0.0807); all 8 styles distinct; every other
  style unchanged. This is a distribution improvement, not a per-image tweak.
- `lightlyWorn` now sits with `frayed`/`tornCorners` at ~0.847 — the next weak
  cluster (all limited by low finger transitions ~4.7). → E-T02.

## 9. Decision — KEEP
Target improved (+0.173), batch avg +0.0199, floor +0.157, **zero regressions**,
gates hold, diversity preserved. **KEPT.** The regenerated `torn_v2/` is the new
reference batch.
