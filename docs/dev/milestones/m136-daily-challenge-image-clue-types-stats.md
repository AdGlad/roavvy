# M136 — Daily Challenge: Typed Clues, Hero Image Reveal & Stats Screen

## Goal

Three focused enhancements to the existing Daily Heritage Challenge (M133–M135):

1. **Typed clues** — upgrade the Cloud Function and `shared_models` so each clue carries a
   `type` (geography / historical / cultural / architectural / natural). Flutter renders
   each type with a distinct icon and tint colour.
2. **Hero image in result overlay** — display the Wikipedia `imageUrl` (already in the bundled
   `whs_sites.json`) at the top of `_ChallengeResultOverlay`, with source attribution.
3. **Stats screen** — a dedicated screen (`ChallengeStatsScreen`) showing streak, solve-rate,
   average guesses, and a 30-day solve grid, accessible via a "Stats" button on the result
   overlay and via a long-press on the challenge chip.

**Prerequisite:** M135 complete (typed model fields, stats service, enriched WHS dataset all in place).

---

## Phases & Tasks

### T1 — Typed clues: Cloud Function

**File:** `functions/src/dailyChallenge.ts`

Add `type` to each clue object. Emit:

```ts
interface ChallengeClue {
  type: 'geography' | 'historical' | 'cultural' | 'architectural' | 'natural';
  text: string;
}
```

- Order clues from most-abstract to most-specific.
- Clue 1 is always `geography` or `natural`.
- Clue 5 is always the most revealing (specific country / site type).
- Existing Firestore documents remain valid — `ChallengeClue.fromJson` already handles
  plain-string fallback (M135 T2). No migration needed.
- Deploy updated function.

### T2 — Typed clues: Flutter display

**File:** `lib/features/challenge/daily_challenge_screen.dart`

Upgrade `_ClueCard` to use `ChallengeClue` (already the model type). Add type icon + tint:

| type           | icon                            | tint               |
|----------------|---------------------------------|--------------------|
| geography      | `Icons.public`                  | `Colors.blue`      |
| historical     | `Icons.history_edu_outlined`    | `Colors.amber`     |
| cultural       | `Icons.account_balance_outlined`| `Colors.purple`    |
| architectural  | `Icons.architecture_outlined`   | `Colors.teal`      |
| natural        | `Icons.park_outlined`           | `Colors.green`     |

- Icon sits in the numbered circle's place; number moves to a small subscript label.
- Backwards-compatible: clues with no type (plain string fallback) show a default
  `Icons.help_outline` icon in `Colors.white38`.

### T3 — Hero image in result overlay

**File:** `lib/features/challenge/daily_challenge_screen.dart` — `_ChallengeResultOverlay`

When `site.imageUrl` is non-empty, show a 200 px hero image at the top of the
`DraggableScrollableSheet` content, above the site name:

```
┌──────────────────────────────────┐
│   [drag handle]                  │
│   ┌──────── hero image ────────┐ │
│   │  220 px, BoxFit.cover      │ │
│   │  bottom gradient overlay   │ │
│   └────────────────────────────┘ │
│   ✅ Solved! / ❌ Better luck    │
│   Site name  ·  flag country     │
│   …existing content…             │
└──────────────────────────────────┘
```

- Use `Image.network` with `errorBuilder` fallback (same pattern as `_HeroImage` in
  `heritage_detail_sheet.dart`).
- Bottom gradient from `Colors.transparent` → `Colors.black54` so the solve/fail
  header text remains readable if it overlaps the image.
- Attribution: small `"© Wikipedia / CC BY-SA"` caption below the image in
  `Colors.white38`, `fontSize: 10`. Only shown when imageUrl is non-empty.
- No new packages — `Image.network` caches by default via Flutter's `ImageCache`.

### T4 — Stats screen

**New file:** `lib/features/challenge/challenge_stats_screen.dart`

`ConsumerWidget` pushed as a full-screen modal (`MaterialPageRoute`).

Layout:

```
AppBar: "Your Stats"  ×
─────────────────────────────────
  [Streak card]   [Best streak card]
  [Played]  [Solved]  [Solve %]
─────────────────────────────────
  Avg guesses: 2.4   Avg clues: 3.1
─────────────────────────────────
  Last 30 days
  [7×5 grid of coloured dots]
  green = solved, red = failed, grey = not played
─────────────────────────────────
```

