# M134 — Daily Heritage Challenge: UI & Integration

## Goal

Build the playable Daily Heritage Challenge on top of the M133 data layer. By the end of this milestone the feature is fully playable end to end: a user can open the challenge, reveal clues one at a time, type a guess, see a celebration on success, and fly the globe to the winning site.

**Prerequisite:** M133 must be complete (Firestore document populated, providers wired, Drift table migrated).

---

## Screen Flow

```
Map screen
  └── DailyChallengeChip (top controls row)
        └── tap → /challenge
              ├── DailyChallengeScreen (loading state)
              ├── DailyChallengeScreen (active — clues + input)
              └── _ChallengeResultOverlay (solved)
                    └── "Go to site" → Map tab, globe flies to site
```

---

## Guess Mechanics (recap)

- Free-text input, always visible while unsolved.
- Normalize both input and all WHS names: lowercase, strip diacritics, remove punctuation, collapse whitespace.
- **Match condition:** `normalize(input) == normalize(site.name)` OR `normalize(site.name).contains(normalize(input))` where `input.length >= 4`.
- Wrong guess: horizontal shake on the input field, "Not quite — try again or reveal another clue" toast, guess appended to `guesses` list, input cleared.
- Correct guess: confetti burst, `_ChallengeResultOverlay` slides up.
- Guesses and clues are tracked independently — revealing a clue does not count as a guess.

---

## Result & Sharing

```
Memphis and its Necropolis — Egypt
Solved in 3 clues · 2 wrong guesses

Shareable text (copy button):
Roavvy Daily — 27 May 2026
3 clues · 2 guesses
⬛⬛⬜⬜⬜
roavvy.app/daily
```

Grid: one cell per clue (always 5). Filled = clue was revealed, empty = unused.

---

## Tasks

### T1 — DailyChallengeNotifier

**New file:** `apps/mobile_flutter/lib/features/challenge/daily_challenge_notifier.dart`

`StateNotifier<DailyChallengeState>` where `DailyChallengeState` is:

```dart
class DailyChallengeState {
  final DailyChallenge challenge;    // from Firestore (M133)
  final DailyChallengeProgress progress; // from local DB (M133)
  final WorldHeritageSite site;      // looked up from bundled whs_sites.json
  final bool submitting;             // true while persisting a guess
}
```

Methods:
- `revealNextClue()` — increments `cluesRevealed`, persists via `DailyChallengeRepository`.
- `submitGuess(String input)` — normalizes, checks match, either records wrong guess or marks solved; persists.

Site lookup: load `whs_sites.json` once via `parseWhsSitesJson` (already in `shared_models`), find by `siteId`. Throw `StateError` if not found (data integrity failure).

Provider (add to `providers.dart`):
```dart
final dailyChallengeNotifierProvider =
    StateNotifierProvider.autoDispose<DailyChallengeNotifier, AsyncValue<DailyChallengeState>>(
  (ref) => DailyChallengeNotifier(
    challenge: ref.watch(dailyChallengeProvider),    // M133
    progress:  ref.watch(dailyChallengeProgressProvider), // M133
    repo:      ref.watch(dailyChallengeRepositoryProvider), // M133
    whsJson:   ref.watch(whsSitesJsonProvider),
  ),
);

/// Raw JSON string from the bundled whs_sites.json asset. Loaded once.
final whsSitesJsonProvider = FutureProvider<String>(
  (_) => rootBundle.loadString('assets/geodata/whs_sites.json'),
);
```

### T2 — Guess normalization helper

**New file:** `apps/mobile_flutter/lib/features/challenge/guess_normalizer.dart`

