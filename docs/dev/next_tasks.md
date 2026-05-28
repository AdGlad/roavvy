# M135 — Daily Challenge Enhancement

## Tasks

### T2 — shared_models: extend models
- Add `ChallengeClue` class (`type`, `text`) to `daily_challenge.dart`
- Update `DailyChallenge.clues` from `List<String>` to `List<ChallengeClue>` (backwards-compat: plain string fallback in `fromJson`)
- Add `failed` field to `DailyChallengeProgress` (default false)
- Add nullable fields to `WorldHeritageSite`: `shortDescription`, `criteria`, `imageUrl`, `difficulty`
- Update `parseWhsSitesJson` / `fromJson` with null-safe fallbacks
- Update TypeScript mirror in `packages/shared_models/index.ts` (if present)

### T3 — Hot/cold util + DailyChallengeNotifier changes
- New `lib/features/challenge/hot_cold_feedback.dart`
  - `distanceKm(lat1, lng1, lat2, lng2)` — Haversine
  - `bearingDeg(fromLat, fromLng, toLat, toLng)`
  - `cardinalDirection(bearing)` — returns 'north', 'north-east', etc.
  - `hotColdRating(distanceKm)` — returns `(label, color)` record
- Extend `DailyChallengeState`: add `GuessResult? lastGuessResult`, `int maxGuesses = 5`
- `GuessResult`: `guess`, `distanceKm`, `direction`, `hotColdLabel`, `hotColdColor`
- In `submitGuess`: look up guessed site coords from `allWhsSitesProvider` list; compute distance + bearing; populate `lastGuessResult`
- Enforce 5-guess limit: set `failed = true` on 5th wrong guess, trigger result overlay
- Add `failed` to Drift schema (migration v15)
- Update `DailyChallengeRepository` for `failed` field

### T4 — DailyChallengeScreen UI updates
- Remove "Give up" button
- Add remaining-guesses label: `3 guesses left` (labelSmall, muted)
- Add `_HotColdChip` widget (animated in with AnimatedSwitcher after first wrong guess)
  - Colored border + background pill, icon, label + direction text
- Update `_GuessHistory` chip to show attempt number prefix: `1/5 Paris`
- Update clue access to `clue.text` (from `ChallengeClue`; with `.text` fallback)
- Wire `lastGuessResult` from notifier state to `_HotColdChip`

### T5 — Heritage reveal card (DraggableScrollableSheet)
- New `lib/features/challenge/heritage_reveal_card.dart`
- Replace `_ChallengeResultOverlay` inner card with `DraggableScrollableSheet`
  - `initialChildSize: 0.55`, `maxChildSize: 0.92`, `minChildSize: 0.4`
- Content: site image (`imageUrl` via `Image.network` + fallback placeholder), solve/fail header, site name + country flag, year/category/region chips, criteria display (`i · iii · vi`), short description, share button, go-to-globe button
- Add `cached_network_image` to pubspec (if not already present)
- Globe fly-to: set `globeTargetProvider` when sheet mounts
- Updated share text including site name

### T6 — challenge_stats Drift table + ChallengeStatsService
- New `challenge_stats` table in `roavvy_database.dart` (migration v16)
  - `date TEXT PK`, `site_id TEXT`, `solved INT`, `guesses_used INT`, `clues_used INT`, `duration_secs INT`
- New `lib/features/challenge/daily_challenge_stats.dart`
  - `ChallengeAggregate`: `totalPlayed`, `totalSolved`, `currentStreak`, `bestStreak`, `avgGuesses`, `avgClues`
  - `ChallengeStatsService`: `record(progress, durationSecs)`, `loadAggregate()`
- Record stats in `DailyChallengeNotifier` on game end (solve or fail)
- Stats summary row in reveal card (shown when `totalPlayed >= 3`): streak, solved, avg clues

### T8 — Tests
- `test/features/challenge/hot_cold_feedback_test.dart` — distance, bearing, cardinal, thresholds
- Update `test/features/challenge/daily_challenge_notifier_test.dart` for guess limit + lastGuessResult + failed
- `test/features/challenge/daily_challenge_stats_test.dart` — streak calc, aggregate

### T9 — Analyze + docs
- `flutter analyze 2>/tmp/analyze.txt; tail /tmp/analyze.txt`
- Update `docs/dev/current_task.md`

---

**Deferred to M136:**
- T1: Cloud Function typed clues (needs Firebase deploy, separate concern)
- T7: WHS dataset enrichment script (Wikidata SPARQL, external network)
