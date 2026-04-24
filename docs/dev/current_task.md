# Active Task: M77 — Incremental Scan Redesign
Branch: milestone/m77-incremental-scan-redesign

## Goal
Make the scan screen immediately useful: globe pre-populated with known countries, country list shows existing visits from the start, assetId-based dedup for robustness, instant visual feedback on auto-scan.

## Scope
In: `lib/features/scan/scan_screen.dart`, `lib/data/visit_repository.dart`
Out: Firestore, web, card editor, merch, packages, map screen, any other feature

## Tasks
- [x] T1 — Pre-populate scan globe with existing countries
- [x] T2 — Show existing + new in scan country list
- [x] T3 — AssetId-based incremental deduplication (+ tests)
- [x] T4 — Auto-scan progress indicator
- [x] T5 — Verify/fix full-scan globe: only animate to new countries

## ✅ Complete (2026-04-24)

## Risks
| Risk | Mitigation |
|---|---|
| Large `knownAssetIds` Set memory usage | Loaded once, Set<String> only — no coordinates or photo data |
| `existingCodes` list mutation during scan | Pass as unmodifiable copy before scan starts |
| Filtering null assetId photos | Explicit null check: `assetId == null` photos always pass through |
