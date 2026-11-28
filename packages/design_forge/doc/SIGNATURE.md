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
