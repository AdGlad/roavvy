# Experiment E-T03 — global strand-density floor (Torn family)

- **Status:** kept (with a follow-up to recover one style → E-T04)
- **Created:** 2026-08-16 · **Family:** Torn · **KB:** torn-flag-hero; R-TEX-01, R-VH-01, R-MERCH (distribution)
- **Before:** post-E-T02 `torn_v2` (avg 0.9247) → `before_batch.json`

## 1. Hypothesis
Several styles under-deliver separated fingers (the KB's defining torn trait);
raising the **base** strand density in the geometry generator should lift the
low-finger styles broadly, while the strong styles (already ≥12 fingers, the
scorer saturation point) stay unchanged in score — a distribution-floor lift with
no ceiling cost.

## 2. Expected outcome
- **Improves:** the low/medium-finger styles across the board.
- **Must NOT:** breach interior/edge gates; collapse diversity.

## 3. Variables changed (1, global)
| File | Knob | From | To |
|---|---|---|---|
| `torn_geometry_generator.dart` | `strandCycles` base | `12.0 + fray·44` | `15.0 + fray·44` |

## 4. Implementation
One constant in `_EdgeProfile.forEdge`. No per-style or scorer change.

## 5. Rendered batch
`TORN_STUDIO_BATCH=1 flutter test .../torn_studio_batch_test.dart` → `torn_v2/`.

## 6. Before / after
| Style | before | after | Δ |
|---|---|---|---|
| battleWorn | 0.938 | 0.990 | +0.052 |
| ragged | 0.944 | 0.986 | +0.042 |
| frayed | 0.875 | 0.903 | +0.028 |
| asymmetricTear | 0.972 | 1.000 | +0.028 |
| tornCorners | 0.847 | 0.861 | +0.014 |
| deepRips | 0.944 | 0.944 | 0 |
| heavyEdgeDamage | 1.000 | 1.000 | 0 |
| **lightlyWorn** | 0.847 | **0.833** | **−0.014** |
| **batch avg** | 0.9247 | **0.9439** | **+0.0192** |
| worst design | 0.792 | 0.792 | 0 |
| styles present | 8 | 8 | 0 |

## 7. Measurements / regression
analyze clean; all torn gates green; interiorClean/edgeConcentration min = 1.0;
diversity preserved (8 styles, light→heavy spread intact).

## 8. Observations
- Big, **broad** lift — 5 styles up, 2 saturated-flat, exactly one down. My
  "this will just confirm a plateau" expectation was wrong: the global finger
  floor was the single biggest lever after E-T01.
- **One micro-regression:** `lightlyWorn` −0.014 (fingers 4.7→4.0). Cause: finer
  strands under its (deliberately) shallow band merge and undercount. It is within
  the 0.03 family tolerance and the net is strongly positive, but a regressed
  family is worth eliminating → **E-T04** deepens `lightlyWorn`'s band slightly to
  restore its fingers under the new finer-strand regime.

## 9. Decision — KEEP
Net +0.0192 batch, 5 styles improved, gates hold, diversity preserved; the single
−0.014 style is within tolerance and is addressed by E-T04. **KEPT.**
