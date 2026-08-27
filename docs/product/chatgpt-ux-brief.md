# Roavvy T-Shirt Studio — Context Brief for UX Design (paste into ChatGPT)

> Paste everything below into ChatGPT. It gives you (ChatGPT) the full configuration
> model, logic, and current groupings so you can design the screens, widgets, and
> interactions. A task prompt is at the very bottom.

---

## 0. Who you're designing for

Roavvy scans a traveller's photo library, detects the countries they've visited, and
lets them turn that travel history into a **custom printed T-shirt** (front + back,
shipped via Printful). The design is **procedurally generated from their real travel
data** — flags of countries they've been to, trip dates, a world map, a word cloud, etc.

**The emotional goal:** the customer must feel *"I designed this. It is unique to me."*
NOT *"I picked a template"* and NOT *"I kept hitting a Generate button until something
looked okay."* Every meaningful choice should feel like a creative decision, and the
result should be theirs.

Design constraints for the UX:
- **Mobile-first** (iOS), single-hand use, thumb-reachable primary actions.
- The very first screen must show an **instant finished hero design** built from their
  travels — no blank canvas, no setup wizard before they see something beautiful.
- Editing is **live**: every change re-renders the shirt immediately.
- It must stay **legible**: a non-designer should understand every control.

---

## 1. The core mental model: a design is a "recipe"

Under the hood every design is a deterministic **recipe** (a structured genome). The
same recipe always renders the same shirt, so we can offer free undo, branching,
"lock this part / re-roll the rest", and a saveable/reproducible library. You don't
need to expose "recipe" to users — but knowing designs are structured, reproducible,
and composed of independent **axes** is important, because it's what makes lock/branch/
re-roll trustworthy.

**The 5 creative axes** (each can be independently re-rolled or locked 🔒):
1. **Direction** — what the design is *about* (the subject/genre).
2. **Vibe** — the overall style/mood (see Styles below).
3. **Focus** — the form/composition (grid vs single hero, clip shape, layout).
4. **Colour** — palette strategy + garment-aware inking.
5. **Words** — title/subtitle text and typography.

---

## 2. GENRES (a.k.a. "Direction" / the subject)

The subject the shirt is built from. In the current funnel these are the top-level
"Direction" choices:

| Genre (internal)   | User-facing "Direction" | What it renders |
|--------------------|-------------------------|-----------------|
| `flags`            | **Flags**               | The country flags themselves (the core product) |
| `animalsNature`    | **Animals & Nature**    | Flags clipped into animal/plant silhouettes |
| `landmarks`        | **Landmarks**           | Flags clipped into famous-landmark silhouettes |
| `maps`             | **Maps**                | Flags clipped into the country's map outline |
| `passport`         | **Stamps**              | Real passport-style entry/exit stamps with trip DATES |
| `travelLog`        | **Routes**              | Trip timeline / journeys (chronological travel data) |
| `typography`       | **Words**               | Typographic / word-cloud treatment of place names |
| `milestones`       | **Milestones**          | Achievement / big-number statement ("28 countries") |

**IMPORTANT grouping logic:** Flags, Animals & Nature, Landmarks, and Maps are *all the
same underlying subject (flags)* — they differ ONLY by the **clip shape** the flag is
poured into. So in the funnel, after choosing a flag-based Direction, the user picks a
**"Detail"** sub-step (the clip shape). Passport, Routes, Words, and Milestones are
genuinely different subjects (real stamps, trip data, text, achievement numbers).

---

## 3. The "Detail" sub-step (clip shapes) — only for flag-based directions

After a flag-based Direction, the flag content can be poured into one of these shapes:

- **Grid** — flags tiled in a grid (no clip; the classic multi-flag look).
- **Map** — clipped to the selected country's map outline.
- **Animals & Nature** — clipped to an animal or plant silhouette.
- **Landmarks** — clipped to a landmark silhouette.
- **Heart** — heart shape.
- **Circle** — circle/roundel.
- (plus procedural shapes, custom **text** clip, and passport page as a special case)

**Silhouette picker:** for Animals/Plants/Landmarks there can be *many* silhouettes per
country (e.g. multiple animals, plants, and landmarks). The UI must let the user pick
from the **full list of available silhouettes across all their selected countries**.

