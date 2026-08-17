# Roavvy Design Rules

The testable rulebook. Every rule is derived from the four research streams
(`research_summaries/`) and the studio's own reference analysis, deduplicated and
bound to the design genome (`design_recipe.schema.json`) and the scoring engine.

**How to read a rule:** each has a stable **id**, a one-line **statement**, the
**why** (mechanism), a **confidence**, the **genes** it biases, the **scorers**
that encode it, when it **applies**, and its **exceptions**. The machine-readable
mirror is `design_rules.json` (validated by `design_rule.schema.json`); when the
two disagree, fix the JSON to match this file.

**Confidence:** High = near-universal across all four research streams + heritage
tradition. Medium-High = strong but segment/context-dependent. Medium = plausible,
validate against references + telemetry.

> **The one-line summary of the whole book:** *One hero, few muted colours,
> generous space, real personal data, one coherent style, process-emulated
> texture — and never touch the printability gate.*

---

## A. Composition & Visual Hierarchy

### R-VH-01 — One dominant hero element. **(High)**
Build every design around a single hero (one flag, one outline, one seal, one
count); demote everything else to support.
*Why:* the eye needs one entry point; equal-weight elements read as "a pile of
assets," not a design, and small parts dissolve at across-the-room distance.
*Genes:* `composition.template`, `composition.density` (favour sparse/balanced),
`clip.shape`. *Scorers:* `focalHierarchy`.
*Applies:* all designs, **especially** multi-country sets (highest clutter risk).
*Exceptions:* deliberate uniform grid/collage where repetition **is** the concept
(then enforce R-FLAG-03).

### R-VH-02 — Three-tier hierarchy: hero / support / detail. **(High)**
Assign every element to exactly one of three tiers with big scale jumps between.
*Why:* hierarchy = deliberate difference; near-equal sizes read as undesigned.
*Genes:* `typography.*`, `composition.imageSize`. *Scorers:* `focalHierarchy`.
*Applies:* any multi-element lockup. *Exceptions:* single-icon left-chest marks.

### R-VH-03 — Decisive scale contrast (≈1.6–2×+), not timid steps. **(High)**
When two elements differ in importance, make them differ a lot in size.
*Why:* small differences read as mistakes; large ones read as confidence; weak
contrast collapses to mush at distance. *Scorers:* `focalHierarchy`, `edgeDensity`.
*Exceptions:* refined monoline "quiet luxury" marks use low contrast on purpose.

### R-COMP-01 — Bind parts with Gestalt so they read as one object. **(High)**
Use proximity, alignment, a shared shape or an enclosing frame.
*Why:* the brain chunks tight, aligned clusters into one "logo"; floating
fragments look like clip-art dropped on a shirt. *Genes:* `clip.shape`,
`composition.template` (badge/frame). *Scorers:* `coverageBalance`.
*Exceptions:* skilled asymmetric editorial layouts (risky procedurally).

### R-COMP-02 — Anchor to a containing geometry + an alignment grid. **(High)**
Resolve the design into a defined outer shape (circle, shield, banner, stacked
block, route grid) with everything on shared axes.
*Why:* a container signals intentional boundaries and gives the generator a
layout skeleton; misalignment is the subconscious tell of cheap work.
*Genes:* `composition.template`, `composition.layoutMode`. *Scorers:*
`coverageBalance`, `aspectFit`. *Exceptions:* full-bleed editorial, still grid-governed.

### R-COMP-03 — Win at 200px: optimise the thumbnail / across-the-room read. **(High)**
One readable idea, strong silhouette, high figure/ground contrast.
*Why:* marketplace purchase starts at a tiny thumbnail and the chest print is
first seen across a room; fine detail dies in both. *Scorers:* `contrastLegibility`,
`focalHierarchy`, `edgeDensity`. *Exceptions:* detail-reward pieces sold via
lifestyle photography.

### R-COMP-04 — Compose personalised data, never just insert it. **(High)**
Templates must reflow/rebalance so a 3-country trip and a 40-country trip each
look deliberately laid out — not one template with a longer overflowing list.
*Why:* the core failure of generative merch is the "Mad-Libs / auto-filled"
smell. *Genes:* `composition.density`, `composition.rowCount`,
`composition.layoutMode`. *Scorers:* `coverageBalance`, `profileFit`.
*Applies:* every personalised output. *Exceptions:* fixed-count product lines.

---

## B. Negative Space & Print Sizing

