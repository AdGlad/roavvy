# M44 — Passport Stamp Card: Authentic Stamp Renderer

**Goal:** Replace the widget-based `PassportStampsCard` with a `CustomPainter`-driven stamp renderer that draws realistic ink-style country stamps on a paper-textured background, using real trip dates and ENTRY/EXIT labels — making it the most visually distinctive of the three card templates.

**Branch:** `milestone/m44-passport-stamp-renderer`

**ADR:** ADR-096

---

## Scope

### Included
- `StampData` rendering model + `StampShape` enum (4 shapes: circular, rectangular, oval, double-ring)
- `StampPainter` CustomPainter — ink-style border, rotation, transparency, per-shape drawing logic
- `PassportLayoutEngine` — deterministic seeded positioning, partial-overlap allowed, full occlusion prevented, margin respect
- `PaperTexturePainter` — procedural off-white grain background (no PNG asset)
- Upgraded `PassportStampsCard` widget — accepts `List<TripRecord>? trips` + `List<String> countryCodes`; maps trips to stamps with date (DD MMM YYYY) + ENTRY/EXIT label
- `CardGeneratorScreen` — reads `tripRepositoryProvider` and passes `trips` to `PassportStampsCard` only; Grid/Heart unchanged
- Updated `card_templates_test.dart` for new signature

### Excluded
- Server-side image generation (Printful handles high-res merch)
- New canvas sizes / poster/shirt dimensions
- Airport codes (not in data model)
- City labels (city detection not built)
- Hexagonal stamp shape, vintage worn stamp, block typography stamp (deferred)
- Rare/milestone stamp gamification (deferred)
- Sound effects

---

## Tasks

### Task 151 — `StampData` model and `StampShape` enum

**Deliverable:** `lib/features/cards/passport_stamp_model.dart` — pure Dart file containing:
- `StampShape` enum: `circular`, `rectangular`, `oval`, `doubleRing`
- `StampColor` enum: `blue`, `red`, `purple`, `green`, `black` (each maps to a specific `Color` constant)
- `StampData` class (immutable): `countryCode`, `countryName`, `dateLabel` (nullable String, formatted "DD MMM YYYY"), `entryLabel` ("ENTRY" or "EXIT"), `shape`, `color`, `rotation` (radians), `center` (`Offset`), `scale` (double, default 1.0)
- `StampData.fromTrip(TripRecord trip, {required StampShape shape, required StampColor color, required double rotation, required Offset center, required bool isEntry})` factory
- `StampData.fromCode(String code, {required StampShape shape, required StampColor color, required double rotation, required Offset center})` factory — fallback for countries without trips

**Acceptance criteria:**
- `StampData.fromTrip` formats `trip.startedOn` as "12 JAN 2023"
- `StampData.fromCode` produces `dateLabel: null` and `entryLabel: 'ENTRY'`
- All fields are final; `StampData` is not a domain model (no Firestore serialisation)
- Unit tests in `test/features/cards/passport_stamp_model_test.dart` (date formatting, factory outputs)

**Dependencies:** `TripRecord` from `packages/shared_models`; `dart:intl` via `intl` package (already in pubspec)

---

### Task 152 — `StampPainter` CustomPainter

**Deliverable:** `lib/features/cards/stamp_painter.dart` — `StampPainter extends CustomPainter` that draws a single `StampData` onto a `Canvas`. Drawing logic:

- `circular`: outer circle border (2pt stroke) + inner concentric circle (1pt) + country name arc text along top + date text at centre + entry label at bottom
- `rectangular`: double-border rectangle (outer 2pt, inner 1pt, 3px gap) + country name (bold uppercase) + date + entry label stacked
- `oval`: `rrect` with high radius + single border + content layout same as rectangular
- `doubleRing`: two concentric circles (outer 2pt, inner 1.5pt) + wavy or serrated inner ring effect via `Path.lineTo` segments + country name + date

All shapes:
- Use `canvas.save()` / `translate(center)` / `rotate(rotation)` / `restore()` pattern
- Paint stroke colour from `StampData.color` at 75% opacity (ink worn effect)
- Fill transparent (stamps are outline-only)
- Text colour matches border colour
- Font: monospace (use `TextStyle(fontFamily: 'Courier', ...)` or system monospace)

**Acceptance criteria:**
- `StampPainter` is a pure `CustomPainter` (no Flutter widget tree inside `paint()`)
- All 4 shapes render without assertion errors
- `shouldRepaint` returns false when `StampData` is unchanged
- Widget test in `test/features/cards/stamp_painter_test.dart`: wrap in `CustomPaint` + `RepaintBoundary`, call `toImage`, verify non-null

**Dependencies:** Task 151 (`StampData`)

---

### Task 153 — `PassportLayoutEngine`

**Deliverable:** `lib/features/cards/passport_layout_engine.dart` — `PassportLayoutEngine` class with:

