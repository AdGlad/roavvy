# Roavvy T‑Shirt Studio **V2** — Implementation Plan (PLAN ONLY, do not implement)

Parallel, opt‑in V2 customer experience for t‑shirt creation, built to the approved storyboard
(`~/Downloads/design-engine-v2.png`) and the functional contract in
`docs/product/chatgpt-tshirt-ux-design-brief.md`. **V1 stays fully intact and operational.** V2 is
a *new UI* over the *existing shared Design Studio engine* — the engine is **not** duplicated.

```
V1 mobile merch UI ─┐                          (unchanged; its own ProceduralDesignRecipe engine)
                    │
Design Studio engine (packages/design_forge + design_forge_render)  ◄── shared, reused
                    │
V2 mobile UI ───────┘  +  macOS design_lab UI    (both thin hosts over the shared engine)
```

---

## 0. Critical finding — there are TWO engines; V2 uses the newer one

| | V1 (production merch) | V2 (this plan) & macOS `design_lab` |
|---|---|---|
| Recipe model | `ProceduralDesignRecipe` / `DesignParams` (`apps/mobile_flutter/.../merch/design_engine/`) | **`design_forge.DesignRecipe`** + `GarmentDesign` |
| Renderer | mobile merch rendering + `local_mockup_painter` | **`design_forge_render.CanvasRenderer`** |
| Generator | `procedural_generator.dart` | **`LabShowcaseGenerator`** (currently in `design_lab`) |
| Travel input | `merch_country_selection_screen` + `DesignContext`‑less | **`DesignContext` / `Trip` / `DateRange` / `TravelHistory`** |

The storyboard and the UX brief are expressed **entirely in the design_forge Studio vocabulary**
(DesignRecipe axes, GarmentDesign front/back, DesignContext trips, the exact Fine‑Tune categories).
So **V2 = a mobile UI on the design_forge Studio engine**, sharing it with `design_lab`. V1's
`ProceduralDesignRecipe` engine is a *separate* stack and is **out of scope / not touched**.

> Consequence: "share the engine, don't duplicate" is satisfied between **V2‑mobile and
> design_lab‑macOS**, not between V1 and V2. V1 keeps its own engine.

---

## 1. Relevant existing architecture (what to reuse vs. leave alone)

### 1a. Shared Studio engine — REUSE (pure/portable)
- **`packages/design_forge`** (already a mobile dependency — `apps/mobile_flutter/pubspec.yaml:43`):
  `DesignRecipe` + parts (`Composition`, `Clip`, `Palette`, `Effects`, `EdgeTreatment`,
  `FillAlgorithm`, `Placement`), **`GarmentDesign`** (front/back, `deriveBack`, `withGarmentColour`),
  **`DesignContext` / `Trip` / `DateRange` / `TravelHistory`** (`src/travel/trip.dart`,
  `src/generation/recipe_generator.dart`), `DesignAxis`, **`PreferenceLearner` / `PreferenceScorer`
  / `PreferenceSignal`**, **`PersistentDesignLibrary` + abstract `DesignStore`**
  (`src/library/design_library.dart`).
- **`packages/design_forge_render`** (NOT yet a mobile dependency — must be added):
  `CanvasRenderer`, abstract **`AssetResolver`**, **`SvgFlagResolver`** (takes `SvgStringLookup` /
  `AssetBytesLookup` callbacks → works from **either disk or the asset bundle**), the stages
  (composition/clip/effects/typography/data_layouts).

### 1b. Studio reference implementation — LIFT/EXTRACT (currently macOS‑only)
`apps/design_lab/lib/` is effectively a **working V2 prototype** but bound to macOS + repo‑disk
assets:
- `studio_canvas_screen.dart` — the whole Studio interaction (axes deck, alternatives tray, locks,
  undo, Remix, Refine category menu, Tier‑1 format bar, **front‑print model**, **Trips Source/Year**,
  Review). State currently lives *inline* in the widget.
- `lab_generator.dart` (`LabShowcaseGenerator`) — pure Dart; the subject/style/axis generator.
- `render_service.dart` (`RenderService`) — caches `CanvasRenderer` output by `recipeId@size`.
- `flag_source.dart` (`FlagSource`) — **repo‑disk** resolver (Lab‑only; not device‑usable).

