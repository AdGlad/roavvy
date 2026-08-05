# Architecture — procedural design engine (foundation)

This document defines the **five-stage separation** the engine is built around
and how the new specification layer (`design_engine/`, `design_studio/`) extends
the working Dart engine already in the app.

> Companion docs. The runtime engine is already documented in
> `docs/design/ai-tshirt-design-engine.md` (thesis, integration boundary,
> scoring tiers, optimisation loop, deployment). **This document does not repeat
> it** — it formalises the contracts (the three schemas, the grammar, the config)
> and adds the preference-learning + studio development workflow. Read that doc
> first for the runtime; read this for the spec/foundation.

## Prime directive

Generate **effectively unlimited, high-quality T-shirt designs locally on the
iPhone in real time**, from travel data + filters, as **reproducible recipes**
(rules + parameters + seed) — **no remote LLM/API on the runtime path**, and
**without replacing any working functionality**. A design is a recipe, never a
stored image.

## The five stages (strict separation)

Each stage has one job, a typed input and a typed output, and can be tested and
replaced independently. Data flows one way; nothing downstream feeds back into an
earlier stage except the **learned preference profile**, which is an *input* to
stages 2–3, never a mutation of stage 1's facts.

```
 ┌───────────────────────────────────────────────────────────────────────────┐
 │ 1. TRAVEL / FILTER CONTEXT          → DesignContext                        │
 │    "What is this design about?"                                           │
 │    Trips/visits/years/regions + scope  ⇒  resolved country set + metadata │
 │    Impl: TravelProfileAnalyzer, MerchContext, region/continent lookup     │
 └───────────────┬───────────────────────────────────────────────────────────┘
                 ▼
 ┌───────────────────────────────────────────────────────────────────────────┐
 │ 2. PROCEDURAL DESIGN GENERATION     DesignContext + seed → DesignRecipe[]  │
 │    "What could we draw?"                                                   │
 │    Grammar + priors + preference weights ⇒ diverse, legal, deterministic  │
 │    Impl: candidate_generator, genome_mutator, grammar (this workspace)    │
 └───────────────┬───────────────────────────────────────────────────────────┘
                 ▼
 ┌───────────────────────────────────────────────────────────────────────────┐
 │ 3. QUALITY VALIDATION / SCORING     DesignRecipe → DesignScore (gate+rank) │
 │    "Which are good, and printable?"                                       │
 │    Hard printability gate → analytic → pixel(thumbnail) → optional critic  │
 │    Impl: printability, analytic_scorers, pixel_scorers, ai_critic (gated) │
 └───────────────┬───────────────────────────────────────────────────────────┘
                 ▼
 ┌───────────────────────────────────────────────────────────────────────────┐
 │ 4. RENDERING                        DesignRecipe → PNG bytes (+ hash)      │
 │    "Draw it for real."                                                    │
 │    Genome → CardImageRenderer → PrintStylePipeline → preview & print file │
 │    Impl: card_image_renderer, card_templates, print_style/*  (UNCHANGED)  │
 └───────────────┬───────────────────────────────────────────────────────────┘
                 ▼
 ┌───────────────────────────────────────────────────────────────────────────┐
 │ 5. USER PREFERENCE LEARNING         feedback → UserDesignPreferenceProfile │
 │    "Learn this person's taste."                                           │
 │    like/dislike/chosen/purchased ⇒ gene weights + scorer overrides        │
 │    Feeds back as an INPUT to stages 2 & 3. All on-device.                 │
 └───────────────────────────────────────────────────────────────────────────┘
```

### Why the separation matters

- **Determinism is containable.** Only stage 2 consumes the seed; stage 4 is a
  pure function of the recipe. So the same recipe always prints the same shirt
  ("print == preview"), and regression goldens key off `recipeId`.
- **The purchase/print path is sacred.** Stage 4 is the *existing* renderer and
  Printful mapping. Stages 1–3 only ever emit recipes that stage 4 can already
  print — enforced by the grammar's legality productions (P1–P5).
- **No network on the runtime path.** Stages 1, 2, 4, 5 are fully local. The
  only optional remote piece is stage 3's Tier-3 AI critic, which is
  flag-gated, non-blocking, and never required for a design to ship.
- **Taste never corrupts facts.** Stage 5 changes *probabilities* in stages 2–3,
  not the traveller's data or the legality rules.

## Integration boundary (what this foundation may and may not touch)

| May extend | Must not replace |
|---|---|
| Add genes to `DesignParams` (normalize/violation/contentHash) | The `CardImageRenderer` capture path |
| Add `DesignScorer`/`PrintabilityConstraint` impls to the `kDefault*` lists | `PrintStylePipeline` insertion point / clean pass-through |
| Add scopes/priors to the generator + grammar | `MerchPresetConfig` legacy bridge (`toPresetConfig`) |
| Load `engine_config.json` instead of constants | Printful placement mapping / cart / checkout |
| Persist + apply `UserDesignPreferenceProfile` | Title generation being downstream of the genome |

## Where the new artifacts live

- **Runtime (Dart, exists):** `apps/mobile_flutter/lib/features/merch/design_engine/`
  and `.../print_style/` and `apps/mobile_flutter/lib/features/cards/`.
- **Spec (this workspace):** `design_engine/schemas|grammar|config|docs`.
- **Development-only:** `design_studio/` (never bundled — see its README).

When the schemas are wired into Dart, add thin adapters (e.g.
`design_recipe_codec.dart`) next to `design_params.dart` that convert
`DesignRecipe ⇄ DesignParams`; do **not** fork `DesignParams`.

## Reproducibility contract (summary)

A rendered shirt is reproducible iff you persist:
`schemaVersion`, `engineVersion`, `grammarVersion`, `configVersion`, `seed`, and
the resolved `content.countryCodes` (order-independent). `recipeId` =
`DesignParams.contentHash` of the mapped subset ties the recipe to its cache
entry, its telemetry, and its regression golden.
