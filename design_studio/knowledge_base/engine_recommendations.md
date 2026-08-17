# Recommendations for the Procedural Design Engine

*How the Design Knowledge Base should change what the engine generates, scores
and optimises. This is the bridge from "design taste" to `design_recipe`,
`engine_config.json`, the scorers, and the `OptimizationLoop`. Research-phase
output — **no implementation yet**; every item is a proposal keyed to existing
code so it extends rather than replaces (`design_engine/README.md` §"one rule").*

Grounded in: `design_engine/grammar/design_grammar.md`,
`design_engine/config/engine_config.json`,
`design_engine/docs/capability_matrix.md`,
`docs/design/ai-tshirt-design-engine.md`.

---

## 0. The single objective this KB encodes

> Maximise **"reads as a premium, intentional travel graphic"** subject to the
> **printability gate**, while preserving **diversity of ideas** and **personal
> relevance**.

Everything below is a way to push the searchable genome toward that objective.
The KB's rules (`design_rules.json`) are the human-readable form; the scorers and
generation priors are the executable form. **They must stay in sync** — a rule
with `confidence: high` and no scorer/gene binding is a gap to close.

---

## 1. Design recipes (priors & presets)

The KB should ship as **generation priors**, not hard-coded presets, so the space
stays open. Concrete changes to how `RankerSeededGenerator` seeds a population:

1. **Bias templates by scope using the Design Language vocabulary** (§3 of
   `design_language.md`). The grammar's "scope → bias" table
   (`design_grammar.md`) is the right hook; enrich its priors with KB confidence:
   - `singleCountry` → hero flag / `countryOutline` / `badge` (strong focal rules).
   - `lifetime` (large sets) → `montage`/`treemap` **but cap density at balanced**
     to avoid the clutter anti-pattern (see rules R-COMP-*).
   - `trip` → `passport` + `stampMode: entryExit`.
   - `region` → `continentOutline` / region map.
2. **Curated recipes as anchors, not cages.** Keep `design_studio/recipes/*.json`
   (e.g. `torn_flag_usa`) as known-good seeds injected into the population, then
   let mutation explore around them. Anchors guarantee a floor; the loop finds the
   ceiling.
3. **Palette recipes** (once `paletteEngine` is on): encode the earthy/muted
   temperament (§4 Design Language) as weighted `palette.strategy` priors —
   `duotone`/`monochrome`/`garmentAware` favoured over literal `flagDerived` at
   full saturation.
4. **Every recipe records the rules it satisfies** (add rule ids to
   `provenance`/critique) so a batch can be audited against the KB.

---

## 2. Procedural generation (open up the biggest levers)

The `capability_matrix.md` names the highest-value gaps; the KB says which to
prioritise and how to bias them. **Turn the off-by-default flags into genes,
in this order** (each is the biggest unlock for "premium, unlimited variety"):

| Flag (`engine_config.featureFlags`) | Why the KB prioritises it | Prior to seed it with |
|---|---|---|
| `typographyTreatment` | Type is the #1 amateur-vs-pro tell (see `typography.md`). Fixed per-template type caps quality. | ≤2 type roles, tracked caps, case discipline; arced type only on `badge`. |
| `paletteEngine` | Colour is the #1 premium-vs-souvenir tell (`colour.md`). | Muted/earthy priors; garment-aware contrast; accent count ≤2. |
| `motifEngine` | Adds "discovery" storytelling (landmarks, coordinates, journey lines). | One hero motif max; consistent stroke; motif must not fight the focal element. |
| `preferenceReRank` | Personalises taste once feedback exists (Stage 5). | Cold-start from persona + reference affinity, then learn. |

**Determinism stays sacred:** every new stochastic choice draws from a *named*
seed sub-stream (`engine_config.determinism.seedStreams` already lists
`palette`, `motif`, `jitter`…). Adding a gene = append an optional field + a
sub-stream, never reorder (grammar §"Extending").

**Diversity is a KB requirement, not just an anti-local-optima trick:** the
gallery must span *distinct ideas* (an outline, a montage, a badge), because
"variety of legitimate designs from the same history" is core to the product
(`ai-tshirt-design-engine.md` §5). Keep `diversityInjectPerGen` and the
genome-distance filter; the KB adds *semantic* diversity (don't present three
designs that all satisfy the same top rules the same way).

---

## 3. Evaluation criteria (turn rules into gates and signals)

Two tiers, matching the existing engine:

### 3a. Hard gates (extend `printabilityGate`)
Rules with `polarity: avoid` + `confidence: high` that concern *legibility or
production* should be **gates**, not soft scores — a design that fails them is
never shown. Candidates for promotion to gate status:
- Min feature size / min text size at print scale (already gated —
  `printability.minFeaturePx: 90`).
- Garment contrast ΔL (already gated — `garmentLuminanceContrastMin: 0.30`).
- **New:** "no more than N stacked print-style effects" (mud-prevention).
- **New:** "≤ 2 type families", "≤ 2 accent colours" — cheap analytic checks.

### 3b. Soft scorers (bias, don't reject)
Everything else is a weighted scorer. Map KB topics → existing scorer names so no
new scoring plumbing is needed:

| KB topic | Existing scorer(s) | Rule intent |
|---|---|---|
| composition / negative space | `coverageBalance`, `whitespace` | breathing room, not cramped, not empty |
| visual hierarchy | `focalHierarchy` | one dominant element |
| colour | `colorHarmony` | muted harmony, tamed flags |
| typography / legibility | `contrastLegibility` | readable at glance |
| texture / busyness | `edgeDensity` | intentional, not noisy |
| apparel layout / aspect | `aspectFit` | fits chest print, no letterbox |
| personal relevance | `profileFit` | right set for the persona |
| "looks like our liked references" | `referenceAffinity` **(new)** | anchored to `reference_analysis/` |

**The one missing scorer worth building: `referenceAffinity`.** The studio already
has the data pipeline (`reference_images/liked|disliked` +
`reference_record.schema.json` mapping each to recipe-space features + a verdict).
A scorer that rewards genomes whose features resemble *liked* references and
penalises resemblance to *disliked* ones is the cheapest path to "matches human
taste" without a heavy learned model. `capability_matrix.md` explicitly lists this
as a headline gap ("No reference-driven quality bar").

---

## 4. Automated design scoring (weights & the aggregate)

Today: `DesignScore.total() = 0.7·aesthetic + 0.3·profileFit`, aesthetic = equal-
weighted sum of analytic + pixel scorers (`engine_config.json`).

KB-driven recommendations:

1. **Weight scorers by rule confidence.** A scorer that encodes several
   `confidence: high` rules should out-weight one encoding mostly `low` rules.
   Start from the current all-1.0 weights and adjust *only* where the KB and
   references agree; keep changes small and versioned (`scorerVersion`).
2. **Keep aesthetic ≫ profileFit (0.7/0.3).** The Design Language test ("good even
   if not personalised") says taste should dominate relevance. Do **not** let
   profileFit rescue an ugly-but-relevant design.
3. **Make the AI critic a *taste backstop for the top 3*, aligned to the KB.**
   When `aiCritic` is enabled, its prompt should be the Design Philosophy + the
   high-confidence rules, so cloud taste and local heuristics pull the same way
   (`ai-tshirt-design-engine.md` §6.4). It nudges genes, never blocks, never on
   the print path.
4. **Calibrate against the studio, not vibes.** Before shipping any weight change,
   run it over `regression_tests/` goldens and the liked/disliked reference set;
   a weight change that ranks a *disliked* reference above a *liked* one is wrong.

---

## 5. Future optimisation loops

1. **Objective = KB compliance + diversity, gated by printability.** The
   evolutionary loop (`OptimizationLoop`) already mutates high-impact genes; point
   its fitness at the KB-weighted score above. Elitism preserves quality; the KB
   defines what "quality" means.
2. **Mutate the genes the KB says matter most.** Bias `GenomeMutator`'s per-gene
   flip probability toward the high-leverage genes (palette, typography treatment,
   layout mode, clip) once those flags are on — that's where the quality delta is.
3. **Close the learning loop (Stage 5).** `preferenceLearning` is already
   configured (learning rate, exploration decay, clamps). Feed it two signals:
   explicit like/dislike (needs the capture UI — a `capability_matrix` gap) and
   implicit "design chosen/purchased" telemetry (already logged). Learn per-user
   gene weights that *bias generation*, never override the printability gate or
   the high-confidence hard rules.
4. **Guard against taste drift.** Personalisation should move within the Design
   Language, not out of it. Clamp learned weights (config already does:
   `weightClamp: [0.25, 4.0]`) and keep the KB's high-confidence rules as a floor
   so a few noisy dislikes can't teach the engine to make souvenir-shop tees.
5. **The studio IS the optimiser's test harness.** Every loop change is validated
   by: (a) no regression on `regression_tests/` goldens, (b) improved mean score
   on *liked* references, (c) no increase on *disliked* references, (d) human spot
   critique in `critiques/`. This is the "reviewed before implementation" gate the
   goal requires.

---

## 6. Sequencing (research-phase recommendation, not a commitment)

1. **Build `referenceAffinity` + populate `reference_analysis/`** — cheapest path
   to a KB-aligned quality bar; unblocks calibration for everything else.
2. **Turn on `typographyTreatment`** — biggest amateur-vs-pro delta, low risk.
3. **Turn on `paletteEngine`** — biggest premium-vs-souvenir delta.
4. **Add the like/dislike capture UI**, then wire `preferenceReRank`.
5. **`motifEngine` last** — highest clutter risk; needs the strongest rules
   (one-hero-motif, consistent stroke) in place first.

Each step ships behind its existing flag and is gated by the studio harness (§5).

---

## 7. Non-negotiables (inherited, restated so the KB never violates them)

- **The purchase/print path is untouchable.** A recipe must always collapse to a
  legal `DesignParams` the current renderer + `PrintStylePipeline` + Printful
  mapping can print (`design_engine/README.md`).
- **Printability is a hard gate, above all taste.**
- **Determinism:** same `(grammarVersion, seed, context)` ⇒ same pixels.
- **On-device by default;** the AI critic is optional, cached, thumbnail-only,
  never blocking, no photos leave the device.
