# Optimisation Roadmap — Design Director's living plan

*The ranked backlog of generator experiments and the log of what's been kept or
reverted. This is the Director's home base: a fresh context can resume the whole
optimisation from this file alone. Update it every cycle.*

Framework: `../OPTIMIZATION_STUDIO.md` · Bar: `../knowledge_base/` · Arbiter:
`../regression_tests/baselines/procedural_baseline.json`.

---

## Current baseline snapshot (engine 0.1.0 / grammar 0.1.0, seeds 1–3)

| Context | meanQuality | topQuality | rejectionRate | familyDiversity |
|---|---|---|---|---|
| one-country-light | 0.864 | 0.912 | 0.000 | 4 |
| one-country-dark | 0.858 | 0.911 | 0.000 | 4 |
| two-countries | 0.793 | 0.848 | 0.007 | 7 |
| several-countries | 0.782 | 0.854 | 0.007 | 7 |
| year | 0.779 | 0.825 | 0.000 | 6 |
| region-europe | 0.762 | 0.879 | 0.090 | 7 |
| lifetime | 0.737 | 0.776 | **0.583** | 4 |
| massive-light | **0.697** | **0.730** | **0.715** | 3 |
| **aggregate** | **0.784** | — | — | — |

**The through-line:** quality falls and rejection rises monotonically with country
count. Single-country is strong; large/massive sets are the drag on the aggregate
and the weakest product experience. That is where the leverage is.

> ✅ **Baseline confirmed valid (E-000, 2026-08-16).** Ran the arbiter against
> current code: all |Δ| ≤ 0.005, tests green. The staleness concern was **not**
> borne out — the committed baseline reproduces within noise, so it is a valid
> arbiter as-is; no re-baseline was needed. The framework is validated end-to-end.

---

## Ranked experiment backlog

### E-000 — Re-baseline against current code *(housekeeping)* — ✅ DONE
- **Why:** confirm the arbiter matches current code before trusting any Δ.
- **Result (2026-08-16):** regression green, all |Δ| ≤ 0.005; baseline valid,
  **no re-baseline needed**. Framework validated end-to-end.
  See `experiments/E-000-rebaseline-check/`. **Status:** kept.

### E-001 — Large/massive-set rejection & quality *(highest leverage)*
- **Weakness:** `massive-light` rejects **71.5%** and tops out at 0.730;
  `lifetime` rejects **58.3%**. The generator wastes most of its pool on invalid
  large-set layouts and never reaches high quality.
- **Hypothesis:** for high country counts the hard constraints (MinFeature /
  ClutterCap) reject most sampled layouts because families keep per-flag features
  below the printable floor as density rises; the survivors are low-hierarchy
  fields. Root cause is in family density-suitability + clutter cap interaction,
  not any one image.
- **Expected:** raise `lifetime`/`massive-light` meanQuality and cut rejection
  markedly; **must not** regress one/two-country contexts; diversity must hold ≥
  baseline.
- **Variables (≤3):** `kCompositionFamilies` density-suitability/max-count for the
  large-set families (repetitionField, negativeSpaceCutout, typographicIntegration)
  and/or `hard_constraints.dart` ClutterCap for massive scope.
- **KB:** R-MERCH-02, R-PRINT-04. **Status:** 🟡 PARTIAL (2026-08-17) — capped
  chronoSequence maxCountries 120→20 (0 survivors at lifetime/massive, pure waste):
  lifetime rej 0.521→0.438, massive 0.667→0.625; zero quality/diversity cost.
  **E-001b remaining:** repetitionField+small-imageSize MinFeature rejects; negativeSpaceCutout ClutterCap at high n. See `experiments/E-001-*`.

### E-002 — Multi-country hierarchy / quality ceiling
- **Weakness:** topQuality for multi-country caps at 0.73–0.85 vs 0.91 for
  one-country — no family reaches "excellent" once there are many flags.
- **Hypothesis:** no family establishes a clear focal country for medium/large
  sets, so `hierarchy`/`focalContrast` sub-scores cap the total (R-VH-01). A
  hero-in-field or dominantAccent bias for medium counts should lift the ceiling.
- **Expected:** raise topQuality for two-/several-countries/year without flattening
  diversity. **Variables:** family scope/density weights for medium counts;
  possibly `quality_model` hierarchy weight (careful — global).
- **KB:** R-VH-01/02, R-MERCH-02. **Status:** planned.

