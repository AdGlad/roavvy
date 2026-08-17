# Research Summary — Print Production, DTG & Premium Texture

*Stream 3 of 4. Screen-print vs DTG realities, halftones, distress, and the
effects that read premium vs cheap. Informs rules R-PRINT-*, R-TEX-*, R-COL-02/08,
R-TREND-02, and `topics/print-techniques.md` + `topics/texture.md`.*

## The core mental model
Two things decide premium-vs-cheap on a printed tee:
1. **Does the ink sit on the fabric like real ink, or like a photo of ink?** Real
   garment ink = limited opaque spot colours, slight registration imperfection,
   halftone texture where it fades, fabric weave showing through. A flat digital
   gradient with millions of colours reads "printed by a machine."
2. **Does the distress belong to the artwork, or was it sprinkled on top?**
   Premium vintage looks like ink that *wore off a real shirt* (thinner on
   high-wear zones, following shapes). Cheap vintage looks like a grunge.png
   multiplied over everything.

**Roavvy's specific gap:** you generate *for* DTG (cheap full-colour photographic
detail) but the aesthetic that reads premium is *screen-print* (limited spot
colours + halftones). The game is to **emulate the screen-print look in software,
then print it on DTG.** Most rules below live in that gap.

## Rules (condensed; full set in `design_rules.md`)
- **Limited spot palette (2–6)** even though DTG allows unlimited — the strongest
  premium signal. → R-COL-01.
- **Emulate fades with halftones, never smooth gradients;** **35–65 LPI, rotated
  angle (15/45/75°, never 0/90°);** scale LPI to print size. → R-PRINT-01/02.
- **Min line ≥~1.5 pt; min text ~6–7 pt; knockout ≥8 pt.** DTG ink spreads;
  hairlines break, counters fill, small type mushes. → R-PRINT-04.
- **Distress follows the artwork & real wear zones,** is **subtractive** (reveals
  garment, not dark speckle on top), **subtle (5–20%, never >25%),** and driven by
  **one shared coherent noise field.** → R-TEX-01/02/03/04.
- **Add subtle ink mottle (3–8%)** to flat fills so ink looks physical. → R-TEX-05.
- **Rasterize effects at true print DPI** (the #1 pipeline failure is grain tuned
  on a small preview then upscaled to mud). **Export 300 DPI transparent PNG,
  clean alpha edge.** → R-PRINT-03/07.
- **Design for the garment colour;** prefer **off-white over pure white, warm
  near-black over pure black** (dark-garment underbase halo). → R-COL-02/08.
- **Break large solid fills; avoid full-bleed on DTG.** **Trap/slightly overlap
  adjacent colours.** → R-PRINT-05/06.
- **Emulate a physical process (timeless), not a software filter (dated).** →
  R-TREND-02.

## Effects that improve vs reduce quality

| Improves | Reduces |
|---|---|
| Limited spot palette (2–6) | Smooth photographic gradients |
| Coarse rotated halftone fades | Uniform full-canvas grunge overlay |
| Off-white / warm near-black inks | Over-distress (>25% ink loss) |
| Subtle ink mottle in fills | Additive dark "dirt" speckle on dark shirts |
| Design-aware subtractive distress (5–20%) | Bevel/emboss, drop shadow, chrome, lens flare |
| Trapping / slight colour overlap | Pure #FFF/#000 large flats |
| One coherent shared noise field | Huge full-bleed solids on DTG |
| Effects rasterized at true print DPI | Hairlines & small knockout text |
| — | Halftone too fine (>85 LPI) at small size |

## POD / DTG technical checklist (Printful-oriented)
- Export **300 DPI at physical size** (150 floor); **transparent PNG-24 + alpha**,
  no white box, no baked mockup; **rasterize effects at final print px**; clean the
  alpha edge (no 1px halo).
- **Line ≥~1.5 pt; positive text ≥~6–7 pt; knockout ≥8 pt;** convert fine detail to
  printable halftone/stipple.
- **Safe margin ~0.25–0.5″;** avoid full-bleed; account for seams/collars.
- **Design as 2–6 spot colours** (RGB working space); off-white>white,
  warm-black>black; **tonal contrast vs the actual garment;** break large fills;
  allow for dot gain + trapping.
- **Dark garments:** white underbase enlarges/haloes light inks — avoid ultra-thin
  light detail; soften pure white to off-white.

## Dated vs timeless
**Timeless (process-rooted):** limited spot palettes; coarse rotated halftones;
heritage/badge vocabulary; subtle ink mottle + design-aware distress; cream/warm-
black tones; bold simple flats with negative space; single-ink tonal designs.
**Dated (software-filter markers):** bevel & emboss; glossy Web-2.0 gradients;
chrome/metallic type; hard 1px drop shadows; lens flares/sparkles; uniform grunge
overlay; sandblasted over-distress; smooth airbrush gradients; rainbow blends;
outer-glow neon on black. *Principle: emulating a physical process ages well;
emulating a software filter ages badly.*
