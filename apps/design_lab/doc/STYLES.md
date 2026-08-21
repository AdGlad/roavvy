# Lab style presets

Named **aesthetic directions** that flavour a whole batch coherently, instead of
per-tile randomness. Pick one from the **Style** dropdown (top-left of the Lab);
`Generate` fills the grid in that style. `Showcase` is the broad everything-default.

The Edit panel has its own **Style** control: pick a style to re-derive the
selected design in that preset (same seed + flags), then fine-tune the sliders;
the dice advances the seed to browse the style's other subjects. The style is
stored in `provenance.generator` (`lab:<style>`) and read back via
`labStyleFromProvenance`.

`lib/lab_styles.dart` is the single source of truth. Each `LabStyle` → a
`StyleSpec`, and every tile is built in two coherent halves:

1. **Subject** — a `ClipArchetype` drawn from the style's *front-loaded* rotation
   → a `Clip` (or the plain flag). Consecutive seeds walk the rotation, so the
   grid's first tiles are the style's signature looks; a given seed always
   reproduces the same tile.
2. **Finish** — edge treatment + effects + palette from `StyleSpec.finish`,
   layered on top. `tornOnClip` lets a style (grunge) tear clipped shapes too.

Silhouette / country / continent subjects are country-specific; they're skipped
when unavailable (e.g. a multi-country batch), so the rotation degrades cleanly.

## The presets

| Style | Signature subjects | Finish |
|---|---|---|
| **Showcase** | basic · silhouettes · outline, then all shapes | mixed: clean / torn / vintage / halftone / tie-dye |
| **Maximal** | bold shapes + silhouettes + outline, edge-to-edge | everything stacked: torn (on clips too) + distress + grain + halftone + colour grade |
| **Beachwear** | sunset · wave · island · circle · heart | faded flag palette, tie-dye/fade, light torn |
| **Surf** | wave · badge · circle · sunset | sun-faded palette, retro halftone |
| **Grunge** | torn flag · shield · star · hexagon | heavy distress + grain + cracks, mono/duotone, torn-on-clip |
| **Minimalist** | small circle · hexagon · arch · rounded-rect | none (clean); big negative space |
| **Streetwear** | oversized star · text · shield · lightning | bold halftone, duotone/mono, high contrast |
| **Vintage** | postage/passport stamp · arch · circle | strong vintage grade, grain, fade, screen-print wear |
| **Retro** | arch · sunset · circle | 60s–90s duotone, heavy halftone |
| **Outdoor** | mountain · badge · compass · shield | earthy grain/fade, muted grade |
| **Premium** | circle · arch · shield (moderate scale) | restrained; occasional mono / subtle vintage |
| **Typography** | text hero (flag fills the letters) | restrained; occasional halftone/mono |

## Adding / tuning a style

Add one `LabStyle` enum value + one `_specs` entry (rotation, orientation
weights, clip-scale range, finish builder). No generator or renderer changes.
`provenance.generator` records `lab:<style>` so favourites/exports stay traceable.

`test/showcase_contact_sheet_test.dart` renders one contact sheet per style when
run with `OUT=<dir>` — the fast way to eyeball a change:

```
OUT=/tmp/lab flutter test test/showcase_contact_sheet_test.dart
```
