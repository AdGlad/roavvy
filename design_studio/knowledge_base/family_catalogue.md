# Roavvy Design Family Catalogue

*The canonical registry of every approved procedural design family/technique, across
all axes. The Creative Director keeps this current: a concept enters via the
[concept discovery roadmap](../reports/concept_discovery_roadmap.md), is validated
in the Studio, and — if it significantly improves the catalogue — is promoted here.
Development-only.*

**Axes multiply.** A finished design = **composition family × print style × palette
× (optional) torn treatment**, realised on a **template + mask + layout**. Growth
on any axis expands the whole catalogue combinatorially, so new *treatment* axes
(print styles, flag treatments) are as valuable as new *composition* families.

Legend: ✅ live · 🧪 in validation · ⛔ retired · 🔭 candidate (see roadmap).

---

## 1. Composition families (`composition_family.dart`)
The relationship/hierarchy backbone. 9 live + 1 in validation; 1 retired.

| Family | Hierarchy | Count range | Best scope | Status |
|---|---|---|---|---|
| singleHero | singleFocal | 1–2 | singleCountry, trip | ✅ |
| dominantAccent | dominantAccent | 2–10 | multiCountry, trip | ✅ |
| repetitionField | uniform | 4–240 | lifetime, multiCountry | ✅ |
| negativeSpaceCutout | singleFocal (mask hero) | 1–80 | region, singleCountry | ✅ |
| typographicIntegration | typeLed | 1–240 | lifetime, year | ✅ |
| chronoSequence | sequence | 2–120 | year, lifetime | ✅ |
| splitField | dualZone | 2–30 | multiCountry, trip | ✅ |
| duoBlend | dualZone (2-flag blend) | 2 only | multiCountry, trip | ✅ |
| **statementCount** | typeLed (count-as-hero) | 5–300 | lifetime, region | ✅ C-01 — production-ready: on-device renders a bold "28 / COUNTRIES" hero (statementHero gene → _drawStatementHero); pixel-verified 2026-08-17 |
| radialEmblem | radial | 1–24 | — | ⛔ retired (product preference) |

## 2. Torn / distress treatments (`torn_recipe.dart`, family `Torn`)
Reference-quality edge geometry. All optimised in run 2026-08-16 (avg 0.9015→0.9455).

`lightlyWorn` · `ragged` · `tornCorners` · `battleWorn` · `deepRips` · `frayed` ·
`asymmetricTear` · `heavyEdgeDamage` — all ✅. (Composite 2-flag torn supported.)

## 3. Print styles (`print_style/`, applied post-render)
`clean` · `vintage` · `retro` · `halftone` · `stamp` · `grunge` · `riso` ·
`newsprint` · `sunFaded` · `photocopy` · `edgeTear` · `acidWash` — all ✅.
(The texture/era axis; the strongest carrier of Roavvy identity — process-emulated,
not filter-stamped: KB R-TREND-02, R-TEX-01.)

## 4. Renderable primitives (the building blocks families recombine)
- **Templates** (`CardTemplateType`): grid, passport, timeline, frontRibbon,
  typography, badge, wordCloud, landmark, journeys.
- **Masks/clips** (`GridClipShape`): none, heart, circle, countryOutline,
  continentOutline, animalSilhouette, plantSilhouette, landmarkSilhouette.
- **Layout modes** (`FlagGridLayoutMode`): packedRow, normalizedGrid, treemap,
  montage.
- **Palette strategies** (recipe): flagDerived, brand, garmentAware, duotone,
  monochrome.

## 5. Catalogue health (diversity guardrail)
The set must **span** one-country → massive without any family collapsing into
clutter, and must not converge on one look. Current coverage by count:
- **solo/small (1–2):** singleHero, negativeSpaceCutout, (radialEmblem retired).
- **small-multi (2–10):** dominantAccent, splitField, duoBlend, chronoSequence.
- **large/massive (16+):** repetitionField, typographicIntegration, chronoSequence,
  **statementCount (new — the premium count-forward option this tier lacked).**

**Known thin spots (→ roadmap):** the coordinate/expedition-log typographic look and
a clean cartographic outline-as-frame are only partially covered; new *print/flag
treatments* are the highest-leverage catalogue multipliers.

**Deferred (validated but not promoted):** *Passport-Stamp Collection* (C-02) —
commercially strong and on-brand, but rejected for now because the analytic scorer
can't render stamps to judge it fairly; blocked on the C-00 rendered-evidence
evaluation path. See `concepts/C-02-stamp-collection.md`.

---
*Update rule:* promote a concept here only after Studio validation shows it
**significantly improves the catalogue** (commercial appeal + originality + Roavvy
identity) **without reducing diversity**. Link its validation experiment + catalogue
concept doc. Never delete a retired family's row — mark it ⛔ with the reason.
