# What Makes a Roavvy T-Shirt

*The creative foundation. Every procedural recipe, every scorer weight, every
optimisation loop exists to produce shirts that satisfy this document. If a
generated design contradicts the philosophy, the design is wrong — not the
philosophy. This is the "constitution"; `design_rules.md` is the "law" that
enforces it; `engine_recommendations.md` is how the machine obeys.*

---

## The thesis

> **A Roavvy tee turns "where I've been" into a graphic good enough to wear even
> if it weren't personalised.**

Roavvy has one structural advantage no stock apparel brand has and no pure-AI
image generator can fake: **the wearer's real travel data.** The entire
philosophy is built to protect two things at once —

1. **Personalisation that still looks *designed*** (not auto-filled), and
2. **A premium system that survives *any* data input** (2 countries or 92).

Lose either and you get the two failure modes we exist to avoid: a beautiful
template that says nothing about the wearer, or a personal design that looks like
a spreadsheet mail-merge. Everything below serves keeping both true.

---

## The seven commitments

Each is a promise the engine makes on every design, with the rules that enforce it.

### 1. One hero, always.
Every design is *one idea seen from across a room*, that rewards a closer look.
There is a single dominant element — a flag, an outline, a seal, a count — and
everything else supports it. We never present a democracy of equal parts, because
the eye needs somewhere to land and "having to hunt" is logged as cheap.
→ *R-VH-01, R-VH-02, R-VH-03, R-ICON-02.*

### 2. Restraint is the premium signal.
Few colours (2–4, garment included), generous negative space, at most one accent,
one or two typefaces, subtle texture. Cheap merch adds; premium merch removes.
Restraint is not minimalism-as-style — it is the discipline that reads as
confidence and taste at every price point.
→ *R-COL-01, R-COL-04, R-COL-05, R-NEG-01, R-TYPE-01, R-TEX-03.*

### 3. It must be true.
We ground every design in the wearer's real, specific, verifiable data — accurate
country outlines, correct dates, honest counts, real coordinates. We never
fabricate precision. Truth is what turns decoration into *proof of experience*,
and proof is why the shirt gets worn. A wrong outline or invented coordinate is
worse than none — it breaks trust and the identity claim in one stroke.
→ *R-STORY-01, R-ICON-04.*

### 4. Sell the journey, not the inventory.
A list of countries is a database; a journey is an emotion. We bias toward
narrative and time — routes, "explorer since", worn stamps, a personal count
worn with pride — because nostalgia and identity, not information, are what people
buy and gift. Every design is a flattering-yet-true statement the wearer is proud
to make.
→ *R-STORY-02, R-STORY-03, R-STORY-04.*

### 5. One coherent world per design.
Each shirt lives fully inside one aesthetic — heritage badge, expedition-
utilitarian, vintage-poster, modern-minimal-line, passport-stamp — and never
blends their signatures. Coherence is the master signal of art direction; the
classic generative failure is a mashup because each element was optimised alone.
We generate from **locked style presets** that bundle palette + type + texture +
container, so coherence is structural, not hoped-for.
→ *R-TREND-01, R-COL-06, R-TYPE-05.*

### 6. Emulate the process, not the filter.
Our texture is *earned wear* — limited inks, coarse rotated halftones, distress
that follows the artwork and reveals the garment beneath, driven by one coherent
noise field. We emulate the physics of ink on cotton, which has looked good for
sixty years, and we ban the software-filter era-markers (bevel, gloss, chrome,
lens flare, uniform grunge, over-distress) that date a design the moment they're
applied. Timelessness comes from process; dating comes from filters.
→ *R-TEX-01, R-TEX-02, R-PRINT-01, R-PRINT-02, R-TREND-02.*

### 7. Printable by construction; wearable on a Tuesday.
A Roavvy design is never a "will this print?" gamble — it is produced by the same
renderer that prints it, and it passes a hard printability gate before anyone sees
it. And it is something a person wears on an ordinary day, not just a trip
souvenir: contained scale, garment-aware contrast, everyday restraint.
→ *R-COL-02, R-COL-03, R-PRINT-03, R-PRINT-04, R-PRINT-07, R-NEG-02.*

---

## The line we patrol: traveler, not tourist

The single sharpest boundary in everything we make is **premium heritage vs.
souvenir-shop tat.** It is mostly a matter of *volume and restraint*:

| A Roavvy tee is… | …never |
|---|---|
| One hero, generous space | Edge-to-edge, everything equal |
| 2–4 muted, derived colours | A rainbow of literal full-saturation flags |
| Tonal / duotone, one accent | Gradient soup, drop shadows, bevels |
| Real data, honestly shown | "I ♥ [PLACE]", invented coordinates |
| Understated insider cue | Loud tourist declaration |
| One coherent style | A mashup of three |
| Earned, process-based wear | A grunge.png over everything |
| A personal journey | Countries "conquered" or ranked |

We design for the person who wants to read as a *traveler*, not a *tourist* — and
who will pay for the difference.

---

## What this means for the machine (in one paragraph)

The engine is a designer that has internalised this philosophy: it seeds a
population from **locked style presets** biased by the wearer's persona and scope,
scores candidates against rules that encode these seven commitments (with
printability as a hard gate above all taste), keeps aesthetic quality weighted
above personal relevance so no design is ugly-but-relevant, enforces *semantic*
diversity so the three presented designs are genuinely different ideas, and learns
the individual's taste only *within* the Design Language — never out of it. The
studio (references, critiques, regression goldens) is the conscience that checks
the machine still believes all seven. See `engine_recommendations.md`.

---

## The test (use this on any design, human or generated)

1. **Hero?** Can you name the one dominant element in under a second?
2. **True?** Is every fact the wearer's real data, and correct?
3. **Restrained?** ≤4 colours, ≤2 type families, room to breathe, ≤1 accent?
4. **Coherent?** One aesthetic world, no mixed signatures?
5. **Earned?** Texture that follows the art, not a filter on top?
6. **Personal but designed?** Would this look composed at 3 countries *and* at 40?
7. **The stranger test:** would someone who has never used Roavvy still think
   this is a good T-shirt?

A design that misses any of these is not yet a Roavvy T-shirt.
