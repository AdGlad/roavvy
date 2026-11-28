# M207 — Lab Pair Workbench and pair QA sheet

**Phase:** Two-country Signatures (M206–M214, ADR-185)
**Depends on:** M206
**Status:** Todo
**Size:** M

---

## 1. Why

There are 272 × 271 pairs, too many for a full sheet. Approval needs a **fixed, hard sample** plus a way to try any pair.

## 2. Scope

- **Signatures screen:** pair packs show a country A / country B picker with a ⇄ swap button. The shirt panel, print layout and `roavvy.com` mark work unchanged.
- **Sample pair set (~32):** chosen to break designs:
  - look-alikes: ID+MC, RO+TD, NL+LU, IE+CI;
  - same-colour neighbours: FR+IT, US+GB, CO+EC;
  - emblem flags: MX+PT, ES+CR, PY+DZ;
  - non-rectangular: NP+CH (NP+any);
  - canton flags on the B side: CO+US, HU+US;
  - very dark/light: LY, CY, JP+KR;
  - the reference pairs: VE+PR, US+CO, HU+US, DZ+PY.
- **Pair QA checks** (in addition to the existing ones):
  - **two-flag legibility:** the colour distance across the seam is above a minimum, or the seam is drawn;
  - **emblem not cut:** the focus point/emblem box keeps at least 70% visible;
  - **balance:** each half's ink area is between 40% and 60%;
  - **swap sanity:** A/B and B/A both pass.
- **Headless sheet:** `PACK=<id> flutter test test/signature_qa_cli_test.dart` renders the pair sample for pair packs (`PAIRS=us+co,fr+it` overrides it).
- **Approve** works as for single packs (locks on the sample pairs).

## 3. Definition of done

- [ ] The pair picker, swap and sheet work for a dummy pair pack.
- [ ] The new QA checks have unit tests (look-alike pair → warn; emblem cut → fail).
- [ ] The `signature-workbench.md` guide is updated.

## As built (2026-11-28)

- **Signatures screen** (`apps/design_lab/lib/signature/signature_screen.dart`). For pair packs:
  - the sheet shows the sample pairs, plus any pair added with the A/B picker (`pair-a`, `pair-b`, ⇄ `pair-swap`, `pair-show`);
  - the inspector has a ⇄ button (`inspect-swap`) and labels its override box as the pair override;
  - the lock dialog takes `a+b` pairs;
  - shirt panel and print layout are unchanged.
- **`SignatureSweep`** works on pack keys:
  - `cell` uses `variationFor`, adds `PairQa` for pair packs, and for heroes also checks the swapped order;
  - new: `defaultSamplePairs` (32), `defaultLockPairs`, `keysFor`, `defaultLocksFor`, `probeKey`;
  - the contact sheet labels pairs `US + CO`.
- **`PairQa`** (`packages/design_forge_render/lib/src/qa/pair_qa.dart`):
  - `analyse` / `checkImage(image, geometry:)`, `seamLegibility`, `leftShare`, `emblemFinding(FlagCrop)`, `swapFinding(swapKey, report)`;
  - codes `pair_seam` (warn), `pair_emblem` (fail), `pair_balance` (warn), `pair_swap` (fail).
- **Geometry** comes from `PairGeometry.of(recipe)` (M206). With no geometry, QA uses a vertical centre seam and skips the emblem check.
- **Headless sheet:** pair packs sheet their sample pairs. `PAIRS=` overrides the set, and `PACK_FILE=` sheets a pack that isn't bundled yet.
- **Fixed in passing:** `SignatureEdit` dropped the pack's print `layout` on any base, range, override or hero edit, and on approve. It now keeps `layout`, `countries` and `samplePairs`.
- **Tests:**
  - `pair_qa_test.dart` (7): a look-alike pair warns, a cut emblem fails;
  - `signature_workbench_test.dart` (+4): a pair cell with swap, the sample set, edits and approval keeping layout and pair fields, and a widget test covering the picker, swap and approve with pair locks.
- **Not shipped:** no pair pack is in assets; M209 adds the first one.
- **Known limit:** until a composition reports geometry, the seam check judges a vertical centre line. On stacked layouts (the test-only duo pack) every pair warns `pair_seam`.