---

## 4. STYLES (a.k.a. "Vibe" — 13 total)

A style is a coordinated look. Choosing a style seeds sensible defaults for **edge
treatment, effect mix, colour treatment, clip archetypes, and orientation bias** — but
only for axes the user hasn't locked. The 13 styles (names may be refined):

Modern/Clean, Bold/Statement, Minimal, Vintage, Retro, Halftone, Stamp, Grunge,
Editorial, Playful, Monochrome, Neon/Vivid, Classic.

(Print-media looks like Vintage/Retro/Halftone/Stamp/Grunge come from a real
Canvas-raster print pipeline, so they look like genuine print treatments, not filters.)

---

## 5. EFFECTS (post-processing, independently adjustable)

Effects are numeric intensities (0–1) applied on top. They fall into two groups:

**Distress / texture group:**
- `distress` (general wear)
- `cracks`
- `acid` (acid-wash)
- `tieDye`
- `shatter` (+ `spikes`)
- `ripple` (+ `frequency`)
- `halftone` (+ `scale`)

**Print group (ported from the production mobile engine):**
- `riso` (Risograph — offset multiply ink passes + grain)
- `newsprint` (grayscale + coarse halftone + warm tint)
- `sunFaded` (warm desaturated, faded)
- `photocopy` (steep contrast + speckle)

Effects can be exposed as a **"Finish"** concept with named presets (e.g. one tap sets a
coordinated effect mix) AND individual sliders in an advanced panel.

---

## 6. COLOUR

- **Colour strategy** — how the palette is chosen (e.g. semantic flag colours vs a
  curated palette vs monochrome vs vintage-graded).
- **Garment-aware inking** — some elements re-ink to contrast with the shirt colour;
  flags keep their *semantic* colours (a French flag stays blue/white/red regardless of
  shirt colour). This "semantic-lock vs adaptive" distinction matters.
- **Vintage grade** — an aging/wash treatment slider.

**Passport ink Multi/Mono option:**
- **Multi** = each stamp is filled with its country's real flag colours.
- **Mono** = a single ink auto-chosen for contrast with the shirt (black on light
  shirts, white on dark shirts).

---

## 7. WORDS / typography

- User can type their **own title/subtitle text**, or use AI-suggested titles (with an
  offline fallback bank of ~12 phrases).
- **Title rules:** one ready-to-use title, no numbering/preamble, never a single-country
  name for a multi-country design, and it should vary on each press.
- Typography carries a display font family; title placement/case are adjustable.

---

## 8. FORM / composition controls (contextual, per subject)

- **Grid controls:** fill algorithm, rows, density, **copies-per-country** (repeat one
  country's flag to fill a grid), scatter.
- **Flag combination:** Single / Blend / Multi (how multiple flags combine) + seam/weight
  (planned — needs multi-flag selection first).
- **Clip transforms:** size/scale, rotation, corner radius, feather (soft edge).
- **Passport:** ink (Multi/Mono), stamp size, scatter, **stampMode** (entry only / exit
  only / both), trip dates.
- **Data subjects (Routes/Words/Milestones):** which entries, weighting, date range,
  journey style, big-number "statement hero".

---

## 9. The THREE CONTROL TIERS (critical for your layout)

This is the single most important structural idea for the UX. Controls live in three
tiers, and **which tier a control is in dictates where it lives on screen and whether a
style change is allowed to touch it.**

**Tier 1 — FIXED / GLOBAL (always available, a persistent bar; NEVER changed by picking a
style):**
- Aspect / orientation: Portrait, Landscape, Square
- Size: Small / Medium / Large
- Garment (shirt) colour
- Front / Back side toggle
- Surprise-me / seed
- Save / Add to cart / Share

**Tier 2 — CROSS-CUTTING creative deck (the main creative choices):**
- Direction, Style/Vibe, Effects/Finish, Words, Colour treatment

**Tier 3 — CONTEXTUAL (only shown for the relevant subject):**
- Grid fill/rows/density/copies/scatter; flag combine; clip transforms; passport
  ink/size/scatter/stampMode/dates; data entries/weights/range/journey style/big-count.

**Governing principle:** picking a style seeds defaults for **unlocked** Tier-2/Tier-3
axes only. Tier-1 fixed controls **survive** style changes. **Locks** 🔒 make any axis
sticky so re-rolls and style changes leave it alone.

---

## 10. The current funnel / flow (6 phases)

1. **A — Start:** instantly show a finished hero design from the user's travels (best of
   several, ranked by their learned preferences if we have any).
