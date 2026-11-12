# `portrait_torn_flag` — standalone Design Studio

The distressed "torn flag" design (reference:
`design_studio/reference_images/liked/us-flag-torn.jpg`, git-ignored) is
developed and approved in the macOS **Design Lab**, on the same engine the
mobile app uses. Nothing runs on a phone, a simulator or Firebase.

## Run it

```bash
cd apps/design_lab
flutter run -d macos            # debug; add --release for fastest sliders
```

In the Lab's toolbar, click **Torn Flag**. On that screen you can:

- **Flag:** pick a flag (type to filter).
- **Seed:** use ‹ › to step through seeds, or 🎲 for a random one.
- **Parameters:** sliders in Layout / Strips / Tears / Intact block / Distress / Colour.
- **Views:**
  - **Design** is the full preview.
  - **Variations** shows six seeds side by side; click one to use it.
  - **Vs reference** puts the reference image beside the design. You can paste any reference path.
- **Backdrops:** White / Black / Heather / Navy / Transparent (checkerboard).
- **Load preset / Save preset** read and write
  `design_studio/recipes/portrait_torn_flag/<name>.preset.json` (committed).
- **Full res** renders at print size (3600×4500) in a pan/zoom viewer.
- **Export PNG** writes a transparent print PNG plus a `.json` sidecar.
- **Contact sheet** and **Export comparison** write review images.

Exports go to `design_studio/generated_batches/lab_export/torn_flag/` (git-ignored).

## Export from the command line

From `apps/design_lab`:

```bash
PRESET=../../design_studio/recipes/portrait_torn_flag/us-classic.preset.json \
  flutter test test/torn_flag_export_cli_test.dart
```

Optional settings:

| Variable | Effect |
|---|---|
| `LONG_SIDE` | Output long side in pixels. Default 4500 (3600×4500). |
| `SEED` | Override the preset's seed. |
| `SHEET_SEEDS=6` | Also write a contact sheet of seeds `seed..seed+5`. |
| `REFERENCE=<path>` | Also write a reference-vs-generated comparison. |

Every PNG has a sidecar holding the complete preset (flag, seed, parameters,
engine versions), its `recipeId` and `imageHash`, and the render call and size.
Loading the sidecar's `preset` reproduces the image exactly.

## Tests

```bash
cd packages/design_forge        && dart test test/torn_strips_test.dart
cd packages/design_forge_render && flutter test test/torn_strips_raster_test.dart test/torn_flag_golden_test.dart
cd apps/design_lab              && flutter test test/torn_flag_studio_test.dart
cd apps/mobile_flutter          && flutter test test/features/studio_v2/torn_flag_parity_test.dart
```

- **`torn_strips_test`**: parameter JSON round-trips and `recipeId` stability. Every committed preset still loads to the `recipeId` stored in it, so the test fails if an engine change would silently alter an approved design.
- **`torn_strips_raster_test`**: the pure-Dart rasteriser runs on a synthetic flag.
  - It checks a bit-exact hash, which holds on any machine.
  - It checks that the seed and every parameter group take effect, the background is transparent, rotation and mirroring are correct, output is resolution-independent, and white knockout works.
- **`torn_flag_golden_test`**: every committed preset through the full pipeline with the real flag SVGs, compared exactly against `test/goldens/portrait_torn_flag/*.png`.
- **`torn_flag_studio_test`**: the Lab's preset save/load, export with sidecar (re-rendering from the sidecar must give the same hash), contact sheet, comparison, and the screen itself.
- **`torn_flag_parity_test`** (mobile): each committed preset rendered by Roavvy's print path (`RenderService.renderArtwork` over the bundled-asset resolver) must be pixel-identical to the Lab's disk render **and** to the engine golden.

**Approving a deliberate visual change:** review it in the Lab, re-save the
affected presets, then run:

```bash
cd packages/design_forge_render && flutter test --update-goldens test/torn_flag_golden_test.dart
```

