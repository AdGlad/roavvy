# M191 — Design Lab: Signature Workbench (all-countries contact sheet, QA, approve)

**Phase:** v2 Signature T-shirts (M190–M199)
**Depends on:** M190
**Status:** Todo
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

- [ ] The torn-flag seed pack opens and shows all 272 countries with QA badges.
- [ ] Editing a base parameter updates the whole sheet; editing an override updates one tile.
- [ ] Approve is refused with any hard failure and succeeds otherwise, writing pack + goldens + sheet.
- [ ] The CLI produces the same report as the UI for the same pack.
- [ ] `flutter build macos` ✓; Lab tests green.
