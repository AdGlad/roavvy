# Topic: Colour

**What it governs:** the palette — the single strongest premium-vs-souvenir signal.
In genome terms: `palette.garmentColour`, `palette.strategy`, `palette.accents`
(currently mostly derived inside card widgets; `paletteEngine` flag is **off** —
this is one of the biggest unlocks).

## Principles
- **Limit to 2–4 colours including the garment** (hard cap 6). Rooted in the
  screen-print heritage: few flat inks = real garment print. (R-COL-01)
- **The garment colour is an active ink** — design with it, let it show through
  knockouts and negative space (garment-as-paper/shadow). (R-COL-02)
- **Luminance contrast carries legibility, not hue** — light shirts want dark art,
  dark shirts light; mid-on-mid vanishes. (R-COL-03; also the printability gate's
  ΔL ≥ 0.30)
- **Default to tonal/duotone/monochrome;** reserve full colour for concepts that
  need it. (R-COL-04)
- **One disciplined accent, small area, single job** — scarcity is what makes an
  accent work. (R-COL-05)
- **Commit to one temperature story** (warm sunbaked / cool alpine-nautical).
  (R-COL-06)
- **Muted, era-coded, derived palettes** — sample and tame source/flag colours;
  default to desaturated earths. **Off-white over pure white, warm near-black over
  pure black.** (R-COL-07, R-COL-08)

## Rules in this topic
R-COL-01 … R-COL-08 (interacts strongly with `flag-usage.md` R-FLAG-01 and
`texture.md`/`print-techniques.md`).

## Scorers
`colorHarmony` (palette relationships, clashing-flag detection),
`contrastLegibility` + `printabilityGate` (value contrast vs garment).

## Engine implication
**Turning on `paletteEngine` is the highest-leverage premium unlock** after
typography. Seed `palette.strategy` priors toward `duotone`/`monochrome`/
`garmentAware`, cap `accents` at 1–2, and encode the earthy/muted temperament of
the Design Language. Calibrate `colorHarmony` so it rewards muted, coherent-
temperature palettes and penalises full-saturation multi-flag clashes — validate
against liked vs disliked reference `dominantColors`. See
`engine_recommendations.md` §2.
