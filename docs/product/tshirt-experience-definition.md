# The Roavvy T-Shirt Experience — Definition

**Status:** definition only. Screen numbering implies no implementation order.
**Reconciles:** `chatgpt-tshirt-ux-design-brief.md` (functional contract) ·
`studio-ux-reconciliation.md` (storyboard ↔ repo) · `tshirt-creation-experience.md`
(proposal), against the shipped Studio V2 code.

Illustrated version: https://claude.ai/code/artifact/07d17cb1-fa64-41e1-abfd-6c0b107ffbe8

---

## The thesis

**A great shirt is already made when you arrive, and every step after that is optional.**
Effort is something the customer spends by choice, never a toll they pay to reach a result.
Fifteen seconds to a shirt, or an hour of shaping — both are first-class paths.

## The four modes

Gears, not gates. A person can stop at any one and buy, or drop down a gear for more control.

| Mode | Name | What it is |
|---|---|---|
| 01 | **Instant** | A finished shirt, chosen for them. Swipe for alternatives. Buy, or go deeper. |
| 02 | **Make It Yours** | Six or seven legible creative choices, each picture-led. |
| 03 | **Fine Tune** | Every deep control, disclosed by category, only where it applies. |
| 04 | **Buy** | Place it on the garment, pick a size, check out. |

## Persistent frame

On screen at all times — the reason the modes can be shallow.

- The live shirt in the chosen colour · Front/Back switch · Shirt/flat-artwork toggle · step position
- Always reachable: **Undo** (history is free) · **Remix** (re-roll everything unlocked) ·
  **Lock** (hold an axis fixed) · **Save** (reproducible later)
- Never: a step that hides the garment · a change you can't see until you go back · a blank canvas

---

## Screens

### S1 · Ready to wear — *Instant, the entry*
A finished shirt built from their own countries, not a template with their data poured in.
- **On screen:** the shirt; a deck of eight named designs; deck position and arrows; the eight stocked colours
- **Can do:** swipe either way (wraps); switch shirt colour; turn front to back
- **Exits:** **Buy this one** → S11 · **Configure** (keeps this design) → S5 · **Start custom** → S3

### S2 · Travels — *only when trip history exists*
The only step that changes what the design is *about* rather than how it looks. Skipped for a
flat country list with no dates.
- **On screen:** their countries as map or list; a year range when trips carry dates; selection count
- **Can do:** select/deselect countries; narrow to a year range; switch source between countries and trips
- **Exits:** S3 · back to S1 with the deck rebuilt

### S3 · Direction — *what it's about*
The subject family, as big picture cards rendered from their own travels.
- **Subjects:** Flags · Passport · Route · World · Words · Milestones
- **Rules:** changing subject keeps garment colour, size, orientation · a subject never silently
  becomes another · leaving Flags resets Detail to Grid
- **Exits:** Flags → S4 · anything else → S5

### S4 · Detail — *only when subject = Flags*
Map, Animals and Landmarks are the shape the flags pour into, not separate subjects.
- **Choices:** Grid · Map · Animals · Plants · Landmarks · Heart · Circle
- **Rules:** only offer shapes the bundled artwork can fill; silhouettes scoped to selected countries
- **Exits:** S5

### S5 · Vibe — *the style*
Thirteen named styles, each a thumbnail of *their* design in that style — never a generic sample.
The highest-leverage screen: one tap transforms the shirt while keeping every prior decision.
- **Styles:** Showcase · Extreme · Maximal · Beachwear · Surf · Grunge · Minimalist · Streetwear ·
  Vintage · Retro · Outdoor · Premium · Typography
- **Rules:** a style seeds only **unlocked** axes; never overrides garment colour, aspect, size,
  side, subject, title or seed; the subject survives every style
- **Exits:** S6 · straight to S11 (a style change alone is often enough)

### S6 · Focus — *the composition*
Same subject, same style, arranged differently. The step for "nearly, but not quite".
- **On screen:** four live alternatives, ordered by what they've liked before
- **Can do:** take one · dismiss one (teaches the system) · ask for more
- **Exits:** S7

### S7 · Colour — *ink and cloth*
Two different decisions, kept visibly separate: how the artwork is inked, and what colour shirt it
prints on. One is the designer's choice, the other the wearer's.
- **Artwork:** Flag colours · Monochrome · Duotone · Match shirt · vintage grade
- **Garment:** the eight stocked colours, every one exact; a colour that can't be ordered is never offered
- **Exits:** S8