- `ChallengeAggregate` (already computed by `ChallengeStatsService.loadAggregate()`) drives
  all the numbers. No new data layer needed.
- 30-day grid: query `ChallengeStatsTable` for the last 30 `date` rows
  (`ChallengeStatsService.last30Days()` — new method, returns
  `List<({String date, bool solved, int guessesUsed})>`).
- Grid cells: `Container` 28×28, `BorderRadius.circular(6)`, colour:
  - solved → `Colors.green.shade600`
  - failed → `Colors.red.shade400`
  - no entry → `theme.colorScheme.surfaceContainerHigh`

**Route:** no GoRouter entry needed — push via `Navigator.of(context).push(MaterialPageRoute(...))`.

**Entry points:**

1. `_ChallengeResultOverlay` — add `TextButton("View Stats")` below the Share button.
2. `_DailyChallengeChip` (map screen) — `onLongPress` opens stats screen.

### T5 — Streak badge on challenge chip

**File:** `lib/features/map/map_screen.dart` — `_DailyChallengeChip`

Replace the plain green dot badge with a streak count badge when streak ≥ 2:

```
[Daily Challenge 🏛️  🔥3]
```

- Read `challengeAggregateProvider` (already added in M135) for `currentStreak`.
- Badge widget: orange pill `"🔥$streak"` shown only when `streak >= 2`.
- When `streak < 2`, show existing green dot for unsolved / nothing for solved.

### T6 — `ChallengeStatsService.last30Days()`

**File:** `lib/features/challenge/daily_challenge_stats.dart`

New method on `ChallengeStatsService`:

```dart
/// Returns the most-recent 30 days in DESC order (today first).
/// Each record is {date: 'yyyy-MM-dd', solved: bool, guessesUsed: int}.
Future<List<({String date, bool solved, int guessesUsed})>> last30Days();
```

- Direct Drift query: `SELECT * FROM challenge_stats ORDER BY date DESC LIMIT 30`.

### T7 — Tests

**New:** `test/features/challenge/challenge_stats_service_test.dart`

- `last30Days()` returns at most 30 rows.
- `last30Days()` returns rows in descending date order.
- Aggregate streak counts streak correctly when today has an entry.
- Widget test: `ChallengeStatsScreen` renders streak value from mock aggregate.

---

## File Map

```
functions/src/
  dailyChallenge.ts                     EDIT — typed ChallengeClue, deploy

packages/shared_models/lib/src/
  daily_challenge.dart                  EDIT — ChallengeClue.type enum (already has fromJson stub)

apps/mobile_flutter/lib/
  features/challenge/
    daily_challenge_screen.dart         EDIT — _ClueCard type icons; hero image; stats button
    daily_challenge_stats.dart          EDIT — last30Days() method
    challenge_stats_screen.dart         NEW  — stats modal screen
  features/map/
    map_screen.dart                     EDIT — streak badge on chip; long-press to stats

apps/mobile_flutter/test/features/challenge/
  challenge_stats_service_test.dart     NEW  — 4 tests
```

---

## ADRs

- **ADR-004**: Hero image sourced from bundled `whs_sites.json` `imageUrl` (Wikipedia REST API,
  fetched once at enrichment time). No runtime network call to Wikipedia is made; the URL is
  loaded by `Image.network` directly. Attribution text always shown.
- **ADR-005**: `ChallengeStatsScreen` is a device-local view of `ChallengeStatsTable`
  (Drift). No Firestore read. Stats are not synced across devices.

---

## Definition of Done

- [x] Cloud Function updated to emit typed clues; build + tests pass; deploy requires Blaze plan (blocked externally).
- [x] Clue cards show type icon + tint; plain-string fallback shows default icon.
- [x] Result overlay shows hero image (with attribution) when `imageUrl` is non-empty; layout is clean when image is absent or fails to load.
- [x] `ChallengeStatsScreen` opens from result overlay "View Stats" button and from chip long-press; shows streak / solve-rate / 30-day grid.
- [x] Streak badge (🔥N) appears on challenge chip when `currentStreak >= 2`.
- [x] `last30Days()` tested; 7 new tests + 61 total challenge tests pass.
- [x] `flutter analyze` reports no new warnings (30 pre-existing issues unchanged).
- [x] Docs updated.

**Status:** ✅ Complete (2026-05-29)
