# Curated recipes

Hand-authored `DesignRecipe`s (engine `toJson` shape) that capture a specific
look distilled from the reference library. Drop-in reproducible: the same
`(engineVersion, grammarVersion, seed, fields)` renders the same design.

| Recipe | Look | Source |
|---|---|---|
| `torn_flag_usa.recipe.json` | Full-colour national flag with ragged Edge-Tear edges + distress | `reference_images/liked/tshirts` (torn-flag tees) |
| `torn_flag_mono.recipe.json` | Mono "tattered flag" — heavy Edge-Tear + distress, one ink | same |

**Re-target any country:** change `countryCodes` + `heroCode` (ISO-2). Keep
`seed` for reproducibility, or change it for a fresh weathering pattern.

**How it renders:** `family=singleHero`, `mask=none` → the flag fills the frame;
`printStyle=edgeTear` supplies the torn edges (its preset's `roughEdges`), and
the continuous `distress`/`grain` genes add the weathered texture. See the
review in `../reference_analysis/torn-flag-tshirts.json`.

**Not yet expressible:** the "ripped-through-fabric" look (flag visible through a
claw gash in the shirt) needs a fabric-tear mask the renderer doesn't have — a
future capability. The tattered/torn-edge flag above is fully supported today.
