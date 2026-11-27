# M197 — Signature 6 — Retro Travel Poster

**Phase:** v2 Signature T-shirts (M190–M199)
**Depends on:** M196 (approved before this starts)
**Status:** Todo
**Pack:** `packages/design_studio/assets/signature/retro_poster.pack.json`
**Size:** L

---

## 1. The design

A mid-century travel poster look: flat colour bands (sunset/horizon), the country outline or national animal as the hero shape, the name in a poster face and "VISIT"/year lettering. The "designed for you" piece of the six.

## 2. Engine and recipe work

- Not landmark-based: only 1 landmark silhouette is bundled, so the poster uses outline (239) or animal (159) as the hero shape, a shared choice rule in the pack.
- New composition stage `PosterLayout` in design_forge_render: horizon bands, sun disc, hero shape, title block, limited palette (4–5 flat inks derived from the flag, with a contrast-safe fallback palette set).
- Envelope: band count, sun on/off, palette derivation (flag / warm / cool set), hero scale and position set, title font from M195's approved set.
- QA: flat-colour designs are prone to low contrast on matching garments; soft checks per garment.

**Main risk:** Most new engine work of the six (new stage); last so it benefits from M195 fonts and M196 outline rules.

## 3. The approval loop (same for every signature recipe)

1. **Draft:** I build or extend the engine stage and create `retro_poster.pack.json` (status `draft`) with a first base + envelope.
2. **Sheet:** I run the M191 CLI and hand the owner the contact sheet + QA report (`design_studio/contact_sheets/signature/retro_poster/`).
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