### 1c. Mobile map / globe infra — REUSE for Travel Selection
`apps/mobile_flutter/lib/features/map/`: `globe_map_widget.dart`, `globe_painter.dart`,
`globe_projection.dart`, `country_polygon_layer.dart`, `country_centroids.dart`,
`country_region_map_screen.dart`, `region_globe_painter.dart`. These already render an interactive,
selectable world map — **do not build another geographic renderer**.

### 1d. Mobile trip data — REUSE to build `DesignContext`
`tripListProvider` → `FutureProvider<List<TripRecord>>` (`core/providers.dart:220`);
`TripRecord` (`packages/shared_models/lib/src/trip_record.dart`) already mirrors `design_forge.Trip`
(`countryCode`, `startedOn`, `endedOn`, `photoCount`) → trivial map → `DesignContext.fromTrips(...)`.

### 1e. On‑device assets — already bundled
`apps/mobile_flutter/pubspec.yaml` bundles `assets/flags/svg/` and `assets/silhouettes/`. So a
**bundle‑backed `AssetResolver`** = `SvgFlagResolver(rootBundleLookups)` — no new asset pipeline.

---

## 2. V1 boundaries — DO NOT CHANGE

Treat as read‑only:
- **`apps/mobile_flutter/lib/features/merch/`** — the entire production flow:
  entry `MerchShopScreen` → `MerchDesignEntryScreen` → … → `LocalMockupPreviewScreen`; the
  `design_engine/` (ProceduralDesignRecipe, DesignParams, procedural_generator, scorers);
  `merch_cart_*`, `product_mockup_specs`, `local_mockup_painter`, `merch_country_selection_screen`.
- **`apps/mobile_flutter/lib/features/cards/`** — card renderers/engines used by V1.
- The V1 route from `main_shell.dart` (tab 3 → `MerchShopScreen`) stays the sole production entry.

V2 adds files; it does not edit V1 files. Shared‑engine packages may gain **additive** APIs
(never breaking changes) since V1 does not depend on `design_forge_render`.

---

## 3. The linchpin move — extract a shared `packages/design_studio`

To share (not duplicate) the Studio logic between macOS `design_lab` and mobile V2, extract the
**portable** parts of `apps/design_lab/lib` into a new package:

```
packages/design_studio/            (pure Dart + Flutter-render, no app/platform deps)
  lib/
    src/
      generator/lab_showcase_generator.dart   (moved from design_lab/lib/lab_generator.dart)
      render/render_service.dart              (moved from design_lab; wraps CanvasRenderer)
      studio_controller.dart                  (NEW: the state machine currently inline in
                                               studio_canvas_screen.dart — recipe, GarmentDesign,
                                               context, axes, history/undo, preferences, front-print)
      assets/asset_resolver_factory.dart       (interface; impls provided by the host)
  design_studio.dart (exports)
```

- `design_lab` (macOS) is refactored to a **thin host**: it keeps `FlagSource` (disk resolver) +
  its `main.dart`, and renders a UI over `StudioController`. *(This refactor is additive and does
  not touch V1.)*
- V2 (mobile) becomes a **second thin host** over the same `StudioController`, providing a
  **bundle** resolver + real `DesignContext`.

**Decided (product):** use a dedicated **`packages/design_studio`** — do **not** fold this into
`design_forge`. The layering is deliberate:
- **`design_forge`** stays the lower‑level **design domain / engine** (recipe model, garment,
  travel context, deterministic generation, rendering primitives). No session/UI concepts.
- **`design_studio`** is the **application / session layer** that *orchestrates* the engine for
  interactive editing (the `StudioController`, generator wiring, render‑cache service, axis/undo/
  preference state). It depends on `design_forge` + `design_forge_render`; it never leaks into them.

Both the macOS Lab and mobile V2 host `design_studio`. This keeps the engine reusable and pure and
concentrates all "editing session" logic in one shared, testable place.

---

## 4. Proposed V2 structure (UI only; logic lives in the shared package)

