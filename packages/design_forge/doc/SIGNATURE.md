# Signature Recipes (ADR-181)

A **Signature Recipe** is one of the v2 T-shirt designs: a design that works for
every country, approved by the owner in the Design Lab. It is data, stored as a
pack file, not code.

| Piece | Where |
|---|---|
| Model, codec, resolver (pure Dart) | `packages/design_forge/lib/src/signature/` |
| Bundled packs + index | `packages/design_studio/assets/signature/` |
| Loader (`SignatureCatalog`) | `packages/design_studio/lib/src/signature_catalog.dart` |
| Preset → draft pack tool | `packages/design_forge/tool/pack_from_preset.dart` |

## Pack file (`roavvy.signature_pack` v1)

```jsonc
{
  "format": "roavvy.signature_pack",
  "formatVersion": 1,
  "id": "torn_flag",              // = file name torn_flag.pack.json
  "title": "Torn Flag",
  "version": 1,                   // bumped on every approval
  "status": "draft",              // draft | approved (approved needs approvedAt)
  "approvedAt": "2026-…",         // ISO-8601, approved packs only
  "notes": "…",
  "base": { …DesignRecipe JSON… "content": {"flags": [{"code": "{{country}}"}]} },
  "envelope": {                   // what variations may change, and how far
    "seed":                { "min": 1, "max": 1000000, "integer": true },
    "tornStrips.distress": { "min": 0.55, "max": 0.85 },
    "tornStrips.mirror":   { "values": [true, false] }
  },
  "overrides": {                  // sparse per-country fixes, reason required
    "jp": { "params": { "tornStrips.distress": 0.6 }, "reason": "Red disc vanishes under heavy distress" }
  },
  "heroes": { "fr": { "seed": 42 } },   // curated envelope values for the hero
  "locks":  { "us": "748dc73163b8ec40" }, // hero recipeId per sample country
  "layout": {                     // optional: where the tee prints by default
    "front": { "zone": "leftChest" },
    "back":  { "zone": "fullBack", "scale": 0.9 }
  }
}
```

- **Paths** (`RecipePath`) are dotted keys into the recipe JSON; list indices are
  numbers (`content.flags.0.code`). They must already exist in `base` and end at
  a value. A typo fails when the pack loads.
- **`{{country}}`** is replaced by the lowercase ISO code everywhere in `base`.
  `base` must use it. Other `{{name}}` tokens can be passed to the resolver
  (trip year, etc.) for later recipes.
- **Overrides** change parameters only. An override on an enveloped path must be
  inside the range, and pins that path for the country (variations stop moving it).
