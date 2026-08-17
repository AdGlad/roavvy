# Experiment E-001 — Large/massive-set rejection & quality

- **Status:** planned
- **Created:** 2026-08-16   **Decided:** —
- **KB rules targeted:** R-MERCH-02 (density tiers by count), R-PRINT-04 (min
  feature), R-NEG-01 (breathing room), R-COMP-04 (compose, don't overflow)
- **Critique refs:** _(none yet — seeded from baseline metrics; run a batch +
  design-critic to attach evidence before implementing)_

## 1. Hypothesis
The generator systematically fails large country sets. In the baseline,
`massive-light` rejects **71.5%** of its pool and tops out at meanQuality **0.697**
/ topQuality **0.730**; `lifetime` rejects **58.3%** (mean 0.737). Quality falls and
rejection rises monotonically with country count (one-country ≈ 0.86 → massive ≈
0.70).

Mechanism (to confirm with the Critic): as density rises for many flags, families
push per-flag features below the printable **MinFeature** floor and/or trip the
**ClutterCap**, so most sampled candidates are rejected and the survivors are
low-hierarchy uniform fields. This is a **generator/constraint interaction for the
large-set families**, not any individual image.

## 2. Expected outcome
- **Improves:** `massive-light` and `lifetime` — cut rejectionRate substantially
  (target < ~0.35) and raise meanQuality by ~+0.03–0.06.
- **Must NOT regress:** `one-country-*`, `two-countries`, `several-countries`,
  `year`, `region-europe` (all within the 0.03 tolerance).
- **Diversity guard:** must not drop `lifetime` (4) / `massive-light` (3) family
  diversity further; ideally widen eligible large-set families.

## 3. Variables changed (keep to 1–3)
| File | Knob | From | To |
|---|---|---|---|
| `lib/features/merch/design_engine/procedural/composition_family.dart` | `kCompositionFamilies[repetitionField].densitySuitability` / `maxCountries` | _(current)_ | _(raise headroom for dense large sets)_ |
| `lib/features/merch/design_engine/procedural/hard_constraints.dart` | ClutterCap threshold for massive scope | _(current)_ | _(loosen within printable limits)_ |

_(Fill exact before→after values when the Engineer implements. Change ONE primary
lever first; add the second only if the first is insufficient.)_

## 4. Implementation
_(Engineer fills: the smallest edit that tests the hypothesis, before→after.)_

## 5. Rendered batch
- **experimentId:** E-001   **batchId:** batch_v0.1.0_large-set-rejection
- Generate + regress: `design_studio/tools/run_experiment.sh E-001 large-set-rejection`
- Contact sheet: `generated_batches/batch_v0.1.0_large-set-rejection/index.html`

## 6. Before / after (regression Δ)
| Context | base mean | cur mean | Δ | base div | cur div |
|---|---|---|---|---|---|
| massive-light | 0.697 | | | 3 | |
| lifetime | 0.737 | | | 4 | |
| _(watch)_ one-country-light | 0.864 | | | 4 | |
| _(watch)_ two-countries | 0.793 | | | 7 | |
| **aggregate** | 0.784 | | | | |

## 7. Scores
_(after run)_

## 8. Observations
_(Critic / Reference Analyst notes; tradeoffs named explicitly.)_

## 9. Decision — KEEP / REVERT
_(Director's call. Keep only if massive/lifetime improved AND no watched context
regressed beyond tolerance AND diversity held. Note if a deliberate tradeoff
required REGEN_BASELINE.)_