### R-NEG-01 — Protect generous negative space. **(High)**
Leave clear margin around and within the design; don't fill the shirt.
*Why:* empty space signals confidence and isolates the hero; edge-to-edge
crowding is the fear-of-empty-space amateur tell and implies "quantity to justify
price." *Genes:* `composition.density` (penalise `dense` at low counts),
`composition.imageSize`. *Scorers:* `whitespace`. *Exceptions:* committed
maximalist all-over prints (even-rhythm, deliberate).

### R-NEG-02 — Contain the print; standard chest print is smaller than people think. **(High)**
Target ~25–30 cm wide, high-to-mid centre; left-chest marks ~7–10 cm.
*Why:* oversized prints crowd neckline/armholes, distort on the body curve, and
read fast-fashion. *Genes:* `composition.imageSize`, `composition.orientation`.
*Scorers:* `aspectFit`. *Exceptions:* deliberate oversized streetwear drops.

---

## C. Colour

### R-COL-01 — Limit the palette to 2–4 colours (garment included; ≤6 hard cap). **(High)**
*Why:* limited palettes read as intentional/premium and derive from the physical
screen-print heritage ("few flat inks = real garment print"); every extra colour
risks a clash. *Genes:* `palette.strategy`, `palette.accents` (`maxItems`).
*Scorers:* `colorHarmony`. *Exceptions:* genuine full-colour illustration/AOP —
still governed by one palette.

### R-COL-02 — The garment colour is an active ink. **(High)**
Design with the shirt colour; let it show through knockouts and negative space.
*Why:* on apparel the "background" is never neutral — it mixes with every colour;
using it (garment as "paper"/shadow tone) is the premium screen-print move.
*Genes:* `palette.garmentColour`, `palette.strategy` (`garmentAware`). *Scorers:*
`contrastLegibility`, `colorHarmony`. *Exceptions:* none.

### R-COL-03 — Guarantee luminance (figure/ground) contrast vs the garment. **(High)**
Never rely on hue alone; light shirts want dark-anchored art, dark shirts light.
*Why:* distance legibility and colour-blind/low-light viewing depend on value,
not hue; mid-on-mid vanishes. *Genes:* `palette.*`, `composition`. *Scorers:*
`contrastLegibility`, **`printabilityGate`** (already gates ΔL ≥ 0.30).
*Exceptions:* intentional tone-on-tone niche (sacrifices distance legibility).

### R-COL-04 — Prefer tonal / duotone / monochrome by default. **(Medium-High)**
Reserve full colour for concepts that truly need it.
*Why:* restraint reads editorial and confident; duotone unifies disparate
elements (flag + map + type) under one mood and hides print banding.
*Genes:* `palette.strategy` (`duotone`/`monochrome`). *Scorers:* `colorHarmony`.
*Exceptions:* single-flag hero where accurate colours are the point (still mute
the surround).

### R-COL-05 — One disciplined accent, small area, single job. **(High)**
*Why:* an accent works because it's rare — it directs the eye to the one thing
that matters; spread everywhere it accents nothing and turns garish.
*Genes:* `palette.accents` (≤2, ideally 1). *Scorers:* `colorHarmony`.
*Exceptions:* pop-art/retro concepts where saturated colour is the theme.

### R-COL-06 — Commit to one temperature story. **(Medium-High)**
Warm sunbaked (sand/terracotta/olive) or cool alpine-nautical (navy/ice/green),
plus at most one contrasting note.
*Why:* temperature is read emotionally before content; random warm+cool mixing
reads as "colours from the default swatch." *Scorers:* `colorHarmony`.
*Exceptions:* a single deliberate complementary accent for energy.

### R-COL-07 — Muted, era-coded, derived palettes — not literal saturation. **(High)**
Sample and tame source colours (esp. flags); default to desaturated earths.
*Why:* muted/faded reads as sun-aged/authentic and premium; full-spectrum RGB
freedom reads as digital default. *Genes:* `palette.strategy`, `palette.accents`.
*Scorers:* `colorHarmony`. *Exceptions:* flag-accurate small elements, surround
stays muted.

### R-COL-08 — Off-white over pure #FFF; warm near-black over pure #000. **(Medium-High)**
*Why:* pure white/black inks look flat, harsh and digital on fabric and maximise
the dark-garment underbase halo; cream/bone/warm-black read expensive and
"aged correctly." *Genes:* `palette.accents`. *Scorers:* `colorHarmony`,
`printabilityGate`. *Exceptions:* stark modern/streetwear may want pure white.

