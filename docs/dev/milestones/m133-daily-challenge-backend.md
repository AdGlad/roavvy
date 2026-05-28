# M133 — Daily Heritage Challenge: Backend & Data Layer

## Goal

Stand up the server-side scheduler and Dart data layer for the Daily Heritage Challenge. By the end of this milestone, Firestore is populated daily with the correct site + clues, the local SQLite table exists, and the repository + service are unit-tested. No UI is built here — that is M134.

---

## Why a Cloud Function?

The daily site and its clue set must be identical for every user on a given UTC date so results are comparable ("I got it in 2 clues!"). A Firebase Scheduled Function runs once at 00:00 UTC, picks the site deterministically from the bundled WHS dataset, and writes to Firestore under `daily_challenge/{YYYY-MM-DD}`. All clients read that single document. Without it, each device would independently derive a different site.

---

## Data Model

### Firestore: `daily_challenge/{YYYY-MM-DD}`

```
{
  siteId:      "208",
  clues:       ["clue1", "clue2", "clue3", "clue4", "clue5"],
  generatedAt: Timestamp
}
```

Clues are ordered from hardest (index 0, shown first) to easiest (index 4, shown last).

### Local SQLite: `daily_challenge_progress` table (new Drift table)

| Column | Type | Notes |
|---|---|---|
| `date` | TEXT PK | `YYYY-MM-DD` UTC |
| `site_id` | TEXT NOT NULL | matches `WorldHeritageSite.siteId` |
| `clues_revealed` | INTEGER NOT NULL DEFAULT 1 | 1–5 |
| `guesses` | TEXT NOT NULL DEFAULT '[]' | JSON array of wrong guess strings |
| `solved` | INTEGER NOT NULL DEFAULT 0 | 0 or 1 |
| `solved_at_clue` | INTEGER | nullable, 1–5 |

---

## Clue Progression

Five clues derived purely from `WorldHeritageSite` fields — no external AI needed.

| # | Shown | Content |
|---|---|---|
| 1 | Automatically | Category + UNESCO region. "A Cultural site in Africa and the Arab States" |
| 2 | On request | Inscription year + hemisphere. "Inscribed in 1979. Located in the Northern Hemisphere." |
| 3 | On request | Country flag emoji + country name. "Found in Egypt." |
| 4 | On request | Contextual hint from category + inscription year relative rank. "One of the oldest entries on the UNESCO list." |
| 5 | On request | First word of site name. "The site name begins with 'Memphis'." |

### Hemisphere derivation

| Latitude | Value |
|---|---|
| >= 0 | "Northern Hemisphere" |
| < 0 | "Southern Hemisphere" |

### Country code → flag emoji

Standard Unicode regional indicator pair: `String.fromCharCode(0x1F1E6 + (code[0] - 'A')) + String.fromCharCode(0x1F1E6 + (code[1] - 'A'))` — computed at function runtime, no lookup table needed.

### Example — Memphis and its Necropolis (siteId 86)

1. "A Cultural site in Africa and the Arab States"
2. "Inscribed in 1979. Located in the Northern Hemisphere."
3. "🇪🇬 Found in Egypt."
4. "One of the oldest entries on the UNESCO World Heritage List."
5. "The site name begins with 'Memphis'."

---

## Tasks

### T1 — Cloud Function: daily challenge scheduler

**New file:** `apps/functions/src/dailyChallenge.ts`
**Edit:** `apps/functions/src/index.ts` — add export

```typescript
// scheduleDailyChallenge: runs 00:00 UTC daily
// 1. Load whs_sites.json (bundled alongside the function)
// 2. Sort siteIds lexicographically for a stable order
// 3. epochDay = Math.floor(Date.now() / 86_400_000)
//    siteIndex = epochDay % sites.length
// 4. buildClues(site) → string[5]
// 5. Write daily_challenge/{YYYY-MM-DD} if not already present (idempotent)
```

Export `getDailyChallenge` as an additional `onCall` function for manual triggering and local testing.

`whs_sites.json` must be copied into `apps/functions/src/assets/` and included in the deployed bundle. Add to `apps/functions/package.json`:
```json
"files": ["lib", "src/assets"]
```

Verify the scheduled function trigger compiles: `cd apps/functions && npm run build`.

### T2 — `DailyChallenge` + `DailyChallengeProgress` models

**New file:** `packages/shared_models/lib/src/daily_challenge.dart`

```dart
/// The server-side document fetched from Firestore.
class DailyChallenge {
  const DailyChallenge({required this.siteId, required this.clues});
  final String siteId;
  final List<String> clues; // length 5, index 0 = hardest
}

/// Local progress state for a single day's challenge.
class DailyChallengeProgress {
  const DailyChallengeProgress({
    required this.date,
    required this.siteId,
    required this.cluesRevealed,
    required this.guesses,
    required this.solved,
    this.solvedAtClue,
  });
  final String date;           // YYYY-MM-DD
  final String siteId;
  final int cluesRevealed;     // 1–5
  final List<String> guesses;  // wrong guesses only
  final bool solved;
  final int? solvedAtClue;     // 1–5

  DailyChallengeProgress copyWith({ ... });
}
```

