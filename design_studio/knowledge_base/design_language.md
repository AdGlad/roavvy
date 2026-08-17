# The Roavvy Design Language

*The visual identity every Roavvy T-shirt must express. This is the "north star"
that the philosophy, rules, topics and engine recommendations all serve. It is a
development-only reference for the procedural design engine — nothing here ships
as copy.*

---

## 1. One sentence

> **A Roavvy tee turns where you've been into a graphic you'd wear even if it
> weren't personalised — premium, adventurous, and quietly earned, never a
> souvenir-shop print.**

The test for every design: *would a stranger who has never used the app still
think this is a good T-shirt?* If the personalisation is the only thing carrying
it, the design has failed.

---

## 2. The adjectives — and what each one means *concretely*

Brand words are useless until they map to genome decisions. Each adjective below
is bound to observable design traits and to specific genes in
`design_recipe.schema.json`.

| Adjective | What it MEANS visually | Genome expression |
|---|---|---|
| **Adventurous** | Motion, scale, confidence; a graphic that looks like it *went somewhere*. | Bold scale (`imageSize: large`), strong focal element, expressive `printStyle` (edgeTear, sunFaded), earthy/expedition accents. |
| **Premium** | Restraint, breathing room, intentional texture, tight alignment. | `density: sparse\|balanced`, high `whitespace`, limited palette (`duotone`/`monochrome`), clean type. |
| **Timeless** | Reads as well in 10 years as today; avoids trend gimmicks. | Classic layouts (badge, emblem, single hero), muted palettes, halftone/vintage over "effect-of-the-month". |
| **Exploration / Discovery** | Cartographic, expeditionary, "field-notes" feel. | Country outlines, journey lines, coordinates, stamps, region maps; motif kind `landmark`/`symbol`. |
| **Modern** | Current without chasing fads; confident negative space. | Clean type lockups, `strategy: garmentAware`, generous margins, `printStyle: clean\|riso`. |
| **Vintage — where appropriate** | Earned wear, not fake dirt. | `printStyle: vintage\|sunFaded\|halftone`, muted palette; distress that follows the artwork (see `texture.md`). |
| **Everyday-wearable** | Something worn on a normal Tuesday, not just a trip souvenir. | Subtle scale options, left-chest small marks, one-colour options, garment-aware contrast. |

### The anti-identity (equally important)

A Roavvy tee is **NOT**:

- **Cluttered** — many small disconnected flags/icons fighting for attention.
- **Generic** — a stock globe + "ADVENTURE AWAITS" in a free font.
- **Souvenir-shop** — loud full-colour flags, novelty gags, "I ♥ [PLACE]",
  rainbow gradients, drop shadows, bevels.
- **Over-effected** — three distress filters stacked until the artwork is mud.
- **Nationalistic / tacky flag-waving** — flags used as decoration, not identity.

If a candidate drifts toward the right-hand column of that list, the scorer
should push it back. Several rules in `design_rules.md` exist specifically to
patrol this boundary.

---

## 3. The Roavvy visual vocabulary

The recurring "moves" that are on-brand for us. These map directly to templates,
clips and motifs the engine already has.

| Move | Feeling | Engine primitive |
|---|---|---|
| **The hero flag / outline** | Bold, singular, confident | `grid` + `packedRow` sparse, or `countryOutline` clip, single country |
| **The earned montage** | "Look how far I've gone" | `grid` + `montage`/`treemap`, balanced density, many countries |
| **The passport stamp** | Nostalgia, proof, journey | `passport` template, `stampMode: entryExit` |
| **The expedition badge** | Heritage, club, achievement | `badge` template, circular seal, arced type |
| **The field map** | Cartographic discovery | `continentOutline` / region map, journey lines |
| **The tour poster** | Music-tour cool, list-as-graphic | `timeline` / `journeys`, typographic |
| **The quiet mark** | Everyday, understated | left-chest small `typography` lockup |

---

## 4. Palette temperament

Roavvy leans **earthy, expeditionary and muted** rather than bright and
saturated — the palette of weathered maps, national-park signage, worn field
gear and vintage travel posters, not airline logos or flag emoji.

- **Grounds:** off-white/bone, sand, olive, slate, ink navy, charcoal.
- **Accents (sparingly):** ochre/mustard, rust/terracotta, forest, faded teal.
- **Garment-aware:** the shirt colour is a colour in the palette, never ignored.
- **Flag colours are *sampled and tamed*,** not reproduced at full saturation
  (see `flag-usage.md` and `colour.md`).

The engine expresses this through `palette.strategy` (`duotone`, `monochrome`,
`garmentAware`) and accent discipline — not by literal flag reproduction.

---

## 5. How this language is enforced

This document is aspirational; the enforcement lives in:

- **`design_philosophy.md`** — the creative foundation ("What makes a Roavvy
  T-shirt") the whole engine serves.
- **`design_rules.md` / `design_rules.json`** — the testable rules, each bound to
  genes and scorers.
- **`topics/`** — the deep reference per discipline.
- **`engine_recommendations.md`** — how the language becomes generation priors,
  scorer weights, and an optimisation objective.

> Keep this file short. When the language and a specific rule disagree, the rule
> wins (it is testable); update the language to match reality.
