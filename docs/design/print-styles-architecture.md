# Print Styles Architecture (Vintage / Retro / Halftone / Stamp / Grunge)

**Status:** Implemented (M-A … M-E). See the "Implementation status" section at
the end. Guide for adding styles: `print-styles-adding-a-style.md`.
**Scope:** Add a reusable, offline, deterministic "Print Style" (filter) layer that
transforms existing flag/grid/silhouette/shape-clipped merch artwork so it reads as
professional apparel. Extends the current system; changes no existing designs, assets,
clipping, travel data, purchase flow, or Printful integration.

---

## 1. How designs are currently rendered

The merch artwork pipeline has a single choke point:

```
CardImageRenderer.render(context, template, …)            [features/cards/card_image_renderer.dart]
  → mounts the card widget (grid / heart / passport / silhouette / timeline /
    wordCloud / landmark / journeys) off-screen in an Overlay
  → RenderRepaintBoundary.toImage(pixelRatio)             (pixelRatio = 12.0 for t-shirts, 3.0 for cards)
  → image.toByteData(png)  →  CardRenderResult.bytes (Uint8List PNG)
```

That PNG (`artworkImageBytes`) is used two ways, and **they share the same bytes**:

- **Preview (on device):** decoded to a `ui.Image` and composited onto a shirt photo by
  `LocalMockupPainter` (`features/merch/local_mockup_painter.dart`). T-shirt artwork is
  rendered **transparent-background** (`transparentBackground: true`), composited with
  `srcOver` + a `dstIn`-masked fabric-shading overlay so only inked pixels pick up fabric
  texture and transparent areas show the garment.
- **Print (Printful):** `merch_variant_screen.dart` sets
  `clientCardBase64 = base64Encode(artworkImageBytes)` and posts it to the `createMerchCart`
  cloud function. **The print file is the exact approved artwork bytes.**

**Consequence:** if the Print Style is baked into the artwork PNG *before* the user
approves it, both the preview and the Printful print file inherit the style automatically.
No change is required to `LocalMockupPainter`, `ProductMockupSpecs`, the clipping engine,
or `createMerchCart`.

## 2. Where flags, SVGs and clipping are handled

- **Flags:** `FlagTileRenderer` (`features/cards/flag_tile_renderer.dart`) rasterises
  `assets/flags/svg/<code>.svg` into cached `ui.Image`s via `flutter_svg` + `PictureRecorder`.
- **Silhouettes / outlines:** `SilhouetteFlagWidget` and `card_templates.dart` build a
  clip `Path` (`_clipPathFor`) and call `canvas.clipPath(...)` +
  `MaskCalculator.applyFeatheredEdge` (`heart_layout_engine.dart`). Country/continent
  outlines, heart, circle, animal/plant/landmark silhouettes all resolve to a `Path`.
- **Clip options / layout:** `flag_clip_options.dart` + `flag_grid_layout_engine.dart`
  decide *what* is drawn and *where*. All of this runs **before** `toImage` and produces
  the flat artwork.

The Print Style operates on the **rasterised output** of this stage — it never touches
SVGs, clip paths, or layout. It is purely "source artwork → styled artwork".

## 3. Where the Print Style layer should sit

Exactly one stage, immediately after `CardImageRenderer.render` and before the bytes are
stored/decoded:

```
Source artwork  →  existing clipping/layout  →  [CardImageRenderer → ui.Image]
   →  PrintStylePipeline.apply(image, params)   ← NEW, the only insertion point
   →  styled ui.Image  →  PNG bytes (== preview source == Printful print file)
```

Concretely, every call site that currently does
`final result = await CardImageRenderer.render(...)` in
`local_mockup_preview_screen.dart` gains an optional post-process:

```dart
final rendered = await CardImageRenderer.render(...);          // unchanged
final styled   = _printStyle.isClean
    ? rendered.bytes
    : await PrintStylePipeline.instance.applyToBytes(rendered.bytes, _printStyleParams);
_artworkBytes = styled;                                        // preview + print, styled
```

`PrintStyleId.clean` is a pass-through (returns the original bytes unchanged) so existing
behaviour is byte-identical when no style is selected — the default. This guarantees
"do not change or break existing designs".

## 4. Best local technology for these effects

**Recommendation: Flutter `Canvas` raster compositing with cached, seeded procedural
texture layers.** Primary approach; optional fragment-shader upgrade later (§4.3).

### 4.1 Why raster compositing first (the simplest performant solution)