Export from `packages/shared_models/lib/shared_models.dart`.

### T3 — Drift table + migration

**Edit:** `apps/mobile_flutter/lib/data/db/roavvy_database.dart`

Add `DailyChallengeProgressTable` class. Increment `schemaVersion`. Add migration step (create table; no data migration needed).

Run codegen: `dart run build_runner build --delete-conflicting-outputs`

### T4 — DailyChallengeRepository

**New file:** `apps/mobile_flutter/lib/data/daily_challenge_repository.dart`

```dart
class DailyChallengeRepository {
  const DailyChallengeRepository(this._db);
  final RoavvyDatabase _db;

  Future<DailyChallengeProgress?> loadToday(String date) async { ... }
  Future<void> save(DailyChallengeProgress progress) async { ... }
}
```

Serialises/deserialises `guesses` as JSON using `dart:convert`.

### T5 — DailyChallengeService + providers

**New file:** `apps/mobile_flutter/lib/features/challenge/daily_challenge_service.dart`

```dart
class DailyChallengeService {
  Future<DailyChallenge> fetchToday() async {
    final date = DateFormat('yyyy-MM-dd').format(DateTime.now().toUtc());
    final doc = await FirebaseFirestore.instance
        .collection('daily_challenge')
        .doc(date)
        .get();
    if (!doc.exists) throw const DailyChallengeUnavailable();
    return DailyChallenge(
      siteId: doc['siteId'] as String,
      clues: List<String>.from(doc['clues'] as List),
    );
  }
}

class DailyChallengeUnavailable implements Exception {
  const DailyChallengeUnavailable();
}
```

**Edit:** `apps/mobile_flutter/lib/core/providers.dart` — add:

```dart
final dailyChallengeRepositoryProvider = Provider<DailyChallengeRepository>(
  (ref) => DailyChallengeRepository(ref.watch(roavvyDatabaseProvider)),
);

final dailyChallengeProvider = FutureProvider<DailyChallenge>(
  (_) => DailyChallengeService().fetchToday(),
);

final dailyChallengeProgressProvider = FutureProvider<DailyChallengeProgress?>((ref) {
  final today = DateFormat('yyyy-MM-dd').format(DateTime.now().toUtc());
  return ref.watch(dailyChallengeRepositoryProvider).loadToday(today);
});
```

### T6 — Unit tests

**New files:**

`test/features/challenge/clue_builder_test.dart`
- Test `buildClues` output for cultural / natural / mixed sites.
- Test hemisphere derivation (positive/negative latitude).
- Test flag emoji generation for several country codes.
- Test clue 5 uses first word of multi-word name.

`test/data/daily_challenge_repository_test.dart`
- Round-trip: save `DailyChallengeProgress` → load by date → verify all fields.
- Test that `loadToday` returns null for a different date.
- Test guesses JSON serialisation survives round-trip.

### T7 — Deploy + verify

```bash
cd apps/functions
npm run build
firebase deploy --only functions:scheduleDailyChallenge,functions:getDailyChallenge
```

Manually invoke `getDailyChallenge` from the Firebase console or `firebase functions:call` to write today's document. Confirm in Firestore console that `daily_challenge/{YYYY-MM-DD}` exists with correct shape.

Update `docs/dev/backlog.md` and `docs/dev/next_tasks.md` (write M134 stub).

`flutter analyze 2>/tmp/analyze.txt; tail /tmp/analyze.txt`

---

## File Map

```
apps/functions/src/
  dailyChallenge.ts                      NEW
  assets/whs_sites.json                  NEW (copy from mobile assets)
  index.ts                               EDIT — export scheduleDailyChallenge, getDailyChallenge

packages/shared_models/lib/src/
  daily_challenge.dart                   NEW
  shared_models.dart                     EDIT — export daily_challenge.dart

apps/mobile_flutter/
  lib/
    data/
      db/roavvy_database.dart            EDIT — table + migration
      daily_challenge_repository.dart    NEW
    features/
      challenge/
        daily_challenge_service.dart     NEW
    core/
      providers.dart                     EDIT — 3 new providers
  test/
    features/challenge/
      clue_builder_test.dart             NEW
    data/
      daily_challenge_repository_test.dart  NEW
```

---

## Definition of Done

- [ ] `scheduleDailyChallenge` deployed and visible in Firebase console.
- [ ] `daily_challenge/{today}` document present in Firestore with `siteId` and 5-element `clues` array.
- [ ] Drift migration runs without error on a fresh install and an upgrade.
- [ ] All new unit tests pass (`flutter test`).
- [ ] `flutter analyze` reports no new issues.