```
static List<StampData> layout({
  required List<TripRecord> trips,
  required List<String> countryCodes,
  required Size canvasSize,
  int seed = 0,
})
```

Algorithm:
1. Merge trips and any codes without a trip into a unified input list (trips sorted ascending by `startedOn`, trip-less codes appended)
2. For each item, assign: `shape` (cycle through enum values using item index), `color` (deterministic from `countryCode` hash), `rotation` (seeded random ±12°)
3. Place stamps using a seeded `Random(seed)`:
   - Margins: 8% of canvas width/height
   - First attempt: random point in usable area
   - Reject if centre is within 80% of any already-placed stamp's effective radius (partial overlap allowed; full occlusion prevented)
   - Max 8 placement attempts per stamp; accept best-effort on failure
4. Alternate ENTRY/EXIT: even index = ENTRY, odd = EXIT (based on trip sequence order)
5. Cap at 20 stamps maximum; if more countries, do not render overflow (share button shows full count separately)

**Acceptance criteria:**
- Unit test: `layout()` with 5 known codes + seed 0 produces stable, deterministic positions across calls
- All stamp centres within canvas margins
- No two stamps have identical centres
- `trips` empty: falls back to codes-only path without error
- `countryCodes` empty: returns empty list

**Dependencies:** Task 151 (`StampData`)

---

### Task 154 — `PaperTexturePainter` background

**Deliverable:** `lib/features/cards/paper_texture_painter.dart` — `PaperTexturePainter extends CustomPainter`:

- Base fill: `Color(0xFFF5ECD7)` (warm parchment)
- Grain: scatter ~1000 micro-rects (1×1 to 2×2 px) with seeded `Random(42)` positions and slight colour variance (±8 lightness from base)
- Two faint horizontal lines at 30% and 70% canvas height (passport page fold marks, 0.3pt, 15% opacity)
- Corner aging: very faint radial gradient darkening in all 4 corners (radius = 20% of smallest dimension, black at 8% opacity)

**Acceptance criteria:**
- Renders within a `CustomPaint` without errors
- `shouldRepaint` always returns false (static)
- Widget test: paint into an `ImageRecorder`, verify size matches

**Dependencies:** None (pure `dart:math` + `dart:ui`)

---

### Task 155 — `PassportStampsCard` upgrade + `CardGeneratorScreen` wiring

**Deliverable:**
1. `PassportStampsCard` in `card_templates.dart` replaced: new constructor signature `const PassportStampsCard({required List<String> countryCodes, this.trips = const []})`. Widget wraps a single `CustomPaint` sized to `AspectRatio(3/2)` using `LayoutBuilder` for size. Painter is `_PassportPagePainter` which composes: `PaperTexturePainter` → `PassportLayoutEngine.layout()` → one `StampPainter` per stamp. ROAVVY watermark retained as a tiny `Text` widget overlaid on the `Stack`.

2. `CardGeneratorScreen` updated: watches `tripRepositoryProvider` (already in `providers.dart`); extracts trips for the selected country codes; passes `trips:` param when building `PassportStampsCard`. Grid and Heart cards receive only `countryCodes` (unchanged).

3. Remove `_StampWidget`, `_OverflowChip` private classes (now unused).

**Acceptance criteria:**
- `PassportStampsCard` renders with trips: shows at least one stamp with a date label
- `PassportStampsCard` renders without trips: shows stamps with no date label, no crash
- `RepaintBoundary.toImage(pixelRatio: 3.0)` captures the upgraded card (verified by Share flow)
- `card_templates_test.dart` updated: tests for `PassportStampsCard` pass with `trips: []`
- No regressions in Grid/Heart card tests
- All existing flutter tests pass

**Dependencies:** Tasks 151–154; `tripRepositoryProvider`

---

## Dependencies

- `TripRecord` — in `packages/shared_models`
- `tripRepositoryProvider` — already in `lib/core/providers.dart`
- `intl` package — already in `pubspec.yaml` (date formatting)
- `dart:math` — standard library (PRNG)
- `dart:ui` / `CustomPainter` — Flutter core

## Risks

| Risk | Mitigation |
|---|---|
| Monospace font not available on all iOS versions | Use `TextStyle(fontFamily: 'Courier New')` — ships with iOS; no custom font needed |
| Arc text for circular stamps is complex | Arc text via `TextPainter` + manual glyph positioning; fall back to top-aligned straight text if implementation is too complex |
| `PassportLayoutEngine` overlap rejection loops forever with many stamps | Max 8 attempts per stamp; accept placement regardless on attempt 9 |
| `TripRecord.startedOn` is null (manual entry with no date) | `StampData.fromTrip` checks null and produces `dateLabel: null` |
| `CardGeneratorScreen` acquires second async dependency (trips) | Use `.when(data:, loading:, error:)` on combined provider; loading state shows shimmer already |