2. **B — Shape:** evolve it through the 5 axes (Direction / Vibe / Focus / Colour /
   Words). Each choice **re-rolls ONE axis live**. Features: an **alternatives tray**
   (a few variations of the current axis), **per-axis lock 🔒**, and **branch/undo**
   (free, because recipes are deterministic).
3. **C — Back:** design the shirt back as part of the same garment (it shares a theme
   with the front but is independently editable).
4. **D — Review:** see front + back on the garment, in the chosen colour/size/aspect.
5. **E — Refine (optional):** an advanced "Adjust" sheet exposing Tier-3 contextual
   controls and individual effect/shape/colour/edge sliders (progressive disclosure).
6. **F — Save / Cart / Share.**

**Interaction principles already decided:**
- De-duplicated: colour choices collapsed 3→1, AI-text 2→1, editing surfaces 3→1.
- "Direction" (subject switch) was added as an explicit step.
- "Put it on a t-shirt" was reframed as "Add to cart."
- The persistent Tier-1 bar is separate from the creative deck.

---

## 11. Delete-to-learn / preference model

The app learns taste over time: viewing, choosing a style, saving (a "like"), and
rejecting/deleting a design (with an optional reason) all feed a preference model that
biases future opening designs and variation suggestions. You can lean on this: the UX
can feel personalised and get better the more the user interacts.

---

## 12. Terminology cheat-sheet (use these words with users)

- "Direction" = subject/genre. "Detail" = clip shape for flag subjects.
- "Vibe" or "Style" = the coordinated look. "Finish" = effect/print treatment.
- "Alternatives" = the tray of variations for the current axis.
- "Lock" = pin an axis so it survives re-rolls/style changes.
- "Garment" = the shirt (colour, size, aspect, front/back).

---

## 13. FULL CONTROL INVENTORY — every editing control mapped to the workflow

This is the exact, as-built control set. **Phases:** A Start · B Shape · C Back ·
D Review · E Refine (the Adjust panel) · F Save. **Tier:** T1 Fixed/Global (persistent
bar, style-proof) · T2 Cross-cutting creative deck · T3 Contextual (per-subject).

### Tier 1 — Persistent Format & Colour bar (visible in EVERY phase A–F)

| Control | Options | Phase(s) | Tier |
|---|---|---|---|
| Aspect / Orientation | Portrait · Landscape · Square | A–F | T1 |
| Size | S · M · L | A–F | T1 |
| Garment colour | swatch set | A–F | T1 |
| Side | Front · Back | A–F (drives **C**) | T1 |
| Surprise me | re-roll unlocked axes | A, B | T1 |
| Adjust (open Refine) | toggle | opens **E** | T1 |

### Tier 2 — Creative deck (Phase B "Shape": per-axis re-roll + lock + alternatives)

| Control | Options / behaviour | Phase(s) | Tier |
|---|---|---|---|
| **Direction** (subject) | Flags · Animals&Nature · Landmarks · Maps · Stamps · Routes · Words · Milestones | B | T2 |
| **Detail** (flag subjects only) | Grid · Map · Animals · Plants · Landmarks · Heart · Circle | B (sub-step) | T2/T3 |
| **Vibe / Style** | 13 styles | B | T2 |
| **Colour** (axis) | re-rolls palette | B | T2 |
| **Words** (axis) | title/subtitle re-roll | B | T2 |
| Alternatives tray | tap a variation to keep it | B | T2 |
| Lock 🔒 (per axis) | pin axis through re-rolls/style changes | B | T2 |

### Tier 3 — Adjust / Refine panel (Phase E) — contextual sections