### S8 · Words — *the title*
Optional, and last among the creative steps: a title is a caption for a design that already exists.
- **On screen:** the title as it prints, live; suggestions drawn from their actual trips
- **Rules:** one ready-to-use suggestion at a time, no numbered lists · fresh on every press ·
  never a single country's name for a multi-country design · empty is valid
- **Exits:** S9

### S9 · Front — *the chest print*
Two faces, one product. Back carries the main design; front defaults to a small left-chest ribbon
— the wordmark over their flags.
- **Fit:** Full · Chest · None — **Side:** Left · Right *(chest only)* —
  **Art:** Ribbon · Complement · Match back — **Coverage:** Selected · All *(ribbon only)*
- **Rules:** the preview shows the print where it will land · "left chest" is the wearer's left
  (viewer's right) · a blank front shows a bare shirt, not an error
- **Exits:** S11 · down a gear to S10

### S10 · Fine Tune — *refine, by category*
A menu of categories opening one focused panel at a time, never one long scroll. **Only categories
that apply appear** — this is what keeps depth from becoming clutter.

| Category | Appears when | Contains |
|---|---|---|
| Finish | always | Clean, Vintage, Retro, Halftone, Distress, Tie-dye, Shatter, Riso, Mono |
| Layout | subject = Flags | fill algorithm, copies per country, scatter |
| Graphic | clipped, or Passport | passport stamp size/scatter/ink/which stamps; silhouette pick; shape size, rotation, corner, feather |
| Text | subject = Words | the word itself |
| Colour | always | treatment and vintage grade |
| Edges | always | torn-edge styles |
| Effects | always | distress, grain, fade, cracks, acid wash, tie-dye, shatter, halftone, ripple |
| Print | always | riso, newsprint, sun-faded, photocopy |

### S11 · Review — *both faces*
The whole garment and a plain-language summary. The last moment before money.
- **Can do:** Save to library (reproducible exactly) · Add to cart · back to editing intact
- **Exits:** S12

### S12 · Placement — *the real mockup*
A photorealistic shirt where the design is dragged, pinched and turned by hand, with the fabric's
folds falling across the ink.
- **Can do:** drag, pinch, twist · snap to Centre, Left chest, Reset
- **Rules:** artwork clipped to the real printable area, always · where they leave it is where it
  prints · folds bleed through the ink, never a grey box around it
- **Exits:** S13

### S13 · Size and quantity
Body size (XS–XXL) belongs here, not in the studio: it is a fit decision about a person, not a
design decision about artwork.
- **Rules:** only sizes stocked in the chosen colour · price in the buyer's currency
- **Exits:** S14

### S14 · Checkout and after
Hosted checkout, then the part most shops forget.
- **After:** the design stays in their library · shareable (the shirt is a travel brag) · order
  status through to delivery
- **Exits:** back into the studio to make another

---

## The rules that make it work

1. **Open finished, never blank.** A blank canvas asks the customer to do the work the product exists to do.
2. **The garment is always on screen.** Every change visible the instant it's made.
3. **Buying is reachable from everywhere.** Not a final gate; confidence rewarded with speed.
4. **A control appears only where it applies.** Contextual disclosure is what lets depth exist without cost.
5. **Garment decisions and artwork decisions are different modes.** Never mixed in one row.
6. **Browsing is not choosing.** Flicking through alternatives must not fill undo or teach the system.
7. **Choices survive each other.** Nothing a person has decided gets quietly reset.
8. **What they see is what prints.** Placement, colour and scale all match the print file.
9. **Every design is reproducible.** Which is what makes undo, branching and re-ordering free.
10. **Never offer what can't be made.** An unbuyable choice on screen is a promise broken at the door.

---

## Where the current build stands

All fourteen screens exist in some form. Specific gaps found in the code:

- **Orange and Royal can't be ordered.** Offered in the studio, no store variant. Blocked by name
  at add-to-cart rather than silently substituted — but rule 10 says they shouldn't be offered
  until Printful stocks them.
- **Two greys collapse into one.** Dark Heather and Sport Grey both map to the store's single
  heather; one ships a visibly different shirt from the one chosen.
- **The Instant deck shows names, not shirts.** Eight live thumbnails would be truer to "swipe
  through ready-made shirts", at the cost of eight renders.
- **Garment photography is 513×640.** Fine in the merch preview it was shot for; soft as a
  full-height studio hero.