- **Heroes** may only set enveloped paths, inside their ranges.
- **`layout`** is the tee's default print layout (`design_studio`'s
  `PrintLayout`): at most one zone per face — front `fullFront | leftChest |
  rightChest`, back `fullBack | upperBack | backNeck` — with an optional
  `scale` (zone minimum … 1, hung from the zone's top edge). Omitted = a full
  back print. `"mark": false` turns off the small `roavvy.com` mark below the
  back collar (on by default; it prints only with a back design that isn't the
  back-neck print, and pushes that design 1.4" down). It is garment data: it
  never changes a hero's `recipeId` or lock,
  and an unreadable layout falls back to the full back rather than failing.
- **Unknown fields and newer `formatVersion`s are refused.**
- Files are written sorted, 2-space indented, with a trailing newline; the
  catalog test fails if a pack was hand-edited out of that form.

## Two-country packs (ADR-185)

A pack with `"countries": 2` is a **pair pack**: one design for two
countries, A (left/top) and B (right/bottom). Order matters: `fr+jp` and
`jp+fr` are different designs.

```jsonc
{
  "countries": 2,                          // omitted (= 1) for every single pack
  "samplePairs": ["us+co", "hu+us", …],    // the Lab sheet + QA set; first = default pair
  "base": { … "content": {"flags": [{"code": "{{countryA}}"}, {"code": "{{countryB}}"}]} },
  "overrides": {
    "jp":    { "params": { "content.flags.{slot}.weight": 0.6 }, "reason": "…" },
    "fr+nl": { "params": { "splitPair.seamGap": 0.02 }, "reason": "Look-alike stripes" }
  },
  "heroes": { "us+co": { "seed": 42 } },
  "locks":  { "us+co": "…" }
}
```

- **Tokens:** `{{countryA}}`, `{{countryA3}}`, `{{countryAName}}` and the same
  for `B`. The base must use an A token and a B token, and must not use
  `{{country}}`/`{{country3}}`/`{{countryName}}`. A single pack must not use
  pair tokens.
- **Keys:** heroes and locks are keyed `"a+b"` (lowercase). `samplePairs` is
  only allowed in pair packs.
- **Country overrides** still key on one country and apply wherever that
  country appears. In their params, the path segment `{slot}` is replaced by
  the country's slot (`0` for A, `1` for B), so
  `content.flags.{slot}.weight` only changes that country's half. Paths
  without `{slot}` change the whole design.
- **Pair overrides** (`"a+b"`) are for one ordered pair that clashes. They
  apply after both country overrides and may not use `{slot}`.
- **Flag focus** (`FlagFocus.of(code)`, `design_forge/lib/src/geo/flag_focus.dart`)
  is shared engine data, not pack data. It holds each flag's focus point and
  emblem box in flag space, e.g. the US canton, Portugal's arms or Japan's disc.
  A pair composition crops each half around the focus
  (`focus.windowLeft(0.5)`), and reports what it shows through
  `PairGeometry.of(recipe)` (`FlagCrop` per flag, plus `PairSeam`) so pair QA
  can check it.

### `splitPair` — two flags along a seam (M209)

Family `splitPair` + a `splitPair` group (`SplitPair`,
`design_forge/lib/src/recipe/split_pair.dart`). Flag A is left of the seam,
B right; both cover the block height and are cropped around their focus.
Layout maths is `SplitPairLayout` (pure), shared by the renderer
(`SplitPairComposer`) and `PairGeometry.of`, so QA checks what is drawn.

| Field | Default | Meaning |
|---|---|---|
| `seam` | `curtain` | `straight` \| `curtain` (eased sweep) \| `diagonal` |
| `seamPosition` | 0.47 | seam x at mid height (fraction of block width) |
| `seamSlant` | 0.27 | x travel top→bottom; sign set by the focus rule |
| `seamCurve` | 0.6 | curtain ease-out |
| `seamFlip` | false | slant direction when no flag needs the top |
| `seamGap` | 0 | garment-colour channel (fraction of block width) |
| `autoGap` | 0.012 | channel used when the flags look alike at the seam |
| `blockAspect` | 0.86 | block width/height |
| `margin` | 0.04 | block to canvas edge |
| `rotateFlags` | false | quarter-turn both flags (Diagonal Split) |
| `shadow` | 0.3 | shade on A along the seam |
| `edge` | `torn` | `clean` \| `torn` \| `brush` (M208 `BrushEdge`, stroke running down the block) |
| `brush` | unset | `BrushStroke` for `edge: brush` (written only when set) |
| `edgeWear`, `distress`, `distressScale`, `scratches`, `fade` | 0.6, 0.6, 0.5, 0.5, 0.15 | `WearRaster.grunge` |

Shared rules (engine, not pack): the top of the block goes to the flag whose
focus is high (a canton) — so the US keeps its stars on either side; two such
flags straighten the seam and widen the block; a wide canton widens the block
just enough; a protected box that cannot fit its half (Swiss cross, Nepal's
pennant, Bhutan's dragon) shrinks the flag and each one-colour edge is
extended to fill the half; vertical-stripe flags with no emblem (France) are
narrowed so all stripes show; look-alike flags get `autoGap` (pair QA
recognises a drawn channel even when `seamGap` is 0).

Diagonal Split (M212, `diagonal_split`) uses `seam: diagonal`, `seamSlant`
0.7–0.82 with `seamFlip: true` (top-left → bottom-right, as the reference),
`seamGap` 0.035, `rotateFlags: true`, `edge: brush`, almost no distress.
With `edge: brush` the block outline is painted by `BrushEdge` (spikes carry
the paint next to them), the inside keeps the composed art exactly (the
channel and any bare garment stay bare), and the channel's sides are
roughened by the same brush.

More shared rules for turned flags (M212): a flag whose emblem sits at the
hoist (a canton, a hoist triangle) turns so its hoist lands at the end where
its half is widest — clockwise (hoist at the top) or anticlockwise
(`SplitFlagPlacement.ccw`, hoist at the bottom); every other flag turns
clockwise. On a diagonal seam a flag that must shrink is placed at the
height that allows the largest flag (Nepal sits in the wide end). A hoist
triangle's protected box is its middle 60% (`FlagFocus`), not the thin
corners along the hoist.

## Resolving

```dart
SignatureResolver.hero(pack, 'jp');          // feed index 0
SignatureResolver.variation(pack, 'jp', 17); // envelope sampled
SignatureResolver.driftedLocks(pack);        // [] unless the engine moved a locked design
```

Order: base → country tokens → override → hero values / sampled envelope →
`DesignRecipe`. Variation `i` draws each path from
`DeterministicRng.stream(hash('id|version|cc|i'), path)`, so it is the same on
every device and isolate, and bumping `version` reshuffles variations.

Pair packs:

```dart
SignatureResolver.heroPair(pack, 'us', 'co');          // feed index 0
SignatureResolver.variationPair(pack, 'us', 'co', 17); // key id|version|us+co|17
SignatureResolver.heroFor(pack, 'us+co');              // by key; also 'jp' for single packs
```

Pair order: base → A/B tokens → A's override (slot 0) → B's override (slot 1)
→ pair override → hero values / sampled envelope. `hero`/`variation` refuse a
pair pack, and `heroPair`/`variationPair` refuse a single pack.
`driftedLocks`/`lockFor` take either kind of key.

## Loading in a host

```dart
// Mobile
final catalog = await SignatureCatalog.load(rootBundle.loadString);
// Lab / tests (paths relative to packages/design_studio)
final catalog = await SignatureCatalog.load(read, prefix: SignatureCatalog.packagePrefix);
```

Release builds drop `draft` packs (`includeDrafts` defaults to `!kReleaseMode`).
`catalog.verify()` lists drifted locks per pack.

## Making a draft from a Lab preset

```sh
cd packages/design_forge
dart run tool/pack_from_preset.dart \
  ../../design_studio/recipes/portrait_torn_flag/us-classic.preset.json \
  torn_flag "Torn Flag" ../design_studio/assets/signature/torn_flag.pack.json
```
Then add the id to `assets/signature/index.json`.

## Shared dry-brush edge (`BrushEdge`, M208)

The Brush Flag pack (`brush_flag`) paints the flag as one dry-brush stroke:
`DesignRecipe.brushStroke` (`BrushStroke`: `bristles`, `dryness`, `liftFray`,
`leadClean`, `taper`, `spill`, `skew`, `scale`, `centerY`, `minAspect`,
`maxAspect`) drives `BrushFlagStage`, and the caption uses the embedded
handwritten font (`captions.font: "handwritten"`, Kalam Regular, OFL).

The edge itself is reusable by any stage or pack (Shared Heart, Twin Hearts,
Diagonal Split…). It is **vector**: the shape's outline is resampled and moved
along its normals, then filled anti-aliased, as if painted with one broad brush
moving left → right (`vertical: true` = top → bottom). The long edges wobble
with a few nicks, the trailing edge lifts off in pointed spikes with notches
between them, the stroke is a few staggered bands, the leading edge stays
clean. The inside is never cut, and inward bites are capped by the shape's
local thickness (a heart's tip is roughened, not shredded).

```dart
// design_forge_render
path = BrushEdge.outline(heartPath, brush, seed);                  // ui.Path
mask = await BrushEdge.maskForPath(heartPath, w, h, brush, seed);  // white = keep; dstIn it
mask = await BrushEdge.maskForRect(rect, w, h, brush, seed, vertical: true);
art  = await BrushEdge.brushArtwork(art, brush, seed, shape: heartPath); // spikes carry the paint
```

`brushArtwork` first extends the artwork's colour outward (nearest painted
pixel, `BrushEdge.extendColour`), so a spike continues its stripe. Without
`shape` it brushes the box of the painted pixels and keeps the artwork's own
alpha (a pennant keeps its diagonals).

What the edge reads (fractions of the shape's own box): `bristles` = spikes
across the trailing edge (3–40), `dryness` = wobble and nicks, `liftFray` =
spike length, `taper` = how much the stroke thins and leans towards its end,
`spill` = band stagger, `leadClean` = calm leading edge. `scale`, `centerY` and
the aspect range only matter to `BrushFlagStage`.
