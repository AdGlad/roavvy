# Design Forge — architecture & phased plan

**Status:** proposal (2026-08-20). **Scope:** a NEW, standalone, cross-platform
procedural T-shirt design engine + a macOS "Design Lab" dev tool, developed and
perfected **independently** of the shipping Roavvy renderer, targeted to
eventually **replace** it with minimal integration work.

> **Prime constraint:** the production purchase/print path stays **untouched**
> until we deliberately cut over. Nothing here edits
> `apps/mobile_flutter/lib/features/merch/*` or `.../cards/*`. Design Forge is a
> parallel implementation validated on macOS first.

---

## 0. Why a new engine (and what it is *not*)

Roavvy already has a working procedural engine inside the app
(`lib/features/merch/design_engine/`) and a spec workspace (`design_engine/`,
`design_studio/`). The existing `design_engine/` spec was explicitly designed to
**wrap and never replace** the shipping `CardImageRenderer`. This goal is the
opposite direction: an isolated engine we can iterate on aggressively and later
swap in.

The single fact that motivates a clean re-home rather than in-place edits:

> **`CardImageRenderer.render()` draws by mounting a card *widget* into an
> off-screen `OverlayEntry` and calling `RenderRepaintBoundary.toImage()`.**
> (`apps/mobile_flutter/lib/features/cards/card_image_renderer.dart:67`)

That requires a live `BuildContext` + widget tree + the platform UI thread. It is
why rendering is on the UI thread (headline perf risk #3 in the capability
matrix), why headless `flutter test` capture is flaky (studio Lane A is
"best-effort"), and why the engine can't run in an isolate or a pure Dart batch.

**Design Forge replaces widget-tree capture with a pure
`ui.Canvas`/`ui.Picture` pipeline.** Same visual output, but drawable headless,
in an isolate, off the UI thread, and unit-testable. That one change is what
makes the engine simultaneously (a) portable to a macOS lab, (b) real-time-safe
on mobile, and (c) a clean drop-in for the production path later.

---

## 1. What exists today (inventory + reuse map)

Grounded in a full read of `design_engine/`, `design_studio/`, and the app.

