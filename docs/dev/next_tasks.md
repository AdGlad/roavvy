# M77 — Incremental Scan Redesign: Task List

## T1 — Pre-populate scan globe with existing countries
**File:** `lib/features/scan/scan_screen.dart`
**Deliverable:** `_ScanGlobeWidget` receives `existingCodes` (from `_effectiveVisits`) and renders them in a muted visual state on the globe from scan start.
**AC:** When scan starts (before any batch completes), the globe shows all previously-known countries in `CountryVisualState.visited` (muted gold). Newly discovered countries from `_liveNewCodes` animate on top as `CountryVisualState.newlyDiscovered`.

## T2 — Show existing + new in scan country list
**File:** `lib/features/scan/scan_screen.dart`
**Deliverable:** `_ScanningView` / `_LiveCountryList` receives `existingCodes` and shows them in a muted style above new discoveries. No empty list flash at scan start.
**AC:** Left panel shows existing countries (grey, no animation) at scan start. New countries from `_liveNewCodes` appear below with the existing animated slide-in. The "Countries will appear here…" placeholder is removed.

## T3 — AssetId-based incremental deduplication
**File:** `lib/features/scan/scan_screen.dart`, `lib/data/visit_repository.dart`
**Deliverable:** Add `loadAllKnownAssetIds()` to `VisitRepository`. In `_scan()`, load the set before the stream starts, then filter each batch's `PhotoRecord` list to skip records whose `assetId` is already known.
**AC:** Photos with a previously-seen `assetId` are skipped before `_resolveBatch` is called. Photos with `assetId == null` are always processed (no data loss). `Set<String>` is loaded once before the batch loop.
**Tests:** Unit tests in `test/features/scan/asset_id_dedup_test.dart` covering: null assetId passes through, known assetId is filtered, unknown assetId passes through.

## T4 — Auto-scan progress indicator
**File:** `lib/features/scan/scan_screen.dart`
**Deliverable:** Add a "Scanning your library…" pill shown immediately when `_scanning == true && _scanProgress?.processed == 0` so auto-scan has instant visual feedback.
**AC:** As soon as the auto-scan fires on app open, a "Scanning your library…" pill appears within one frame. It disappears when the first batch arrives (`processed > 0`).

## T5 — Verify/fix full-scan globe: only animate to new countries
**File:** `lib/features/scan/scan_screen.dart`
**Deliverable:** Confirm `_liveNewCodes` only contains codes NOT in `preScanCodes`. Add clarifying comment to the guard `!preScanCodes.contains(code)` in `_scan()`.
**AC:** Full scan does not animate the globe to countries the user already had. Guard is confirmed correct.
