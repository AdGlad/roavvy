# Topic: Flag Usage

**What it governs:** how national flags appear — the highest-reward and highest-risk
travel-merch element (garish clashes, kitsch, and geopolitical sensitivity all live
here). Maps to `content.countryCodes`, `palette.strategy`, `clip.shape`,
`layoutMode`.

## Principles — tasteful vs tacky
- **Mute/unify flags; never combine several at full literal saturation** — flags
  are engineered for maximal individual contrast and clash violently en masse.
  Render as one ink, duotone, or a tamed shared palette so form carries them.
  (R-FLAG-01)
- **Contain flags (flag-in-outline); never stretch a flag to a rectangle shirt
  front** — the stretched rectangle is the souvenir-stand read. (R-FLAG-02)
- **In flag grids, enforce ruthless uniformity and normalise aspect ratios** —
  flags vary wildly (Nepal, Switzerland, Qatar); tokenise into identical tiles/
  roundels with equal gutters. (R-FLAG-03)
- **Personal-journey framing; nationalism-neutral by default** — "places I've
  been," not "conquered/ranked." (R-FLAG-04)
- **Handle disputed/sensitive flags & borders in the data layer** — neutral outline
  fallbacks, careful adjacency, user curation. A floor, not a preference. (R-FLAG-05)

## The torn-flag exemplar (studio reference)
The liked `torn-flag-tshirts` reference (single flag IS the whole graphic, ragged
edges, distressed, bold centred, sparse) scores `focalConcentration` 0.85 — a clean
demonstration of R-FLAG-01 (single hero), R-VH-01, R-TEX-01, R-NEG-01. Achievable
via `edgeTear` + distress on a single-country grid (`recipes/torn_flag_usa`).

## Rules in this topic
R-FLAG-01 … R-FLAG-05 (with R-COL-01/07, R-STORY-02/04).

## Scorers
`colorHarmony` (clashing-flag detection — the key signal), `aspectFit` (contained,
non-stretched), `coverageBalance` (grid uniformity), `profileFit` (framing),
`printabilityGate` (R-FLAG-05 sensitivity fallbacks).

## Engine implication
Two concrete asks: (1) a `colorHarmony` term that specifically penalises
multi-flag full-saturation clashes and rewards a monochrome/duotone treatment
across a set; (2) a **data-layer sensitivity map** (disputed regions → neutral
outline fallback, adjacency rules) treated as a **hard gate** — a blind generator
will otherwise eventually emit something harmful. See `engine_recommendations.md`
§3a and R-FLAG-05.
