# Core schemas

Language-neutral JSON Schema (Draft 2020-12) for the three foundational models.
They are the **contract**; the Dart runtime is one implementation of that
contract. Keep these authoritative and versioned via `schemaVersion`.

| Schema | Purpose | Maps to existing Dart |
|---|---|---|
| `design_context.schema.json` | The travel/filter **input** — what the user wants a design *about*. Supports all 7 scopes. | `TravelProfile`, `CountrySetOption` (`source`/`scopeKey`), `MerchContext`, `TravelProfileAnalyzer.analyze()` |
| `design_recipe.schema.json` | A **deterministic, parametric** design — a reproducible recipe from `seed` + rules, never a stored image. | Superset of `DesignParams`; today (de)serialises to it (see mapping below) |
| `user_design_preference_profile.schema.json` | Learned **per-user taste** used to bias generation and re-rank candidates. | New; extends `TravelPersona` priors, `AiCritic`, `DesignEngineTelemetry` |

## DesignRecipe ⇄ DesignParams mapping (today)

Every `DesignRecipe` must collapse to a legal `DesignParams`. The recipe adds
explicit sub-objects that are currently *implicit or downstream*; unmapped
fields are forward-looking and ignored by the current renderer until wired.

| DesignRecipe path | DesignParams field | Notes |
|---|---|---|
| `seed` | `seed` | deterministic driver; print == preview |
| `composition.template` | `template` (`CardTemplateType`) | grid, passport, timeline, frontRibbon, typography, badge, wordCloud, landmark, journeys |
| `composition.layoutMode` | `gridLayoutMode` (`FlagGridLayoutMode`) | grid template only |
| `composition.rowCount` | `rowCount` | 1..10 |
| `composition.density` | `density` (`MerchDensity`) | sparse/balanced/dense |
| `composition.jitter` | `jitter` | 0..1 |
| `composition.orientation` | `isPortrait` | portrait/landscape |
| `composition.imageSize` | `imageSize` (`ImageSize`) | render tier |
| `clip.shape` | `clipShape` (`GridClipShape`) | none/heart/circle/countryOutline/continentOutline/animal|plant|landmarkSilhouette |
| `clip.code` | `clipCode` | ISO-2 / continent / silhouette slug |
| `content.countryCodes` | `countryCodes` | resolved from the context |
| `content.source` | `source` (`MerchCountrySource`) | provenance of the set |
| `content.stampMode` | `stampMode` (`MerchStampMode`) | entryOnly/entryExit |
| `palette.garmentColour` | `shirtColour` | garment-aware palette |
| `printStyle.*` | (downstream) `PrintStyleParams` | applied by `PrintStylePipeline` after render |
| `palette.*`, `typography.*`, `motifs[]` | (implicit today) | forward-looking; currently derived inside the card widgets |

`DesignRecipe.recipeId` should equal `DesignParams.contentHash` for the mapped
subset so caches, telemetry and regression goldens line up across the boundary.
