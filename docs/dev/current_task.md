# M30 — Task 114 — ✅ Complete (2026-03-23)

**Milestone:** 30
**Phase:** 12 — Commerce & Mobile Completion
**Status:** ✅ Complete

## Task List

| Task | Description | Status |
|---|---|---|
| 114 | Wire `tripRepo` through Apple sign-in flush | ✅ Done |

## Notes

Trip sync was substantially pre-built during earlier milestones:
- `FirestoreSyncService.flushDirty()` with trip support — ✅ pre-built
- `TripRepository.loadDirty()` + `markClean()` — ✅ pre-built
- Sync wired at scan save, review save, app startup — ✅ pre-built
- 5 trip-flush tests in `firestore_sync_service_test.dart` — ✅ pre-built
- Firestore rules cover `users/{uid}/trips` — ✅ pre-built

M30 task 114 completed the only remaining gap: `apple_sign_in.dart` now passes `tripRepo` so trips are flushed immediately after sign-in.

Web `/map` trip count deferred (mobile-first).
