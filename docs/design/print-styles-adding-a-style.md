# Adding a new Print Style

The print-style system is designed so a new style (Cracked Ink, Duotone,
Stencil, Ink Bleed, Travel Patch, …) is almost always **just data** — a new
enum value and a preset entry. You only touch the pipeline when a style needs an
effect the parameters can't already express.

All code lives in `apps/mobile_flutter/lib/features/merch/print_style/`.

## The common case: params only

1. **Add the id** — `PrintStyleId` in `print_style.dart`:
   ```dart
   enum PrintStyleId { clean, vintage, retro, halftone, stamp, grunge, crackedInk }
   ```

2. **Add a label** — `printStyleLabel()` in the same file (the picker uses it).

3. **Add a preset** — one entry in `kPrintStylePresets`, composed from existing
   parameters:
   ```dart
   PrintStyleId.crackedInk: PrintStyleParams(
     id: PrintStyleId.crackedInk,
     distress: 0.55,
     roughEdges: 0.40,
     grain: 0.20,
     colorTreatment: ColorTreatment.muted,
   ),
   ```

That's it. The picker strip enumerates `PrintStyleId.values`, the preview screen
routes the render through `PrintStylePipeline`, and the styled bytes flow to the
Printful print file automatically. Determinism, the per-artwork detail
protection (`detailFactor` + local edge mask), preview caching, and the
`clean` pass-through all apply for free.

**Available parameters** (see `PrintStyleParams`): `distress`, `grain`, `fade`,
`roughEdges`, `halftone` + `halftoneScale`, `colorTreatment`
(`none`/`muted`/`vintageWarm`/`monoInk`/`duotone` with `duotoneA`/`duotoneB`),
and `seed`. `effective*` getters fold in `detailFactor`.

> **Duotone** is the worked example that proves this path: it needed no pipeline
> change beyond the colour-matrix branch already present. A duotone style is
> defined purely by `colorTreatment: ColorTreatment.duotone` + `duotoneA/B`
> (see `print_style_protection_test.dart`).

## When you need a new effect

If the look needs something the parameters can't express (e.g. a *stencil*
bridge pattern, an *ink-bleed* dilation):

1. Add a texture generator in `print_style_textures.dart` (a pure
   `generate*Bytes(seed, size, …)` function) and, if it should be cached, a
   `PrintTextureKind` case. Keep it **deterministic** — seed-driven, no timing.
2. Add a compositing pass in `PrintStylePipeline.apply()` gated on the relevant
   parameter, reusing `_erase` (ink removal → transparency), `_fillTiled`
   (overlays), `_applyHalftone`, or a colour matrix in `_buildColorFilter`.
3. Keep transparency semantics: **distress removes ink to transparent**, never
   paints the garment colour.

## Testing checklist (mirrors the existing suites)

- **Determinism**: same `(id, params, seed)` → identical bytes; different seed →
  different bytes.
- **Clean untouched**: `clean` stays a byte-perfect pass-through.
- **Detail protection**: a busy design keeps more ink than a sparse one at the
  same preset (global `detailFactor`); high-edge emblem regions keep more ink
  with the local mask than without.
- **Resolution independence** (if geometric, like halftone): the effect's
  frequency matches at two pixel sizes.
- **Printability guard**: the style never wipes the design out (ink survives).

Add cases to `test/features/merch/print_style/` alongside the existing files.