```dart
/// Normalizes a WHS name or user input for fuzzy matching.
///
/// Steps:
/// 1. NFD-decompose unicode (splits diacritics from base letters).
/// 2. Strip combining marks (diacritics).
/// 3. Strip parenthetical suffixes, e.g. "(– Danger List)".
/// 4. Lowercase.
/// 5. Remove non-alphanumeric chars except spaces.
/// 6. Collapse multiple spaces, trim.
String normalizeForGuess(String s) { ... }

/// True if [input] matches [siteName] under the fuzzy rules.
bool guessMatches(String input, String siteName) {
  final n = normalizeForGuess(input);
  final m = normalizeForGuess(siteName);
  return n == m || (n.length >= 4 && m.contains(n));
}
```

Use `package:characters` for correct Unicode grapheme iteration, or the `String.runes`-based NFD approach via `dart:core`. Do not add new packages for this; `String.normalize` is not available in Dart, so implement manually using `RegExp(r'\p{Mn}', unicode: true)` to strip marks after NFD split via `toNFD` trick (`Uri.encodeFull` roundtrip is sufficient for Latin diacritics).

### T3 — DailyChallengeScreen

**New file:** `apps/mobile_flutter/lib/features/challenge/daily_challenge_screen.dart`

Full-screen modal. Consumes `dailyChallengeNotifierProvider`.

**Structure:**

```
Scaffold
  AppBar: "Daily Challenge" | subtitle: "27 May 2026" | close ×
  body: Column
    ├── Expanded: ListView of _ClueCard (only revealed clues)
    ├── _GuessHistory (wrong guesses as small chips, hidden when empty)
    ├── _GuessInput (hidden when solved)
    └── _RevealClueButton (hidden when solved or all 5 revealed)
  _ChallengeResultOverlay (covers body when solved, AnimatedSwitcher)
```

**`_ClueCard`**
- Numbered chip (e.g. "Clue 1") + clue text.
- `AnimatedSwitcher` so new cards slide in from below.
- Background: `Theme.of(context).colorScheme.surfaceContainerHigh`.

**`_RevealClueButton`**
- Label: "Reveal Clue 2", "Reveal Clue 3", … "Reveal Clue 5".
- `FilledButton.tonal`, full width, bottom of screen above keyboard.
- Calls `notifier.revealNextClue()`.

**`_GuessInput`**
- `TextField` with hint "Type the site name…".
- Submit on keyboard action `TextInputAction.done` or trailing `IconButton(Icons.send)`.
- Calls `notifier.submitGuess(controller.text)`.
- On wrong guess: trigger shake via `AnimationController` (±8 px horizontal, 3 oscillations, 300 ms). Reset and clear input after animation.

**`_GuessHistory`**
- Row of `Chip` widgets showing each wrong guess string.
- Wrapped in `SingleChildScrollView(scrollDirection: Axis.horizontal)`.

**Loading state:** `CircularProgressIndicator` centred.

**Error state:** `DailyChallengeUnavailable` → "No challenge today — check back later." centered text with a retry button that invalidates `dailyChallengeProvider`.

### T4 — _ChallengeResultOverlay

Private widget inside `daily_challenge_screen.dart`.

- Positioned to fill the body area (Stack child with `Positioned.fill`).
- Background: `Colors.black54` blur using `BackdropFilter`.
- Content card (centred):
  - Site name in heading style.
  - Country flag emoji + country name.
  - "Solved in X clue(s)" on one line.
  - "Y wrong guess(es)" on the next (omit if 0).
  - Clue grid: 5 `Icon(Icons.square_rounded)` — filled colour for revealed, outline for unused.
  - "Go to site" `FilledButton`.
  - "Share result" `OutlinedButton` (copies text to clipboard).
- Confetti: use existing `confetti` package (already a dependency). `ConfettiController` burst from top-center, fires once on `initState`.

**"Go to site" action:**
```dart
void _navigateToSite(WidgetRef ref, WorldHeritageSite site) {
  Navigator.of(context).popUntil((r) => r.isFirst);
  ref.read(globeTargetProvider.notifier).state = (site.latitude, site.longitude);
}
```
No tab switch needed — closing the modal returns to the map screen which is already showing. The globe fly-to is triggered by `globeTargetProvider` as normal.

