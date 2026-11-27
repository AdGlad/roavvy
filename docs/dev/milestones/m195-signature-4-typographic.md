# M195 — Signature 4 — Bold Typographic

**Phase:** v2 Signature T-shirts (M190–M199)
**Depends on:** M194 (approved before this starts)
**Status:** Todo
**Pack:** `packages/design_studio/assets/signature/bold_type.pack.json`
**Size:** M

---

## 1. The design

A type-led design: country name set huge, with coordinates, a short descriptor and the trip year as secondary lines, plus a small flag-colour accent. Should look like a modern graphic tee, not a souvenir.

## 2. Engine and recipe work

- Built on the `typographic` family. Needs 3–4 licensed display fonts bundled (OFL only; list in the pack) and a fit algorithm: one line if it fits at ≥ 70% width, else a deliberate two-line break at word boundaries.
- Coordinates = country centroid from `country_lookup` data (offline), formatted DMS.
- Envelope: font from the approved set, weight, tracking, layout set (stacked / centred / left-aligned), accent style (stripe, underline, block), ink = garment-contrast ink or flag colour.
- QA: text cap height and stroke width are the main soft checks.

**Main risk:** Font licensing and long-name fitting; low asset risk (works for every country).

## 3. The approval loop (same for every signature recipe)

1. **Draft:** I build or extend the engine stage and create `bold_type.pack.json` (status `draft`) with a first base + envelope.
2. **Sheet:** I run the M191 CLI and hand the owner the contact sheet + QA report (`design_studio/contact_sheets/signature/bold_type/`).
3. **Review:** the owner opens the pack in the Lab Signature Workbench, marks countries/variations they dislike (the existing delete-to-learn tags apply) and notes what's wrong.
4. **Tune:** I change the **shared** recipe first; per-country overrides only where one flag genuinely needs it, each with a reason. Repeat 2–4.
5. **Approve:** the owner presses Approve in the Lab. Pack, locks, goldens and the final sheet are committed. Only then does the next recipe start.

## 4. Definition of done

- [ ] Zero hard QA failures for every country's hero and its first 8 variations.
- [ ] Soft failures reviewed by the owner (accepted or fixed), listed in an "As built" section added on completion.
- [ ] Owner approved in the Lab (pack `status: approved`, `approvedAt` set).
- [ ] Goldens for the 6 lock countries committed; mobile parity test extended to this pack and green.
- [ ] No V1 merch code changed.

## 5. Owner gate

The owner's approval in the Lab is the only exit from this milestone. I do not start the next signature recipe until this pack is approved.
