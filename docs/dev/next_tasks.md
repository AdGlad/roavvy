# M78 — Unified Scan Experience: Task List

## Goal
Initial, Incremental, and Full scan all share the same screen, layout, and animation pipeline.
The globe + country list + passport stamp preview is the permanent home view of the scan tab:
pre-populated with existing data at rest, live-updating as batches arrive during a scan.

## Scope
In:  `lib/features/scan/scan_screen.dart` only.
Out: Firestore, web, card editor, merch, packages, map screen, any other feature.

---

## T1 — Always-visible scan home view
**File:** `lib/features/scan/scan_screen.dart`
**Deliverable:** `_ScanningView` shown at all times when user has data (or scanning),
not only during active scan. Remove `_VisitList` / `_StatsCard` idle layout.

**Changes:**
- Add `isScanning` param to `_ScanningView`. Show `LinearProgressIndicator` + progress
  text only when `isScanning == true`; hide them at rest.
- In `_ScanScreenState.build()`: replace the `if (_scanning)/_ScanningView / if (!_scanning)/...`
  split with a single always-on `_ScanningView` block when
  `_effectiveVisits.isNotEmpty || _scanning`. Keep `_NoScanYetHint` for first-run (no data).
- Move scan button + mode toggle above the persistent view (compact header, stays visible).
- Keep `_ScanningPill` for the zero-batch lag window (unchanged).
- Keep `_EmptyResultsHint` for the no-geotagged-photos path (unchanged).

**Acceptance criteria:**
- Opening scan tab after first scan shows globe + country list + stamp preview immediately.
- Progress bar and count text only appear while `_scanning == true`.
- Scan button remains tappable at top while globe is visible.

---

## T2 — Passport stamp preview pre-populated with existing countries
**File:** `lib/features/scan/scan_screen.dart`
**Deliverable:** `_ScanPassportPreview` shows all visited countries (existing + newly found),
not just discoveries from the current scan run.

**Changes:**
- Add `existingCodes` param to `_ScanPassportPreview`.
- Pass `[...existingCodes, ...liveNewCodes]` as `countryCodes` to `PassportStampsCard`.

**Acceptance criteria:**
- On scan start, stamp panel immediately shows all previously visited stamps.
- New stamps appear alongside existing ones as scan runs.

---

## T3 — ScanSummaryScreen for NothingNew outcome
**File:** `lib/features/scan/scan_screen.dart`
**Deliverable:** When a scan completes with no new countries, push `ScanSummaryScreen`
(State B — "All up to date") instead of silently navigating to map.

**Changes:**
- In `_scan()`, replace the `_NothingNew` branch (calls `widget.onScanComplete?.call()`)
  with a push to `ScanSummaryScreen(newCountries: const [], newCodes: const [],
  newAchievementIds: const [], lastScanAt: preScanTimestamp, onDone: ...)`.

**Acceptance criteria:**
- Incremental scan with no new finds shows "All up to date" summary, then returns to map.
- Full scan with no new finds shows same summary.

---

## T4 — Remove dead widgets
**File:** `lib/features/scan/scan_screen.dart`
**Deliverable:** Delete widgets replaced by the unified view.

**Remove:** `_VisitList`, `_StatsCard`, `_StatRow`, `_NothingNewView`, `_NewCountriesView`
**Keep:**   `_NoScanYetHint`, `_EmptyResultsHint`, `_ScanningPill`, `_ErrorView`

**Acceptance criteria:**
- File compiles; `flutter analyze` clean.
- No references to removed widgets remain.

---

## T5 — Update tests
**File:** `test/features/scan/scan_screen_incremental_test.dart`
**Deliverable:** Tests updated for new always-visible layout. New test: `_NothingNew` triggers
navigation to `ScanSummaryScreen`.

**Acceptance criteria:**
- Tests compile and reflect new widget structure.
- A test verifies `ScanSummaryScreen` is pushed on NothingNew outcome.

---

## Risks
| Risk | Mitigation |
|---|---|
| `PassportStampsCard` layout overflow with many stamps | Uses existing grid logic; no new risk |
| `_ScanningView` always visible causes layout overflow | Wrap in `Expanded` same as scanning path |
| Tests reference removed widgets | Update finders to match new structure |