---

## D. Typography

### R-TYPE-01 — Max two typefaces (a third only for a distinct technical role). **(High)**
One display + one support; never two loud display faces or two similar sans.
*Why:* each face is a voice; too many = noise and amateurism. *Genes:*
`typography.titleStyle`. *Exceptions:* a real 3-role system (display/support/mono).

### R-TYPE-02 — Track all-caps & small type; kern hero display by eye. **(High)**
*Why:* tight caps jam and hurt readability; open tracking reads engraved/premium;
big display words show ugly default gaps that need tightening; even letter rhythm
is a hallmark of pro type. *Scorers:* `contrastLegibility`. *Exceptions:* never
track scripts (breaks joins).

### R-TYPE-03 — Match case to intent. **(Medium-High)**
All-caps for badges/banners/official; mixed case or script for warmth/narrative.
*Why:* caps form stable blocks that fill rings/banners and read "heritage"; mixed
case is friendlier/editorial. *Genes:* `typography.case`. *Exceptions:* long
all-caps passages (kills readability).

### R-TYPE-04 — Clean arcs: consistent radius, symmetric top/bottom, even spacing. **(High)**
*Why:* arced type is the emblem signature and where amateurs fail (wobble,
mismatched radii); a clean arc reads as a crafted seal. *Genes:* `typography`,
`composition.template` (badge). *Exceptions:* straight stacked lockups — don't
arc for its own sake.

### R-TYPE-05 — Treat type as a designed, era-coded system. **(High)**
Condensed grotesque = expedition/utilitarian; slab = rugged heritage; ornate
serif = grand-tour; mono = technical/coordinate. Pair by contrast of role,
harmony of feel.
*Why:* type carries half the storytelling; a coherent pairing does the era work.
*Genes:* `typography.titleStyle`. *Exceptions:* icon-only designs may drop type.

### R-TYPE-06 — No default system fonts; never render garbled/pseudo text. **(High)**
*Why:* default fonts and broken letterforms are the #1 "cheap/AI" tell. The
printed string is generated downstream (TitleGen) and is **not** part of the
reproducible genome — only the treatment is; validate it renders cleanly.
*Genes:* `typography.titleStyle`. *Exceptions:* none.

### R-TYPE-07 — Solve contrast with colour/value, not outline+shadow+bevel. **(High)**
*Why:* stacked type effects are the clip-art/2000s tell; they cheapen premium art.
*Scorers:* `contrastLegibility`. *Exceptions:* knowing retro/Y2K themes only.

---

## E. Texture, Distress & Print Technique

### R-TEX-01 — Distress must follow the artwork and real wear zones. **(High)**
Heavier on bold fills, edges, fold/high-wear points; oriented along shapes.
*Why:* genuine wear is spatially correlated with the design; a uniform semi-
transparent noise overlay is design-blind — the fake-vintage tell. *Genes:*
`printStyle.id` (vintage/sunFaded/grunge/edgeTear). *Scorers:* `edgeDensity`.
*Applies:* all vintage/washed styles. *Exceptions:* a very subtle uniform paper
grain over the whole print is acceptable (see R-TEX-05).

### R-TEX-02 — Distress by removing ink (reveal garment), not adding dark speckle. **(High)**
*Why:* real fade/cracks are the **absence** of ink — gaps show shirt colour;
additive dark noise reads as dirt/grime and the "cracks" are the wrong colour on
dark garments. *Genes:* `printStyle.id`. *Exceptions:* additive low-opacity paper
grain/mottle only.

### R-TEX-03 — Keep distress subtle (erode ~5–20%), never over-distress. **(Medium-High)**
*Why:* beyond ~25% it reads as damaged/costume-y and flips to the dated 2010s
fast-fashion "sandblasted" look; restraint signals premium. *Genes:* a distress-
intensity parameter (forthcoming). *Scorers:* `edgeDensity`. *Exceptions:*
deliberate punk/metal thrash niche.

### R-TEX-04 — Drive all effects from one shared, seeded noise field. **(Medium)**
*Why:* uncorrelated random layers read as "noise soup"; real wear is spatially
coherent (cracks, fade, mottle relate to one surface). Matches the determinism
model (named seed sub-streams). *Genes:* `seed`. *Exceptions:* fine additive
paper grain may be independent.

### R-TEX-05 — Add a whisper of ink mottle/fibre texture to flat fills. **(Medium)**
*Why:* real ink on cotton is never perfectly uniform; a 3–8% mottle makes fills
read as physical print, not a vector sticker. *Genes:* `printStyle.id`.
*Exceptions:* ultra-clean modern minimal may want true flat.

