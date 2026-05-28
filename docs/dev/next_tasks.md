# M134 — Daily Heritage Challenge: UI & Integration

## Tasks

### T1 — DailyChallengeNotifier + state model
- New `lib/features/challenge/daily_challenge_notifier.dart`
- `DailyChallengeState` holds challenge, progress, site, submitting flag
- `revealNextClue()` — cluesRevealed++, persist
- `submitGuess(input)` — normalize + match; wrong → append guess; correct → solved=true, solvedAtClue
- Submitting after solved is no-op
- Add `dailyChallengeNotifierProvider` + `whsSitesJsonProvider` to `providers.dart`

### T2 — Guess normalization
- New `lib/features/challenge/guess_normalizer.dart`
- `normalizeForGuess(s)`: lowercase, strip diacritics via Uri roundtrip, strip parens, remove non-alphanumeric, collapse spaces
- `guessMatches(input, siteName)`: exact or contains (min length 4)

### T3 — DailyChallengeScreen + sub-widgets
- New `lib/features/challenge/daily_challenge_screen.dart`
- `_ClueCard` (numbered chip + text, AnimatedSwitcher)
- `_RevealClueButton` (FilledButton.tonal, full-width)
- `_GuessInput` (TextField + send button, shake AnimationController on wrong)
- `_GuessHistory` (horizontal Chip row)
- Loading / error states
- `_ChallengeResultOverlay` (BackdropFilter, confetti, score, Go + Share buttons)
- "Go to site": `Navigator.of(context).pop()` + set `globeTargetProvider`
- Push via `Navigator.of(context).push(MaterialPageRoute(...))` — NOT GoRouter

### T4 — _DailyChallengeChip on map screen
- Edit `lib/features/map/map_screen.dart`
- `Positioned` below `_GlobeActionBar` (same `Colors.black45` pill style)
- Badge: green dot when unsolved/unattempted; hidden when solved
- On tap: `Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DailyChallengeScreen()))`

### T5 — Tests
- `test/features/challenge/guess_normalizer_test.dart`
- `test/features/challenge/daily_challenge_notifier_test.dart` (mock repo)

### T6 — Docs + analyze
- Update `docs/dev/current_task.md`, `docs/dev/backlog.md`
- `flutter analyze 2>/tmp/analyze.txt; tail /tmp/analyze.txt`