- The codebase already uses exactly these primitives everywhere: `saveLayer`,
  `BlendMode.multiply/dstIn/dstOut/srcOver`, `ColorFilter`, `clipPath`,
  `applyFeatheredEdge`. Zero new toolchain, no shader-compilation risk, no Impeller
  edge-cases (the app ships no custom `FragmentProgram` today and sets no Impeller flag).
- It is **deterministic and unit-testable on CI without a GPU**: the effect *parameters*,
  preset mapping, detail analysis, and texture *generation seeds* are pure Dart.
- It runs on the GPU-backed `Canvas` for the actual compositing → fast at both preview and
  print resolution.
- Every effect the brief needs maps directly to a compositing op:

  | Effect | Implementation |
  |---|---|
  | Grain | tileable seeded noise `ui.Image`, `BlendMode.overlay`/`softLight`, low opacity |
  | Fade / colour treatment | `ColorFilter.matrix` (desaturate, warm/muted, duotone, mono-ink) |
  | Distress → **transparent** | seeded blotch-noise mask via `BlendMode.dstOut` (erases ink, garment shows through) |
  | Rough edges | erode/feather the alpha (reuse `MaskCalculator` pattern) + edge-noise `dstOut` |
  | Halftone | procedural dot grid drawn once per (scale,seed), used as a `dstIn`/`multiply` mask |
  | Stamp ink | uneven-alpha paper texture (`dstOut`) + rough edge + mono-ink colour |
  | Scratches/chips (grunge) | seeded scratch-streak texture (`dstOut`) at higher intensity |

### 4.2 Determinism

- All procedural textures are generated from a **seed** using a pure Dart hash PRNG
  (e.g. splitmix64 / `math.Random(seed)` for texture generation only — never for the
  live effect path). Same `(styleId, params, seed)` → identical texture → identical output.
- Texture coordinates are defined in **artwork-normalized space** (0–1, scaled by
  `halftoneScale` etc.), so the low-res preview and the 12× print render look the same —
  grain and dots are relative to the artwork, not to pixel count.
- The chosen `seed` is **persisted** with the design (see §8) so re-opening reproduces
  identical artwork.

### 4.3 Optional fragment-shader upgrade (future, not required for v1)

A single parameterised `print_style.frag` (`FragmentProgram.fromAsset`) could fold
grain + halftone + distress-alpha into one GPU pass driven by uniforms incl. `seed`. Kept
out of v1 to avoid the shader-toolchain/testing risk; the architecture is written so the
pipeline implementation can be swapped behind `PrintStylePipeline` without touching call
sites. Listed here so the design doesn't preclude it.

## 5. Preview vs high-resolution rendering

Two tiers, both from the same params so preview matches print:

- **Preview tier (interactive, cached).** When the user browses styles we apply the
  pipeline to the **already-decoded preview-resolution** artwork (a few hundred px), not
  the 12× print image. Result cached in a `PrintStylePreviewCache` keyed by
  `(artworkHash, styleId, seed, previewSize)`. Switching styles after first generation is
  an instant cache hit — **no full-res regeneration while browsing** (brief requirement).
  Cache is LRU-bounded (mirrors `LocalMockupImageCache`, ~6–8 entries) and disposes evicted
  `ui.Image`s.
- **Print tier (one-shot, on confirm).** The 12× styled render happens **once**, when the
  user proceeds to approval/checkout, reusing the existing `_variantLoading` spinner. The
  detail analysis (§6) is computed on the low-res source and **reused** at print res, so
  there is no heavy CPU work at print time — only GPU compositing.

## 6. Deterministic procedural textures + protecting details

Two protection levers, both computed **once** from a downscaled (~64×64) copy of the
source artwork (pure Dart, ~ms, reused for preview and print):

1. **Global `detailFactor` (0–1).** Derived from alpha coverage + edge density +
   luminance variance (concepts reusable from `design_engine/printability.dart`:
   `estimateInkCoverage`, `kMinFeaturePx`). A busy, detailed flag/grid yields a high detail
   score → distress/roughEdges/halftone intensities are automatically scaled **down** so
   symbols stay recognisable. This satisfies "detailed flags automatically receive less
   aggressive distress" without per-flag configuration.
2. **Local protection mask.** A downsampled edge/contrast map, upsampled and used to
   *attenuate the distress mask* (`distress *= 1 - localEdgeStrength`). High-contrast
   features — flag emblems, text, thin details — keep their ink even at high global
   distress. Small features below a min-feature threshold are excluded from erosion.

Both are pure functions of the source image and are the primary unit-test surface.

## 7. Performance / memory implications

- **Base textures generated once, reused for every design:** a small set of tileable
  256×256 seeded textures (grain, paper, scratches, halftone cell) cached as `ui.Image`s
  and tiled via `TileMode.repeated`. Tiny, bounded memory; no per-design texture growth.
