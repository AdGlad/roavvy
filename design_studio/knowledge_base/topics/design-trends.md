# Topic: Design Trends

**What it governs:** which aesthetic movements to adopt, as durable *grammars*
rather than churning *slogans* — and how to stay timeless.

## Principles
- **One coherent aesthetic world per design; no mashups.** Bundle palette + type +
  texture + container as **locked style presets.** Coherence is the master signal
  of art direction. (R-TREND-01)
- **Emulate a physical process (timeless), not a software filter (dated).** Limited
  palette + halftone + real wear ages well; bevel/gloss/chrome/lens-flare/uniform-
  grunge date fast. (R-TREND-02)
- **Default to vintage and minimalism** (the two safest long-term bets); adopt
  gorpcore/streetwear as grammars not slogans; keep maximalism/Y2K hero-only.
  (R-TREND-03)
- **Avoid oversaturated generic tropes** — wanderlust script, bare dotted world map,
  airplane+arc, compass clip-art. They fail precisely where Roavvy's moat should
  win. (R-TREND-04)

## Timeless vs fad (quick reference)
Timeless: vintage/retro, minimalism, heritage/badge, cartographic/coordinate,
personalisation (a meta-trend, Roavvy's edge). Medium: gorpcore, streetwear
(grammar yes, memes no). Fad/hero-only: maximalism, Y2K/chrome. Dead: "wanderlust"
script + generic map. Full table in `research_summaries/trends-and-marketplaces.md`.

## Rules in this topic
R-TREND-01 … R-TREND-04 (with R-COL-06/07, R-TEX-*, R-TYPE-05).

## Scorers
`colorHarmony` + `aiCritic` (coherence/mashup detection), `profileFit` (trope
avoidance). Coherence is hard to score analytically — it's the clearest job for the
AI critic prompted with the locked style preset.

## Engine implication
**Locked style presets are the recommended unit of generation** (R-TREND-01): each
bundles a palette strategy, type pairing, texture level, and container so coherence
is *structural*, not hoped-for. Era-stamped effects live only behind explicit
retro/Y2K flags. Default the population toward vintage/minimal presets; expose the
rest as intentional capsules. See `engine_recommendations.md` §1.
