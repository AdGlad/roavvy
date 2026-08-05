# Capability matrix — what exists vs what's missing

Snapshot of the engine as of this foundation. Legend:
**✅ shipped** · **🟡 partial** · **⛔ missing**. "Where" points at the current
implementation so we extend rather than duplicate.

## Stage 1 — Travel / filter context (`DesignContext`)

| Capability | State | Where / gap |
|---|---|---|
| Resolve visited-country set | ✅ | `effective_visit_merge.dart`, `TravelSummary` |
| Trips / years from photos | ✅ | `TripRecord`, `trip_repository` |
| Continent mapping | ✅ | `kCountryContinent` (shared_models) |
| Sub-continental regions | 🟡 | `region_lookup` + `continent_subregion_map` exist; not yet a first-class design scope |
| Candidate country-sets (all-time / year / recent / single / continent) | ✅ | `TravelProfileAnalyzer` → `CountrySetOption` |
| Persona classification | ✅ | `TravelPersona` |
| Scope: random | 🟡 | seed exists; no explicit "random" scope/sampler |
| Scope: region (as a design filter) | ⛔ | region lookup exists but no region-scoped generation |
| Scope: trip | 🟡 | `recentTrip` source exists; no per-trip stamp-centric recipe path |
| Unified `DesignContext` object | ⛔ | **new here** — schema defined; not yet a Dart type (data spread across `TravelProfile`/`MerchContext`) |

## Stage 2 — Procedural generation (`DesignRecipe`)

| Capability | State | Where / gap |
|---|---|---|
| Renderable genome | ✅ | `DesignParams` (13 genes) |
| Seeded determinism (print == preview) | ✅ | `DesignParams.seed`, montage/stamp shuffles |
| Legality normalisation | ✅ | `DesignParams.normalize` / `_violation` |
| Ranker/preset/persona-seeded population | ✅ | `RankerSeededGenerator` |
| Mutation / crossover / diversity inject | ✅ | `GenomeMutator`, `OptimizationLoop` |
| Formal grammar / gene-space doc | 🟡 | **new here** (`grammar/`); implicit before |
| Palette gene (beyond garment colour) | ⛔ | colours derived inside card widgets / `flag_colours`; not a searchable gene |
| Typography treatment gene | ⛔ | title styling fixed per template |
| Motif / silhouette layering as a gene | 🟡 | clip shapes exist; free-floating motifs don't |
| Named RNG sub-streams | ⛔ | single seed today; grammar specifies sub-streams |
| Recipe (de)serialisation / persistence | 🟡 | `contentHash` + `TravelCard` persist template+codes; full recipe not serialised |

## Stage 3 — Quality validation / scoring (`DesignScore`)

| Capability | State | Where / gap |
|---|---|---|
| Hard printability gate | ✅ | `printability.dart` (min feature, coverage, reserves) |
| Analytic scorers (no raster) | ✅ | coverage/whitespace/focal/aspect/profile |
| Pixel scorers (thumbnail) | ✅ | contrast/harmony/edge-density |
| Aggregate weighted score | ✅ | `DesignScore.total()` |
| Config-driven weights | 🟡 | **new** `engine_config.json`; constants today |
| Optional AI critic (cloud, gated) | ✅ | `AiCritic` (remote-flag, non-blocking) |
| Reference-anchored aesthetic scoring | ⛔ | no learned "looks like liked references" signal (studio provides the data) |
| Regression scoring over golden batches | ⛔ | **new** `design_studio/regression_tests` |

## Stage 4 — Rendering

| Capability | State | Where / gap |
|---|---|---|
| Genome → PNG (preview + print) | ✅ | `CardImageRenderer` |
| All card templates | ✅ | `card_templates.dart` + per-template engines |
| Print-style pipeline (12 styles) | ✅ | `print_style/` (incl. edgeTear/acidWash) |
| Printful placement/print file | ✅ | `printful_placement_mapper` |
| Thumbnailer for scoring | ✅ | `CardRenderThumbnailer` |
| Off-UI-thread / isolate rendering | ⛔ | capture is on the UI thread (perf risk — see architecture/Risks) |

## Stage 5 — User preference learning

| Capability | State | Where / gap |
|---|---|---|
| Persona priors | 🟡 | analysed persona biases generation; not personalised by feedback |
| "Design chosen" telemetry | ✅ | `DesignEngineTelemetry.logDesignChosen` |
| Explicit like/dislike capture | ⛔ | no UI/store for it |
| Learned per-user gene weights | ⛔ | **new** `UserDesignPreferenceProfile` schema; no learner yet |
| Preference re-rank / biased generation | ⛔ | flag `preferenceReRank` off; not wired |
| On-device only, persisted | ⛔ | schema targets Drift-local + optional Firestore mirror |

## Native on-device assets we can reuse (not duplicate)

| Native capability | Channel / API | Reuse for |
|---|---|---|
| Saliency / scene classify / faces | `roavvy/hero_analysis` (Vision) | photo-derived palette/focal hints |
| Dominant colour | CoreImage `CIAreaAverage` | palette gene seeding |
| On-device title LLM | `roavvy/ai_title` (FoundationModels) | downstream titles (already used) |
| On-device image gen | `roavvy/landmark_image` (ImagePlayground) | optional motif/landmark art |

## Headline gaps (ranked)

1. **No unified `DesignContext`/`DesignRecipe` (de)serialisation** — the recipe
   only half-exists as `DesignParams`; region/trip/random scopes aren't
   first-class. *(schemas here close the design gap; Dart adapters are next.)*
2. **No preference learning loop** — telemetry exists but nothing learns.
3. **Rendering is on the UI thread** — the main real-time/perf risk at scale.
4. **Palette/typography/motif are not genes** — biggest lever for "unlimited
   variety," currently baked into widgets.
5. **No reference-driven quality bar** — studio provides the data pipeline to
   build one.
