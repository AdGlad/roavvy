# Mood Boards — Roavvy's Aesthetic Worlds

A mood board here is not a loose inspiration collage — it is a **locked style
preset** (R-TREND-01): a bundle of palette + typography + texture + layout that is
coherent *by construction*. These are the recommended **unit of procedural
generation** — the engine should seed a population from these worlds and vary
*within* one, never blend across them (mashups are the #1 art-direction failure).

Each board lists: the feeling, a swatch palette (hex), type direction, texture/
print-style, layout archetype, garment pairing, the studio reference images it
draws on, the target genome, the rules it embodies, and what to avoid.

> Swatches are development-only palette *directions*, not final brand tokens.
> Images referenced live in `../../reference_images/` and are dev-only, rights not
> cleared — never bundle them.

## The five core worlds

| Board | One-word feel | Default garment | Best scope |
|---|---|---|---|
| [heritage-badge](heritage-badge.md) | Earned | Sand / bone | singleCountry, region, achievement |
| [vintage-poster](vintage-poster.md) | Nostalgic | Cream / slate | trip, singleCountry, landmark |
| [torn-flag-hero](torn-flag-hero.md) | Bold | Black / white | singleCountry |
| [modern-minimal-line](modern-minimal-line.md) | Quiet | White / navy | singleCountry, everyday |
| [passport-stamp](passport-stamp.md) | Collected | Bone / navy | lifetime, year, multiCountry |

## How a board maps to the engine
Each board resolves to a set of **generation priors**: a `palette.strategy` +
accent set, a `typography.titleStyle` family, a default `printStyle.id`, and a
biased `composition.template`/`layoutMode`. The scorer then judges candidates
*within* the world; the AI critic (when on) is prompted with the board so cloud
taste and local heuristics agree. See `../engine_recommendations.md` §1.

## Gaps to fill (studio TODO, not implementation)
- **Disliked bucket is empty** — add counter-examples (souvenir-shop tat, full-
  saturation flag clashes, uniform-grunge fakes) so `referenceAffinity` has a
  negative anchor. See `../reference_collections.md`.
- Each world needs 3–5 *own-render* exemplars (rights-clean) once the engine can
  produce them, replacing third-party reference images.