### R-PRINT-01 — Emulate fades with halftones, never smooth digital gradients. **(High)**
*Why:* the halftone dot is the visual fingerprint of real screen-print; a smooth
gradient reads digital and bands/halos on DTG dark garments. *Genes:*
`printStyle.id` (halftone). *Exceptions:* elements too small to hold dots →
posterize to flat steps.

### R-PRINT-02 — Halftone 35–65 LPI, rotated screen angle (15°/45°/75°, never 0/90°). **(High)**
*Why:* coarse dots read as intentional retro texture and hold ink; axis-aligned
grids read mechanical and moiré against the weave; scale LPI to print size.
*Genes:* `printStyle.id`. *Exceptions:* deliberate op-art axis-aligned grids.

### R-PRINT-03 — Rasterize effects at true print DPI; smallest feature ≥ printable. **(High)**
*Why:* the #1 procedural-pipeline failure is grain tuned on a small preview then
upscaled — highlight dots/pinholes fall below what fabric holds and clog to mud.
Generate at final print pixel size (~300 DPI). *Scorers:* `printabilityGate`.
*Exceptions:* none; only the numbers change with size.

### R-PRINT-04 — Respect reproduction limits: min line ≥~1.5pt, text ≥~6–7pt, knockout ≥8pt. **(High)**
*Why:* DTG ink spreads into the weave; hairlines break up, tiny knockout counters
fill in, small type mushes; the dark-garment underbase haloes thin light detail.
*Scorers:* **`printabilityGate`** (already gates `minFeaturePx: 90`).
*Exceptions:* light-on-light tolerates slightly finer; still not hairlines.

### R-PRINT-05 — Break large solid fills; avoid full-bleed on DTG. **(Medium-High)**
*Why:* big flats (esp. light-on-dark) show wrinkles, print-head banding and edge
halo and read as a cheap decal panel; a subtle halftone/mottle hides it.
*Genes:* `printStyle.id`, `composition`. *Exceptions:* screen-print tolerates
large solids; small solids fine.

### R-PRINT-06 — Trap / slightly overlap adjacent colours. **(Medium-High)**
*Why:* emulates real multi-screen registration and prevents garment-colour
slivers between abutting shapes after DTG spread. *Exceptions:* single-colour art
needs none.

### R-PRINT-07 — Export 300 DPI transparent PNG at physical size, clean alpha edge. **(High)**
*Why:* a white background prints as a white rectangle; a 1px semi-transparent halo
prints as a grey underbase fringe on dark shirts. *Scorers:* `printabilityGate`.
*Exceptions:* none. (This is downstream of the genome but a hard studio rule.)

---

## F. Icon & Motif Usage

### R-ICON-01 — All icons share one style, stroke weight, corner radius, detail level. **(High)**
*Why:* a mismatched icon (thin-line compass beside a heavy solid mountain)
destroys the single-author gestalt. *Genes:* `motifs[].kind/slug`. *Scorers:*
`edgeDensity`. *Exceptions:* one deliberate solid hero icon amid line details.

### R-ICON-02 — One strong icon beats an illustration crowd. **(High)**
*Why:* simple silhouettes survive distance, wrinkle and small print and print
clean in one colour; detailed scenes lose detail exactly where apparel is viewed.
*Genes:* `motifs` (cap count), `clip.shape`. *Scorers:* `focalHierarchy`.
*Exceptions:* chosen full-front narrative scene.

### R-ICON-03 — Flat, simplified shapes; no photorealism, bevels or gloss. **(High)**
*Why:* simplification is editorial judgement (the labour amateurs skip); flat
reduced forms read as authored illustration, photoreal/bevel read as template.
*Genes:* `motifs`, `printStyle.id`. *Exceptions:* halftone/duotone photo
treatments (they convert a photo into a graphic).

### R-ICON-04 — Country/landmark silhouettes must be recognizable and geographically accurate. **(High)**
Simplify coastline noise but keep identifying features; test at thumbnail size.
*Why:* recognition ("that's MY country") is the emotional payload; a distorted or
wrong outline breaks the identity signal and trust. *Genes:* `clip.shape`
(`countryOutline`), `clip.code`. *Scorers:* `profileFit`. *Exceptions:* heavy
stylisation only if a name/flag restores recognition.

---

## G. Flag Usage