Look at the new PNGs before committing them. Never run `--update-goldens` on
the mobile parity test: it reads the engine's goldens.

## Architecture

| Layer | Where | Role |
|---|---|---|
| Recipe config | `packages/design_forge/lib/src/recipe/torn_strips.dart` | `TornStrips` parameters, `portraitTornFlagRecipe()`, `TornFlagPreset` file format. Pure Dart. |
| Shared engine | `DesignFamily.portraitTornFlag` + `DesignRecipe.tornStrips` | Part of the hashed recipe, so `recipeId` covers every parameter. |
| Rendering | `packages/design_forge_render/lib/src/stages/torn_flag_layout.dart` | The composition stage for this family: fetches the flag from the `AssetResolver`, runs the rasteriser on a background isolate. |
| | `packages/design_forge_render/lib/src/geometry/torn_strips_raster.dart` | Strips, tears, intact block, distress and ink colour, computed on the CPU from byte buffers. |
| Standalone studio | `apps/design_lab/lib/torn_flag/` | Screen plus disk I/O. Edits a `TornStrips`, a flag code and a seed, and nothing else. |
| Mobile | `RenderService` + `createBundleAssetResolver()` | Unchanged. A preset's recipe renders through the existing Studio V2 calls. |

The Lab and the app both call `RenderService` from `packages/design_studio`.
The only difference is where flag SVGs come from (repo disk vs the app bundle;
same files). The torn geometry is pure Dart, so it is bit-identical everywhere.
The one platform-dependent input is the flag SVG raster.

## Cut lines

The recipe never invents stripes. **Cut lines** (Lab: Cut lines → From flag / Even / Fringe; JSON `cutMode`) controls where tears go:

- **From flag** (`flag`, the default): before tearing, the engine scans the rotated flag for colour boundaries that run along at least 40% of its length. Those are the flag's own stripes, and the flag is torn only there:
  - US: 12 stripe edges, one strip per stripe.
  - Greece: 8. Germany: 2.
  - Seychelles, France, Japan, Brazil: none.
- **Fallback for wide or stripeless flags:**
  - A band much wider than a US stripe (Germany's thirds) stays whole at the top and frays into short tongues at its end.
  - A flag with no lengthwise stripes at all frays the same way across its whole width, so it stays one recognisable piece.
- **Even** (`even`): evenly spaced full-length strips (`stripCount`), ignoring the design. This is the old behaviour, kept only as an explicit stylised choice.
- **Fringe** (`fringe`): the whole flag frays at its end (`fringeCount` tongues, reaching `fringeDepth` up the flag).

**Tear lines** wander to either side of each cut instead of eroding both neighbouring strips. Where one stripe loses ink, the next gains it, so stripes keep their true width. Detail sizes (roughness, gap, wear) are measured in US-stripe widths, so they read the same on every flag.

## Flag artwork

- **Official US artwork.** The standard bundled flags are 4:3 icon artwork, which puts the US canton at 57% of the flag's length. US Classic uses `flagVariant: "official"`, which loads `assets/flags/svg/official/us.svg` instead. That file is generated to the official specification (Executive Order 10834: 1.9:1, canton 0.76 of the hoist across 7 stripes, 50 stars at the specified spacing). It is bundled in the mobile app through its own `pubspec` asset line.
- **Other flags.** For any flag without an `official/` file, the recipe falls back to the standard artwork. `flagAspect` can still stretch artwork along its length.
- **Texture at every resolution.** Distress and edge noise add finer layers as the output grows, until the finest is about 2 px, with contrast held constant. A 1000 px preview and the 4500 px print show the same pattern, and the print gains real grain instead of enlarged blobs.
- **US stars fixed.** `us.svg` / `um.svg` drew their stars with an SVG `<marker>`, which `flutter_svg` ignores, so every US flag the app rendered this way had a blank canton. The stars are now explicit paths at the same positions.
