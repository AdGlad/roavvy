# Engine configuration

`engine_config.json` is the declarative source of truth for the engine's
tunable numbers: the printability hard gate, the optimisation budget, mutation
rates, score weights, the (optional, off-by-default) AI critic, and the
on-device preference-learning parameters.

Today these values **mirror** the hard-coded Dart defaults so the file documents
them in one place:

- `printability.*` → `apps/mobile_flutter/lib/features/merch/design_engine/printability.dart`
- `scoreWeights.*` → `DesignScore.total()` weights in `design_engine_contracts.dart`
- `analyticScorers.*` / `pixelScorers.*` → the `kDefault*Scorers` lists
- `budget.*` / `mutation.*` → `DesignEngineBudget` + `GenomeMutator`
- `aiCritic.*` → `ai_critic.dart` remote-flag gate

**Recommended next step (not done here):** load this file (bundled asset) at
engine start and pass the values in, replacing the constants. That keeps tuning
data-driven and lets the studio run A/B config sweeps (see
`design_studio/reports`). Until then, treat it as authoritative documentation and
keep it in sync when the Dart defaults change.

`configVersion` bumps on any breaking shape change.
