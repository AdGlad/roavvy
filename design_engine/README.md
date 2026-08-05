# `design_engine/` — procedural design specification workspace

This is the **language-neutral specification and authoring home** for Roavvy's
procedural T-shirt design engine. It holds the schemas, grammar, configuration
and architecture docs that the on-device engine implements.

It is **not** runtime code. The runtime engine already exists in Dart at
`apps/mobile_flutter/lib/features/merch/design_engine/` (the `DesignParams`
genome, scorers, mutator, `OptimizationLoop`, `TravelProfileAnalyzer`) and is
documented in `docs/design/ai-tshirt-design-engine.md`. This workspace formalises
the *contracts* around that engine so it can grow toward effectively unlimited,
reproducible, locally-generated designs — **extending, never replacing** the
working implementation.

## Layout

```
design_engine/
  schemas/      JSON Schema (Draft 2020-12) for the three core models:
                DesignContext, DesignRecipe, UserDesignPreferenceProfile
  grammar/      The procedural design grammar: gene space + production rules
  config/       Engine configuration (budgets, scorer weights, printability
                constants, feature flags) as versioned data
  docs/         architecture.md (the 5-stage separation) and
                capability_matrix.md (what exists vs what's missing)
```

## The one rule

The purchase/print path is untouchable. A `DesignRecipe` must always resolve to
a genome the **existing** `CardImageRenderer` + `PrintStylePipeline` +
Printful mapping can already print. See `docs/architecture.md` §"Integration
boundary" and the existing `docs/design/ai-tshirt-design-engine.md` §2.

## Relationship to existing Dart types

| Spec artifact (here)            | Existing Dart (implements / maps to)                              |
|---------------------------------|-------------------------------------------------------------------|
| `DesignContext`                 | `TravelProfile` + `CountrySetOption` + `MerchContext` (input side) |
| `DesignRecipe`                  | superset of `DesignParams` (the genome); (de)serialises to it      |
| `UserDesignPreferenceProfile`   | **new** — extends `TravelPersona` bias + `AiCritic` + telemetry    |
| `grammar/`                      | `DesignParams.normalize()` + `candidate_generator.dart`           |
| `config/engine_config.json`     | `printability.dart` consts + `kDefault*Scorers` weights + budget  |

See `schemas/README.md` for the field-by-field mapping.
