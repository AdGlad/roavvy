# T6 — Backend Emulator Tests

**Depends on:** T1–T5 complete (integration tests passing on simulator)

## Goal

Validate Firestore security rules, Cloud Functions behaviour, and authentication flows against the Firebase Emulator Suite in a fully isolated environment. No test in this milestone touches production Firebase.

---

## Why Emulator Tests Are a Separate Phase

Security rules are the last line of defence against a client-side bug writing data it should not write. A widget test cannot tell you whether a Firestore rule correctly rejects a write from a different user's UID. Only the Emulator Suite can test rules in their actual execution environment.

Similarly, Cloud Functions that invoke Printful can only be safely tested against a mock HTTP backend running locally — not against the live Printful API.

---

## Setup Tasks

### T6.0 — Install and configure Firebase Emulator Suite

```bash
# Install Firebase CLI if not present
npm install -g firebase-tools

# In project root
firebase init emulators
# Select: Firestore, Auth, Functions
# Accept default ports: Firestore 8080, Auth 9099, Functions 5001
```

**Edit:** `firebase.json` — add emulator configuration:

```json
{
  "emulators": {
    "auth": { "port": 9099 },
    "firestore": { "port": 8080 },
    "functions": { "port": 5001 },
    "ui": { "enabled": true }
  }
}
```

**New directory:** `apps/mobile_flutter/test/emulator/`

**New file:** `apps/mobile_flutter/test/emulator/emulator_test_setup.dart`

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

Future<void> configureEmulators() async {
  FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
  await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
}
```

Start emulators before running tests:

```bash
firebase emulators:start --only auth,firestore,functions &
cd apps/mobile_flutter
flutter test test/emulator/
```

---

## Security Rule Tests

### T6.1 — Authenticated user writes permitted fields only (Priority 1)

**File:** `test/emulator/firestore_rules_test.dart`

```dart
test('authenticated user can write countryCode, firstSeen, lastSeen to own visits', () async {
  // Sign in as user A
  // Write { countryCode: 'GB', firstSeen: ..., lastSeen: ... } to users/A/inferred_visits/1
  // Expect: write succeeds
});

test('authenticated user write is rejected when it includes a GPS coordinate field', () async {
  // Write { countryCode: 'GB', latitude: 51.5, longitude: -0.1 } to users/A/inferred_visits/1
  // Expect: write throws permission-denied
});

test('authenticated user write is rejected when it includes photo data', () async {
  // Write { countryCode: 'GB', photoUri: '...', assetId: '...' } to users/A/inferred_visits/1
  // Expect: write throws permission-denied
});
```

---

### T6.2 — Unauthenticated user cannot write any document (Priority 1)

Cover:
- Unauthenticated write to `users/{uid}/inferred_visits` → permission-denied
- Unauthenticated write to `users/{uid}/achievements` → permission-denied
- Unauthenticated write to `daily_challenge/{date}` → permission-denied

---

### T6.3 — Authenticated user cannot write another user's data (Priority 1)

Cover:
- User A writes to `users/B/inferred_visits` → permission-denied
- User A reads `users/B/inferred_visits` → permission-denied
- User A writes to `users/B/achievements` → permission-denied

---

### T6.4 — Share token public read, non-owner write rejected (Priority 2)

Cover:
- Unauthenticated read of `sharedTravelCards/{token}` → succeeds (public share)
- User A (non-owner) write to `sharedTravelCards/{ownedByB}` → permission-denied
- Token owner write to own `sharedTravelCards/{token}` → succeeds

---

### T6.5 — Visit sync field guard (Priority 1 — Privacy constraint)

This is the most critical emulator test. Verify at the rules level (not just application level) that GPS coordinates and photo identifiers cannot be persisted to Firestore.

Cover (per ADR-002):
- Document with only `{ countryCode, firstSeen, lastSeen }` is accepted
- Document with `{ countryCode, firstSeen, lastSeen, latitude, longitude }` is rejected
- Document with `{ countryCode, firstSeen, lastSeen, assetId }` is rejected
- The test uses the actual deployed security rules, not a mock

---

## Authentication Flow Tests

### T6.6 — Anonymous sign-in succeeds (Priority 2)

**File:** `test/emulator/auth_flows_test.dart`

Cover:
- `signInAnonymously()` returns a non-null `UserCredential`
- The resulting UID is non-empty
- A second call to `signInAnonymously()` returns the same UID (same session)

---

### T6.7 — Apple Sign-In upgrade preserves data (Priority 2)

Cover (using emulator's test auth provider):
- Anonymous user creates a document in `users/{uid}/inferred_visits`
- User upgrades to Apple Sign-In (credential link)
- Same UID is maintained after the upgrade
- The document created as anonymous is still readable post-upgrade

---

### T6.8 — Account deletion removes all Firestore documents (Priority 2)

Cover:
- Create user with documents in `inferred_visits`, `achievements`, `share_tokens`
- Call `auth.currentUser.delete()`
- Verify all three subcollections are empty after deletion
- (Security rules trigger deletion, or a Cloud Function handles it — test whichever is the implemented mechanism)

---

## Cloud Function Tests

### T6.9 — Order placement: correct Printful payload structure (Priority 2)

**File:** `test/emulator/cloud_functions_test.dart`

Setup: Mock the Printful HTTP endpoint at the Functions emulator level (or inject a mock HTTP client into the function).

Cover:
- Calling the `createMerchCart` function with a fixture cart produces a Printful payload with:
  - Correct recipient address structure
  - Correct line items with Printful variant IDs
  - Correct placement file URLs
- The Firestore `MerchConfig` document is written with `status: 'pending'`

---

### T6.10 — Cloud Function: error handling on fulfilment failure (Priority 3)

Cover:
- Printful returns a 4xx error → function catches it and sets `MerchConfig.status = 'failed'`
- Function does not throw unhandled exception
- Error reason is recorded in the `MerchConfig` document

---

## File Map

```
firebase.json                                    EDIT — add emulator config

apps/mobile_flutter/test/emulator/
  emulator_test_setup.dart                       NEW — configureEmulators()
  firestore_rules_test.dart                      NEW — T6.1–T6.5
  auth_flows_test.dart                           NEW — T6.6–T6.8
  cloud_functions_test.dart                      NEW — T6.9–T6.10
```

---

## Running Emulator Tests

```bash
# Terminal 1
firebase emulators:start --only auth,firestore,functions

# Terminal 2
cd apps/mobile_flutter
flutter test test/emulator/
```

In CI (GitHub Actions):

```yaml
- name: Start Firebase emulators
  run: firebase emulators:start --only auth,firestore,functions &

- name: Wait for emulators
  run: sleep 10

- name: Run emulator tests
  run: flutter test test/emulator/
  working-directory: apps/mobile_flutter
  env:
    FIREBASE_AUTH_EMULATOR_HOST: localhost:9099
```

---

## Definition of Done

- [ ] Firebase Emulator Suite starts cleanly from `firebase emulators:start`.
- [ ] All 10 emulator tests pass.
- [ ] Security rules tests cover: own-write allowed, other-user-write rejected, GPS/photo fields rejected, unauthenticated write rejected.
- [ ] Auth flow tests cover: anonymous sign-in, upgrade, account deletion.
- [ ] Cloud Function tests use mocked Printful HTTP, not the real Printful API.
- [ ] CI pipeline starts emulators and runs emulator tests on each PR.
- [ ] No production Firestore, production Auth, or live Printful endpoint was used.
