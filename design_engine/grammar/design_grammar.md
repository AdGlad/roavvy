# Design grammar

The grammar defines the **space of legal designs** and the **production rules**
that turn a `DesignContext` + `seed` into a `DesignRecipe`. It is the formal
version of what `DesignParams.normalize()` + `candidate_generator.dart` do today,
written so the engine can grow toward effectively unlimited output while every
result stays printable and reproducible.

Three properties are non-negotiable:

1. **Closed under legality** — every production yields a recipe that maps to a
   valid `DesignParams` (the existing renderer can already print it).
2. **Deterministic** — identical `(grammarVersion, seed, resolved context)` ⇒
   identical recipe ⇒ identical pixels. Randomness only ever comes from named
   sub-streams of `seed` (see `config/engine_config.json → determinism`).
3. **Monotone versioning** — changing a rule bumps `grammarVersion`, because it
   can change what a seed means.

## Non-terminals (the gene space)

```
Design        → Composition · Clip? · Content · Palette · Typography · Motifs* · PrintStyle
Composition   → Template · LayoutMode? · RowCount · Density · Jitter · Orientation · ImageSize
Clip          → Shape · Code?
Content       → CountryCodes · Source · StampMode
Palette       → GarmentColour · Strategy · Accents*
Typography    → TitleStyle · Case · Placement
Motif         → Kind · Slug · CountryCode?
PrintStyle    → Id        (applied downstream; recorded for reproducibility)
```

### Terminal domains (legal values)

| Gene | Domain | Source of truth |
|---|---|---|
| Template | grid, passport, timeline, frontRibbon, typography, badge, wordCloud, landmark, journeys | `CardTemplateType` |
| LayoutMode | packedRow, normalizedGrid, treemap, montage | `FlagGridLayoutMode` |
| Shape | none, heart, circle, countryOutline, continentOutline, animal/plant/landmarkSilhouette | `GridClipShape` |
| Density | sparse, balanced, dense | `MerchDensity` |
| Source | recentTrip, thisYear, allTime, singleCountry | `MerchCountrySource` |
| StampMode | entryOnly, entryExit | `MerchStampMode` |
| RowCount | integer 1..10 | `DesignParams.normalize` |
| Jitter | real 0..1 | `DesignParams.normalize` |
| Orientation | portrait, landscape | `isPortrait` |
| ImageSize | small, medium, large | `ImageSize` |
| PrintStyle.Id | 12 styles incl. edgeTear/acidWash | `PrintStyleId` |

## Production constraints (hard — from `DesignParams._violation`)

- **P1 Non-empty:** `Content.CountryCodes` ≥ 1.
- **P2 Grid-only genes:** `LayoutMode ≠ packedRow` or `Shape ≠ none` ⇒ `Template = grid`.
- **P3 Single-country clips:** `Shape ∈ {countryOutline, animal/plant/landmarkSilhouette}` ⇒ `|CountryCodes| = 1`.
- **P4 Clip needs code:** `Shape ∈ {countryOutline, continentOutline, *Silhouette}` ⇒ `Code` present and resolvable in bundled assets.
- **P5 Ranges:** `RowCount ∈ [1,10]`, `Jitter ∈ [0,1]`.

Any derivation that would violate P1–P5 is either rejected or repaired by the
grammar's `normalize` production (nearest legal form), exactly as the Dart does.

## Scope → grammar bias (soft priors)

The `DesignContext.scope` and `density` steer *probabilities*, never legality.
These are priors seeded from `MerchTemplateRanker` + persona, then multiplied by
the user's learned `featureWeights`:

| Scope | Typical bias |
|---|---|
| `random` | full gene space, high jitter/variety, exploration-rate boosted |
| `lifetime` | large/massive density → grid montage / treemap; wordCloud for very large sets |
| `year` | timeline / journeys favoured; medium density |
| `region` | continentOutline clip or region map; palette biased to region |
| `singleCountry` | countryOutline / silhouette clips; badge / passport; portrait allowed |
| `multiCountry` | grid packedRow / normalizedGrid; balanced density |
| `trip` | passport stamp (entry/exit); frontRibbon; single-country motifs |

## Determinism recipe

```
rngFor(stream) = SplitMix64(seed XOR fnv1a(stream))     // per config.determinism.seedStreams
Template       = weightedPick(rngFor("population"), templatePriors(context) × userWeights.template)
LayoutMode     = weightedPick(rngFor("layout"),      layoutPriors(template, density))
CountryCodes   = orderCanonical(context.countryCodes)   // order-independent; see contentHash
Jitter         = clamp01(base(density) + rngFor("jitter").nextGaussian()·σ)
Motifs         = sample(rngFor("motif"), eligibleMotifs(context))   // feature-flagged
recipeId       = DesignParams.contentHash(mappedSubset)
```

Because `recipeId` is the content hash of the **mapped `DesignParams` subset**,
two recipes that render identically share an id — the cache, telemetry, and the
studio regression goldens all key off it.

## Extending the grammar

Add a gene by: (1) adding its terminal domain here + to the relevant schema;
(2) adding a legality production if it interacts with others; (3) adding it to
`DesignParams` (`normalize`/`_violation`/`contentHash`/`copyWith`) and the
generator priors; (4) bumping `grammarVersion`. Prefer new **optional** genes so
old seeds keep meaning (append, don't reorder).
