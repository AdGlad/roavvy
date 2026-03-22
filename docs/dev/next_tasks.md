# M30 — Firestore Trip Sync

**Milestone:** 30
**Phase:** 12 — Commerce & Mobile Completion
**Goal:** Trip records are synced to Firestore so data is available across devices and for web display.

---

## Context

The Firestore trip sync infrastructure was substantially built during earlier milestones:
- `FirestoreSyncService.flushDirty()` already syncs dirty `TripRecord` rows to `users/{uid}/trips/{tripId}` (fire-and-forget)
- `TripRepository.loadDirty()` and `markClean()` already exist
- Trip sync is wired at scan save (`scan_screen.dart`), review save (`review_screen.dart`), and app startup (`main.dart`)
- 5 trip-flush tests already pass in `firestore_sync_service_test.dart`
- Firestore rules cover `users/{uid}/trips` via wildcard `users/{userId}/{document=**}`

The only remaining gap is that `apple_sign_in.dart` does not pass `tripRepo` to `flushDirty`, meaning trip records are not pushed to Firestore immediately after an Apple sign-in (they are still flushed on the next scan or app restart, so this is not a data-loss issue, only a latency gap).

The web `/map` trip count enhancement is deferred (mobile-first priority per project constraints).

---

## Scope

**Included:**
- `apple_sign_in.dart`: add optional `tripRepo: TripRepository?` param; pass it through to `flushDirty`
- `MapScreen._onSignInWithApple`: read `tripRepositoryProvider` and pass it as `tripRepo`
- Test: sign-in flush now includes trips when `tripRepo` is supplied

**Excluded:**
- Web `/map` trip count (deferred — mobile must be complete first)
- Region visit sync (no web consumer yet)

---

## Tasks

### Task 114 — Wire `tripRepo` through Apple sign-in flush

**Deliverable:**
- `apple_sign_in.dart` `signInWithApple()` gains optional `tripRepo: TripRepository?` parameter
- The `flushDirty` call is updated to forward `tripRepo: tripRepo`
- `MapScreen._onSignInWithApple` reads `ref.read(tripRepositoryProvider)` and passes it as `tripRepo`
- `signInWithAppleOverride` test hook in `MapScreen` is unchanged (it bypasses the flush entirely)

**Acceptance criteria:**
- `flutter analyze` zero issues
- Existing trip-flush tests in `firestore_sync_service_test.dart` continue to pass
- `apple_sign_in.dart` call in `map_screen.dart` passes `tripRepo`

---

## Dependencies

- All trip sync infrastructure already exists (see Context above)
- Firestore rules unchanged

## Risks

None — this is a one-line wiring change with no schema impact.