If the site exists in the user's `VisitedHeritageSites` (check via `heritageRepositoryProvider`), wait 1 500 ms then open the heritage detail bottom sheet. If not visited, fly-to is sufficient.

### T5 — DailyChallengeChip (map screen entry point)

**Edit:** `apps/mobile_flutter/lib/features/map/map_screen.dart`

Add `_DailyChallengeChip` widget alongside the globe/flat toggle row.

```
[Daily Challenge 🏛️]   ← pill-style ActionChip
```

- Badge: green dot overlay (`Stack` + `Positioned`) when today's progress is null or `!solved`.
- No badge when solved.
- On tap: `context.push('/challenge')`.
- Reads `dailyChallengeProgressProvider` to determine badge visibility; shows chip regardless (don't hide when challenge unavailable — just navigates to the error state).

### T6 — Routing

**Edit:** `apps/mobile_flutter/lib/app.dart`

```dart
GoRoute(
  path: '/challenge',
  pageBuilder: (context, state) => CupertinoPage(
    child: const DailyChallengeScreen(),
  ),
),
```

Use `CupertinoPage` (slide-from-right) to match the app's existing modal navigation style.

### T7 — Tests

**New file:** `test/features/challenge/guess_normalizer_test.dart`

Test cases:
- Exact match: `"Pyramids of Giza"` matches `"Pyramids of Giza"`.
- Case-insensitive: `"pyramids of giza"` matches.
- Diacritics: `"Tikal"` matches `"Tikal"` (trivial) and `"Schokland"` matches `"Schokland"`.
- Parenthetical stripped: `"Old City of Jerusalem"` matches `"Old City of Jerusalem and its Walls"` via contains.
- Too-short input rejected: `"gi"` does NOT match.
- Country-only input rejected: `"Egypt"` does NOT match `"Memphis and its Necropolis"`.

**New file:** `test/features/challenge/daily_challenge_notifier_test.dart`

Mock `DailyChallengeRepository` and `DailyChallengeService`. Test:
- `revealNextClue()` increments `cluesRevealed` and calls `repo.save`.
- `submitGuess` with wrong input increments `guesses`, does not set `solved`.
- `submitGuess` with correct input sets `solved = true` and `solvedAtClue`.
- Submitting after solved is a no-op.

### T8 — Docs + final checks

- Update `docs/dev/backlog.md`: mark M134 complete.
- Update `docs/dev/next_tasks.md`.
- `flutter analyze 2>/tmp/analyze.txt; tail /tmp/analyze.txt`

---

## File Map

```
apps/mobile_flutter/
  lib/
    features/
      challenge/
        daily_challenge_screen.dart      NEW — screen + overlay + input widgets
        daily_challenge_notifier.dart    NEW — StateNotifier + DailyChallengeState
        guess_normalizer.dart            NEW — normalizeForGuess, guessMatches
    core/
      providers.dart                     EDIT — dailyChallengeNotifierProvider, whsSitesJsonProvider
    features/
      map/map_screen.dart                EDIT — _DailyChallengeChip
    app.dart                             EDIT — /challenge route
  test/
    features/challenge/
      guess_normalizer_test.dart         NEW
      daily_challenge_notifier_test.dart NEW
```

---

## Definition of Done

- [ ] User can open the challenge from the map screen.
- [ ] Clue 1 shown automatically; clues 2–5 revealed on demand.
- [ ] Text guess accepted; wrong guess shakes and records; correct guess shows celebration.
- [ ] "Go to site" flies the globe to the correct coordinates.
- [ ] Badge on map chip reflects solved/unsolved state correctly.
- [ ] Progress persists across app restarts (reopen app mid-challenge, state restored).
- [ ] All new tests pass (`flutter test`).
- [ ] `flutter analyze` reports no new issues.