- **Preview:** small images + cache → style switching is O(cache hit). No UI-thread pixel
  loops (analysis is on the 64×64 thumbnail only).
- **Print:** exactly one 12× GPU composite on confirm; result disposed promptly. No
  per-frame work, no isolate needed for v1 (analysis already done at low res). If profiling
  shows the 12× composite janks, it can move to `ui.Image` off-thread compositing later
  without API change.
- **No change** to existing memory owners (`LocalMockupImageCache`, `FlagImageCache`).
- Output stays a standard transparent PNG → unchanged Printful DTG workflow; distress
  produces transparency (garment colour), never painted-in garment colour, keeping ink
  coverage within `printability.dart` bounds.

## 8. Proposed PrintStyle model

New folder `features/merch/print_style/`:

```dart
enum PrintStyleId { clean, vintage, retro, halftone, stamp, grunge }

enum ColorTreatment { none, muted, vintageWarm, monoInk, duotone }

/// Fully-resolved, deterministic parameters for one styled render.
class PrintStyleParams {
  const PrintStyleParams({
    required this.id,
    this.distress = 0,        // 0..1  ink loss → transparency
    this.grain = 0,           // 0..1  film grain intensity
    this.fade = 0,            // 0..1  desaturate + lift
    this.roughEdges = 0,      // 0..1  edge erosion / irregularity
    this.halftone = 0,        // 0..1  dot treatment intensity
    this.halftoneScale = 0.02,// dot cell size, artwork-normalized
    this.colorTreatment = ColorTreatment.none,
    this.duotoneA, this.duotoneB,
    this.seed = 0,            // deterministic
    this.detailFactor = 1.0,  // filled in by ArtworkDetailAnalyzer (auto-protect)
  });
  // copyWith(...) for user fine-tuning + analyzer injection.
  bool get isClean => id == PrintStyleId.clean;
}

/// Presets: user picks an id; base params come from here, then detailFactor is applied.
const Map<PrintStyleId, PrintStyleParams> kPrintStylePresets = { … };
```

Supporting pieces (all new, all additive):

- `print_style_pipeline.dart` — `applyToBytes(Uint8List, PrintStyleParams)` and
  `apply(ui.Image, PrintStyleParams)`; the raster compositor. `clean` → pass-through.
- `artwork_detail_analyzer.dart` — `analyze(ui.Image) → {detailFactor, protectionMask}`.
- `print_style_textures.dart` — seeded grain/paper/scratch/halftone texture cache.
- `print_style_preview_cache.dart` — LRU of styled preview `ui.Image`s.

**Persistence for reproducibility:** store `printStyleId` + `printSeed` alongside the
existing artwork confirmation / merch config so the exact styled artwork can be
reproduced and re-printed. Backward-compatible: absent ⇒ `clean`.

**Extensibility:** future styles (Cracked Ink, Duotone, Stencil, Ink Bleed, Travel Patch)
are added by (a) one `PrintStyleId` enum value, (b) one entry in `kPrintStylePresets`, and
(c) reusing existing parameters (or adding one texture generator). No call-site or pipeline
signature changes.

---

## 9. Milestone implementation plan

Each milestone is independently shippable; `clean` remains the default until M-D wires UI,
so nothing user-facing changes until the layer is proven.

### M-A — Model & analysis foundations (no UI, no render change)
Build `PrintStyleParams`, `PrintStyleId`, `ColorTreatment`, `kPrintStylePresets`,
`ArtworkDetailAnalyzer`, and the seeded texture generators.
- **Acceptance:** presets resolve to stable params; analyzer returns a lower `detailFactor`
  for a busy grid than for a sparse single flag; textures are byte-identical for a given seed.
- **Tests:** unit — preset table snapshot; `detailFactor` ordering (dense grid < sparse);
  analyzer monotonic in coverage/edge inputs; texture determinism (same seed → same bytes,
  different seed → different bytes).

### M-B — Pipeline: Clean / Vintage / Retro / Grunge (raster core)
Implement `PrintStylePipeline` (grain, fade, colour treatment, distress→transparent,
scratches). `clean` is a verified pass-through.
- **Acceptance:** `clean` output is byte-identical to input; styled output preserves the
  artwork's opaque emblem regions (protection mask honoured); distressed pixels become
  **transparent** (alpha reduced), never garment-coloured.
- **Tests:** unit/widget (with a live binding) — pass-through equality for `clean`;
  determinism (same params+seed twice → identical bytes); "protected region stays opaque"
  (sample a known emblem pixel); "distress adds transparency" (total alpha decreases,
  no new fully-opaque non-emblem pixels).

