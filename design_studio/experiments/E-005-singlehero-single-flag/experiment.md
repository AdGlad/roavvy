# Experiment E-005 — singleHero single-country: one hero, not a tiled grid

- **Status:** kept · **Created:** 2026-08-16 · Track: optimisation (rendering correctness)
- **KB:** R-VH-01 (one bold hero), R-NEG-01 · **Source:** C-00 Lane A rendered evidence

## 1. Hypothesis
Rendered capture (C-00) showed a one-country `singleHero` rendering as a **3×3
repeated flag grid**, not one bold hero — despite a 0.85 analytic hierarchy score.
Cause: for hero families `rowCount` is sampled 1–3; with a single country and
`mask: none`, the flag-grid **tiles** the one flag across the rows. The analytic
model scores single-country by count alone and never reads `rowCount`, so it was
structurally blind to this.

## 2. Change (1 variable, guarded)
`procedural_generator.dart`: after sampling `rowCount`, force a single flag when
there is one country and no clip —
`resolvedRowCount = (n == 1 && mask == GridClipShape.none) ? 1 : rowCount;`
(A clip shape — outline/silhouette/circle — may still host one flag at rowCount>1,
because then the flag fills a hero shape.)

## 3. Before / after
| | Before | After |
|---|---|---|
| one-country singleHero (mask none) recipe | grid, rowCount **3** | grid, rowCount **1** |
| Rendered output | 3×3 grid of 9 flags | **one bold hero flag** (visually confirmed) |
| Regression (all contexts) | — | **all Δ 0.000** (analytic blind to rowCount here; determinism preserved) |
| analyze | — | clean |

## 4. Observations
- The analytic score didn't move (Δ 0.000) — proof this class of defect is
  invisible to the parameter scorer and only findable via C-00 rendered evidence.
- Silhouette-clipped single-country designs are unaffected (they legitimately fill
  a hero shape).

## 5. Decision — KEEP
Corrects a real rendering defect (R-VH-01) with a tight, deterministic guard; zero
regressions; verified in pixels (`generated_batches/rendered_e005/`).
