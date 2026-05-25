# M125 — Scan: Live Achievement Toasts & Live Trip Count

**Status:** In Progress (2026-05-25)
**Branch:** `milestone/m123-scan-live-heritage-stats-totals`
**Phase:** 25 — Scan UX Transformation

---

## Goal

Two live feedback enhancements during scanning:

1. **Achievement toasts** — when a country-count threshold is crossed during a scan,
   show a trophy toast ("🏆 Frequent Flyer — 5 countries!") so the user celebrates
   the milestone in real time rather than discovering it after the scan completes.

2. **Live trip count in stats bar** — extend the stats bar to show how many trips have
   been inferred so far ("3 trips"), updating per batch using the in-memory
   `inferTrips()` call on accumulated photo dates.

---

## What Exists Today (post-M124)

| Element | Current state |
|---|---|
| `_ScanStatsBar` | "14/244 countries · 3/7 continents · 7/1,157 heritage sites" — no trip count |
| Achievement detection | `AchievementEngine` runs post-scan only; nothing fires during scanning |
| `inferTrips(allDates)` | Called once post-scan; takes a `List<PhotoDateRecord>` |
| `allPhotoDates` | Local `List<PhotoDateRecord>` accumulated during scan loop |
| `_liveNewEntries` | Grows with each batch; length = live country count |
| `_ScanningViewState` | Has country toast + heritage toast infrastructure |

---

## Scope In

### T1 — Achievement detection during scan

Track which country-count achievements have already been toasted this session:

```dart
// _ScanScreenState
final Set<String> _toastedAchievements = {};
```

Reset at scan start alongside `_liveNewEntries.clear()`.

Country-count thresholds from `AchievementEngine`:
```
1, 3, 5, 10, 15, 20, 25, 30, 40, 50, 75, 100, 125, 150, 195
```

After each batch, inside the `setState` call, compute total countries:
```dart
final total = _liveNewEntries.length + existingEntries.length;
```

Wait — `existingEntries` is a state field on `_ScanningViewState`, not `_ScanScreenState`.
The scan state `_ScanScreenState` owns `_liveNewEntries`; pre-scan entries come from
`_existingEntries` (loaded before scan starts). Both are available in `_ScanScreenState`.

Check thresholds after adding new entries:

```dart
const _kAchievementThresholds = [1,3,5,10,15,20,25,30,40,50,75,100,125,150,195];

// Inside setState, after updating _liveNewEntries:
final totalCountries =
    _liveNewEntries.length + (_existingEntries?.length ?? 0);
for (final threshold in _kAchievementThresholds) {
  final id = 'countries_$threshold';
  if (totalCountries >= threshold && !_toastedAchievements.contains(id)) {
    _toastedAchievements.add(id);
    _pendingAchievementToasts.add(id);
  }
}
```

Pass pending toasts to `_ScanningView` as a new prop:

```dart
final List<String> pendingAchievementToasts; // drained each frame
```

`_ScanScreenState` uses a `List<String> _pendingAchievementToasts = []` and clears it
after passing to `_ScanningView` (set to `[]` in the same `setState`).

**Files:** `scan_screen.dart` — `_ScanScreenState`

---

### T2 — Live trip count threaded to stats bar

