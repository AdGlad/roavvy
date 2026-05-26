# Current Task

**Milestone:** M133 — Daily Heritage Challenge: Backend & Data Layer
**Status:** Complete (2026-05-27)

All tasks implemented:
- T1: `apps/functions/src/dailyChallenge.ts` — `scheduleDailyChallenge` + `getDailyChallenge` Cloud Functions
- T2: `DailyChallenge` + `DailyChallengeProgress` models in `shared_models`
- T3: `DailyChallengeProgressTable` Drift table, schema v14 migration
- T4: `DailyChallengeRepository` — loadToday + save with JSON guesses
- T5: `DailyChallengeService` — Firestore fetch; 3 providers in `providers.dart`
- T6: TypeScript tests (13/13 ✓) + Dart repository tests (6/6 ✓)
- T7: Firestore security rule added for `daily_challenge/{date}`

Deploy pending: `firebase deploy --only functions:scheduleDailyChallenge,functions:getDailyChallenge`

Next milestone: M134 — Daily Heritage Challenge: UI & Integration
See: `docs/dev/milestones/m134-daily-challenge-ui.md`