### R-FLAG-01 — Mute/unify flags; never combine several at full literal saturation. **(High)**
*Why:* flags are engineered for maximal individual contrast; en masse they clash
violently. Render as one ink, duotone, or a tamed shared palette so form carries
them. *Genes:* `palette.strategy`, `content.countryCodes`. *Scorers:*
`colorHarmony`. *Exceptions:* single-flag hero (its colours are the palette;
surround stays neutral).

### R-FLAG-02 — Contain flags (flag-in-outline), never a stretched rectangle. **(High)**
*Why:* containment gives form and meaning; a flag stretched to the shirt front is
the cheap souvenir-stand read. *Genes:* `clip.shape` (`countryOutline`).
*Scorers:* `aspectFit`. *Exceptions:* none tasteful.

### R-FLAG-03 — In flag grids, enforce ruthless uniformity; normalise aspect ratios. **(High)**
Identical tiles/roundels, equal gutters, unified stroke; flags vary wildly
(Nepal, Switzerland, Qatar) so tokenise them.
*Why:* a grid's beauty is regularity; one full-saturation flag beside a muted one
breaks the curated-set illusion. *Genes:* `composition.layoutMode`
(`normalizedGrid`/`treemap`/`montage`), `composition.density`. *Scorers:*
`coverageBalance`. *Exceptions:* deliberate hero+support hierarchy (not a grid).

### R-FLAG-04 — Personal-journey framing; nationalism-neutral by default. **(High)**
"Places I've been," not "countries conquered/ranked."
*Why:* flags carry political weight; ranking/aggression reads jingoistic and
limits global sellability. *Genes:* `content.source`, `typography`. *Scorers:*
`profileFit`. *Exceptions:* explicit opt-in single-nation pride line (handled
separately).

### R-FLAG-05 — Handle disputed/sensitive flags & borders in the data layer. **(High)**
Neutral outline fallbacks; careful adjacency; user curation/hide.
*Why:* contested flags/borders (Taiwan, Kosovo, Palestine, W. Sahara) are
reputational landmines; a blind generator **will** eventually emit something
harmful. This is a floor, not a preference. *Genes:* `content.countryCodes`,
`clip.code`. *Exceptions:* none.

---

## H. Travel Storytelling

### R-STORY-01 — Ground every design in real, specific, verifiable data. **(High)**
Accurate coordinates, correct est. dates, real elevations, true outlines/flag
proportions.
*Why:* specificity converts generic decoration into proof-of-experience ("I was
there"); plausible-but-wrong details are the AI/generic tell and destroy trust.
This is Roavvy's structural edge (you have the user's real data). *Genes:*
`content.*`, `clip.code`, `motifs`. *Scorers:* `profileFit`. *Exceptions:* never
fabricate precision — false specificity is worse than none.

### R-STORY-02 — Sell the story of the journey, not the inventory of places. **(High)**
Journey lines, route arcs, "explorer since [year]," a worn passport — devices
implying narrative and time.
*Why:* a list is a database; a journey is emotion → nostalgia, pride, gifting.
*Genes:* `composition.template` (`timeline`/`journeys`/`passport`),
`content.stampMode`. *Scorers:* `profileFit`. *Exceptions:* pure collector/grid
pieces where completeness is the point.

### R-STORY-03 — Every design is an identity claim, not decoration. **(High)**
Make the flattering-yet-true statement explicit ("47 countries · 6 continents",
"I did the Camino").
*Why:* graphic tees are low-risk social beacons; a design that clearly says
something about the wearer gets bought and worn — a pretty-but-mute one doesn't.
*Scorers:* `profileFit`. *Exceptions:* none — even minimal marks carry a claim;
make it deliberate.

### R-STORY-04 — Understatement / insider cues over loud tourist branding. **(Medium-High)**
Small emblem, coordinates, muted colourway over "I ♥ [PLACE]" in 200pt.
*Why:* the premium/souvenir divide is largely volume; restraint creates an
in-group "traveler not tourist" flex the segment pays for. *Genes:*
`composition.imageSize`, `palette.strategy`. *Exceptions:* novelty/gift/kids lines.

### R-STORY-05 — Use the country outline as a container/window into meaning. **(High)**
Fill it (flag, texture, visited-city dots, journey line); a bare outline is the
map-site cliché.
*Why:* the fill turns a generic shape into a designed, meaningful object.
*Genes:* `clip.shape`, `motifs`. *Exceptions:* a refined variable-weight single-
stroke line-art outline can stand bare.