### Reuse **as-is** (lift into the new package, keep behaviour)
| Asset | Location | Role in Design Forge |
|---|---|---|
| `DeterministicRng` (SplitMix64 + named sub-streams) | `.../design_engine/procedural/deterministic_rng.dart` | The reproducibility backbone. Copy verbatim into pure core. |
| Torn/ripped geometry engine v2 | `.../design_engine/torn/` (`torn_recipe`, `torn_geometry_generator`, `torn_mask_renderer`, `torn_quality`) | Edge-treatment stage. Already pure-Dart geometry → alpha mask, decoupled from the print filter. |
| Print-style treatment math | `.../merch/print_style/` (`print_style_textures`, `print_style_pipeline` techniques, `artwork_detail_analyzer`) | Effects stage: distress/grain/fade/halftone/cracks/acidWash via `ColorFilter.matrix` + `dstOut/dstIn/softLight/screen`. Resolution-independent, deterministic. |
| Two-flag blend + ripple shader | `apps/mobile_flutter/shaders/flag_blend.frag` + `.../rendering/effect_renderer.dart` (`EffectRenderer`/`SkiaEffectRenderer`) | Flag-combination + ripple/displacement stage (the one thing Canvas can't do). Already behind an abstraction seam. |
| Heart mask + flag packing | `.../cards/heart_layout_engine.dart` (`MaskCalculator`, `HeartLayoutEngine`) | Pure geometry for clip masks + tile layout. |
| 271 flag SVGs | `apps/mobile_flutter/assets/flags/svg/{iso2}.svg` | Flag assets. Load via `flutter_svg` → `ui.Picture` → `ui.Image`. |
| 162 silhouette SVGs | `apps/mobile_flutter/assets/silhouettes/{cc}_{slug}.svg` | Clip masks / motifs. |
| Country/continent outline paths | `assets/country_paths`, `assets/continent_paths` | `countryOutline`/`continentOutline` clip shapes. |

### Reuse **as reference/contracts** (inform, don't bind to)
- **`ProceduralDesignRecipe` (flat `toJson()` shape)** — the runtime recipe the
  generator emits; informs Design Forge's recipe but we don't inherit its
  `DesignParams`-legality coupling.
- **`design_engine/schemas/design_recipe.schema.json`** (nested shape) — the
  formal recipe vocabulary. Design Forge's `DesignRecipe` is a clean superset of
  the *union* of these two, self-contained (no `DesignParams` collapse rule).
- **`design_studio/`** — the reproducibility tuple
  `(experimentId, batchId, scopeKey, seed, engineVersion, grammarVersion,
  recipeId)`, 58 KB design rules (`knowledge_base/design_rules.json`), 8
  regression contexts (`regression_fixtures.dart`), reference images, and the
  `run_experiment.sh` loop. Design Forge plugs its own batches into this.
- **`tool/render_harness.dart`** — the existing macOS preview harness (real
  Skia window, writes contact sheets to `generated_batches/macos_preview/`). The
  Design Lab is the productised successor to this.

### Explicitly **drop / replace**
- `CardImageRenderer` widget-tree capture (`OverlayEntry` + `RepaintBoundary`) →
  pure `ui.Canvas` stage pipeline.
- Per-template card **widgets** (`GridFlagsCard`, `PassportStampsCard`, …) →
  their drawing logic re-expressed as pure `CustomPainter`-style `paint(canvas)`
  routines with no widget dependency. (The cards already delegate to
  `CustomPainter`s like `stamp_painter.dart`, `landmark_painter.dart` — those are
  the reusable primitives.)

---

## 2. Cross-platform rendering technology (decision)

Reaffirms and extends `design_engine/docs/rendering-technology.md`:

1. **Primary raster = Flutter `dart:ui` `Canvas`/`Picture` (Skia/Impeller).**
   One codebase → Metal (iOS/macOS) + Vulkan/GLES (Android). GPU-accelerated,
   already the app's raster. **No widget tree** — draw directly to a
   `PictureRecorder`, `toImage()` off-thread.
2. **GPU per-pixel effects = `ui.FragmentShader`** (`.frag` via `impellerc`):
   two-flag blend + ripple/displacement. Reuse `flag_blend.frag`.
3. **CPU deterministic geometry** for torn masks + textures (already the torn v2
   approach): portable, cacheable, isolate-friendly, exactly reproducible.
4. **No Core Image / no AGSL / no `dart:gpu`** as defaults. iOS-only or
   experimental. Any native fast-path is opt-in **behind the renderer
   interface**, flag-gated, with the Skia path as guaranteed fallback.
5. **SVG → raster** via `flutter_svg` (`vg.loadPicture`), rasterised once and
   cached per (asset, size). Consider a build-time pre-raster/atlas for the Lab's
   large batches (perf risk §10).

Rationale unchanged: cross-platform by construction, composes with what exists,
not Apple-Intelligence-gated, runs on effectively all target devices.

---

## 3. Package boundaries

Three new units. Core logic is **platform-independent**; everything touching
`dart:ui` is isolated in the render layer behind interfaces.

```
packages/
  design_forge/            PURE DART. No flutter, no dart:ui.
    design_recipe          versioned, serialisable recipe model (§4)
    recipe_generator       RecipeGenerator interface + deterministic impl (§7)
    determinism            DeterministicRng (SplitMix64 + named sub-streams)
    geometry               torn masks, clip masks, layout packing → math only
                           (produces Float32/Uint8 buffers + Path descriptions,
                            NOT ui.Image — so it's testable on the Dart VM)
    pipeline               stage contracts: RenderStage, RenderContext, layer graph
    assets                 AssetSpec / AssetResolver interface (no IO)

  design_forge_render/     FLUTTER. Implements the render layer with dart:ui.
    canvas_renderer        DesignRecipe → composable ui.Canvas stages → ui.Image
    stages/                Composition, FlagCombination, Geometry/Mask, EdgeTreatment,
                           Effects, Colour, Typography/Graphics, Output (§5)
    effects                fragment-shader seam (flag_blend.frag), texture raster
    asset_loader           SvgAssetResolver (flutter_svg) + raster cache
    codec                  DesignRecipe <-> ProceduralDesignRecipe adapters (bridge)

apps/
  design_lab/              FLUTTER macOS app. Dev tool only (§8). Depends on
                           design_forge + design_forge_render. Never bundled to
                           mobile; not in the mobile pubspec.
```

**Dependency rule:** `design_forge` (pure) ← `design_forge_render` (flutter) ←
`design_lab` (macOS app) and, later, the mobile app. The mobile app depends only
on the two packages, never the reverse. The renderer is reached only through the
`Renderer` interface, so a native fast-path or a test fake drops in unchanged.

---

## 4. DesignRecipe (the model)

A deterministic, **parametric** description of one design — never a stored
raster. Serialisable (JSON), **versioned**, and self-contained (renders without
any external context). Same `(schemaVersion, engineVersion, assetsVersion, seed,
resolved inputs)` ⇒ visually-equivalent output.

Dimensions (superset of the existing flat + nested shapes, one clean model):

| Group | Fields (initial) |
|---|---|
| **identity** | `schemaVersion`, `recipeId` (content hash), `engineVersion`, `grammarVersion`, `assetsVersion`, `seed`, `provenance{generator,parents,batchId,createdAt}` |
| **family** | `designFamily` (singleHero, duoBlend, grid/montage, passportStamp, timeline, typographic, badge, wordCloud, landmark, journeys, tornHero…) |
| **content** | `flags[]` = `{code, weight}` (weighting is first-class), `source`, `stampMode` |
| **composition** | `template`, `layoutMode`, `rowCount`, `density`, `jitter`, `orientation`, `focalHierarchy`, `placement{anchor,scale,offset}` |
| **flagCombination** | `mode` (mix/diagonal/vertical/horizontal/wave/stripes/checker/radial/torn), `weightA`, `seam` |
| **clip / shape** | `shape` (none/heart/circle/countryOutline/continentOutline/animal|plant|landmarkSilhouette), `code`, `feather` |
| **edgeTreatment** | `TornRecipe` (style family, per-edge weights, depth, fray, corner, asymmetry) OR none |
| **colour** | `garmentColour`, `strategy` (flagDerived/duotone/mono/brand/garmentAware), `accents[]`, `vintageGrade` |
| **effects** | `distress`, `distressHardness`, `grain`, `fade`, `cracks`, `halftone{amount,scale,angle}`, `ripple{amp,freq}`, `acidWash` — all continuous 0..1 |
| **typography** | `titleStyle`, `case`, `placement` (the printed *string* is generated downstream, NOT part of the reproducible genome — only the treatment is) |
| **graphics** | `motifs[]` = `{kind, slug, countryCode?, placement}` |

**Versioning:** append-only optional genes; changing a rule bumps
`grammarVersion`; changing what a pixel means for a given recipe bumps
`engineVersion`; asset changes bump `assetsVersion`. All three participate in
reproducibility. `recipeId = contentHash(canonicalised recipe minus provenance)`.

**Bridge:** `design_forge_render/codec` provides
`DesignRecipe ⇄ ProceduralDesignRecipe` so we can (a) import the 768-design
studio batch + curated `*.recipe.json` anchors as regression fixtures, and (b)
later feed Design Forge output back through the old path during A/B cutover.

---

## 5. Renderer interface — composable stages

The renderer is a **fixed pipeline of swappable stages**, each a pure function
of `(recipe, RenderContext, incoming layers) → layers`. New effects = new
stages, never a new renderer.

```
Renderer.render(recipe, RenderTarget) → RenderResult{ image, recipeId, imageHash, timings }

RenderTarget { size, pixelRatio, quality: preview | print, assetResolver, shaderProvider }

Stage pipeline (ordered, each independently testable & cacheable):
  1. Assets            resolve flags/silhouettes/paths → rasterised layers (cached)
  2. Composition       template layout → placed layer rects (uses geometry pkg)
  3. FlagCombination   1..n flags → single artwork (Canvas or flag_blend.frag)
  4. Geometry / Mask   clip shape + torn perimeter → alpha mask (geometry pkg)
  5. EdgeTreatment     apply torn/ripped mask (dstIn) — realistic OUTER edges
  6. Effects           distress/grain/fade/halftone/ripple (textures + shader)
  7. Colour            ColorFilter.matrix grade (vintage/duotone/mono/garment)
  8. Typography/Graphics  title treatment + motifs layer
  9. Output            flatten → ui.Image → PNG bytes + SHA-256 hash
```

Each stage declares `bool affectsCache` and a cache key contribution, so the Lab
can memoise expensive stages (asset raster, torn mask) across variations that
only differ downstream (e.g. colour sweeps reuse stages 1–6).

**`RenderStage` contract (pure, no global state):**
```dart
abstract class RenderStage {
  String get id;
  LayerBundle apply(DesignRecipe r, RenderContext ctx, LayerBundle input);
}
```

---

## 6. Preview vs print (one renderer, two targets)

**Same pipeline, same stages, same seed** — resolution is a `RenderTarget`
parameter. Guarantees "preview == print":
- **Preview:** ~512–768 px, `pixelRatio` low, textures at normalised (0..1)
  space so they scale, torn mask generated at preview res (no supersample),
  aggressive stage caching. Target < ~40 ms for gallery scroll.
- **Print:** 1800×2400 @ 150 DPI (matches `printability.printfileWidthPx/Height`),
  torn mask supersampled 2–4× then downsampled for clean fibre AA, SVGs
  re-rastered at full res. Off-thread, not latency-critical.
- **Equivalence test:** render the same recipe at preview + print, downscale the
  print to preview size, assert perceptual delta below threshold (SSIM/mean-abs).
  Textures use normalised coordinates + the seed is a shader/RNG input, so the
  two are structurally identical, not merely similar.

---

## 7. Deterministic seed strategy

Reuse the proven backbone verbatim:
- **`DeterministicRng` = SplitMix64**, stable across platforms/Dart versions
  (never `dart:math Random`, which isn't stable).
- **Named sub-streams:** `rng.stream('layout')`, `.stream('palette')`,
  `.stream('torn:top')`, etc. — FNV-1a(name) ⊕ seed. Adding a draw in one
  dimension can't shift another's numbers. Sub-stream names are part of the
  determinism contract (documented, append-only).
- **Only generation (RecipeGenerator) consumes entropy.** The renderer is a
  **pure function of the recipe** — no RNG in stages except via values already
  baked into the recipe (and the shader `uSeed` uniform, which is itself a recipe
  field). ⇒ same recipe always renders identically; regression goldens key off
  `recipeId`.
- **`RecipeGenerator` interface** so recipes can later come from rules,
  preference-learning, Apple on-device models, or other local models — all emit
  the same `DesignRecipe`; rendering never depends on AI.
```dart
abstract class RecipeGenerator {
  List<DesignRecipe> generate(DesignContext ctx, {required int seed, int count});
}
// impls: DeterministicRuleGenerator (now), PreferenceBiasedGenerator,
//        OnDeviceModelGenerator (later) — AI proposes recipes, engine renders them.
```

---

## 8. macOS Design Lab (dev tool)

Standalone Flutter **macOS** app (`apps/design_lab/`), the productised successor
to `tool/render_harness.dart`. Not customer-facing, never bundled to mobile.

Capabilities (mapped to goal):
- **Flag picker** — one or many flags (with weights) from the 271 SVGs.
- **Generate** — batch N designs via a `RecipeGenerator` over selected flags/contexts.
- **Fast gallery** — virtualised scroll of preview renders; async render workers
  (isolates) + preview-res + stage cache keep it smooth at hundreds of tiles.
- **Variations** — "more like this": mutate/seed-sweep a selected recipe.
- **Favourite / save** — persist recipes (JSON) to a local library.
- **Recipe inspector/editor** — view/edit the `DesignRecipe` JSON live; re-render
  on change.
- **Reproduce from seed** — paste seed/recipeId → exact design back.
- **Large batches + contact sheets** — export a grid PNG/HTML contact sheet
  (replaces the ad-hoc inline-HTML builders; a reusable `ContactSheetBuilder`).
- **Export test images** — PNG export at preview or print res.
- **Compare** — side-by-side A/B of two recipes or before/after an engine change
  (diff view), wired to `design_studio/reference_images/`.

The Lab is where the engine is *perfected*: it reads the same
`design_studio/knowledge_base` rules and reference sets, and can drive the
existing `run_experiment.sh` regression arbiter.

---

## 9. Future mobile integration (the contract)

The whole point: mobile integrates against a tiny surface and never learns about
individual effects.

```
Roavvy travel data ─▶ RecipeGenerator ─▶ DesignRecipe ─▶ Renderer.render() ─▶ image
                       (Stage 1→2 today:  (serialisable,   (design_forge_render,
                        TravelProfile →    versioned)        pure ui.Canvas,
                        DesignContext)                       isolate-friendly)
```

- Mobile provides a `DesignContext` (already derivable from `TravelProfile` +
  `MerchContext`) and calls `generate()` then `render()`. No effect knowledge
  leaks upward.
- **Cutover path (later, deliberate):** behind a feature flag, route the merch
  preview/print through `design_forge_render` instead of `CardImageRenderer`.
  The `codec` bridge lets both coexist for A/B and golden comparison before the
  old path is retired. Printful placement/cart/checkout are untouched — they
  consume PNG bytes, which the new renderer produces identically.

---

## 10. Performance risks (identified up front)

1. **SVG rasterisation cost at batch scale** — 271 flags × sizes. Mitigation:
   raster-once cache keyed by (asset, size); optional pre-baked raster atlas for
   the Lab; never re-parse SVG per tile.
2. **Torn mask generation is CPU-heavy** (fBm + strand field + connectivity +
   supersample). Mitigation: generate at preview res for the feed, cache by
   `TornRecipe` hash, supersample only for print, run in an isolate.
3. **Fragment-shader compile/first-use hitch + `impellerc` constraints**
   (fragment-only, ≤~4 samplers). Mitigation: warm the shader once at Lab/app
   start; keep the shader within limits; Skia Canvas fallback for blend modes
   that don't need per-pixel warp.
4. **`toImage()` / isolate image transfer** — moving large `ui.Image`s across
   isolate boundaries. Mitigation: transfer PNG/byte buffers, not live images;
   do print-res renders in a background isolate; keep preview on a bounded worker
   pool.
5. **Determinism drift across GPUs** (float variance) — cosmetically irrelevant;
   correctness lives in the recipe, goldens key off `recipeId` + structural
   metrics, not exact pixels. Cross-GPU pixel goldens use tolerance, not equality.
6. **Gallery memory** — hundreds of decoded tiles. Mitigation: virtualised list,
   evict off-screen `ui.Image`s, cap decode concurrency.

---

## 11. Testing strategy

Per goal, automated tests for:
- **Determinism** — same recipe → byte-identical bytes (or `recipeId`-stable);
  same `(seed, ctx)` → identical recipe.
- **Recipe serialisation** — round-trip JSON, forward-compat (old recipe + new
  schema), version-bump rules.
- **Geometry / masks** — torn edge-concentration (interior stays intact),
  asymmetry, separated fingers, clip-mask coverage (heart/circle/outline).
- **Effects** — each stage's known-input → known-output (golden buffers).
- **Resolution independence** — preview vs print perceptual-equivalence.
- **Regression** — plug batches into `design_studio` baseline arbiter; per-context
  quality may not drop, family diversity may not collapse.
- **Performance** — preview render under frame budget; batch throughput bench.
- **Benchmark recipes/seeds** — curated set (reuse `design_studio/recipes/*` +
  new anchors) for visual before/after contact sheets.

---

## 12. Phased implementation plan

**Phase 0 — Scaffold & spike (proves the thesis).**
Create `packages/design_forge` (pure) + `packages/design_forge_render` (flutter)
+ `apps/design_lab` (macOS). Port `DeterministicRng`. Minimal `DesignRecipe`
(identity + content + composition). One end-to-end path: **single flag → pure
`ui.Canvas` render → PNG**, no widgets. Prove headless render works in the Lab
and in a Dart/Flutter test. *Exit: a single-flag PNG rendered without any
`OverlayEntry`/`BuildContext`.*

**Phase 1 — Recipe + generator + serialisation.**
Full `DesignRecipe` model, JSON codec + versioning, `recipeId` hashing.
`RecipeGenerator` interface + `DeterministicRuleGenerator`. Determinism +
serialisation tests. `codec` bridge to `ProceduralDesignRecipe` to import studio
anchors.

**Phase 2 — Composition + flag combination.**
Grid/montage + single-hero composition as pure painters. Multi-flag combine via
`flag_blend.frag` seam (mix/diagonal/wave/split). SVG asset resolver + raster
cache.

**Phase 3 — Geometry & edges (the signature look).**
Port torn engine v2 (geometry → mask). Clip shapes (heart/circle/outline/
silhouette). Realistic torn OUTER edges wired as a stage. Geometry tests
(edge-concentration/asymmetry/fingers).

**Phase 4 — Effects + colour.**
Port print-style textures + treatment math as stages: distress, grain, fade,
halftone, ripple, vintage/duotone/mono colour grade. Effect golden tests.

**Phase 5 — Preview vs print + perf.**
`RenderTarget` quality tiers, supersampling, isolate render pool, stage caching.
Resolution-equivalence + performance benches.

**Phase 6 — Design Lab productisation.**
Gallery, variations, favourites, inspector/editor, reproduce-from-seed, batch +
contact-sheet export, compare/diff view. Wire to `design_studio` KB + references
+ regression arbiter.

**Phase 7 — Typography, graphics, generators.**
Title treatment + motif graphics stages. Preference-biased + on-device-model
`RecipeGenerator` stubs (AI proposes recipes; engine renders).

**Phase 8 — Integration readiness (no cutover).**
`DesignContext` from `TravelProfile`/`MerchContext`; feature-flag A/B harness
comparing `design_forge_render` vs `CardImageRenderer` on the studio batch;
document the cutover checklist. **Production path still untouched.**

---

## 13. Open decisions (defaults chosen; easily changed)

- **Package names** `design_forge` / `design_forge_render` / `design_lab` —
  placeholders; rename freely.
- **Two packages vs one** — split (pure core vs flutter render) is recommended so
  core logic is VM-testable and truly platform-independent; could collapse to one
  package with `src/` layering if preferred.
- **Recipe format** — JSON (matches studio). Could add a compact binary later.
