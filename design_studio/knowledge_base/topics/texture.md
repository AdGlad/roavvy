# Topic: Texture & Distress

**What it governs:** the surface treatment that makes a print read as earned wear
rather than a filter. Applied by the `PrintStylePipeline` (12 styles incl.
vintage/sunFaded/grunge/halftone/edgeTear/acidWash), recorded as `printStyle.id`.
See also the project's existing Print Styles system (`docs/design/print-styles-*`).

## Principles (the fake-vs-real vintage line)
- **Distress must follow the artwork and real wear zones** — heavier on bold fills,
  edges, folds; oriented along shapes. A uniform semi-transparent noise overlay is
  design-blind: the fake-vintage tell. (R-TEX-01)
- **Distress is subtractive** — it *removes* ink so the garment shows through; it is
  not dark speckle added on top (which reads as dirt, wrong colour on dark shirts).
  (R-TEX-02)
- **Keep it subtle (erode ~5–20%, never >25%)** — over-distress flips to the dated
  2010s sandblasted look. (R-TEX-03)
- **Drive all effect layers from one shared, seeded noise field** so cracks, fade
  and mottle coincide as one aged surface. (R-TEX-04)
- **A whisper of ink mottle (3–8%)** in flat fills makes ink read as physical, not
  a vector sticker. (R-TEX-05)

## Rules in this topic
R-TEX-01 … R-TEX-05 (tightly coupled to `print-techniques.md` halftone rules and
R-TREND-02 process-not-filter).

## Scorers
`edgeDensity` (busy-vs-clean, over-distress detection). Authenticity of distress is
otherwise a candidate for the AI critic / `referenceAffinity` against the liked
"torn/vintage" references.

## Engine implication
The pipeline already implements design-aware, subtractive, fBm-driven distress
(shipped styles M-A…M-E per `project_print_styles`). The KB's job is **discipline**:
a distress-intensity cap (R-TEX-03), a "≤N stacked effects" gate to prevent mud,
and biasing `printStyle.id` toward process-emulating styles by default while gating
era-stamped effects behind explicit retro flags (R-TREND-02). Rasterize at true
print DPI (R-PRINT-03) — the studio's most common failure mode.
