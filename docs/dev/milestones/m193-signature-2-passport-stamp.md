# M193 — Signature 2 — Vintage Passport Stamp

**Phase:** v2 Signature T-shirts (M190–M199)
**Depends on:** M192 (approved before this starts)
**Status:** Todo
**Pack:** `packages/design_studio/assets/signature/passport_stamp.pack.json`
**Size:** M/L

---

## 1. The design

A single bold entry stamp for the country, inked and slightly rotated, with the user's trip date in the stamp's date slot, as on the production stamp tees. No border.

## 2. Engine and recipe work

- Uses the real stamp PNGs (`assets/mobile_png`, ~196 countries with entry/exit stamps) and the existing `passportStamp` family. Date goes at the stamp's metadata position (see the passport-stamps memory/ADR).
- **Coverage gap:** countries without a stamp asset (~76 of 272 flags). The pack declares a fallback: a generated stamp (country name + outline from `country_paths` in a stamp frame) built as a shared engine stage, not per country. The owner approves the fallback look separately on the sheet.
- Envelope candidates: `seed`, rotation −12°…+12°, ink colour from a fixed set of 4 inks, ink wear 0.2–0.6, entry vs exit stamp, date format.
- Hero needs a date: with no trip selected, show the country's first visit date; in the Lab, a fixed sample date.

**Main risk:** Asset coverage and date legibility at print size.

## 3. The approval loop (same for every signature recipe)

1. **Draft:** I build or extend the engine stage and create `passport_stamp.pack.json` (status `draft`) with a first base + envelope.
2. **Sheet:** I run the M191 CLI and hand the owner the contact sheet + QA report (`design_studio/contact_sheets/signature/passport_stamp/`).
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