```
apps/mobile_flutter/lib/features/studio_v2/
  studio_v2_screen.dart            # Scaffold: persistent hero + garment bar + stage host
  studio_v2_controller_binding.dart# Riverpod glue → design_studio StudioController
  assets/bundle_asset_resolver.dart# SvgFlagResolver backed by rootBundle (flags + silhouettes)
  stages/
    instant_stage.dart             # step 1
    travels_stage.dart             # step 2 (reuses map/globe infra)
    direction_stage.dart           # step 3 (+ detail sub-step when Flags)
    vibe_stage.dart                # step 5
    focus_stage.dart               # step 6
    colour_stage.dart              # step 7
    words_stage.dart               # step 8
    front_stage.dart               # step 9
    fine_tune_sheet.dart           # steps 10–14 (Refine category menu)
    review_stage.dart              # step 15
  widgets/
    garment_preview.dart           # live shirt (front/back) — RenderService image + shirt frame
    always_available_bar.dart      # colour · aspect · size · front/back (persistent)
    axis_alternatives_tray.dart    # re-roll tray + lock ✕
    stage_scaffold.dart            # back/next chrome shared by stages
  persistence/
    drift_design_store.dart        # DesignStore impl (Drift/file) for save-to-library
  dev/
    studio_v2_dev_entry.dart       # debug-only launcher (see §10)
```

Registered assets: reuse `assets/flags/svg/`, `assets/silhouettes/` (already declared).
Add `design_forge_render` + `design_studio` to `apps/mobile_flutter/pubspec.yaml` (additive).

---

## 5. V2 state flow

**One `StudioController`** (in the shared package; ChangeNotifier/StateNotifier) owns the whole
design and is independent of screen navigation:

- `GarmentDesign` (front `_hero` + `_frontFace`) · effective `DesignContext` · active `DesignAxis`
  + alternatives · locked axes · **undo/redo history** (recipe stack) · `DesignPreferences` +
  `PreferenceLearner` · front‑print state (fit/side/art/ribbon coverage) · Source/Year.
- **Navigation ≠ recipe history.** A `StudioStage` enum drives which stage widget is shown; the
  controller's undo/redo operates on the recipe stack regardless of stage. Returning to an earlier
  stage must **preserve later compatible state** (e.g. going back to Vibe keeps the chosen garment
  colour and title) — implement stages as *views over the single recipe*, not as data owners.
- The **Always‑Available bar** (garment colour, aspect Portrait/Landscape/Square, artwork Size,
  Front/Back) mutates the controller directly and the hero re‑renders live — visible in **every**
  stage.

Rendering: `RenderService.imageFor(recipe, size)` (cached by `recipeId`); the front stage composites
the front artwork at the mobile print rects (see brief §7) over a shirt‑front frame.

---

## 6. Storyboard → component map

| # | Storyboard step | V2 component | Reuses |
|---|---|---|---|
| — | Always‑Available bar | `always_available_bar.dart` | GarmentDesign, RenderService |
| 1 | Instant Design | `instant_stage.dart` | LabShowcaseGenerator + PreferenceScorer |
| 2 | Choose Your Travels (Countries/Trips · Map/List · Year · select/clear) | `travels_stage.dart` | **map/globe infra**, `tripListProvider`, `DesignContext.fromTrips` |
| 3 | Direction (subject) | `direction_stage.dart` | generator `withGenre` |
| 4 | Detail (flag shape) — Flags only | detail sub‑step in `direction_stage` | `Clip` / `ClipShape` |
| 5 | Vibe (13 styles) | `vibe_stage.dart` | generator `withStyle` |
| 6 | Focus (composition) | `focus_stage.dart` | axis reroll |
| 7 | Colour (palette/treatment) | `colour_stage.dart` | `Palette` / `ColourStrategy` |
| 8 | Words (title + suggest) | `words_stage.dart` | title in `content.meta` + Words axis |
| 9 | Shirt & Front design | `front_stage.dart` | front‑print model (fit/art/ribbon) |
| 10–14 | Fine Tune (Entry/Layout/Graphic/Effects/Print) | `fine_tune_sheet.dart` | Refine category logic |
| 15 | Review (front & back) | `review_stage.dart` | GarmentDesign both faces + spec |

---

## 7. Brief control‑coverage map (every control achievable in V2)

