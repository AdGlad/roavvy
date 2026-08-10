# Decision — rendering technology for the design engine

**Status:** accepted (2026-08). **Scope:** how the procedural design engine turns
a `DesignRecipe` into pixels on device, cross-platform (iOS + Android), GPU-
accelerated. **Context:** Flutter 3.41 stable, Impeller default (Metal/iOS,
Vulkan-GLES/Android); both platform targets exist; the existing Skia
`PrintStylePipeline` already does compositing, masks, colour, distress, grain,
halftone and fade on the GPU.

## Decisions

1. **Primary GPU layer = Flutter `ui.FragmentShader`** (GLSL `.frag` compiled by
   `impellerc`). One shader codebase → Metal (iOS) + Vulkan/GLES (Android). This
   provides the effects Canvas cannot: **two-flag blend** and **ripple /
   displacement**.
2. **Keep the Skia `PrintStylePipeline`** for everything it already does
   (compositing, masks, colour, distress, grain, halftone, fade). Do not rebuild
   these — already GPU-accelerated on both platforms.
3. **No native Core Image renderer (and no Android AGSL) as default.** Core Image
   is iOS-only and would force a duplicate Android path for effects a fragment
   shader already expresses.
4. **Rely on Impeller as-is** — already the default; no renderer flags to change.
5. **Do not use Flutter GPU (`dart:gpu`) yet** — experimental; revisit later, not
   for production 2D FX now.
6. **Isolate rendering behind an `EffectRenderer` abstraction.** Default
   `SkiaEffectRenderer` (Canvas + fragment shader) on both platforms; any native
   implementation plugs in behind the same interface with Skia as the guaranteed
   fallback.
7. **Native APIs are opt-in and evidence-gated only** — introduced solely if
   device profiling shows the Skia + fragment-shader path misses frame budget for
   a specific filter, or an effect isn't expressible as a fragment shader; always
   behind the interface, behind a flag, with a fallback.
8. **One renderer for preview and print.** Feed thumbnails (low-res) and Printful
   artwork (high-res) go through the same `EffectRenderer`; the recipe `seed` is
   a shader uniform, so preview == print and designs stay deterministic.

## Why fragment shaders over native Core Image

- **Cross-platform by construction** — a single `.frag` transpiles to both
  backends; Core Image is iOS-only (would need a parallel Android AGSL path).
- **Only in-Flutter tech that can do per-pixel ripple/displacement**, which
  Canvas fundamentally cannot.
- **Composes with what exists** — render composition → offscreen `ui.Image` →
  fragment-shader blend/ripple → back into `PrintStylePipeline` for treatments.
- **Not Apple-Intelligence-gated** (unlike ImageCreator/ImagePlayground): runs on
  effectively all iPhones and Android devices Impeller supports.

## Where things live

- Shader: `apps/mobile_flutter/shaders/flag_blend.frag` (declared in `pubspec.yaml`
  under `flutter: shaders:`).
- Abstraction + default impl:
  `lib/features/merch/design_engine/rendering/effect_renderer.dart`
  (`EffectRenderer`, `SkiaEffectRenderer`, `FlagBlendMode`).
- Treatments (unchanged): `lib/features/merch/print_style/print_style_pipeline.dart`.

## Risks / verification

- **Shader compat:** GLSL must be `impellerc`-acceptable (fragment-only, no
  compute; keep image samplers ≤ ~4). Compile-test on both platforms.
- **Low-end Android (GLES fallback):** shaders still run; profile perf on a cheap
  device.
- **Cross-GPU float variance:** cosmetically irrelevant; correctness lives in the
  reproducible recipe, not the raster.
- **Headless tests:** `FragmentProgram.fromAsset` loads/validates the shader in
  `flutter test`; fragment-shader *execution* may be limited in the headless
  engine, so the exec check is best-effort (device/integration is authoritative).

## Roadmap (not all built yet)

- `EffectRenderer.blendFlags(...)` — **scaffolded now** (two-flag blend + ripple).
- Next: promote blend/weights + continuous treatments (ripple/distress/…) to
  first-class `DesignRecipe` genes; a full `compose(recipe, size)` that chains
  blend → `PrintStylePipeline`; render treatments in the feed thumbnail.