`allPhotoDates` accumulates during the scan loop. Call `inferTrips()` in-memory each
batch (it's pure/fast) and store the result count on state:

```dart
// _ScanScreenState
int _liveTripCount = 0;
```

Reset to 0 at scan start.

Inside setState after each batch:
```dart
_liveTripCount = inferTrips(allPhotoDates).length;
```

Note: `inferTrips` operates on the in-progress `allPhotoDates` list (not yet written
to DB). This gives a live estimate. It may differ slightly from the final post-scan
count (which uses all historical dates) but is close enough for the progress display.

Pass to `_ScanningView`:
```dart
_ScanningView(
  ...
  liveTripCount: _liveTripCount,
)
```

`_ScanningView` passes to `_ScanStatsBar`.

**Files:** `scan_screen.dart` — `_ScanScreenState`, `_ScanningView`, `_ScanStatsBar`

---

### T3 — Stats bar: add trip segment

Extend `_ScanStatsBar` to show trips when `liveTripCount > 0`:

```
14/244 countries  ·  3/7 continents  ·  7/1,157 heritage sites  ·  3 trips
```

The trip segment has no "total" denominator (total trips is unbounded) — just `"N trips"`.

Show when `liveTripCount > 0`.

**Files:** `scan_screen.dart` — `_ScanStatsBar`

---

### T4 — Achievement toast widget + `_ScanningViewState` wiring

Add `_AchievementToastBanner`:

```
┌────────────────────────────────────────┐
│  🏆  Achievement Unlocked              │
│     Frequent Flyer — 5 countries!      │
└────────────────────────────────────────┘
```

Spec:
- Background: `Colors.deepPurple[600]` at 95% opacity (distinct from amber heritage toast
  and primary country toast)
- Icon: `🏆` at 20px
- Title: `"Achievement Unlocked"` in `labelMedium` bold white
- Subtitle: `"<AchievementTitle> — N countries!"` in `bodySmall` white at 85% opacity
- Auto-dismiss: 3 s
- Slide in from top (same mechanics as other toasts)
- Stacks below heritage toast if active (top: 68 offset when heritage toast visible,
  else top: 0)
- If country toast, heritage toast, and achievement toast all active simultaneously:
  top offset = 136 (two toasts above it)
- Fires immediately upon receiving a pending achievement id from widget props

**Data flow in `_ScanningViewState`:**

```dart
String? _achievementToastId;
AnimationController? _achievementToastCtrl;
Animation<Offset>? _achievementToastSlide;
Timer? _achievementToastTimer;
```

In `didUpdateWidget`: drain `pendingAchievementToasts` (the prop). If it becomes
non-empty, call `_showAchievementToast(pendingAchievementToasts.first)`.
Queue remaining for sequential display (400 ms apart) if multiple arrive at once.

`_showAchievementToast(String id)` mirrors `_showHeritageToast` pattern:
- Extract title from a local map `_kAchievementTitles` keyed by id
- Extract threshold count from id (parse `id.split('_').last`)
- Set `_achievementToastId`, animate slide-in, start 3s dismiss timer

Local title map in `_ScanningViewState`:

```dart
static const _kAchievementTitles = {
  'countries_1': 'First Stamp',
  'countries_3': 'Triple Stamp',
  'countries_5': 'Frequent Flyer',
  'countries_10': 'Seasoned Traveller',
  'countries_15': 'Explorer',
  'countries_20': 'Globe Trotter',
  'countries_25': 'Well Travelled',
  'countries_30': 'World Wanderer',
  'countries_40': 'Continent Hopper',
  'countries_50': 'Borderless',
  'countries_75': 'Horizon Chaser',
  'countries_100': 'Century Club',
  'countries_125': 'Elite Traveller',
  'countries_150': 'Master Explorer',
  'countries_195': 'World Complete',
};
```

(These must match `kAchievementMeta` in `achievement.dart` for consistency.)

**Files:** `scan_screen.dart` — `_AchievementToastBanner`, `_ScanningViewState` state
fields + `_showAchievementToast()`, `didUpdateWidget`, `build`, `dispose`

---

### T5 — Docs & validation

- Update milestone status to Complete
- Update `current_task.md` and `backlog_active.md`
- Run `flutter analyze 2>/tmp/analyze.txt; tail /tmp/analyze.txt`
- Run `python3 scripts/index_docs.py`

---

## Scope Out

| Feature | Reason |
|---|---|
| Achievement pop-up after scan | Post-scan UX; separate milestone |
| All achievement types (heritage, continent, etc.) | Country-count only for now; others need cross-feature data |
| Queuing multiple achievement toasts sequentially | Show first only; additional ones seen in post-scan summary |
| Persistent trip total in stats bar | Trips are re-inferred post-scan; live count is an estimate |

---

## Acceptance Criteria

- [ ] `_toastedAchievements` resets to `{}` at scan start.
- [ ] Achievement toast fires when `liveNewEntries.length + existingEntries.length` crosses
      a threshold for the first time in the session.
- [ ] `_AchievementToastBanner` has deep purple background, "Achievement Unlocked" title,
      and subtitle showing title + country count.
- [ ] Achievement toast auto-dismisses after 3 s.
- [ ] Achievement toast slides from top, stacks below other active toasts.
- [ ] Stats bar shows `"N trips"` segment when `liveTripCount > 0`.
- [ ] `_liveTripCount` resets to 0 at scan start.
- [ ] `flutter analyze` — 0 new errors or warnings.
- [ ] All M121–M124 acceptance criteria still met.

---

## Technical Notes

### Checking `existingEntries` in `_ScanScreenState`

`_existingEntries` is the field on `_ScanScreenState` that holds pre-scan known countries.
Check the field name by reading the scan screen — it may be named `_existingEntries` or
similar. Use `widget.existingEntries` only from within `_ScanningView`.

### inferTrips signature

`inferTrips(List<PhotoDateRecord> dates)` — imported from trip inference library.
`allPhotoDates` is `List<PhotoDateRecord>` accumulated during the scan loop.

### Achievement title verification

Before writing `_kAchievementTitles`, verify against:
`apps/mobile_flutter/lib/features/achievements/achievement.dart` — `kAchievementMeta`

---

## ADR-171

**Scan screen: live achievement toasts and trip count (M125)**

Decision: Surface country-count achievement unlocks as a dedicated `_AchievementToastBanner`
(deep purple) fired immediately when a threshold is crossed. Show live inferred trip count
in the stats bar from the in-memory `inferTrips()` call on accumulated photo dates.

Rationale: Achievement unlocks are the most motivating scan moment after country discovery
itself. Surfacing them live closes the feedback loop. Live trip count adds a second
progression dimension to the stats bar.

Status: Accepted
