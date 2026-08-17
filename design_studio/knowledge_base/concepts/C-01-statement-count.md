# Concept C-01 — Statement Count (achievement-forward typographic)

- **Status:** ✅ ACCEPTED & added to the engine (composition family `statementCount`), 2026-08-16
- **Validation:** batch `generated_batches/batch_v0.1.0_concept-statementcount/` (40 designs); regression green (zero regressions; `massive-light` +0.011; diversity up).
- **KB alignment:** R-STORY-03 (identity claim), R-MERCH-02 (16+ → count-forward tier), R-COMP-03 (thumbnail-strong), R-STORY-04 (understatement), R-TYPE-01/02/05 (type as a system).

## Design description
The traveller's **count/scope is the hero** — a bold typographic achievement
statement ("**47 COUNTRIES · 6 CONTINENTS**", "**EST. 2011**", "**A LIFE IN 52
STAMPS**"), with flags demoted to a whisper (a thin supporting strip) or absent.
It is the premium answer for **large sets**, where rendering many individual flags
reads as clutter and no single flag can be the hero. It converts "places I've
been" from an inventory into a wearable identity claim.

## Design principles (why it works)
- **Identity over inventory (R-STORY-03):** a number the wearer is proud of is a
  low-risk social beacon; it sells and gets worn. A wall of 60 flags does not.
- **The right density tier (R-MERCH-02):** the KB already prescribes "16+ →
  count-forward typographic mode." This family *is* that prescription, realised.
- **Thumbnail & across-the-room legibility (R-COMP-03):** one bold number reads at
  200px and at 3m where flag grids dissolve.
- **Restraint = premium (R-NEG-01, R-STORY-04):** type + space, understated — the
  traveller-not-tourist flex.

## DesignRecipe / family additions (DONE)
`CompositionFamily.statementCount` (`composition_family.dart`):
- hierarchy `typeLed`; countries **5–300**; template **`typography`**; mask `none`;
  layout `packedRow`; heroScale `(0.5, 0.8)`.
- densitySuitability: medium 0.6, **large 1.0, massive 1.0**.
- scopeAffinity: **lifetime 1.0, region 0.9**, year 0.7, multiCountry 0.6, random 0.5.
- DNA `familyAffinity.statementCount = 0.8` (`design_dna.dart`).
Distinct from `typographicIntegration` (all counts, integrates flags) — this leads
with the **numeric/scope stat** and is **large-set-scoped**.

## Procedural requirements (met)
- Pure recombination of existing primitives → **no new renderer**.
- Deterministic, headless-scorable; eligible only for ≥5-country contexts.
- Sampled under the standard weighted priors (scope × density × DNA).

## Rendering requirements (the one implementation gap → recommendation)
The **content** that makes it "count-forward" is a **TitleGen variant** that emits
the stat string from the real profile:
- e.g. `"{countryCount} COUNTRIES"`, `"{continentCount} CONTINENTS"`,
  `"EST. {firstTripYear}"`, `"{countryCount} COUNTRIES · {continentCount} CONTINENTS"`.
- The `typography` template already renders a bold title lockup; it needs to accept
  this stat string and (optionally) a thin supporting flag strip.
- Type treatment per KB: ≤2 faces, tracked caps, big scale jump (R-TYPE-01/02);
  garment-aware contrast (R-COL-02/03).
**No pixel-generation and no new template are required** — only a title-string
source + optional supporting strip.

## Example outputs (from validation batch)
40 `statementCount` recipes across `several-countries`, `region-europe`,
`lifetime`, `massive-light` (mean quality 0.752 — above incumbents repetitionField
0.702 / chronoSequence 0.711 in those contexts). Contact sheet:
`generated_batches/batch_v0.1.0_concept-statementcount/index.html` (family colour
`#F2C94C`). Note: the analytic quality model under-credits type-hero focal (defaults
0.45, can't "see" rendered type) — true commercial quality is higher than 0.752.

## Implementation recommendations
1. **Ship the family** (done in-engine) behind the normal generation path — it is
   already producing valid, scored recipes.
2. **Add the TitleGen stat variant** (small, highest-value follow-up) so the
   `typography` render shows the count, not a generic title.
3. **Optional scorer refinement:** give `typeLed` count-hero families a
   `focalContrast` branch in `quality_model.dart` (the stat *is* the focal) so the
   score reflects reality — will lift `statementCount` above its current 0.752.
4. **Palette:** default `garmentAware`/`monochrome` (R-COL-04) for the premium
   understated look.

## Diversity note
Adds a **new** premium option exactly in the large-set tier that was thin
(repetitionField / typographicIntegration only) and weakest in quality — raising
both diversity and the floor there, not converging the catalogue.
