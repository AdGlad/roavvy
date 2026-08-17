# experiments/ — the optimisation log

One folder per experiment: `E-###-<slug>/`. Each is a full loop pass over the
**generator** (never a single image), and contains:

- `experiment.md` — the human record (from `EXPERIMENT_TEMPLATE.md`): hypothesis →
  expected outcome → variables → implementation → batch → before/after → scores →
  observations → keep/revert.
- `result.json` — the machine record (validates against
  `experiment_record.schema.json`), written/updated by
  `../tools/run_experiment.sh`.
- optional `before.json` / `after.json` — regression metric snapshots.

## Protocol (see ../OPTIMIZATION_STUDIO.md §4)
1. Pick the top candidate from `../reports/optimization_roadmap.md`.
2. Copy `EXPERIMENT_TEMPLATE.md` → `E-###-<slug>/experiment.md`; fill §1–3.
3. Engineer implements the (small) change; Director runs
   `../tools/run_experiment.sh E-### <slug>`.
4. Regression Reviewer reads the Δ; Critic/Reference Analyst review if a visual/KB
   question remains.
5. Director records the **keep/revert** decision in §9 and updates the roadmap.

## Rules
- **1–3 variables per experiment.** One root cause at a time.
- **Green regression or an explicit, documented tradeoff** (then `REGEN_BASELINE=1`).
- **Reverting is cheap** (`git checkout` the edited files); the folder stays as a
  learning record. Mark status `reverted` in the roadmap so it isn't re-tried.
- Numbering is monotonic; never reuse an id.
