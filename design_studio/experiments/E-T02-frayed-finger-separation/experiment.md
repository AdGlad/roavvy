# Experiment E-T02 — frayed finger separation (Torn family)

- **Status:** kept
- **Created:** 2026-08-16 · **Family:** Torn · **KB:** torn-flag-hero; R-TEX-01 (design-aware wear), R-VH-01
- **Before:** post-E-T01 `torn_v2` (avg 0.9215) → `before_batch.json`

## 1. Hypothesis
`frayed` has the **highest** fray parameter (0.80–1.00) yet produced the **fewest**
finger transitions (~4.7, tied-lowest with tornCorners) at mean score 0.847. The
fine strands had too shallow a damaged band (`maxDepth 0.10–0.16`) to taper into
separated, countable fingers — so high fray did not translate into its own
identity ("many fine separated streamers"). This is a generator mismatch, not a
bad image.

## 2. Expected outcome
- **Improves:** `frayed` finger transitions and mean score (target ~0.90+), by
  deepening the band so strands separate.
- **Must NOT regress:** other styles (untouched); interior/edge gates stay 1.0
  (maxDepth 0.22 < 0.30 cap).
- **Diversity guard:** `frayed` stays distinct (its identity = high fray + high
  frequency 6–9 + 3 damaged edges); it is not being made into ragged/battleWorn.

## 3. Variables changed (1, one family)
| File | Knob | From | To |
|---|---|---|---|
| `torn_recipe.dart` | `kTornFamilies[frayed].maxDepth` | (0.10, 0.16) | (0.14, 0.22) |

## 4. Implementation
Deepen only the `frayed` band. No scorer/renderer/other family touched.

## 5. Rendered batch
`TORN_STUDIO_BATCH=1 flutter test .../torn/torn_studio_batch_test.dart` → overwrites
`torn_v2/` (after). Contact sheet `torn_v2/index.html`.

## 6. Before / after
| Metric | before | after | Δ |
|---|---|---|---|
| batch avg | 0.9215 | **0.9247** | +0.0032 |
| frayed mean | 0.847 | **0.875** | +0.028 |
| frayed fingerTransitions | 4.7 | 6.7 | +2.0 |
| frayed removedFraction | 0.0175 | 0.0241 | +0.0066 |
| tornCorners / lightlyWorn (untouched) | 0.847 | 0.847 | 0 |
| styles present | 8 | 8 | 0 |

## 7. Measurements / regression
analyze clean; torn gates all green; interiorClean/edgeConcentration min = 1.0;
every other style byte-identical (determinism preserved).

## 8. Observations
- Deeper band lifted `frayed` fingers 4.7→6.7 and score +0.028 — the hypothesis
  held **partially**: `frayed` still under-delivers fingers vs its high fray (6.7
  vs strong styles' 12+), so the fray→finger translation has a residual ceiling
  (likely fibre-roughening merging strands — higher-risk to chase).
- Zero regressions; diversity preserved (frayed remains a distinct high-fray style).

## 9. Decision — KEEP
Real, clean improvement (+0.028 target, +0.0032 batch) with no regressions and
diversity held. **KEPT.** Smaller than E-T01 → improvements are diminishing.
