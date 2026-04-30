# M87 — Passport PDF Generation & Mobile Preview

**Branch:** `milestone/m87-passport-pdf`
**Phase:** 18 — Passport Stamp Image Quality
**Status:** In Progress (2026-05-01)

## Goal

User can export their passport stamp collection as a multi-page PDF book (cover + stamp pages + summary), preview it page-by-page in-app, and share the PDF file.

## Scope

In: `passport_pdf_service.dart` (new), `passport_book_screen.dart` (new),
    `card_editor_screen.dart` (entry point), `pubspec.yaml` (add `pdf` package)
Out: Blurb/Lulu upload, PDF trim/bleed metadata, background isolate caching,
     quokka emblem, Android, web, Firestore, new Drift schema

## Tasks

- [ ] T1 -- PassportPrintConfig + PassportPdfService
- [ ] T2 -- PassportBookScreen (in-app preview + share)
- [ ] T3 -- Entry point in card_editor_screen.dart

---

## T1 -- PassportPrintConfig + PassportPdfService

**File:** `lib/features/cards/passport_pdf_service.dart`
**pubspec:** add `pdf: ^3.10.8`

### PassportPrintConfig

Const class with A6 at 300 DPI:
- `pageWidthPx = 1240` (4.133 in × 300)
- `pageHeightPx = 1748` (5.827 in × 300)
- `stampsPerPage = 8`
- `coverBackground = Color(0xFF0A1628)` (deep navy)
- `stampPageBackground = Color(0xFFF5F0E8)` (aged cream)

### PassportPdfPageType enum

`cover | stamps | summary`

### PassportPdfPage

Value class:
- `type`: PassportPdfPageType
- `stamps`: List<StampData> (empty for cover/summary)
- `tripSummary`: List<TripRecord> (for summary page only)
- `countryCodes`: List<String> (for summary page only)

### PassportPdfService

Three static methods:

**`buildPages(List<TripRecord> trips, List<String> countryCodes) -> List<PassportPdfPage>`**
- Always: cover page first
- Lay out ALL stamps using `PassportLayoutEngine.layout(forPrint:true, canvasSize: Size(pageWidthPx, pageHeightPx))`
- Partition result into groups of `stampsPerPage`; each group → one stamps page
- Always: summary page last (uses trips + countryCodes)
- Minimum 1 stamps page even if trips empty (empty stamps list = blank page with cream bg)

**`renderPage(PassportPdfPage page) -> Future<Uint8List>` (PNG bytes)**
Cover page:
  - Navy bg rectangle
  - "ROAVVY" centered: white, 96px, w800, letterSpacing 8
  - "PASSPORT" below: gold (0xFFD4A017), 42px, w400, letterSpacing 12
  - Thin gold horizontal rule (3px, 60% width) between title lines
  - Year range at bottom (e.g. "2018 – 2025"): white54, 32px — empty if no trips

Stamps page (index >= 1, not last):
  - Aged cream bg
  - Draw all stamps using `StampPainter(stamp).paint(canvas, pageSize)`

Summary page (last):
  - Navy bg
  - "YOUR TRAVELS" header: gold, 56px, w700, letterSpacing 4
  - Sorted country list: 2-column wrap, each row = flag emoji + country name in white
  - Footer: date range + count e.g. "42 countries · 2015–2025": gold

**`generate(List<TripRecord> trips, List<String> countryCodes) -> Future<Uint8List>`**
1. `buildPages()` → list of PassportPdfPage
2. For each page: `await renderPage(page)` → PNG Uint8List (serial, avoids OOM on 10+ pages)
3. Assemble PDF using `pdf` package:
   - `pw.Document()`, one `pw.Page` per rendered PNG
   - Page format: `PdfPageFormat(pageWidthPx * 72 / 300, pageHeightPx * 72 / 300)` (pt units)
   - Page build: `pw.Image(pw.MemoryImage(pngBytes), fit: pw.BoxFit.fill)`
4. Return `await doc.save()`

AC:
- 1 trip → cover + 1 stamp page + summary = 3 pages
- 9 stamps → cover + 2 stamp pages + summary = 4 pages
- 0 trips → cover + 1 blank stamp page + summary = 3 pages
- PDF bytes non-empty; page count correct.

---

## T2 -- PassportBookScreen

**File:** `lib/features/cards/passport_book_screen.dart`

`PassportBookScreen({required List<TripRecord> trips, required List<String> countryCodes})`
`ConsumerStatefulWidget` (needs tripRepositoryProvider for countries if needed, but receives data directly)

Actually: plain `StatefulWidget` — data passed in at construction.

**State:**
- `_state`: `_BookState.loading | ready | error`
- `_pages`: `List<Uint8List>` rendered PNG pages (same list used in preview)
- `_pdfBytes`: `Uint8List?` raw PDF bytes
- `_currentPage`: int (0-indexed)
- `_sharing`: bool

**initState:** call `_generate()` async

**`_generate()`:**
1. Call `PassportPdfService.generate()` → `_pdfBytes`
2. Call `PassportPdfService.buildPages()` then `renderPage()` for each → `_pages`
   Wait — to avoid double rendering, have `generate()` also return the rendered pages.
   Change `generate()` to return `PassportPdfResult({Uint8List pdfBytes, List<Uint8List> pages})`
   so we render once and get both.

**`_share()`:**
1. Write `_pdfBytes` to `getTemporaryDirectory()/roavvy_passport.pdf`
2. `Share.shareXFiles([XFile(path)], subject: 'My Passport Book — Roavvy')`

**Layout (Scaffold, dark bg 0xFF0A1628):**
- AppBar: title "Passport Book", dark bg, white
- Loading state: `CircularProgressIndicator.adaptive()` + "Generating your passport…" label
- Error state: text + retry button
- Ready state:
  - `PageView.builder(controller, itemCount: _pages.length, itemBuilder: → Image.memory(pages[i], fit:BoxFit.contain))`
  - Bottom bar (surface color, safe area):
    - Page indicator dots (max 7 shown with truncation, gold for current)
    - "Share PDF" amber FilledButton (disabled while _sharing)

AC: Loading shown during generation; pages swiped horizontally; share opens system sheet; error state shown on failure.

---

## T3 -- Entry point in card_editor_screen.dart

**File:** `lib/features/cards/card_editor_screen.dart`

In the passport template's bottom action bar (near the existing Share + Print buttons), add:
- "Book" `OutlinedButton.icon` with a book icon
- Only visible when `_template == CardTemplateType.passport`
- `onPressed`: read `_trips` and `_countryCodes` from existing state, push `PassportBookScreen`

AC: Button visible on passport template only; tapping navigates to PassportBookScreen with correct data.

---

## Risks

| Risk | Mitigation |
|---|---|
| `pdf` package coordinate system (points not pixels) | Convert px → pt: pt = px * 72 / 300 |
| `StampPainter.paint` requires a live `Canvas` + `Size` | Use `ui.PictureRecorder` directly; StampPainter.paint is a pure Canvas call |
| OOM on many stamps pages | Serial rendering (one page at a time); free images after PNG encode |
| `pdf` package not in pubspec | Add `pdf: ^3.10.8` to dependencies |