### E-003 — region-europe rejection & mid-quality
- **Weakness:** `region-europe` rejects 9.0% (highest among non-massive) at mean
  0.762 despite a healthy 0.879 ceiling — the family mix is right but too many
  candidates die.
- **Hypothesis:** a specific constraint (clip legality / min feature for region
  outlines) is over-rejecting; loosening within printable limits recovers quality.
- **KB:** R-ICON-04, R-FLAG-03. **Status:** planned.

### E-004 — Diversity floor for lifetime/massive
- **Weakness:** `lifetime` (4) and `massive-light` (3) have the lowest family
  diversity — large-set output is converging. Guard against E-001/E-002 making
  this worse; possibly widen eligible families for big sets.
- **KB:** R-MERCH-01, diversity guardrail. **Status:** planned (run after E-001).

### E-005 — singleHero one-country renders as a repeated flag grid *(from rendered evidence, C-00 Lane A)*
- **Weakness (pixel-surfaced):** the first rendered capture showed a one-country
  `singleHero` design rendering as a **3×3 repeated flag grid**, not one bold hero
  — contradicting the family's intent (R-VH-01) even though the analytic model
  scored its hierarchy 0.85 (it scored the params, not the pixels).
- **Hypothesis:** for a single country, the `grid` template + rowCount repeats the
  flag; singleHero should prefer a true hero (outline/silhouette clip or a single
  large flag), not an N×N tile. Likely a template/mask or rowCount prior for
  count==1 in `singleHero`.
- **KB:** R-VH-01, R-NEG-01. **Status:** ✅ DONE (2026-08-16) — guard added
  (`n==1 && mask==none → rowCount 1`); rendered evidence confirms one bold flag;
  zero regressions. Only findable via C-00 Lane A. See `experiments/E-005-*`.

---

## Decision log (append one line per completed cycle)

| Date | Experiment | Decision | Aggregate Δ | Notes |
|---|---|---|---|---|
| 2026-08-16 | E-000 rebaseline-check | keep | +0.001 (noise) | Baseline valid; framework validated end-to-end; no code change |
| 2026-08-16 | E-T01 lightlyworn-damage-floor (Torn) | keep | +0.0199 batch | lightlyWorn 0.674→0.847; floor 0.635→0.792; zero regressions; diversity held |
| 2026-08-16 | E-T02 frayed-finger-separation (Torn) | keep | +0.0032 batch | frayed 0.847→0.875 (fingers 4.7→6.7); zero regressions; diminishing returns |
| 2026-08-16 | E-T03 global-strand-density (Torn) | keep | +0.0192 batch | 5 styles up (battleWorn +0.052, ragged +0.042…); lightlyWorn −0.014 (within tol, recovered in E-T04); diversity held |
| 2026-08-16 | E-T04 lightlyworn-recover (Torn) | keep | +0.0016 batch | lightlyWorn 0.833→0.847 recovered; zero regressions; **plateau → Torn family complete (0.9015→0.9455)** |
| 2026-08-16 | E-005 singlehero-single-flag | keep | Δ0.000 (render fix) | one-country singleHero 3×3 grid → one bold flag; found via C-00 rendered evidence; determinism preserved |
| 2026-08-17 | E-001 large-set-rejection (chronoSequence cap) | keep | rej −8/−4pts | lifetime 0.521→0.438, massive 0.667→0.625; zero quality/diversity cost; baseline regenerated |

### E-006 — negativeSpaceCutout hero renders tiny/off-center *(CONFIRMED on-device, C-00 Lane A2)*
- **Confirmed bug:** silhouette renders ~8% of frame, lower-right, despite recipe
  heroScale 0.897 / placement center (real assets loaded on device — not a headless
  artifact). Violates R-VH-01/R-NEG-01; near-blank tee.
- **Diagnosis refined (2026-08-17):** NOT `_clipPathFor` (both the clip and montage
  intend to fill). Root cause = the montage↔clip fill interaction for few-flag
  cutouts — all 3 tiny renders used `layoutMode: montage`, which scatters few flags
  into a small cluster.
