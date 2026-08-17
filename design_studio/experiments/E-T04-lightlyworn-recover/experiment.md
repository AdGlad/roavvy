# Experiment E-T04 — recover lightlyWorn under finer strands (Torn)

- **Status:** kept · **Created:** 2026-08-16 · **Family:** Torn · **KB:** R-TEX-01, R-VH-01
- **Before:** post-E-T03 `torn_v2` (avg 0.9439) → `before_batch.json`

## 1. Hypothesis
E-T03 raised global strand density and lifted 5 styles, but `lightlyWorn`
regressed −0.014 (fingers 4.7→4.0): its finer strands merged under its shallow
band. Deepening that band slightly should let strands separate again and restore
its finger count — eliminating the only regressed family.

## 2. Expected outcome
`lightlyWorn` back to ≥0.847; no other style changed; gates hold; still the
lightest family (diversity preserved).

## 3. Variables changed (1, one family)
| File | Knob | From | To |
|---|---|---|---|
| `torn_recipe.dart` | `kTornFamilies[lightlyWorn].maxDepth` | (0.09, 0.15) | (0.11, 0.17) |

## 4. Implementation
Deepen only `lightlyWorn`'s band. Nothing else touched.

## 5–7. Result / measurements
| Metric | before (E-T03) | after |
|---|---|---|
| lightlyWorn mean | 0.833 | **0.847** (+0.014) |
| lightlyWorn fingers | 4.0 | 4.7 |
| every other style | — | byte-identical (0) |
| batch avg | 0.9439 | **0.9455** (+0.0016) |
| worst design | 0.792 | 0.792 |
| styles present | 8 | 8 |

analyze clean; torn gates green; interiorClean/edgeConcentration min = 1.0;
zero regressions vs E-T03.

## 8. Observations
- Clean recovery — the E-T03 tradeoff is fully resolved; the **final state has no
  regressed family** vs the original.
- `lightlyWorn` stays the lightest family; diversity preserved.
- Improvement has plateaued (+0.0016 recovery); remaining weak styles
  (`tornCorners` 0.861 intrinsic corner-focus; `frayed` 0.903 residual fray-ceiling)
  would need diversity loss or added complexity → stop here per the goal.

## 9. Decision — KEEP
Recovered the only regressed family with no side effects. **KEPT.** Torn-family
optimisation reaches its plateau at batch avg **0.9455** (from 0.9015).
