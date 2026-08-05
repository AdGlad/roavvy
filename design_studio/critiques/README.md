# critiques

Structured critiques of `generated_batches` — the qualitative layer over the
numeric scores.

One JSON per critiqued batch (`<batchId>.json`), each entry keyed by
`recipeId`, with:

- `source`: `auto` (scorer/heuristic), `studio` (human reviewer), or `critic`
  (the optional AI critic).
- per-recipe `verdict` (`keep` / `revise` / `reject`), `reasons`, and optional
  `suggestedGeneChanges` (which gene to nudge and why).

Critiques drive three things: promoting winners into `regression_tests`,
feeding `human_feedback` for preference learning, and surfacing systematic
weaknesses in `reports` (e.g. "montage over-crowds at massive density").

Keep critiques small, specific and gene-level so they translate into concrete
grammar/config changes.