- **Mitigation applied:** `negativeSpaceCutout.layoutModes` montage→[packedRow,
  normalizedGrid] (the engine's fill-the-canvas modes). analyze clean, regression
  Δ0.000. **Status:** ✅ RESOLVED (2026-08-18). Instrumented: clip + coverGrid are
  CORRECT (3 wrong hypotheses disproven with measurements). Real cause = too few
  flags / thin outlines / white-flag invisibility. Fix: minCountries 1->3. Regression
  green; 0 single/two-country cutouts. Residual: white-flag contrast (separate).

### E-007 — dominantAccent fragmented (small+montage+circle) *(confirmed weak, Lane A2)*
- Legal but weak combo (heroScale 0.39 + imageSize small + montage + circle) renders
  fragmented/unbalanced. Generator-prior tunable: avoid that combo / raise min hero
  scale for 2-country dominantAccent. `critiques/rendered_device.md` F3. **Status:** open, low-confidence.

### statementCount content wiring *(CONFIRMED CRITICAL, C-00 Lane A2)*
- On-device, `statementCount` renders **near-empty** — the count is a tiny footer,
  not the hero. C-01 is structurally valid + scored 0.79 but **not production-ready**
  until the stat string is wired as the hero title (TitleGen stat variant + typography
  template renders it hero-scale). `critiques/rendered_device.md` F1. **Status:** open (top C-01 follow-up).

### duoBlend not blended *(sim-limited — needs a physical device)*
- Renders stacked, not blended (GPU shader likely off on the iOS simulator). Re-capture
  on a real device before any fix. `critiques/rendered_device.md` F4.

---

### E-007 — dominantAccent fragmentation — ✅ DONE (2026-08-18, recipe-QA)
- Isolated by the new recipe-QA (5/960 FRAGMENT-RISK). Fix: `dominantAccent`
  layoutModes montage→`[treemap]` (montage-scatter culprit, same as E-006). analyze
  clean, regression Δ0.000, recipe-QA FRAGMENT-RISK 5→0.

### E-008 — typographicIntegration renders near-blank *(pixel-QA, needs on-device confirm)*
- CONFIRMED on-device (2026-08-18): 2 instances near-blank. Auto-flagged by render_qa.py: `several-countries_typographicIntegration_2` at 0.4%
  coverage (BLANK). Same class as pre-F1 statementCount — a type-led family whose
  typography template renders a small name-list, not a hero (near-empty on dark
  garment). F1's statementHero covers only statementCount. **Status:** open; the
  0.4% is from the pre-F1 capture, so re-capture on-device before fixing.

### Automated Render-QA framework (2026-08-18) — ✅ delivered
- `tools/render_qa.py` (pixel-QA: coverage/centroid/blank) + `tools/recipe_qa.py`
  (recipe-QA: encoded defect patterns over hundreds of designs) + widened sampling
  (`BATCH_SEEDS`, `RENDER_CONTEXTS/SEEDS/PERCTX`). 960-design sweep: **0/960 flagged**
  (all fix patterns validated). See `render-qa-framework-2026-08-18.md`.

## Deferred to on-device confirmation (C-00 Lane A2)
Rendered review (2026-08-16) flagged 3 suspect designs; recipe cross-check cleared
all as NON-recipe → not fixed headless (would be phantom-chasing), pending on-device
pixels:
- **negativeSpaceCutout hero renders tiny/off-center** — recipe correct (heroScale
  0.897, continentOutline `africa`, centered); the `africa` outline SVG didn't load
  headless. Confirm on device; if real, it's a clip-outline scale/placement render bug.
- **duoBlend not blended** — GPU blend/ripple shader doesn't run headless
  (`layerMode: flat`). Expected; verify the blend on device.
- **dominantAccent fragmented in circle** — *low-confidence tuning candidate*: legal
  but weak combo (heroScale ~0.39 + imageSize small + montage + circle). Consider a
  prior that avoids small+montage+circle for dominantAccent — but only after on-device
  confirms it reads poorly with real flag art.

## Completed runs
- **Torn family — DONE (2026-08-16).** 4 kept experiments (E-T01…E-T04); batch avg
  **0.9015 → 0.9455 (+4.9%)**, worst design 0.635 → 0.792, every style improved or
  held, zero regressions, gates + determinism preserved. Plateau reached. Full
  writeup: `torn-family-optimization-2026-08-16.md`.

## Next action
Two tracks remain:
1. **Next design family (procedural render loop):** apply the same protocol to
   **Flag Grid** then **Passport** (clear KB rules R-FLAG-03 / R-STORY-02, existing
   templates). Torn-family follow-ups are in that report §6 (a `tornCorners` scorer
   credit; a careful `frayed` fibre experiment).
2. **Composition-family backlog (parameter engine):** the E-001…E-004 items below
   still stand — the large/massive-set rejection (E-001) is the highest-leverage
   lever for the aggregate quality metric. Scope with the `engine-tuner`, ≤3
   variables, arbitrated by the regression suite.