---

## I. Design Trends & Coherence

### R-TREND-01 — One coherent aesthetic world per design; no style mashups. **(High)**
WPA-park / expedition-utilitarian / grand-tour-heritage / modern-minimal-line /
passport-stamp / gorpcore — pick one; don't blend their signature cues.
*Why:* coherence is the master signal of art direction; the classic AI/amateur
failure is a mashup (grunge on sleek line-art under an ornate serif) because each
element was optimised alone. *Implication:* bundle palette + type + texture +
container as **locked style presets**, vary only within one. *Scorers:*
`colorHarmony`, `aiCritic`. *Exceptions:* skilled intentional high-low mixing
(unsafe to automate; default to purity).

### R-TREND-02 — Emulate a physical process (timeless), not a software filter (dated). **(High)**
*Why:* limited palette + halftone + real wear has looked good for 60+ years
because it's rooted in a stable physical process; bevel/emboss, gloss/Web-2.0
gradients, chrome, lens flares, hard drop shadows, uniform grunge are filter
fashions that date fast. *Genes:* `printStyle.id`. *Exceptions:* knowing
retro/Y2K themes behind an explicit flag.

### R-TREND-03 — Default to the two safest long-term bets: vintage and minimalism. **(Medium-High)**
Adopt gorpcore/streetwear as **grammars** (contour lines, bold contrast), not as
**slogans**; keep maximalism/Y2K as hero-only, never defaults.
*Why:* nostalgia and restraint age slowly; label-driven trends churn. *Genes:*
`printStyle.id`, `composition.template`. *Exceptions:* trend-capsule drops.

### R-TREND-04 — Avoid the oversaturated generic tropes. **(High)**
No "Adventure Awaits/Wanderlust" script over a mountain, no bare dotted-line world
map, no airplane+arc, no compass-rose clip art.
*Why:* undifferentiated and non-personal — they fail precisely where Roavvy's
moat (real data × coherent system) should win. *Scorers:* `profileFit`,
`aiCritic`. *Exceptions:* self-aware ironic reappropriation, executed with intent.

---

## J. Merchandising & The Generative System

### R-MERCH-01 — Controlled variation along curated axes, never raw randomness. **(Medium-High)**
Each axis (palette set, layout template, hero element, texture level) constrained
to values that always look good together.
*Why:* random knobs produce ugly outliers; "same 3 templates" feels cheap;
curated variation gives the feel of a designed collection. *Genes:* all, via
grammar priors + `weightClamp`. *Scorers:* diversity filter. *Exceptions:* none —
even "surprise me" samples a vetted space.

### R-MERCH-02 — At least three density tiers per template, chosen by data volume. **(High)**
1–3 countries → hero outline; 4–15 → badge/stamp cluster; 16+ → normalised grid
or count-forward typographic mode.
*Why:* one layout can't look premium from 2 to 90 countries; branching by volume
is what separates a design system from a mail-merge. *Genes:* `composition.density`,
`composition.layoutMode`, `composition.rowCount`. *Scorers:* `coverageBalance`,
`profileFit`. *Exceptions:* fixed-count product lines.

### R-MERCH-03 — Design for the marketplace thumbnail. **(High)**
(See R-COMP-03 — restated as a merchandising constraint.) *Scorers:*
`contrastLegibility`, `focalHierarchy`.

### R-MERCH-04 — Collectibility: keep one consistent system across a series. **(Medium-High)**
*Why:* a "visited-more" series that shares palette/type/layout grammar invites
repeat purchase and reads as a curated line. *Genes:* stable grammar version +
persona priors. *Exceptions:* deliberate special editions.

---

## How the rules feed the engine (pointer)

- **Hard gates** (never shown if failed): R-COL-03, R-PRINT-03, R-PRINT-04,
  R-PRINT-07, R-FLAG-05, plus proposed "≤2 type families / ≤2 accents / ≤N stacked
  effects" checks. See `engine_recommendations.md` §3a.
- **Soft scorers** (bias): everything else, mapped to the existing scorer names in
  each rule. See `engine_recommendations.md` §3b–4.
- **Locked style presets** (R-TREND-01) are the recommended unit of generation:
  bundle palette + typography + texture + container so coherence is structural.
- **Validation:** a rule is "confirmed" when liked references satisfy it at a
  higher rate than disliked ones, and/or chosen designs skew toward it. Until
  then its `confidence` is the honest prior. See `design_rule.schema.json`
  `validation`.
