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
