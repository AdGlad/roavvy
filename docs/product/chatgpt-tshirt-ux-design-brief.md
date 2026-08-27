# Roavvy T‑Shirt Studio — UX Design Brief for ChatGPT

**Your task:** design the end‑to‑end **user experience** for creating a custom t‑shirt in
Roavvy — the screens, widgets, layout, flow, and interactions. This document gives you the
complete **logic, controls, and dependencies** of the design funnel so your UX is correct and
buildable. **Bring your own opinion on layout and interaction** — do not just mirror what's
below. The lists here are the *functional contract* (what must be reachable and when); the
*experience* (how it's arranged, disclosed, sequenced, and styled) is yours to design.

---

## 1. What this is

Roavvy scans a traveller's photo library, detects the countries and trips they've visited, and
turns that history into shareable designs and printable merch. This brief covers the **t‑shirt
creator**: the customer starts from an instantly‑generated design built from *their own travels*
and shapes it into something they feel is uniquely theirs, then buys it.

**Emotional goal for the user:** *"I designed this. It's unique to me."* — with as little effort
as they want to spend. A great result should be one tap away; deep control should be available
but never in the way.

**Core UX principles (hold these throughout):**
1. **The t‑shirt is always the hero** — a live preview of the actual design is on screen at all
   times, and every change is immediately visible on it.
2. **Instant → Make It Yours → Fine Tune** — open on a finished, excellent design (not a blank
   canvas); offer a few legible creative choices; hide deep controls behind progressive disclosure.
3. **Fast path to purchase** — a confident user can go from open → buy in seconds.
4. **Primary choices are creative and visual**, not technical. Show pictures/thumbnails, not jargon.
5. **Garment controls are distinct from artwork controls.** Choosing a shirt colour/size/side is a
   different mental mode from restyling the artwork.
6. **Advanced controls are contextual, never cluttering.** A control only appears when it applies
   to the current design (see the dependency rules in §6 — this is the most important section).

---

## 2. The mental model: one deterministic "recipe"

Every design is a **DesignRecipe** — a deterministic genome. The same recipe always renders the
same image (content‑hashed `recipeId`), so undo/redo, branching, saving and reproducing are free.
A design is shaped by turning a small number of **creative axes**, each of which re‑rolls exactly
*one* part of the recipe and leaves the rest byte‑identical.

**The five creative axes (the "deck"):**

| Axis | What it changes | User label |
|---|---|---|
| **Direction** | The *subject* (see §3) | "Direction" / "Subject" |
| **Vibe** | The *style* (see §4) | "Vibe" / "Style" |
| **Focus** | Composition/emphasis re‑roll within the current subject+style | "Focus" |
| **Colour** | Colour treatment/palette | "Colour" |
| **Words** | The printed title text | "Words" |

Interactions that apply to the whole deck:
- **Tap an axis** → shows a tray of live alternatives (re‑rolls of that axis); tap one to commit.
- **Lock 🔒 an axis** → that axis is held fixed while others re‑roll (long‑press or a lock affordance).
- **Remix** → re‑rolls every *unlocked* axis at once (a "surprise me" that respects locks).
- **Undo / branch** → history is free; stepping back never loses work.
- **Reject ✕** an alternative → teaches the system you dislike it (see §9, learning).

---

## 3. Direction = the Subject

The **Direction** axis cycles the subject. Each subject is a distinct family of designs:

| Subject | What it is |
|---|---|
| **Flags** | The traveller's country flags (the default, richest subject) |
| **Passport** | Real passport‑style entry/exit stamps, collaged |
| **Route** | A journey/timeline of trips in order |
| **World** | A word‑cloud of country/place names |
| **Words** | A typographic statement (flag‑filled or inked letters) |
| **Milestones** | An achievement/badge statement ("47 COUNTRIES · 6 CONTINENTS") |

### 3a. Detail — a sub‑step that exists ONLY for Flags
Flags, Maps, Animals, Landmarks etc. are **all the same "flags" subject** differing only by the
**clip shape** the flags are poured into. This sub‑choice is called **Detail** and appears **only
when the subject is Flags**:

| Detail | Clip shape |
|---|---|
| **Grid** | No clip — plain flag field (rows/tiles) |
| **Map** | Country outline |
| **Animals** | Animal silhouette |
| **Plants** | Plant silhouette |
| **Landmarks** | Landmark silhouette |
| **Heart** | Heart |
| **Circle** | Circle |

> **Design implication:** "Map / Animals / Landmarks" are not separate subjects in the top‑level
> Direction menu — they're a second-level shape choice under Flags. Decide how you want to surface
> this (a sub‑row, a shape picker, a nested step…), but it must be reachable only in the Flags context.

---

## 4. Vibe = the Style

The **Vibe** axis restyles the current design into one of **13 named styles**, each shown as a
live thumbnail of *the user's current design* in that style (not a generic sample):

`Showcase · Extreme · Maximal · Beachwear · Surf · Grunge · Minimalist · Streetwear · Vintage ·
Retro · Outdoor · Premium · Typography`

A **style seeds the defaults** for the *unlocked* axes only — its edge treatment, effect mix,
colour‑treatment defaults, clip archetypes and orientation bias. It **never** overrides the
"generic" fixed controls (garment colour, aspect, size, front/back, subject, title, seed). Picking
a new Vibe should visibly restyle the artwork while leaving the user's fixed choices intact.

---

## 5. The control tiers (how controls are grouped)

There are three tiers. Your layout should make the *mode* of each tier feel distinct.

**Tier 1 — Fixed / Global (persistent, style‑proof).** Always available; never reset by a style or
subject change. These are *garment / product* decisions:
- **Aspect**: Portrait · Landscape · Square
- **Size** (artwork print scale on the shirt): S · M · L
- **Garment colour**: Black · White · Navy · Grey · Sand · Olive
- **Side**: Back · Front (see §7)
- **Front print** controls (only when Side = Front — see §7)
- **Trips** row (Source + Year — only when travel history is present — see §8)
- Global actions: **Save/♥**, **Review & Save**, **Undo**, **Remix**

**Tier 2 — Cross‑cutting creative deck.** The five axes from §2 (Direction · Vibe · Focus · Colour ·
Words). This is the "Make It Yours" surface.

**Tier 3 — Contextual "Fine Tune" (Refine).** Deep, per‑design form controls, disclosed behind a
"Fine tune" entry and organised into a **category menu** (see §6). Only the categories that apply
to the current design are shown.

---

## 6. Fine Tune (Refine) — the category menu and its DEPENDENCY RULES

The deep controls live under a **Refine** panel presented as a **menu of categories**, showing one
focused body at a time (never one long scroll). **Which categories appear is contextual.** This is
the crux of "advanced controls never clutter" — respect these rules exactly:

| Category | Appears when… | Controls inside |
|---|---|---|
| **Finish** | always | One‑tap presets: Clean · Vintage · Retro · Halftone · Distress · Tie‑dye · Shatter · Riso · Mono |
| **Layout** | subject = **Flags** only | Fill algorithm (Grid/Treemap/DiagonalStripe/Voronoi/TornRegion/NoiseBlend/Radial/Mosaic) · Copies per country (1–8) · Scatter (0–1) |
| **Graphic** | the artwork is **clipped** (Map/Animals/Plants/Landmarks/Heart/Circle) **or** subject = **Passport** | *Passport only:* Stamp size (50–150%) · Scatter · Colour (Multi = flag colours / Mono = single ink) · Stamps (Entry+Exit / Entry only / Exit only). *Silhouette clips:* pick a specific animal/plant/landmark. *Any clip:* Size · Rotation · Corner radius · Feather |
| **Text** | subject = **Words** only | Custom text field (type your own word/name) |
| **Colour** | always | Treatment: flagDerived · monochrome · duotone · garmentAware · Vintage grade (0–1) |
| **Edges** | always | Torn‑edge style: Ragged · Frayed · Torn corners · Deep rips · Damage · Corner damage · Fray |
| **Effects** | always | Distress · Grain · Fade · Cracks · Acid wash · Tie‑dye · Shatter · Shatter spikes · Halftone · Halftone scale (2–12) · Ripple · Ripple frequency (1–16) |
| **Print** | always | Riso · Newsprint · Sun‑faded · Photocopy (continuous 0–1 each) |

**All other conditional rules (surface a control only when its predicate holds):**
- **Detail** sub‑choice → only when subject = **Flags**.
- **Front print** controls → only when **Side = Front**.
- **Chest side (Left/Right)** → only when Front **Fit = Chest**.
- **Ribbon coverage (Selected/All)** → only when Front **Art = Ribbon**.
- **Trips row (Source + Year)** → only when the traveller has **trip history** (dates), not just a
  flat country list.
- **Silhouette "pick a specific one"** → only when the current clip is a silhouette (animal/plant/landmark).
- **Passport stamp controls** → only when subject = **Passport**.

> Every control above is *reachable* in the current app. Your job is to decide **where** each lives
> (which step/sheet/panel), **how** it's disclosed, and **what** the primary vs advanced split is —
> but the predicate for *when it's visible* must be honoured.

---

## 7. Front / Back print model (IMPORTANT — mobile parity)

A t‑shirt has two faces and Roavvy treats them as **one product**:

- **Back = the main design** (the big hero artwork). This is the default view and the primary
  authoring surface. Everything in the deck/refine edits this by default.
- **Front = a small chest print**, defaulting to a **flag "ribbon"** (a medal‑bar of the
  traveller's flags). The front is chosen via three controls (only visible when Side = Front):

  1. **Fit**: `Full` · `Chest` · `None`
     - `Full` = a centred full‑front print.
     - `Chest` = a small chest print → then pick **Left** or **Right**.
     - `None` = a blank front (design only on the back).
  2. **Art** (where the front image comes from): `Ribbon` (default flag medal‑bar) ·
     `Complement` (auto‑generate a design that complements the back) · `Match back` (use the main design).
  3. **Ribbon coverage** (only when Art = Ribbon): `Selected` (the countries in the current design)
     vs `All` (every country the traveller has).

**Print‑position fidelity (must be respected):** the chest/full positions map to fixed print
rectangles so the artwork lands where it actually prints on the garment. As fractions of the
shirt‑front image:
- Left chest: `x 0.55, y 0.25, w 0.18, h 0.25`  *(note: "Left" = the wearer's left = the viewer's right)*
- Right chest: `x 0.27, y 0.25, w 0.18, h 0.25`
- Full (centre): `x 0.25, y 0.22, w 0.50, h 0.40`
- None: blank

The Review step shows **both** faces (Front + Back) so the user sees the whole garment.

---

## 8. Travel data → the design (Source & Year)

The design is built from a **travel context**: either a flat list of country codes, or a richer
**trip history** (each trip has a country + start/end dates + photo count). When trip history is
present, two extra controls appear (the **Trips** row):

- **Source**: `Countries` (one flag per distinct country) vs `Trips` (one flag per visit — repeat
  visits repeat the flag).
- **Year filter**: a range slider across the traveller's travel span; filters which trips feed the
  design (e.g. "just my 2023 trips").

Changing either re‑derives the context and regenerates the design. When there's no trip history
(only a country list), this row is hidden entirely.

---

## 9. Words, Review, and Learning

- **Words**: an editable printed‑title field plus a **"Suggest titles"** action that proposes a few
  distinct on‑brand titles. Titles must vary each time; never show numbered options or a single
  country name for a multi‑country design.
- **Review & Save**: a summary showing Front + Back previews, an at‑a‑glance spec (countries,
  subject, detail, style, size, aspect, garment colour, front placement), the title, and **Save to
  library** (+ an Add‑to‑cart action). This is the confident end of the funnel.
- **Physical garment fit size (XS–XXL)** is a **cart/checkout attribute**, not an artwork control —
  do not conflate it with the artwork **Size (S/M/L)** which scales the print. Keep fit‑size out of
  the design surface; it belongs at Add‑to‑cart.
- **Learning (delete‑to‑learn):** the system learns the user's taste from their actions — viewing,
  choosing, saving (♥), and rejecting (✕) alternatives all feed a preference model, and the opening
  design biases toward what they've liked before. Your UX should make "I like this / not this"
  signals easy and natural (e.g. a save heart, a dismiss on alternatives).

---

## 10. A reference flow (the current logical funnel — reshape it as you see fit)

This is the *logical* order; you decide the actual screen/step structure.

1. **Open** on an instant, finished hero design from the user's travels (biased to their taste).
   Show Front/Back and a single strong "Make it yours" affordance.
2. **Make It Yours** — the creative deck: Direction (→ Detail if Flags) · Vibe · Focus · Colour ·
   Words. Live, with lock/branch/undo and an alternatives tray.
3. **Garment** — Tier‑1 fixed choices: garment colour, aspect, artwork size, and the Front print
   (fit/art/ribbon) + Trips Source/Year when available.
4. **Fine Tune** (optional) — the Refine category menu (§6), contextual to the design.
5. **Review & Save** — both faces, spec summary, title, save/cart.

---

## 11. What to deliver

Please produce a UX design that covers:
- **Screen/step architecture** — how the funnel is broken into screens or a single evolving canvas,
  and the navigation between them. Justify where you depart from §10.
- **The live‑preview treatment** — how the hero shirt stays present and how Front/Back are shown.
- **Each control's home** — for every control in §5–§8, say which screen/panel/sheet it lives in and
  whether it's primary or progressively disclosed. Honour every visibility predicate in §6.
- **Interaction patterns** — how axis re‑rolls, alternatives trays, locks, Remix, undo, and the
  Refine category menu behave (gestures, transitions, affordances).
- **Progressive disclosure strategy** — your split between the instant path, "make it yours", and
  "fine tune".
- **Wireframes / mockups** (annotated) for the key screens and the Front‑print + Refine surfaces.

**Explicitly form your own opinion on layout, hierarchy, sequencing and visual language.** Where you
choose a structure different from this document, note *why* — but never drop a control or violate a
visibility rule from §6. If a control seems redundant or mis‑placed, propose a better home for it
rather than removing it.

---

### Appendix — exact option lists (for correctness)

- **Subjects:** Flags, Passport, Route, World, Words, Milestones
- **Detail (Flags only):** Grid, Map, Animals, Plants, Landmarks, Heart, Circle
- **Vibe styles (13):** Showcase, Extreme, Maximal, Beachwear, Surf, Grunge, Minimalist, Streetwear,
  Vintage, Retro, Outdoor, Premium, Typography
- **Garment colours:** Black, White, Navy, Grey, Sand, Olive
- **Aspect:** Portrait, Landscape, Square · **Artwork size:** S, M, L
- **Front fit:** Full, Chest (→ Left/Right), None · **Front art:** Ribbon (→ Selected/All), Complement, Match back
- **Finish presets:** Clean, Vintage, Retro, Halftone, Distress, Tie‑dye, Shatter, Riso, Mono
- **Fill algorithms:** Grid, Treemap, DiagonalStripe, Voronoi, TornRegion, NoiseBlend, Radial, Mosaic
- **Colour treatments:** flagDerived, monochrome, duotone, garmentAware (+ Vintage grade)
- **Edge styles:** Ragged, Frayed, Torn corners, Deep rips
- **Effects:** Distress, Grain, Fade, Cracks, Acid wash, Tie‑dye, Shatter, Shatter spikes, Halftone,
  Halftone scale, Ripple, Ripple frequency
- **Print styles:** Riso, Newsprint, Sun‑faded, Photocopy
- **Passport:** Stamp size, Scatter, Colour (Multi/Mono), Stamps (Entry+Exit / Entry only / Exit only)
- **Trips (when history present):** Source (Countries/Trips), Year range