### M-C — Halftone & Passport Stamp
Add procedural dot mask (scale/intensity) and stamp treatment (uneven ink + rough edges +
mono-ink), extending `roughEdges` via the `MaskCalculator` feather/erode pattern.
- **Acceptance:** halftone dot size tracks `halftoneScale` independent of resolution
  (preview vs 12× visually match); stamp edges are irregular; both respect `detailFactor`.
- **Tests:** unit — dot count scales with `halftoneScale`; rough-edge alpha differs from
  clean only within an edge band; resolution-independence (dot period in normalized space
  equal at two pixelRatios).

### M-D — Preview UI, caching, and print/confirmation wiring
Add a style-picker strip in `local_mockup_preview_screen.dart` (mirrors the existing
clip-option strip); route every `CardImageRenderer.render` result through the pipeline;
add `PrintStylePreviewCache`; persist `printStyleId`+`printSeed` into the artwork
confirmation; confirm `clientCardBase64` carries the styled bytes.
- **Acceptance:** switching among the 6 styles after first generation is instant (cache
  hit, no 12× regen); the approved/printed bytes equal the previewed styled bytes; existing
  flows with no style selected are unchanged; UI thread not blocked (async + spinner reuse).
- **Tests:** widget — picker renders 6 styles and updates `_artworkBytes`; cache hit on
  re-select (no re-render call); persisted id+seed round-trips; `clean` path leaves
  `clientCardBase64` byte-identical to today.

### M-E — Auto-protection tuning, print validation, extensibility docs
Wire `detailFactor` + local protection mask into intensity scaling; validate 12× styled
output against `printability.dart` (coverage/contrast/min-feature); write the
"adding a new Print Style" guide; add Cracked Ink or Duotone as a proof of extensibility.
- **Acceptance:** detailed flags visibly receive less distress than sparse ones at the same
  preset; styled print files pass existing printability gates; a new style is added by
  enum + preset entry only (no pipeline signature change), proven by the extra style.
- **Tests:** unit — printability gate passes for each preset on representative artworks;
  "add-a-style" test constructs a new preset and renders it through the unchanged pipeline.

## Implementation status

All five milestones landed. Code in
`apps/mobile_flutter/lib/features/merch/print_style/`; tests in
`test/features/merch/print_style/` (32 tests, plus the existing preview-screen
suite still green).

- **M-A** `print_style.dart` (model + presets), `artwork_detail_analyzer.dart`
  (pure detail/protection analysis), `print_style_textures.dart` (seeded
  grain/blotch/scratch/stampInk).
- **M-B** `print_style_pipeline.dart` — raster compositor; Clean pass-through,
  colour treatment, fade, grain, distress→transparency, scratches.
- **M-C** halftone dot screen (resolution-independent) + Passport Stamp
  (mono-ink + uneven ink/rough edges).
- **M-D** `print_style_preview_cache.dart` + integration into
  `local_mockup_preview_screen.dart`: `_PrintStyleStrip` picker; every artwork
  (re)render funnels through `_afterArtworkCommitted` → styled `_artworkBytes`,
  which is the preview source, the back print file
  (`MerchImageProcessor.processBack`), and the confirmation `imageHash`. Clean
  default is byte-identical to pre-style behaviour.
- **M-E** local protection mask wired into the erase passes (emblems/text kept
  inked); Duotone colour matrix as the extensibility proof; printability guard
  test; add-a-style guide.

**Deferred (follow-up, not blocking):**
- Persisting the *symbolic* `printStyleId` + `printSeed` into the
  `ArtworkConfirmation` / `MerchCartItem` schema. The styled **pixels** and their
  `imageHash` are already persisted and are what Printful prints, so an order is
  fully reproducible; the symbolic fields would only add convenience for
  *re-editing* a saved design's style later. Deferred to avoid `shared_models` /
  Firestore schema churn touching the purchase flow.
- Styling the small front chest **ribbon** (`_frontRibbonBytes`) — the primary
  (back/centre) artwork is styled; the chest badge remains clean for now.
- Optional fragment-shader fast path (§4.3).

## 10. Explicitly unchanged / non-goals
- No change to `LocalMockupPainter`, `ProductMockupSpecs`, `createMerchCart`, clipping
  engine, flag/silhouette assets, layout engines, travel data, or the purchase flow.
- No remote LLM / image API / cloud AI — everything is on-device and deterministic.
- No golden tests unless requested (per app testing rules); determinism verified via byte
  hashes and targeted pixel/alpha assertions.
