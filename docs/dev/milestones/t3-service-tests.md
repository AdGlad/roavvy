# T3 — Service Tests

**Status:** Complete — 2026-06-03
**Depends on:** T1 complete, T2 complete (business logic coverage ≥ 85%)

## Goal

Achieve 70%+ coverage of the service and repository layer. Every test in this milestone uses mocked or faked dependencies — `fake_cloud_firestore`, `firebase_auth_mocks`, `mocktail`, and `NativeDatabase.memory()` for Drift. No real Firebase. No real network.

---

## Why the Service Layer Matters

The service and repository layer is where the application's state machine lives. This is where:
- Visit data is deduplicated and persisted
- Firestore writes are gated against forbidden fields (privacy guarantee)
- Cart items are managed and totals calculated
- Achievement state is written and synced
- Daily challenge streaks are maintained across days

Bugs here corrupt stored data — the most expensive class of defect to repair because user history is affected.

---

## Standard Test Setup

Every service/repository test file follows this pattern:

```dart
import 'package:drift/native.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late RoavvyDatabase db;
  late FakeFirebaseFirestore firestore;
  late MockFirebaseAuth auth;

  setUp(() async {
    db = RoavvyDatabase(NativeDatabase.memory());
    firestore = FakeFirebaseFirestore();
    auth = MockFirebaseAuth(signedIn: true);
  });

  tearDown(() async {
    await db.close();
  });
}
```

---

## Tasks

### T3.1 — Merch: Cart repository (Priority 1 — Critical revenue)

**New or extend:** `test/features/merch/merch_cart_repository_test.dart`

Cover:
- Add item → item appears in cart with correct quantity
- Add same item twice → quantity increments (not duplicate row)
- Update quantity → correct new quantity persisted
- Remove item → item no longer in cart
- Clear cart → cart is empty
- Total calculation: single item, multiple items, mixed quantities
- Empty cart total is zero

---

### T3.2 — Merch: Mockup approval service (Priority 2 — extend existing)

**Edit:** nearest existing mockup approval test

Add:
- Approval transitions state from `pending` to `approved`
- Rejection with reason persists the rejection reason
- Double-approval is idempotent (no error on second approve)
- Approved artwork bytes are retrievable after approval

---

### T3.3 — Data: Firestore sync field guard (Priority 2 — extend existing)

**Edit:** `test/data/firestore_sync_service_test.dart`

The Firestore field guard is a critical privacy constraint (ADR-002). Verify:
- Write containing `countryCode`, `firstSeen`, `lastSeen` succeeds
- Write containing any GPS coordinate field is rejected/stripped
- Write containing any photo data field is rejected/stripped
- Only the three permitted fields appear in the Firestore document after sync
- A dirty record with `isDirty = true` is written; a clean record is skipped

---

### T3.4 — Data: Visit repository deduplication (Priority 2 — extend existing)

**Edit:** `test/data/visit_repository_test.dart`

Add deduplication scenarios:
- Inserting the same `assetId` twice produces one row, not two
- Re-scan of the same photo updates `lastSeen`, not a new row
- `assetId = null` rows are not deduplicated against each other (multiple null-assetId rows allowed)
- Delete all removes every row; subsequent query returns empty list

---

### T3.5 — Data: Achievement repository Firestore sync (Priority 2 — extend existing)

**Edit:** `test/data/achievement_repository_test.dart`

Add:
- Unlocking an achievement sets `isDirty = true` in Drift
- `flushDirty()` writes the achievement to Firestore with correct fields
- Attempting to unlock an already-unlocked achievement is idempotent
- `syncedAt` is updated after a successful Firestore write

---

### T3.6 — Data: Daily challenge repository streak (Priority 2 — extend existing)

**Edit:** `test/data/daily_challenge_repository_test.dart`

Add:
- Saving progress for today and loading it back returns identical data
- Loading progress for a different date returns null
- Streak increments when `date` is consecutive with previous solved date
- Streak resets when a day is skipped
- `guesses` JSON round-trips without data loss

---

### T3.7 — Sharing: Share token service (Priority 3 — extend existing)

**Edit:** nearest existing share token test

Add:
- Token generation produces a UUID-format string
- Two successive generations produce different tokens
- A generated token can be round-tripped through Firestore and retrieved
- An expired token returns an expiry error (if expiry is implemented)

---

### T3.8 — Challenge: Daily challenge service date selection (Priority 3)

**New file:** `test/features/challenge/daily_challenge_service_test.dart`

Cover:
- Today's date key (`YYYY-MM-DD` UTC) is used to fetch the Firestore document
- A missing document throws `DailyChallengeUnavailable`
- A correctly shaped document is deserialised into `DailyChallenge` without error
- `FakeFirebaseFirestore` is used; no real Firestore call is made

---

### T3.9 — Account: Deletion service cascade (Priority 3 — extend existing)

**Edit:** nearest existing account deletion test

Add:
- Deletion removes all rows from local Drift tables
- Deletion removes all Firestore documents under `users/{uid}/`
- `auth.delete()` is called after Firestore cleanup
- If `auth.delete()` fails, the error is propagated correctly

---

### T3.10 — Data: Bootstrap service idempotency (Priority 3 — extend existing)

**Edit:** `test/data/bootstrap_service_test.dart`

Add:
- Running bootstrap twice produces no error and no duplicate rows
- `bootstrapCompletedAt` is set after first run
- Second run detects `bootstrapCompletedAt` and exits early

---

### T3.11 — Data: Region repository continent rollup (Priority 3 — extend existing)

**Edit:** `test/data/region_repository_test.dart`

Add:
- Countries with known continent codes are assigned correctly
- Mixed-continent set produces correct continent list
- Unknown country code produces a documented fallback (not a crash)

---

### T3.12 — Data: Heritage repository proximity lookup (Priority 3)

**New file:** `test/data/heritage_repository_test.dart`

Cover:
- A GPS coordinate near a known UNESCO site returns that site
- A GPS coordinate far from all sites returns empty list
- A country code filter returns only sites in that country
- Results are ordered by distance (nearest first)

---

## File Map

```
test/
  features/
    merch/
      merch_cart_repository_test.dart         NEW
      mockup_approval_service_test.dart       EDIT — extend
    challenge/
      daily_challenge_service_test.dart       NEW
    sharing/
      share_token_service_test.dart           EDIT — extend
    account/
      account_deletion_service_test.dart      EDIT — extend
  data/
    firestore_sync_service_test.dart          EDIT — extend
    visit_repository_test.dart               EDIT — extend
    achievement_repository_test.dart         EDIT — extend
    daily_challenge_repository_test.dart     EDIT — extend
    bootstrap_service_test.dart              EDIT — extend
    region_repository_test.dart              EDIT — extend
    heritage_repository_test.dart            NEW
```

---

## Definition of Done

- [ ] Service / repository layer coverage ≥ 70% (verify with `make coverage`).
- [ ] All 12 task areas have tests added or extended.
- [ ] `flutter test` exits with zero failures after each task area.
- [ ] No test writes to production Firestore or calls a real Printful endpoint.
- [ ] Drift tests use `NativeDatabase.memory()`.
- [ ] Firestore tests use `FakeFirebaseFirestore`.
- [ ] HTTP-dependent services have their `http.Client` injected and mocked with `mocktail`.
- [ ] No production Firebase, real payment flow, or live Printful endpoint was used.
