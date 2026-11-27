# M192 — Signature 1 — Torn Flag

**Phase:** v2 Signature T-shirts (M190–M199)
**Depends on:** M191 (approved before this starts)
**Status:** Todo
**Pack:** `packages/design_studio/assets/signature/torn_flag.pack.json`
**Size:** M

---

## 1. The design

The distressed, torn-into-hanging-strips flag (ADR-179). The engine work is largely done and US Classic is tuned; what's missing is making it reliable for **every** flag and approving it.

## 2. Engine and recipe work

- Start from the M190 seed pack (US Classic as base).
- Run all 272 flags. Expected weak spots, from ADR-179's cut-line rule:
  - flags with no lengthwise stripes (JP, BR, SC, CA, CH…) only fray at the free end; check they still read as "torn" and not just "ragged";
  - flags with fine detail or emblems (MX, ES, PT, BT, Lesotho-type crests) where distress may erase the emblem: consider an envelope cap on `distress` tied to flag complexity, as a shared rule, not per country;
  - very dark or very light flags on matching garment colours (contrast soft checks).
- Envelope candidates: `seed`, `distress` 0.55–0.85, `curvature`, `waviness`, `tearLength`, `fringeDepth`, `brightness` −0.12–0; `flagVariant` fixed.
- Seychelles starter preset becomes a regression country (it must never gain fake stripes).

**Main risk:** Lowest risk; it is first so the M191 workbench and approval loop get proven on a nearly finished design.

## 3. The approval loop (same for every signature recipe)

1. **Draft:** I build or extend the engine stage and create `torn_flag.pack.json` (status `draft`) with a first base + envelope.
2. **Sheet:** I run the M191 CLI and hand the owner the contact sheet + QA report (`design_studio/contact_sheets/signature/torn_flag/`).
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
