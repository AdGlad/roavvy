# M196 — Signature 5 — Silhouette Fill

**Phase:** v2 Signature T-shirts (M190–M199)
**Depends on:** M195 (approved before this starts)
**Status:** Todo
**Pack:** `packages/design_studio/assets/signature/silhouette_fill.pack.json`
**Size:** M

---

## 1. The design

The country's outline filled with its flag (or a halftone/print-style treatment of it), with the name underneath. Instantly recognisable, works for every country.

## 2. Engine and recipe work

- Built on `singleHero` with the outline clip (`country_paths`, 239). Gap: 33 flag codes without an outline (mostly territories). Fallback: the pack excludes them explicitly, or they get the roundel clip; owner decides on the sheet.
- Tiny or fragmented countries (MV, KI, VA, SG, archipelagos) need a shared rule: bounding-box normalisation with a minimum fill area, or switch to the roundel when coverage < threshold. QA coverage check flags them.
- Envelope: fill treatment set (flag / halftone / vintage / stamp texture from Print Styles), outline stroke, name placement, flag rotation for best fit.

**Main risk:** Small/fragmented countries and outline gaps.

## 3. The approval loop (same for every signature recipe)

1. **Draft:** I build or extend the engine stage and create `silhouette_fill.pack.json` (status `draft`) with a first base + envelope.
2. **Sheet:** I run the M191 CLI and hand the owner the contact sheet + QA report (`design_studio/contact_sheets/signature/silhouette_fill/`).
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
