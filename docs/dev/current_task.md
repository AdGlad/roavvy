# Active Task: M78 — Unified Scan Experience
Branch: milestone/m78-unified-scan-experience

## Goal
One scan UX for all modes: always-visible globe + country list + passport stamps,
pre-populated at rest, live-animated during scan. All scan outcomes navigate through ScanSummaryScreen.

## Scope
In: `lib/features/scan/scan_screen.dart`, `test/features/scan/scan_screen_incremental_test.dart`
Out: Firestore, web, card editor, merch, packages, map screen, any other feature

## Tasks
- [x] T1 — Always-visible scan home view (remove idle/scanning split)
- [x] T2 — Passport stamp preview pre-populated with existing countries
- [x] T3 — ScanSummaryScreen for NothingNew scan outcome
- [x] T4 — Remove dead widgets (_VisitList, _StatsCard, _StatRow, _NothingNewView, _NewCountriesView)
- [x] T5 — Verify analyze clean; existing repo + summary screen tests unaffected

## Status: Complete (2026-04-24)
