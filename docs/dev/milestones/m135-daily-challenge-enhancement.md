# M135 — Daily Heritage Challenge Enhancement: Hot/Cold, Educational Reveal & Stats

## Goal

Upgrade the playable Daily Heritage Challenge (M134) with Wordle-style hot/cold distance feedback, a 5-guess hard limit, an educational DraggableScrollableSheet reveal on game end, user stats/streaks, UNESCO autocomplete guess input, and globe fly-to on reveal. All logic is local/device-only (no Firestore sync).

**Prerequisite:** M134 complete (screen, notifier, chip, routing all wired).

---

## Phases & Tasks

### T1 — Cloud Function clue-type upgrade *(deferred to M136)*
Update `dailyChallenge.ts` to emit `{type, text}` clue objects + `difficulty` field. Deploy.

### T2 — `shared_models` extensions
- `ChallengeClue` class with backwards-compat `fromJson` (handles `String` or `{type,text}`)
- `DailyChallenge.clues` changed from `List<String>` to `List<ChallengeClue>`, `difficulty` field added
- `DailyChallengeProgress.failed` field (bool, default false)
- `WorldHeritageSite` nullable enrichment fields: `shortDescription`, `criteria` (List<String>), `imageUrl`, `difficulty`

### T3 — Drift schema v15
- Add `failed` column to `DailyChallengeProgressTable`
- New `ChallengeStatsTable`: `date`, `siteId`, `solved`, `guessesUsed`, `cluesUsed`, `durationSecs`
- Migration `from < 15`: addColumn(failed) + createTable(challengeStatsTable)
- Update `DailyChallengeRepository.save()` and `_fromRow()`

### T4 — Hot/cold feedback utilities + notifier upgrades
- `hot_cold_feedback.dart`: Haversine `distanceKm`, `bearingDeg`, 8-way `cardinalDirection`, `hotColdRating` (5 tiers: ≤250→On fire, ≤1000→Hot, ≤3000→Warm, ≤7000→Cold, >7000→Freezing)
- `GuessResult` class: guess, distanceKm, direction, hotColdLabel, hotColdEmoji, hotColdColor
- `DailyChallengeState`: add `lastGuessResult`, `maxGuesses = 5`
- `DailyChallengeNotifier` constructor: `allSites`, `statsService` dependencies
- `submitGuess`: site lookup by normalized name, hot/cold computation, 5-guess limit (sets `failed=true`), stats recording on game end (solve or exhaust)

### T5 — Screen upgrades (autocomplete, hot/cold chip, reveal sheet, stats)
- Replace `_GuessInput` with `_HeritageSiteSearchInput` (Autocomplete<WorldHeritageSite>, opens upward, flag+name rows, submits on selection)
- Add `_HotColdChip` with AnimatedSwitcher slide-in showing distance+direction+emoji+label
- Add remaining-guess counter (red at 1 left)
- Remove "Give up" button
- Upgrade `_ChallengeResultOverlay` to `DraggableScrollableSheet`: solve/fail header, site metadata chips, criteria, shortDescription, globe fly-to on mount
- Providers wiring: `allSites`, `statsService` passed to notifier; `challengeAggregateProvider` added

### T6 — `ChallengeStatsService` + streak tracking
- `ChallengeAggregate`: totalPlayed, totalSolved, currentStreak, bestStreak, avgGuesses, avgClues
- `ChallengeStatsService.record()`: upserts per-day stats
- `ChallengeStatsService.loadAggregate()`: walks DESC-ordered rows, streak logic (current: from today/yesterday backward; best: longest run in history)

### T7 — WHS dataset enrichment *(deferred to M136)*
Wikidata SPARQL enrichment script to populate `imageUrl`, `criteria`, `shortDescription`.

### T8 — Tests
- `test/features/challenge/hot_cold_feedback_test.dart` (21 tests: distanceKm, bearingDeg, cardinalDirection, hotColdRating)
- Updated `test/features/challenge/daily_challenge_notifier_test.dart` (54 tests: existing + 4 new — failed state, no-op after failed, GuessResult populated, solvedAtClue)

---

## File Map

```
packages/shared_models/lib/src/
  daily_challenge.dart          EDIT — ChallengeClue, failed, difficulty
  world_heritage_site.dart      EDIT — shortDescription, criteria, imageUrl, difficulty

apps/mobile_flutter/lib/
  data/db/roavvy_database.dart          EDIT — schema v15, ChallengeStatsTable
  data/daily_challenge_repository.dart  EDIT — failed field
  features/challenge/
    hot_cold_feedback.dart              NEW  — Haversine, bearing, cardinal, rating
    daily_challenge_stats.dart          NEW  — ChallengeStatsService, ChallengeAggregate
    daily_challenge_notifier.dart       EDIT — GuessResult, maxGuesses, allSites, statsService
    daily_challenge_screen.dart         EDIT — autocomplete, hot/cold chip, DraggableSheet
  core/providers.dart                   EDIT — notifier wiring, challengeAggregateProvider

apps/mobile_flutter/test/features/challenge/
  hot_cold_feedback_test.dart           NEW  — 21 tests
  daily_challenge_notifier_test.dart    EDIT — 54 tests (4 new)
```

---

## ADRs

- **ADR-002**: `ChallengeStatsTable` not synced to Firestore — private per-device data.
- **ADR-003**: Drift is source of truth for challenge progress and stats.

---

## Definition of Done

- [x] `ChallengeClue` type used throughout; backwards-compat with String Firestore docs
- [x] Wrong guess shows hot/cold chip (distance + direction + emoji)
- [x] 5th wrong guess ends game with `failed=true`
- [x] Game-end reveal uses `DraggableScrollableSheet`; globe flies to site on mount
- [x] Stats recorded per-day (guesses used, clues used, solved/failed)
- [x] `ChallengeStatsService.loadAggregate()` computes streak, totals, averages
- [x] All 54 notifier tests pass; 21 hot/cold tests pass
- [x] Zero new `flutter analyze` warnings introduced
- [x] Docs updated; `index_docs.py` run

**Status:** ✅ Complete (2026-05-28)