| Brief control (§5–§8) | V2 home | Engine field |
|---|---|---|
| Garment colour · Aspect · Artwork size · Front/Back | Always‑Available bar | `Palette.garmentColour`, `Composition.orientation`, `SizeClass`, `GarmentDesign` view |
| Direction (6 subjects) | Direction stage | generator genre |
| Detail (Flags only) | Direction sub‑step | `Clip.shapeId` |
| Vibe (13) | Vibe stage | `withStyle` |
| Focus | Focus stage | axis reroll |
| Colour treatment + Vintage grade | Colour stage / Refine‑Colour | `Palette.strategy`, `vintageGrade` |
| Words + Suggest | Words stage | `content.meta['title']` |
| Front fit Full/Chest(L/R)/None · art Ribbon/Complement/Match · ribbon Selected/All | Front stage | front‑print state + `deriveBack` |
| Trips Source (Countries/Trips) + Year | Travels stage | `DesignContext.fromTrips` + `DateRange.years` |
| Fine Tune: Finish/Layout/Graphic/Text/Colour/Edges/Effects/Print | Fine‑Tune sheet (contextual) | `Effects`, `EdgeTreatment`, `Clip`, `FillAlgorithm`, passport ink/stamp |
| Review + Save + Cart | Review stage | `PersistentDesignLibrary` + cart bridge |

**All visibility predicates from brief §6 must be enforced** (Detail↔Flags, Graphic↔clipped/passport,
Text↔Words, Front controls↔Front side, Chest L/R↔Chest fit, Ribbon coverage↔Ribbon art, Trips
row↔hasTrips, silhouette pick↔silhouette clip, passport controls↔Passport).

**Decided (product):** **artwork Size = S/M/L only** in the Always‑Available bar. **Physical garment
size (XS–XXL) is a cart/checkout attribute** and lives at Add‑to‑Cart, exactly as the UX brief
specifies (and the design_lab reconciliation §4). These two concepts must **never** be merged in the
UI — the storyboard's `S M L XL XXL` bar is a graphical detail we intentionally do not follow here.

---

## 8. Travel selection detail (reuse the globe/map)

- Toggle **Countries ↔ Trips**; toggle **Map ↔ List**.
- **Map**: reuse `globe_map_widget` / `country_polygon_layer` / `country_centroids`; tap a country
  to select/deselect (highlight state). **List**: a searchable country/trip list with checkboxes.
- **Year range** slider shown only when trip history exists (`TravelHistory.span`); filters trips.
- **Select all / Clear**.
- Output → build the effective `DesignContext` (Countries = distinct codes; Trips = per‑visit codes)
  and hand it to the controller, which regenerates the hero. This is exactly the `_rebuildContext`
  logic already prototyped in `studio_canvas_screen.dart` — lift it into `StudioController`.

---

## 9. Milestones (vertical, demonstrable; each shippable behind the dev switch)

- **M0 — Extraction & scaffolding.** Create `packages/design_studio`; move
  generator + RenderService; add `design_forge_render` to mobile pubspec; add a `BundleAssetResolver`;
  render ONE static hero on a mobile dev screen. *No V1 change.*
- **M1 — StudioController.** Lift the inline state from `studio_canvas_screen.dart` into a reusable
  `StudioController`; re‑host the macOS Lab on it (proves reuse) — additive.
- **M2 — Hero + Always‑Available bar** on mobile: live preview, garment colour/aspect/size/front‑back,
  undo/redo.
- **M3 — Creative deck stages**: Instant → Direction(+Detail) → Vibe → Focus → Colour → Words, with
  alternatives tray + lock + Remix + stage nav (back/next, state‑preserving).
- **M4 — Travels stage**: map/list selection, Countries/Trips, Year filter → DesignContext.
- **M5 — Front configuration** stage (fit/art/ribbon) + front print preview.
- **M6 — Fine Tune sheet**: the full contextual Refine category menu (all brief controls).
- **M7 — Review + Save**: both faces, spec, `DriftDesignStore` save‑to‑library.
- **M8 — Cart bridge (adapt V1 commerce boundary — no new cart)**: a thin adapter that turns a
  finished V2 `GarmentDesign` into the payload the **existing** commerce/cart boundary already accepts
  (`MerchCartItem` via `MerchCartRepository`) — final artwork/product/variant + garment fit size
  chosen at checkout. Reuse V1's cart, order, Printful and checkout logic wholesale; do **not**
  duplicate checkout. The adapter is a V2‑side translation only (no V1 edit).
