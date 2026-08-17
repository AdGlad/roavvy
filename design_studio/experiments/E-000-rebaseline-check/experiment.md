# Experiment E-000 — Re-baseline / arbiter integrity check

- **Status:** kept (baseline confirmed valid; no change needed)
- **Created:** 2026-08-16   **Decided:** 2026-08-16
- **KB rules targeted:** n/a (framework integrity step)
- **Critique refs:** n/a

## 1. Hypothesis
Before optimising, confirm the regression baseline is a valid arbiter for the
*current* generator. Concern: the committed baseline still lists `radialEmblem`
(believed retired from generation) and predates `duoBlend`, so later Δs might be
measured against stale numbers.

## 2. Expected outcome
Either (a) the regression is green and current code matches the baseline → proceed,
or (b) it reports drift from the retirement → review, then re-baseline
(`REGEN_BASELINE=1`) and record old→new.

## 3. Variables changed
None. This is a measurement-only cycle (no generator edit).

## 4. Implementation
Ran the arbiter:
`cd apps/mobile_flutter && flutter test test/features/merch/design_engine/procedural/regression_test.dart`

## 5. Rendered batch
None required (regression uses fixed fixtures internally).

## 6. Before / after (regression Δ) — ACTUAL
| Context | base mean | cur mean | Δ |
|---|---|---|---|
| one-country-dark | 0.858 | 0.862 | +0.004 |
| one-country-light | 0.864 | 0.863 | −0.001 |
| two-countries | 0.793 | 0.796 | +0.003 |
| several-countries | 0.782 | 0.782 | +0.000 |
| year | 0.779 | 0.780 | +0.001 |
| region-europe | 0.762 | 0.767 | +0.005 |
| lifetime | 0.737 | 0.735 | −0.002 |
| massive-light | 0.697 | 0.699 | +0.002 |

**Result:** `All tests passed` (exit 0). All |Δ| ≤ 0.005 — well inside the 0.03
tolerance; family diversity held.

## 7. Scores
Aggregate unchanged (~0.784). No context regressed.

## 8. Observations
- The **loop's measurement + arbiter run correctly** in this environment — the
  framework is validated end-to-end (generate/score/regress/compare all execute).
- The staleness hypothesis was **not** borne out: current code reproduces the
  committed baseline within noise, so the baseline is a **valid arbiter as-is**.
  (Whatever the `radialEmblem` code path status, the regression fixtures produce
  numbers consistent with the committed baseline — no honest-Δ problem.)
- This run is the **"before" snapshot** for E-001+.

## 9. Decision — KEEP
Baseline confirmed valid; **no re-baseline performed** (would have been an
unnecessary change). Proceed to E-001 (large/massive-set rejection). Recorded in
the roadmap decision log.
