# Signature Workbench (Design Lab)

Where each v2 signature T-shirt design is tuned against every country and approved
(M191, ADR-181). Recipes are pack files in `packages/design_studio/assets/signature/`;
the format is in `packages/design_forge/doc/SIGNATURE.md`.

## Open it

```sh
cd apps/design_lab && flutter run -d macos
```
Top bar → **Signatures**. The first pack in `index.json` opens.

## The screen

| Area | What it does |
|---|---|
| **Left: parameters** | Every recipe parameter. The value applies to **every country**. Tick **Vary** to let variations move it; set the range (min – max, or `a, b, c` for choices). |
| **Centre: all countries** | Every flag's hero on the chosen shirt colour, with a QA dot: green pass, amber warning, red failure (hover for the reason). Filter to Warnings/Failures, search by name, switch the shirt colour. ✎ = has an override, ★ = curated hero. |
| **Right: one country** | Large hero on the 6 orderable shirt colours, QA detail, the first 12 variations (**v3 → hero** makes that variation the country's hero), and the country's **override**. |
| **Far right: on the shirt** | The selected country's hero on the app's own shirt mockup. **Front / Back / Both** (or swipe) turns the shirt; a dot marks each face that prints. Below it, the **print layout**: presets (Back, Front, Crest + back, Front + back, Front + neck, Crest only), then each face's zone and size. The dashed box is the zone's largest printable area. **Roavvy mark at back neck** (on by default) adds a small `roavvy.com` below the back collar in black or white to suit the shirt; it only prints with a back design, which then starts 1.4" lower. The layout is saved in the pack and is what the app's tee page opens on; travellers can still change it there. |
| **Top bar** | Pack picker, status (`draft v1 · unsaved`), Undo/Redo, **Save draft**, **Export sheet**, **Approve…** |

Edits re-render only what changed: a parameter edit re-renders every country, an override
or hero change re-renders one, and a print-layout edit re-renders nothing but the shirt
(a slider drag is one undo step).

## Rules of thumb

1. **Fix the shared recipe first.** Override a country only when that flag genuinely needs
   it, and say why (the reason is required and saved in the pack). Never encode one flag's
   anatomy in the shared recipe.
2. **Keep ranges narrow.** Variations should all look approved; wide ranges produce
   designs nobody reviewed.
3. **Warnings are for you to judge.** "Disappears on White" for a white-field flag may be
   fine if you won't sell it on white.

## Quality checks

Run on the transparent artwork at 300×375 (`SignatureQa`, thresholds in `QaThresholds`):

- **Hard (block approval):** render error or missing flag; artwork < 8% or > 92% of the
  print area; artwork running into the print-area edge.
- **Soft (shown to you):** more than 35% of the artwork vanishes on one of the 6 orderable
  shirts (close in both brightness and colour); more than 2% of the ink is isolated specks.

## Approve

**Approve…** asks for the lock countries (default US, JP, BR, FR, ZA, SC), then checks every
country's hero and its first 8 variations (≈ 2,400 renders, several minutes). Any hard failure
lists the blockers and stops. Otherwise it:

1. saves the pack as `approved` with `approvedAt` and locks (version unchanged, so the
   variations you reviewed are the ones that ship);
2. writes `design_studio/contact_sheets/signature/<pack>/v<version>/` (sheet + QA report;
   commit the `qa_report.json`);
3. offers **Update goldens now**, which runs
   `flutter test --update-goldens test/signature_golden_test.dart` in
   `packages/design_forge_render`. Review the PNGs in `test/goldens/signature/<pack>/` and
   commit them with the pack.

Editing an approved pack reopens it as a draft at the next version; users keep seeing the
approved version until you approve again.

## Headless review sheet

```sh
cd apps/design_lab
PACK=torn_flag flutter test test/signature_qa_cli_test.dart
# optional: COUNTRIES=us,jp,br  VARIATIONS=8  LABEL=my-review
```
Writes the same sheet + report as the UI to `design_studio/contact_sheets/signature/<pack>/<label>/`
(PNGs are git-ignored). All 271 heroes take about 50 s.

## Two-country (pair) packs (ADR-185)

A pack with `"countries": 2` is one design for two countries: A (left/top) and B
(right/bottom). The order matters: `us+co` and `co+us` are different designs.

- **Sheet:** shows the pack's `samplePairs`, not all 271 countries. If the pack lists
  none, it shows the default set of 32 pairs in `SignatureSweep.defaultSamplePairs`:
  - look-alikes: `id+mc`, `ro+td`, `nl+lu`, `ie+ci`;
  - same-colour neighbours: `fr+it`, `us+gb`, `co+ec`, `de+be`;
  - emblems: `mx+pt`, `es+cr`, `py+dz`, `br+ar`, `sa+ae`;
  - non-rectangular: `np+ch`, `bt+np`;
  - cantons and hoist triangles on the B side: `co+us`, `hu+us`, `mx+us`, `ca+us`,
    `gr+cy`, `au+nz`, `jm+cu`;
  - dark, light and disc flags: `ly+cy`, `jp+kr`, `pk+in`;
  - your references: `ve+pr`, `us+co`, `dz+py`, `gb-eng+pt`;
  - crosses and regression flags: `fi+se`, `za+gb`, `sc+mu`.
- **A / B picker:** in the sheet toolbar, pick country A and country B, use ⇄ to swap
  them, and press **Show** to add that pair to the sheet and inspect it. The inspector
  also has a ⇄ button that opens the same pair in the other order.
- **Overrides:** the inspector's override box sets a **pair override** for that ordered
  pair. A fix for one country wherever it appears goes in the pack file as a country
  override using `{slot}` (see `SIGNATURE.md`).
- **Shirt panel and print layout** work as for single packs.
- **Approve** asks for lock pairs (`a+b`, default
  `us+co, fr+it, mx+pt, jp+kr, np+ch, id+mc`).

### Pair checks (in addition to the usual ones)

| Code | Level | Fires when |
|---|---|---|
| `pair_seam` | warn | The two flags have nearly the same colour where they meet (median RGB distance under 60), so the seam disappears. Never fires when the seam has a gap. |
| `pair_emblem` | fail | A flag shows less than 70% of its emblem, canton or symbol (from `FlagFocus`). |
| `pair_balance` | warn | One side holds less than 40% of the ink. |
| `pair_swap` | fail | The same pair in the other order fails a hard check (heroes only). |

The seam and the flag crops come from the composition (`PairGeometry.of`). A
composition that doesn't report them yet (anything before M209's `splitPair`) is judged
against a vertical seam through the middle, with no emblem check. This makes the seam
check noisy for layouts that aren't side by side.

### Headless

```sh
PACK=<pair_pack> flutter test test/signature_qa_cli_test.dart
# optional: PAIRS=us+co,fr+it  VARIATIONS=8  LABEL=…
# a pack not in the bundle yet: PACK_FILE=/path/to/x.pack.json
```
