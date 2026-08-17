# Topic: Apparel Layouts (Archetypes)

**What it governs:** the recurring chest-print layout families and when to use each.
Maps to `composition.template` + `layoutMode` + `clip.shape`.

## The archetype map

| Archetype | Best for | Strengths | Pitfalls / print size | Roavvy primitive |
|---|---|---|---|---|
| **Centered emblem / badge** | Country + name + motif; heritage | Instantly premium; self-contained gestalt; the workhorse | Generic if overused; interior crowds; medium–large only | `badge` |
| **Stacked type lockup** | Long/wordy names, taglines, coords | Variable-length friendly; strong hierarchy | Boring if timid contrast; alignment critical | `typography` |
| **Arced banner** | Short punchy names; varsity | Energetic; classic; pairs w/ hero icon | Arc failure-prone; breaks long names | `frontRibbon` / `badge` |
| **Circular seal / stamp** | Passport concept; official tone | Very on-brand; ring holds arced text | Densest; dies small; long names won't fit ring | `passport` / `badge` |
| **Left-chest small mark** | Minimal/premium; one icon | Understated, expensive; cheap to print | Must be truly simple; placement consistency | small `typography` / mark |
| **Full-front scene** | Illustrative maps/landscapes | Maximal impact; storytelling | Loses detail at distance/wrinkle; costliest; busy risk | `landmark` |
| **Stamp/badge collage (grid)** | "Places visited" multi-stamp | Repetition-as-concept; many at once | Only works if one shared style; each unit tiny | `grid` + `montage`/`treemap` |
| **Journey / timeline** | Trips over time; routes | Narrative + time; on-brand storytelling | Spaghetti with many points | `timeline` / `journeys` |

## Selection heuristic (procedural)
short name + one motif → seal / arced banner; long name → stacked lockup; single
icon / premium tier → left-chest; multi-country → unified collage grid;
illustrative hero → full-front (sparingly); trips-over-time → journey/timeline.
This is the KB's enrichment of the grammar's "scope → bias" priors.

## Rules
R-COMP-01/02, R-VH-01, R-MERCH-02 (density tiers), R-NEG-02 (size), plus archetype
notes above. Full archetype table also in
`research_summaries/graphic-design-fundamentals.md`.

## Engine implication
The engine already has all these templates. The KB's contribution is the
**selection heuristic** (which archetype fits the data shape and print size) and
the rule that **archetype must fit content** — don't pour 40 countries into a badge
or a lone icon into a full-front. Bias template priors by scope + count; keep
diversity so the presented three span *distinct archetypes*.
