# M194 — Signature 3 — Crest / Badge Emblem

**Phase:** v2 Signature T-shirts (M190–M199)
**Depends on:** M193 (approved before this starts)
**Status:** Todo
**Pack:** `packages/design_studio/assets/signature/crest_badge.pack.json`
**Size:** L

---

## 1. The design

A varsity/club-style crest: shield or roundel, country name on a ribbon, the national animal or the country outline in the centre, founding-style text ("EST. <first visit year>").

## 2. Engine and recipe work

- Built on the `badge` family. Centre motif: national animal silhouette where available (159 countries), else the country outline (239). The pack's fallback rule is shared, not per country.
- Text layout must handle long names ("Bosnia and Herzegovina", "Saint Vincent and the Grenadines"): fit rules (ribbon arc length, two-line split, short-name table already in shared_models) are engine rules tested against the 20 longest names.
- Envelope: shield shape set (4), palette from flag colours vs 2-colour ink, ribbon style, motif scale, outline weight.

**Main risk:** Typography on curved ribbons for long names; this is where the QA text-size check matters most.

## 3. The approval loop (same for every signature recipe)

1. **Draft:** I build or extend the engine stage and create `crest_badge.pack.json` (status `draft`) with a first base + envelope.
2. **Sheet:** I run the M191 CLI and hand the owner the contact sheet + QA report (`design_studio/contact_sheets/signature/crest_badge/`).
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
