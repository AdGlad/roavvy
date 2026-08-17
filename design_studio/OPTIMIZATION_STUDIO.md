# The Roavvy Graphic Design Studio — Autonomous Optimisation Framework

*A reusable framework that improves the **procedural generator**, not individual
images. It runs like a professional design studio: generate → render → review →
critique → score → find weaknesses → modify the generator → regenerate → compare →
keep or revert → repeat. Development-only; nothing here ships.*

> **The prime directive:** optimise the *system that produces designs*, never a
> single design. A fix is only valid if it helps **across contexts and seeds** and
> does not regress other design families. The regression suite is the arbiter.

---

## 1. The loop

```
        ┌──────────────────────────────────────────────────────────────┐
        ▼                                                              │
  ┌───────────┐   ┌────────┐   ┌──────────┐   ┌───────┐   ┌──────────┐ │
  │ GENERATE  │──▶│ RENDER │──▶│ CRITIQUE │──▶│ SCORE │──▶│ IDENTIFY │ │
  │ (batch)   │   │(contact│   │ (Critic +│   │(quality│   │ WEAKNESS │ │
  │           │   │ sheet) │   │ Ref Anal)│   │ model) │   │ (Director│ │
  └───────────┘   └────────┘   └──────────┘   └───────┘   └────┬─────┘ │
                                                                │       │
   ┌───────────┐   ┌─────────┐   ┌──────────┐   ┌────────────┐ ▼       │
   │  KEEP or  │◀──│ COMPARE │◀──│ REGRESS  │◀──│  MODIFY    │◀────────┘
   │  REVERT   │   │(before/ │   │ (Reviewer│   │ GENERATOR  │
   │ (Director)│   │ after)  │   │  vs base)│   │ (Engineer) │
   └─────┬─────┘   └─────────┘   └──────────┘   └────────────┘
         └────────────────────── repeat ──────────────────────────────▶
```

Every pass through the loop is **one experiment** (§4). The Design Director owns
the loop; the other five roles are invoked only when their step is due.

## 2. The studio workspace (`design_studio/`)

```
design_studio/
  knowledge_base/       ← the APPROVED design bar (philosophy, 58 rules, mood boards)
  generated_batches/    ← batch_v<engine>[_<label>]/{batch.json, index.html, img/*}
  contact_sheets/       ← per-batch visual review surface (index.html is the sheet)
  reference_images/     ← liked/ + disliked/ exemplars (calibration)
  reference_analysis/   ← ReferenceRecord per image → recipe-space features + verdict
  critiques/            ← <batchId>.json — systematic generator weaknesses (Critic)
  experiments/          ← E-###-<slug>/ — one folder per experiment (§4)
  reports/              ← optimization_roadmap.md + tune_<date>.md (Engineer) + cycle reports
  regression_tests/     ← baselines/procedural_baseline.json (the arbiter) + goldens/
  recipes/              ← curated known-good anchor recipes
  human_feedback/       ← raw like/dislike events (optional taste signal)
```

### Provenance every design retains
A generated design is identified and reproducible by the tuple:

> **(experimentId, batchId, context.scopeKey, seed, engineVersion, grammarVersion, recipeId)**

`batch.json` records `experimentId`, `engineVersion`, `grammarVersion`,
`generatedAt`, `seeds[]`, and per-design `{context, scopeKey, seed, quality,
qualityBreakdown, recipe}`. The full `DesignRecipe` + seed + versions mean any
design can be re-rendered byte-identically. The **experiment ID** ties a batch to
its hypothesis in `experiments/`.

## 3. The six roles (who does what)

| Role | Agent | Reads | Writes | Never |
|---|---|---|---|---|
| **Design Director** | `design-director` | roadmap, critiques, reports, regression Δ | roadmap, cycle checkpoints, keep/revert decisions | edits engine code |
| **Generator** | `design-generator` | contexts, seeds, families | a batch archive (runs the harness) | invents non-deterministic output |
| **Design Critic** | `design-critic` | `batch.json`, contact sheet, DNA | `critiques/<batchId>.json` (systematic findings) | per-image fixes; edits code |
| **Reference Analyst** | `reference-analyst` | KB rules + mood boards + `reference_analysis/` | KB-alignment findings + principle hits/misses | subjective taste calls |
| **Engineer** | `engine-tuner` | critiques, DNA, generator config, regression | smallest generator edit + `reports/tune_<date>.md` | per-image special-casing |
| **Regression Reviewer** | `regression-reviewer` | regression test output vs baseline | pass/fail verdict + per-context Δ table | approving unexplained regressions |

The **Director** is the only always-on role; it invokes the others one step at a
time with a *narrow* task and stores only their **summary**, never their transcript.

## 4. The experiment (the unit of work)

