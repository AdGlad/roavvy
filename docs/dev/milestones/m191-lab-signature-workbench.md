# M191 — Design Lab: Signature Workbench (all-countries contact sheet, QA, approve)

**Phase:** v2 Signature T-shirts (M190–M199)
**Depends on:** M190
**Status:** Done (branch `feat/m191-signature-workbench`)
**Primary target:** `apps/design_lab` · `packages/design_forge_render` (SignatureQa)
**Size:** L

---

## 1. Why this exists

This is the "work outside the app" tool. The owner develops one recipe at a time on macOS, sees it applied to every country at once, fixes the weak ones, and approves it. Approval writes the pack file the app ships. It generalises the Torn Flag studio (`apps/design_lab/lib/torn_flag/`) from one flag to all of them.

## 2. Architecture

```
packages/design_forge_render/lib/src/qa/
  signature_qa.dart       SignatureQa.check(recipe, image) -> QaReport{hard[], soft[], score}
apps/design_lab/lib/signature/
  signature_screen.dart   workbench: pack picker | contact sheet | inspector
  contact_sheet_view.dart lazy grid of all countries, QA badge per tile
  envelope_editor.dart    sliders/sets for base + envelope ranges (writes pack in memory)
  override_editor.dart    per-country deltas with required reason
  variation_strip.dart    first N variations for the selected country
  signature_io.dart       read/write packages/design_studio/assets/signature/*.pack.json
apps/design_lab/test/signature_qa_cli_test.dart   headless: PACK=<id> -> report + PNG sheet
```

- Rendering goes through `RenderService` (design_studio) with the disk asset resolver, the same as the Torn Flag studio. Previews at 600×750 on a worker isolate pool; selected tile at full print size (3600×4500) on demand.
- **QA checks** (ADR-181 §4): hard = artwork coverage < 8% or > 92% of the print area, alpha touching the print-area edge where the recipe doesn't allow bleed, any asset fallback fired, render error. Soft = ink/garment luminance contrast < 3:1 on any of the 6 orderable garment colours, features thinner than 1.5 px at 300 dpi, text cap height < 0.25". Thresholds live in one `QaThresholds` constant so they can be tuned once.
- **Country set** = every code with a bundled flag SVG (272), grouped by continent, with a toggle for "countries users have" (top 60 by app usage, list committed as JSON, no personal data).

## 3. Tasks

- **T1 SignatureQa** in design_forge_render with unit tests on synthetic images (empty, clipped, low contrast, thin line).
- **T2 Workbench screen** added to the Lab's navigation next to Torn Flag. Pack picker (all packs in the assets folder, plus "New from preset").
- **T3 Contact sheet**: all countries, QA badge (green/amber/red), filter "failures only", click → inspector. Re-renders only tiles affected by an edit (override edits re-render one tile; base/envelope edits re-render all, cancellable).
- **T4 Inspector**: full-size render on 6 garment colours (reuse the garment mockup tint from Studio V2), QA detail, variation strip (first 12 variations), "save as hero seed".
- **T5 Envelope + override editors** with undo; override requires a reason string.
- **T6 Approve flow**: blocked while any hero or sampled variation (first 8 per country) has a hard failure. On approve: set `status: approved`, `version++`, `approvedAt`, recompute `locks` for 6 sample countries (US, JP, BR, FR, ZA, SC by default, editable), write the pack, write goldens for the locks, and write a contact-sheet PNG + QA report to `design_studio/contact_sheets/signature/<id>/v<version>/`.
- **T7 CLI**: `PACK=torn_flag flutter test test/signature_qa_cli_test.dart` in `apps/design_lab` writes the same report + sheet headlessly, so I can produce review sheets without the owner opening the Lab.
- **T8 Docs**: `docs/design/signature-workbench.md`: how to tune, override, approve.

## 4. Acceptance

- [x] The torn-flag seed pack opens and shows all 271 flag codes with QA badges.
- [x] Editing a base parameter updates the whole sheet; editing an override updates one tile (re-render is keyed on each hero's recipeId).
- [x] Approve is refused with any hard failure and succeeds otherwise, writing pack + locks + sheet/report; goldens via the offered command (see below).
- [x] The CLI and the UI share `SignatureSweep`, so they produce the same report for the same pack.
- [x] `flutter build macos` ✓; Lab 92 tests, design_forge_render 66, design_studio 85, design_forge 135 green; analyze clean.

## 6. As built (2026-11-27)

- `packages/design_forge_render/lib/src/qa/signature_qa.dart`: `SignatureQa.analyse` (pure over RGBA) / `checkImage`, `QaReport`, `QaThresholds` (one constant set, 6 orderable garments).
- `apps/design_lab/lib/signature/`: `signature_io.dart` (packs, index, review output, golden runner), `signature_sweep.dart` (render + QA per cell, report JSON, contact sheet), `signature_edit.dart` (pure edits, approve, reopen-as-draft), `signature_screen.dart` (workbench). Lab top bar: **Signatures**.
- `apps/design_lab/test/signature_qa_cli_test.dart` (headless review), `signature_workbench_test.dart` (9, incl. edit → save → undo → approve end to end); `packages/design_forge_render/test/signature_qa_test.dart` (8), `signature_golden_test.dart` (approved packs' locks; none yet).
- First full run, torn_flag draft: 271 countries in 50 s, 0 hard failures, 120 pass / 151 warnings (contrast on matching shirt colours).
- Guide: `docs/design/signature-workbench.md`.

**Deviations from the plan, and why:**
- **Version is not bumped on approval.** Variations are seeded by version, so bumping on approve would ship different variations from the ones reviewed. Instead, editing an approved pack reopens it as a draft at version + 1.
- **Contrast = brightness AND colour.** A luminance-only rule flagged Brazil's green on a red shirt; a pixel now "vanishes" only when its contrast ratio < 1.5 and RGB distance < 110.
- **Thin features** are measured as isolated specks at preview size; a true 300 dpi line-width check needs a print-size render and moves to M193+ if a recipe needs it. **Text cap height** needs typography data and arrives with the first text recipe (M193/M195).
- **"Countries users have" toggle** replaced by search: there is no usage list without user data.
- **Goldens** are written by `flutter test --update-goldens` (the Lab's "Update goldens now" button runs it) rather than by the Lab itself, so they are always produced by the same comparator that checks them.
- **Review PNGs are git-ignored** (a full sheet is ~20 MB); each approval's `qa_report.json` is committed.