| Section | Control | Range / options | Shows when | Tier |
|---|---|---|---|---|
| **Finish** | Preset row | named effect presets | always | T3 |
| **Text** | Custom word | free text | Direction = Words | T3 |
| **Grid** | Fill algorithm | dropdown | Direction = Flags | T3 |
| Grid | Copies (per country) | 1–8 | Flags | T3 |
| Grid | Scatter (jitter) | 0–1 | Flags | T3 |
| **Passport** | Scatter | 0–1 | Direction = Stamps | T3 |
| Passport | Colour | **Multi** · **Mono** | Stamps | T3 |
| Passport | Stamps | entryExit · entryOnly · exitOnly | Stamps | T3 |
| **Silhouette** | Pick | full list across selected countries | clip = animal/plant/landmark | T3 |
| **Shape** | Size (scale) | 0.25–1.4 | any clip (not grid/passport) | T3 |
| Shape | Rotation | −45°…45° | clipped | T3 |
| Shape | Corner radius | 0–1 | clipped | T3 |
| Shape | Feather | 0–1 | clipped | T3 |
| **Colour** | Treatment | flagDerived · monochrome · duotone · garmentAware | always | T3 |
| Colour | Vintage grade | 0–1 | always | T3 |
| **Edges (torn)** | Style | ragged · frayed · tornCorners · deepRips | always | T3 |
| Edges | Damage | 0–1 | always | T3 |
| Edges | Corners | 0–1 | always | T3 |
| Edges | Fray | 0–1 | always | T3 |
| **Effects** | Distress · Grain · Fade · Cracks · Acid wash · Tie-dye · Shatter · Shatter spikes · Halftone · Halftone scale (2–12) · Ripple · Ripple freq (1–16) | 0–1 unless noted | always | T3 |
| **Print** | Riso · Newsprint · Sun-faded · Photocopy | 0–1 each | always | T3 |

### Phases C / D / F

| Phase | Controls available |
|---|---|
| **C — Back** | Same full set as A/B/E, but editing the **Back** garment (toggled via Side pill; back starts theme-derived from the front and is independently editable) |
| **D — Review** | Read-only composite; only the T1 bar (aspect/size/colour/side) stays adjustable |
| **F — Save** | Save · Add to cart · Share (no design edits) |

**Notes for you (ChatGPT):**
- **Direction/Detail** straddle T2–T3: the *subject switch* is a cross-cutting deck axis,
  but the *Detail clip-shape* it exposes is contextual to flag subjects.
- The current build is **one screen** (persistent bar + deck + a toggleable Adjust panel),
  not six separate pages — the A–F phases describe the intended *flow*, and every control
  above is mapped to the phase where it belongs. Feel free to propose splitting them into
  distinct screens if that improves the experience.

---

## TASK FOR YOU (ChatGPT)

Using the model above, design the **screens, widgets, and interactions** for the Roavvy
T-Shirt Studio to maximise user experience. Specifically:

1. Propose the **screen flow** (phases A–F) with a wireframe-level layout for each screen
   — where the live shirt preview sits, where the Tier-1 persistent bar sits, and how the
   Tier-2 creative deck and Tier-3 contextual controls are surfaced without clutter.
2. Design the **key widgets**: the axis deck + alternatives tray + lock affordance; the
   Direction→Detail sub-step; the silhouette picker (many per country); the garment
   colour/size/aspect/front-back bar; the "Finish" presets vs advanced effect sliders;
   the passport Multi/Mono toggle; the Words/title entry.
3. Specify the **interactions**: how re-rolling one axis feels, how lock/branch/undo
   behave, how live re-render is communicated, gestures (swipe alternatives?), and how
   progressive disclosure into the Refine sheet works.
4. Keep it **mobile-first, single-hand, legible to non-designers**, and preserve the
   emotional goal: *"I designed this. It's unique to me."*
5. Call out any **control taxonomy conflicts** or moments where the 3-tier rule (esp.
   "style must not touch Tier-1, locks override everything") could confuse users, and
   propose how the UI makes that legible.

Deliver: annotated screen descriptions (or ASCII/wireframe sketches), a component list,
and an interaction spec. Ask me clarifying questions first if anything is ambiguous.
