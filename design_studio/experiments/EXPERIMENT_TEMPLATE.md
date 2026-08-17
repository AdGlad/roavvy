# Experiment E-### — <short title>

- **Status:** planned | running | kept | reverted | abandoned
- **Created:** <date>   **Decided:** <date>
- **KB rules targeted:** <e.g. R-VH-01, R-MERCH-02>
- **Critique refs:** <critiques/<batchId>.json finding ids>

## 1. Hypothesis
<The SYSTEMATIC generator weakness and the mechanism. Cite baseline numbers and a
critique finding. This is about the *generator*, across contexts/seeds — never one
image. e.g. "Two-/three-country sets in `repetitionField` read flat (mean
hierarchy sub-score 0.41 vs 0.78 for singleHero); the family sampler over-weights
uniform fields for small counts, so small sets lack a focal country.">

## 2. Expected outcome
- **Improves:** <contexts/families + rough magnitude, e.g. two-countries meanQuality +0.03..0.05>
- **Must NOT regress:** <contexts/families to watch, e.g. lifetime, massive-light>
- **Diversity guard:** <why familyDiversity won't collapse>

## 3. Variables changed (keep to 1–3)
| File | Knob | From | To |
|---|---|---|---|
| <path> | <knob> | <value> | <value> |

## 4. Implementation
<The exact edit(s). Before→after. Smallest change that tests the hypothesis.>

## 5. Rendered batch
- **experimentId:** E-###   **batchId:** batch_v<engine>_<label>
- Generate: `design_studio/tools/run_experiment.sh E-### <label>`
- Contact sheet: `generated_batches/<batchId>/index.html`

## 6. Before / after (regression Δ)
| Context | base mean | cur mean | Δ | base div | cur div |
|---|---|---|---|---|---|
| … | | | | | |
| **aggregate** | | | | | |

## 7. Scores
<Aggregate + per-context after; note top/rejection changes.>

## 8. Observations
<What the Critic / Reference Analyst saw. Surprises. Tradeoffs named explicitly.>

## 9. Decision — KEEP / REVERT
<Director's call and the reason. If reverted: `git checkout <files>` (the folder
stays as a record). If kept with a deliberate tradeoff: note that the baseline was
re-generated and exactly what got worse and why it's acceptable.>
