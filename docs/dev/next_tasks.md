# M133 — Daily Heritage Challenge: Backend & Data Layer

## Tasks

### T1 — Cloud Function: daily challenge scheduler
- New `apps/functions/src/dailyChallenge.ts`
- `scheduleDailyChallenge` (pub/sub, 00:00 UTC daily) + `getDailyChallenge` (onCall, for testing)
- Deterministic picker: sort siteIds lexicographically, `epochDay % sites.length`
- `buildClues(site)` → string[5] from site fields
- Idempotent write to `daily_challenge/{YYYY-MM-DD}`
- Copy `whs_sites.json` to `apps/functions/src/assets/`
- Register exports in `apps/functions/src/index.ts`
- Verify: `cd apps/functions && npm run build`

### T2 — DailyChallenge + DailyChallengeProgress models
- New `packages/shared_models/lib/src/daily_challenge.dart`
- `DailyChallenge` (siteId, clues: List<String>)
- `DailyChallengeProgress` (date, siteId, cluesRevealed, guesses, solved, solvedAtClue) + copyWith
- Export from `shared_models.dart`

### T3 — Drift table + migration (v13 → v14)
- Add `DailyChallengeProgressTable` to `roavvy_database.dart`
- Increment schemaVersion to 14
- Add `if (from < 14)` migration block
- Run codegen: `dart run build_runner build --delete-conflicting-outputs`

### T4 — DailyChallengeRepository
- New `apps/mobile_flutter/lib/data/daily_challenge_repository.dart`
- `loadToday(date)` and `save(progress)` methods
- JSON encode/decode guesses list via `dart:convert`

### T5 — DailyChallengeService + providers
- New `apps/mobile_flutter/lib/features/challenge/daily_challenge_service.dart`
- Fetches `daily_challenge/{YYYY-MM-DD}` from Firestore
- `DailyChallengeUnavailable` exception for missing/network-error cases
- Add 3 providers to `lib/core/providers.dart`:
  `dailyChallengeRepositoryProvider`, `dailyChallengeProvider`, `dailyChallengeProgressProvider`

### T6 — Unit tests
- `test/features/challenge/clue_builder_test.dart` — clue content, hemisphere, flag emoji, first word
- `test/data/daily_challenge_repository_test.dart` — round-trip, null for wrong date, JSON guesses

### T7 — Deploy + verify + docs
- `firebase deploy --only functions:scheduleDailyChallenge,functions:getDailyChallenge`
- Verify Firestore document written for today
- `flutter analyze 2>/tmp/analyze.txt; tail /tmp/analyze.txt`
- Update `docs/dev/current_task.md` and `docs/dev/backlog.md`