Every loop pass is a folder `experiments/E-###-<slug>/` containing an
`experiment.md` (see `experiments/EXPERIMENT_TEMPLATE.md`) with **all** of:

1. **Hypothesis** — the systematic weakness and the mechanism (cite critique id +
   baseline numbers).
2. **Expected outcome** — which contexts/families should improve, by roughly how
   much, and what must *not* regress.
3. **Variables changed** — a *small* number (1–3 knobs); list exact files + values.
4. **Implementation** — the Engineer's edit (before→after).
5. **Rendered batch** — the `batchId` produced under this `experimentId`.
6. **Before/after comparison** — per-context meanQuality / topQuality /
   familyDiversity / rejectionRate, from the regression Δ table.
7. **Scores** — aggregate + per-context after.
8. **Observations** — what the Critic/Analyst saw; surprises; tradeoffs.
9. **Keep/Revert decision** — Director's call, with the reason.

**Rules:** modify only a limited number of variables per experiment; one root
cause at a time; the regression suite must be green (or the tradeoff explicitly
documented and the baseline re-generated). Reverts are cheap — `git checkout` the
edited files; the experiment folder stays as a record of what was learned.

## 5. Evaluation axes (judged against the Knowledge Base)

composition · balance · visual hierarchy · apparel quality · originality · print
suitability · readability · flag recognisability · colour harmony · texture
quality · commercial appeal · **overall Roavvy identity** · **visual diversity**.

Each maps to a signal: the analytic **quality model** (`quality_model.dart` —
dnaAlignment, hierarchy, densityBalance, negativeSpace, familyFit, focalContrast,
treatment), the **printability gate** (hard), the **Critic** (systematic visual
findings), the **Reference Analyst** (KB-rule hits/misses), and **diversity**
(familyDiversity + familyCounts). See `knowledge_base/design_rules.md` for the
rules behind each axis.

## 6. Running one cycle (autonomous, one command)

```
design_studio/tools/run_experiment.sh <experiment-id> <label>
```
It: snapshots the current baseline → generates a batch under the experiment id →
runs the regression suite → captures the Δ → writes a machine-readable
`experiments/E-###-<slug>/result.json`. The Director then invokes Critic /
Reference Analyst / Engineer as needed and records the keep/revert decision.

Manual equivalents (what the runner calls):
- **Generate:** `cd apps/mobile_flutter && EXPERIMENT_ID=<id> EXPERIMENT_LABEL=<label> flutter test test/features/merch/design_engine/procedural/batch_generate.dart`
- **Score/Regress:** `cd apps/mobile_flutter && flutter test test/features/merch/design_engine/procedural/regression_test.dart`
- **Accept a new baseline (only after a reviewed, intended change):** prefix `REGEN_BASELINE=1`.
- **Analyze:** `flutter analyze lib/features/merch/design_engine/procedural/`
- **Torn PNG batch (visual):** `TORN_STUDIO_BATCH=1 flutter test test/features/merch/design_engine/torn/torn_studio_batch_test.dart`

## 7. Token & compute frugality (mandatory for long sessions)

The Director must:
- **Invoke a sub-agent only when its step is due,** with a task scoped to one
  batch/critique/edit. Store the agent's **summary**, not its conversation.
- **Reuse findings.** Before researching, check `critiques/`, `reports/`,
  `reference_analysis/`, and the roadmap — never re-derive a known weakness.
- **Prefer analytic signals over renders.** The recipe batch + quality model are
  cheap and headless; only render PNGs (torn harness) when a visual question
  can't be answered from parameters + breakdown.
- **Checkpoint every cycle** to `reports/optimization_roadmap.md` (what ran, the
  decision, next candidate) so a fresh context can resume without re-reading
  history.
- **Archive** completed experiments (leave the folder; mark status `kept`/
  `reverted` in the roadmap). Don't keep stale batches around — the newest kept
  batch per engine version is the reference.
- **Batch the cheap steps.** Generate + regress in one runner call; don't spawn an
  agent to run a shell command the Director can run directly.

## 8. Guardrails (never violate)

- **Printability is a hard gate** — a design failing it is never scored/shipped.
- **Diversity is a guardrail, not a free variable** — the regression fails if any
  context's `familyDiversity` collapses by >1. Never tune so hard that the set
  converges to one family.
- **No overfitting** — no special-casing a country set, seed, or single design; a
  change must help across the fixed regression fixtures.
- **The purchase/print path is untouchable** — the engine only ever produces a
  legal `DesignParams`/recipe the existing renderer already prints.
- **The KB is the bar** — quality is defined by `knowledge_base/`, not ad-hoc taste.

## 9. Where to start
Read `reports/optimization_roadmap.md` (the Director's living plan). It is seeded
with the current baseline's weaknesses and an ordered backlog of experiments. Run
the top-ranked one with §6.
