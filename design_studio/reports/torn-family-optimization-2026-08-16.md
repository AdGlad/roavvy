# Torn Family — Optimisation Run Report (2026-08-16)

*Autonomous Design-Studio optimisation of the **Torn** design family. The goal was
to improve the **generator's output distribution**, not individual images. Ended on
the **quality-plateau** stopping criterion after 4 experiments (all kept).*

Framework: `../OPTIMIZATION_STUDIO.md` · Bar: `../knowledge_base/` (torn-flag-hero
mood board, R-TEX/R-VH rules) · Evidence: `../experiments/E-T0{1..4}-*` +
regenerated `../generated_batches/torn_v2/`.

---

## 1. Final comparison (before → after)

Batch = 26 torn designs (8 curated families × seeds, + 2 composites), scored by the
reference-derived `torn_quality` metric (interior-clean & edge-concentration gates ×
finger-separation × sensible removed-material).

| Metric | Original generator | Optimised generator | Δ |
|---|---|---|---|
| **Batch average score** | 0.9015 | **0.9455** | **+0.0440 (+4.9%)** |
| **Worst design (floor)** | 0.635 | **0.792** | **+0.157** |
| Interior-clean / edge gates | 1.0 / 1.0 | 1.0 / 1.0 | held (print quality preserved) |
| Styles present (diversity) | 8 | 8 | held |
| removedFraction spread (light→heavy) | 0.005–0.081 | 0.015–0.080 | held (identity preserved) |

**Per-style (mean score):**

| Style | Original | Final | Δ | Note |
|---|---|---|---|---|
| lightlyWorn | 0.674 | **0.847** | **+0.173** | was degenerate (barely torn) |
| frayed | 0.847 | **0.903** | **+0.056** | fray now reads as separated streamers |
| battleWorn | 0.938 | **0.990** | +0.052 | more finger separation |
| ragged | 0.944 | **0.986** | +0.042 | " |
| asymmetricTear | 0.972 | **1.000** | +0.028 | " |
| tornCorners | 0.847 | **0.861** | +0.014 | corner-focused (intrinsically fewer edge fingers) |
| deepRips | 0.944 | 0.944 | 0 | already strong / saturated |
| heavyEdgeDamage | 1.000 | 1.000 | 0 | already ceiling |

**Every family improved or held; none regressed. The distribution's floor rose
+0.157 and its mean +0.044 — a system-level improvement, not selected examples.**

---

## 2. Experiments performed

| # | Change (variables) | Δ batch | Decision |
|---|---|---|---|
| **E-T01** | `lightlyWorn` damage floor: edgeDamage (0.15,0.30)→(0.28,0.45), maxDepth (0.05,0.10)→(0.09,0.15) | +0.0199 | keep |
| **E-T02** | `frayed` band: maxDepth (0.10,0.16)→(0.14,0.22) | +0.0032 | keep |
| **E-T03** | Global strand-density base: `12.0 → 15.0` (geometry generator) | +0.0192 | keep |
| **E-T04** | `lightlyWorn` recover: maxDepth (0.09,0.15)→(0.11,0.17) | +0.0016 | keep |

Each kept ≤3 variables, ran analyze + regenerated the same seeds + ran the torn
regression gates, and was recorded in `experiments/E-T0*/` (hypothesis →
implementation → before/after → measurements → observations → decision).

---

## 3. Accepted improvements (the shipped generator changes)

1. **`lightlyWorn` is now genuinely-but-lightly worn** (E-T01+E-T04). It was
   degenerate — ~0.5% removed, ~1 finger, barely readable as "torn" (violating the
   KB torn brief). Now ~1.5% removed with separated fingers, while remaining the
   lightest family. **+0.173.**
2. **`frayed`'s high fray now produces separated streamers** (E-T02) rather than a
   shallow near-solid bite. **+0.056.**
3. **A global finger-separation floor** (E-T03) lifted every non-saturated style at
   once (battleWorn/ragged/asymmetricTear/frayed/tornCorners) — the single biggest
   broad lever, aligned with the liked references (best reference = 22 finger
   transitions). **+0.019 batch.**

**WHY these work (per the KB):** the torn-flag references and mood board define the
family by *separated ragged fingers* and *visible-but-non-destructive wear*
(R-TEX-01, R-VH-01). Every accepted change moved the generator toward that trait —
more separated fingers and a sensible removed-material band — which is why scores
rose *and* the designs read as more on-brand, not merely metric-higher.

---

## 4. Rejected / reverted improvements

- **No full reverts were required** — all four hypotheses held.
- **One intra-run tradeoff was corrected, not shipped as-is:** E-T03 caused a
  −0.014 dip in `lightlyWorn` (finer strands merged under its shallow band). Rather
  than accept a regressed family, **E-T04 recovered it** — final state has zero
  regressed families.
- **Deliberately NOT pursued (would violate the diversity mandate):**
  - Forcing `tornCorners` to grow more edge-fingers — its low finger count is
    **intrinsic** to a corner-focused look; chasing it would homogenise the family
    toward ragged/battleWorn and *reduce diversity*. Left at 0.861 by design.
  - Pushing `lightlyWorn` further up by adding damage — would erode the light→heavy
    spread. Left as the lightest family.

---

## 5. Remaining weaknesses

1. **`frayed` residual finger ceiling** — 9.3 vs strong styles' 13–22. Its very
   high-frequency fibre-roughening likely merges some strands before they separate.
   Improvable but higher-risk (touches the fibre model) — deferred to respect
   "avoid unnecessary complexity".
2. **`tornCorners` scores lowest (0.861)** — but this is a **scorer limitation**,
   not a generator flaw: the finger metric under-credits a legitimately distinct
   corner-torn look. A "corner-damage" reward term in `torn_quality` would credit it
   fairly without changing the generator.
3. **Composite/2-flag torn designs** reuse single-flag metrics; no seam-specific
   quality signal yet.
4. **Metric coverage:** `torn_quality` scores geometry only — it does not yet judge
   colour harmony, on-garment contrast, or type (the broader KB axes). Those apply
   once torn designs flow through the full card renderer + print pipeline.

---

## 6. Recommended future work

1. **Scorer, not generator, for `tornCorners`:** add a corner-damage credit to
   `torn_quality` so distinct styles aren't penalised for being distinct — this
   protects diversity while lifting the floor.
2. **`frayed` fibre model** (one careful experiment): reduce fibre-merge at very
   high fray so its identity fully lands; measure finger separation, keep only if
   diversity holds.
3. **Extend the loop to the next families** using the same protocol: **Flag Grid**
   and **Passport** are the natural next scopes (both have clear KB rules — R-FLAG-03
   uniform grids, R-STORY-02 passport narrative — and existing templates).
4. **Wire `referenceAffinity`** (the KB's named gap): with the liked/disliked
   reference set, score torn batches by resemblance to liked references, not just
   the hand-built geometry metric — closing the loop between the KB bar and the
   scorer.
5. **Promote the tuned ranges into a versioned config** so torn tuning is
   data-driven (mirrors `design_engine/config/engine_config.json`).

---

## 7. Bottom line

Four small, disciplined, diversity-preserving generator changes moved the **whole
Torn distribution**: batch average **0.9015 → 0.9455 (+4.9%)**, worst-case
**0.635 → 0.792 (+25%)**, every family improved or held, zero regressions, all
print-quality gates and determinism preserved. This is a **measurable improvement
in the procedural engine**, achieved by tuning the generator against the Knowledge
Base — exactly the objective, and the reusable loop is now proven on a real family
and ready for the next one.
