# M160 — Firestore Restore on Reinstall

**Status: Complete**

## Goal

When a user deletes and reinstalls the app, restore their previously scanned travel
data from Firestore into the local Drift database automatically on first launch,
without requiring them to re-scan their entire photo library.

Currently the sync is one-way: the app pushes dirty local rows to Firestore
(`flushDirty`) but never pulls. On reinstall the Drift database is empty and the
user sees a blank map until they re-scan.

---

## User Experience

**Current (broken):**
1. User reinstalls → blank map → must re-scan full photo library to see countries

**After this milestone:**
1. User reinstalls → signs in (or anonymous session restored via Keychain) → app
   detects empty local DB + data exists in Firestore → silently restores →
   map shows all previous countries within a few seconds

The restore should be transparent: no "Restoring…" splash unless it takes more
than 2 seconds, in which case a subtle progress indicator is shown.

---

## Architecture

### What is stored in Firestore (ADR-029)

```
users/{uid}/
  inferred_visits/{countryCode}   → inferredAt, photoCount, firstSeen?, lastSeen?
  user_added/{countryCode}        → addedAt
  user_removed/{countryCode}      → removedAt
  unlocked_achievements/{id}      → unlockedAt
  trips/{tripId}                  → countryCode, startedOn, endedOn, photoCount, isManual
```

### Restore trigger conditions (all must be true)

1. User is authenticated (uid available)
2. Local Drift DB has zero `inferred_visits` AND zero `photo_date_records`
3. A restore has not already been attempted this session (dedup guard)

Condition 2 ensures a user who genuinely has zero countries is not repeatedly
queried. Condition 3 prevents a restore loop if Firestore returns empty.

### Restore order

Restore in dependency order to avoid foreign-key-like issues in Drift:

1. `inferred_visits` → write to `inferred_visits` table (mark `isDirty = 0`)
2. `user_added` → write to `user_added` table
3. `user_removed` → write to `user_removed` table
4. `trips` → write to `trip_records` table
5. `unlocked_achievements` → write to `achievement_unlocks` table

After restore: call `bootstrapExistingUser` to synthesise any missing trip records
(handles edge cases from old schema versions).

### Fail-safe behaviour

- If Firestore is unreachable (offline), skip restore silently — user can
  still re-scan or the restore will succeed on next launch.
- If restore partially fails, write what succeeded. The next launch will
  re-attempt any collections that are still empty.
- Never overwrite existing local data — the restore only runs when the local DB
  is empty (condition 2).

### No re-scan required

The restored data comes from `inferred_visits` (derived country codes and dates),
not from raw GPS records. The map, achievements, and stats all work from this
derived data. The user does not need to re-scan.

If the user later chooses to scan, incremental scan (`sinceDate`) will only
process photos taken after `lastScanAt` (which is not restored — first scan after
restore is treated as a full scan but skips already-known assetIds).

---

## Tasks

### T1 — Create `FirestoreRestoreService`

**New file:** `apps/mobile_flutter/lib/data/firestore_restore_service.dart`

```dart
class FirestoreRestoreService {
  FirestoreRestoreService({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Returns true if a restore is warranted:
  /// - local inferred_visits is empty, AND
  /// - local photo_date_records is empty (ensures fresh install, not just zero visits)
  static Future<bool> shouldRestore(VisitRepository visitRepo) async {
    final inferred = await visitRepo.loadInferred();
    if (inferred.isNotEmpty) return false;
    final photoDates = await visitRepo.loadPhotoDates();
    return photoDates.isEmpty;
  }

  /// Pulls all collections from Firestore and writes them to local Drift tables.
  /// Fails silently on network error — returns false if restore could not complete.
  Future<bool> restore(
    String uid, {
    required VisitRepository visitRepo,
    required TripRepository tripRepo,
    required AchievementRepository achievementRepo,
  }) async {
    try {
      final userDoc = _firestore.collection('users').doc(uid);

      // 1. inferred_visits
      final inferredSnap = await userDoc.collection('inferred_visits').get();
      // parse and upsert to Drift...

      // 2. user_added
      final addedSnap = await userDoc.collection('user_added').get();
      // parse and upsert...

      // 3. user_removed
      final removedSnap = await userDoc.collection('user_removed').get();
      // parse and upsert...

      // 4. trips
      final tripsSnap = await userDoc.collection('trips').get();
      // parse and upsert...

      // 5. unlocked_achievements
      final achievementsSnap =
          await userDoc.collection('unlocked_achievements').get();
      // parse and upsert...

      return true;
    } catch (_) {
      return false;
    }
  }
}
```

### T2 — Call restore in `main.dart` before `runApp`

**File:** `apps/mobile_flutter/lib/main.dart`

After Firebase initialises and the DB is ready, before `runApp`:

