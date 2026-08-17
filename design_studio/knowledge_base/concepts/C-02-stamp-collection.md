# Concept C-02 — Passport-Stamp Collection

- **Status:** ❌ REJECTED (deferred — blocked on the scorer, not the idea), 2026-08-16
- **Validation:** batches `generated_batches/batch_v0.1.0_concept-stampcollection/` (initial + refined); regression green both times but **no context improved and 2 marginally degraded**; reverted (determinism restored, all Δ 0.000).
- **KB alignment:** passport-stamp mood board; R-STORY-02 (journey/collection); R-FLAG-03 (uniform grid).

## Design description
A collection of passport stamps — one uniform stamp token per country, slight
controlled scatter — reading as a well-travelled passport. Realised via the
existing `passport` template (pure recombination). Intended niche: small–medium
trip / multi-country sets.

## Why it was rejected (the data)
| | Result |
|---|---|
| Analytic quality (mean) | **0.733** — above peer collection families (repetitionField 0.692, chronoSequence 0.710) but mid-low overall |
| Effect on contexts | `lifetime` neutral (after refine), **`year` −0.011, `region-europe` −0.006** — within tolerance but negative |
| Contexts improved | **none** |
| Weak/thin tiers helped | **none** (capped ≤24 countries; doesn't reach massive) |

Unlike C-01 (which entered the **weakest, thinnest** context and *raised* it),
C-02 enters **already-well-served** contexts as a mid-tier option, so it slightly
*lowers* their mean and improves nothing. It does not **significantly improve the
catalogue**, so per the mission it is rejected rather than shipped.

## Why it is DEFERRED, not killed (the real blocker)
The concept is commercially strong and on-brand (the KB has a dedicated
passport-stamp mood board). The low score is partly a **scorer blind spot**: the
analytic `quality_model` scores geometry/parameters and **cannot render passport
stamps**, so it under-credits any template-rendered family (same limitation that
under-credits C-01's type hero at focal 0.45). C-02 cannot be *fairly* validated
until it can be *seen*.

## What would unblock it (implementation recommendations)
1. **Render + rendered-PNG critique:** make the `passport` template produce a real
   stamp-collection raster, then evaluate via a rendered contact sheet (the torn
   family's PNG path) or a stamp-specific quality metric (like `torn_quality`).
2. **Re-validate against the liked references** (add passport-stamp exemplars to
   `reference_images/liked/`).
3. Only then reconsider promotion — with rendered evidence, not analytic proxy alone.

## Evaluation-criteria lesson (→ KB intelligence)
**The analytic quality model cannot fairly judge families whose quality lives in
rendering** (passport stamps; partly type-hero lockups). Concepts of this kind must
be validated with a **rendered-PNG critique or a family-specific pixel metric**
before acceptance — not the analytic score alone. Recorded as **C-00** (the
rendered-evidence evaluation prerequisite) in
`../../reports/concept_discovery_roadmap.md` so future cycles don't re-reject a
strong idea on a proxy metric.