- **M9 — Hardening**: on‑device render parity, performance, analytics/telemetry to compare V1 vs V2.

---

## 10. Dev‑only launch switch (V1 vs V2 independently, production untouched)

Prefer a **compile‑time flag + debug‑only entry**, never a change to the production route:
- `const kStudioV2 = bool.fromEnvironment('STUDIO_V2');` → run V2 via
  `flutter run --dart-define=STUDIO_V2=true` (a top‑level dev route to `StudioV2Screen`).
- Plus a **debug‑only** affordance (e.g. a long‑press on the Merch tab header, gated by `kDebugMode`)
  that pushes `StudioV2Screen`. Production `MerchShopScreen → MerchDesignEntryScreen` is unchanged.
- Optional Remote Config/feature‑flag gate for later staged rollout (off by default).

This lets us launch either experience on demand, compare them, and fall back to V1 at any time.

---

## 11. Tests required

- **Shared package (unit, headless):** StudioController — axis reroll determinism, lock/branch/undo,
  front‑print rects + fit/art/ribbon, `_rebuildContext` Source/Year, preference signals. (Port the
  existing `design_lab/test/studio_canvas_test.dart` + `..._learning_test.dart` to the package —
  they already cover most of this: 78 green today.)
- **Mobile widget tests:** Always‑Available bar mutations re‑render the hero; stage navigation
  preserves later compatible state; Travels selection builds the expected DesignContext; Fine‑Tune
  visibility predicates; Review shows both faces.
- **Golden/render:** a small on‑device render‑parity check (bundle resolver vs Lab disk resolver).
- **Guard test:** assert V2 imports nothing from `features/merch` / `features/cards` (V1 isolation).

---

## 12. Risks & mitigations

| Risk | Mitigation |
|---|---|
| Package extraction churn touches many files | M0/M1 are additive; keep `design_lab` green as the canary; no V1 files touched |
| On‑device render performance (SVG raster, many flags) | RenderService caching by `recipeId@size`; pre‑warm; size‑appropriate raster; profile in M9 |
| Asset resolver gaps on device (silhouettes/outlines/passport PNGs) | Bundle lookups mirror `FlagSource.resolver()` wiring; verify each `AssetResolver` callback has a bundle path |
| Two engines diverge (V1 vs forge) | V2 does not aim for pixel‑parity with V1; it's a *different* engine by design; compare via analytics, not goldens |
| Cart integration coupling to V1 | **Decided:** adapt the existing V1 commerce boundary — a V2‑side `GarmentDesign → MerchCartItem` payload adapter; reuse V1 cart/checkout/Printful wholesale. No new cart, no V1 edit. If the payload shape needs a field V1 lacks, add it *additively* to the shared cart‑item boundary |
| Storyboard size control (S–XXL) vs brief (artwork S/M/L + fit at cart) | **Decided:** artwork Size = S/M/L in the bar; physical fit XS–XXL only at checkout. Never merged |
| `design_forge_render` becomes a mobile dep → build weight | It's Flutter‑native (`flutter_svg` already used); additive, no V1 runtime impact |

---

## 13. Confirmed decisions (product, 2026‑08‑27)

1. **`packages/design_studio`** is a dedicated **application/session layer** over `design_forge`
   (engine) + `design_forge_render`. Do **not** fold into `design_forge`; the engine stays pure and
   lower‑level. (§3)
2. **Artwork Size = S/M/L only**; physical garment size **XS–XXL at cart/checkout**. Never merge the
   two. (§7)
3. **No new V2 cart** — adapt the existing V1 commerce/cart boundary via a `GarmentDesign →
   MerchCartItem` payload adapter; reuse V1 checkout/Printful. (§9 M8, §12)

### Immediate next actions (still no V2 UI code)
Begin **M0** (create `packages/design_studio`; move generator + RenderService; add `design_forge_render`
to mobile pubspec; add the bundle `AssetResolver`; render one mobile hero) behind the dev switch (§10).

*Stop here — plan only. No V2 implementation.*