```dart
final uid = FirebaseAuth.instance.currentUser?.uid;
if (uid != null) {
  final shouldRestore = await FirestoreRestoreService.shouldRestore(visitRepo);
  if (shouldRestore) {
    await FirestoreRestoreService(
    ).restore(uid, visitRepo: visitRepo, tripRepo: tripRepo,
        achievementRepo: AchievementRepository(db));
  }
  // existing flushDirty call...
  unawaited(FirestoreSyncService().flushDirty(...));
}
```

The restore runs synchronously before `runApp` so the map is populated on first
frame. If Firestore is unreachable the await completes quickly (timeout) and the
user sees an empty map as today.

### T3 — Add timeout to restore

Wrap the Firestore calls in a `Future.wait` with a 5-second timeout:

```dart
await Future.any([
  _doRestore(uid, ...),
  Future.delayed(const Duration(seconds: 5)),
]);
```

This ensures a slow network connection does not delay app startup beyond 5 seconds.

### T4 — Restore loading indicator

**File:** `apps/mobile_flutter/lib/main.dart` (or initial route widget)

If restore takes more than 2 seconds, show a subtle "Restoring your map…"
message on the splash / loading screen. Dismiss it once `runApp` completes.

Use a `Completer` to signal the indicator:

```dart
// Start timer — show indicator if still waiting after 2s
final showIndicatorTimer = Timer(const Duration(seconds: 2), () {
  // update splash state to show indicator
});
await restore(...);
showIndicatorTimer.cancel();
```

### T5 — Mark restored rows as clean (`isDirty = 0`)

All rows written by the restore service must be marked `isDirty = 0` so
`flushDirty` does not immediately re-upload them to Firestore.

The existing `upsert` methods in the repositories accept an `isDirty` flag — use
`isDirty: false` for all restore writes.

### T6 — Unit tests for `FirestoreRestoreService`

**New file:**
`apps/mobile_flutter/test/data/firestore_restore_service_test.dart`

Test cases:
- Empty Firestore → restore returns true, local DB still empty (no crash)
- Firestore has data → all collections written to local DB correctly
- `shouldRestore` returns false when local DB already has inferred_visits
- `shouldRestore` returns false when local DB has photo_date_records (incremental scan user)
- Network timeout → restore returns false, app continues normally
- Restored rows have `isDirty = false`

Use `fake_cloud_firestore` and `mocktail` (already in dev dependencies).

### T7 — Integration test: delete + reinstall simulation

**File:** `apps/mobile_flutter/integration_test/restore_flow_test.dart`

Simulate reinstall by:
1. Clearing the Drift DB (`await db.close(); await db.delete()`)
2. Seeding Firestore with known data (via `fake_cloud_firestore`)
3. Running the restore
4. Asserting local DB matches Firestore seed data

---

## Firestore Schema Notes

The restore reads these fields per collection:

| Collection | Fields read |
|---|---|
| `inferred_visits` | `inferredAt`, `photoCount`, `firstSeen`, `lastSeen` |
| `user_added` | `addedAt` |
| `user_removed` | `removedAt` |
| `trips` | `countryCode`, `startedOn`, `endedOn`, `photoCount`, `isManual` |
| `unlocked_achievements` | `unlockedAt` |

All timestamp fields are stored as ISO-8601 strings (existing convention in
`FirestoreSyncService`).

---

## File Map

```
apps/mobile_flutter/
  lib/main.dart                                        EDIT — call restore
  lib/data/firestore_restore_service.dart              NEW
  test/data/firestore_restore_service_test.dart        NEW
  integration_test/restore_flow_test.dart              NEW
```

---

## ADR

**ADR-160: Firestore restore on reinstall**

- Restore is pull-on-demand (triggered by empty local DB), not continuous sync.
  Continuous two-way sync would conflict with the offline-first Drift model.
- Restore runs before `runApp` to avoid a visible "blank then populated" flash.
- 5-second timeout prevents a slow Firestore connection from blocking startup.
- Restored rows are marked clean (`isDirty = 0`) so `flushDirty` does not
  immediately re-upload them, creating unnecessary Firestore writes.
- `photo_date_records` emptiness is checked alongside `inferred_visits` to
  distinguish a genuine zero-country user from a fresh install.
- No raw GPS or photo data is stored in Firestore (ADR-002) so the restored
  map reflects country-level granularity only, not individual photo positions.

---

## Definition of Done

- [ ] `FirestoreRestoreService` implemented with all 5 collections
- [ ] `shouldRestore` guard prevents restore for existing users
- [ ] Restore called in `main.dart` before `runApp`
- [ ] 5-second timeout — slow network does not block startup
- [ ] Loading indicator shown if restore takes > 2 seconds
- [ ] Restored rows marked `isDirty = false`
- [ ] `bootstrapExistingUser` called after restore
- [ ] Unit tests pass for all T6 cases
- [ ] `flutter analyze` — no new warnings
- [ ] Manually tested: delete app → reinstall → sign in → map populated without re-scan
- [ ] Manually tested: existing user (non-empty DB) → restore does NOT run

**Phase:** Core infrastructure
**Depends on:** M117 (auth gate), ADR-029 (Firestore schema)
**Blocks:** Nothing — additive feature
