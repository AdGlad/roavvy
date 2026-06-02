# T1 — Test Framework Establishment — COMPLETE

## Tasks

- [x] T1.1 — Add mocktail + integration_test to pubspec.yaml dev_dependencies
- [x] T1.2 — Run full test suite; classify and fix all failures
- [x] T1.3 — Create Makefile with check/test/coverage targets; add coverage/ to .gitignore
- [x] T1.4 — Record coverage baseline in docs/testing/coverage_baseline.md
- [x] T1.5 — Create test/fixtures/ directory with 7 JSON fixture files
- [x] T1.6 — flutter analyze clean pass; document any pre-existing warnings

---

# Previous (M136 — Daily Challenge: Typed Clues, Hero Image Reveal & Stats Screen — COMPLETE)

## Tasks

### T1 — Cloud Function typed clues (COMPLETE)

## Tasks

### T1 — Cloud Function typed clues
Update `apps/functions/src/dailyChallenge.ts`:
- Change clues type to `{type:string,text:string}[]`
- buildClues() returns typed objects with: geography, historical, location, historical/natural, direct
- Deploy function

### T2 — Flutter typed clue icons
Edit `daily_challenge_screen.dart` `_ClueCard`:
- Render type icon + tint based on clue.type
- geography→Icons.public/blue, historical→Icons.history_edu/amber, location→Icons.place/orange, direct→Icons.lightbulb/green, fallback→Icons.help_outline/white38

### T3 — Hero image in result overlay
Edit `_ChallengeResultOverlay` in `daily_challenge_screen.dart`:
- 220px hero image above solve header when site.imageUrl non-empty
- Image.network + errorBuilder + bottom gradient (same pattern as _HeroImage in heritage_detail_sheet)
- Attribution "© Wikipedia / CC BY-SA" below image (white38, size 10)

### T4 — ChallengeStatsService.last30Days()
Edit `daily_challenge_stats.dart`:
- Add last30Days() → List<({String date, bool solved, int guessesUsed})>
- ORDER BY date DESC LIMIT 30

### T5 — ChallengeStatsScreen
New `challenge_stats_screen.dart`:
- ConsumerWidget modal
- Streak + best streak row, totals (played/solved/%), avg guesses, avg clues
- 30-day grid: 28×28 dots, green=solved, red=failed, grey=no entry

### T6 — Provider + entry points
- Add challengeLast30Provider in providers.dart
- "View Stats" TextButton in _ChallengeResultOverlay
- _DailyChallengeChip: streak badge (🔥N when streak≥2), long-press → stats screen

### T7 — Tests
New `challenge_stats_service_test.dart`: last30Days rows, ordering, streak logic

Status: In progress
