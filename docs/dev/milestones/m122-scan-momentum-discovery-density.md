# M122 — Scan: Momentum & Discovery Density

**Status:** Complete (2026-05-25)
**Branch:** `milestone/m122-scan-momentum-discovery-density`
**Phase:** 25 — Scan UX Transformation

---

## Goal

Evolve the scan screen from "celebration-first" to "discovery + progression + lightweight
celebration". After M121, the screen has the right emotional language and a live discovery feed,
but the discovery cards consume too much vertical space, confetti fires at full intensity for every
country, and there is no live sense of progression breadth (continents, photo volume). The screen
should feel like a fast, smooth, continuously-moving exploration — not a series of celebration
interruptions.

**Target emotional arc:** constant forward momentum, where each discovery is a small signal in a
larger story, and only genuinely rare achievements trigger bigger responses.

---

## Design Principles

- **Momentum over interruption.** Scan must never pause or be obscured by celebration.
- **Density means more.** Fitting more discoveries on screen simultaneously creates a stronger
  sense of richness than one large card at a time.
- **Proportional celebration.** A new country is a micro-moment; a new continent is real news;
  50 countries is a cinematic event.
- **Globe dominance preserved.** The 55 % flex from M121 is the baseline — nothing below the globe
  should creep back into competing with it.

---

## What Exists Today (post-M121)

| Element | Current state |
|---|---|
| `_DiscoveryFeed` | Horizontal `ListView`, each `_DiscoveryCard` is 110 px wide with flag (26 px), name, year, photo count |
| Confetti | Single `ConfettiController` (800 ms, 8 particles, explosive, max 5 bursts, 8 s cooldown) |
| Progress header | Phase copy ("Discovering your world…") + thin `LinearProgressIndicator` |
| Scan mode selector | `SegmentedButton<bool>` with long label "New photos (since DD Mon YYYY)" |
| Discovery toast | Slide-in banner with flag, name, year subtitle — 2.5 s dismiss |
| Globe | `Flexible(flex: 55)`, no fixed height |

---

## Scope In

### T1 — Compact discovery chips (replaces horizontal card scroll)

Convert `_DiscoveryFeed` from a horizontal card scroll to a compact **vertical** list of
`_DiscoveryChip` rows. Each chip is a single tight row:

```
[flag 20px]  [Country Name]  [year or "This year"]          [photo count right-aligned]
  e.g.  🇯🇵  Japan            Since 2019                     124 photos
```

Chip spec:
- Height: 40 px (fixed via `itemExtent: 40` for O(1) layout)
- Flag: 20 px text
- Name: `bodySmall` weight 600
- Year: `labelSmall` muted — omit if unknown
- Photo count: `labelSmall` right-aligned, muted
- Newest chip: left accent bar (2 px, primary colour) instead of full border
- Existing chips: `onSurface` at 40 % opacity throughout
- New chips: `onSurface` full opacity, slide in from bottom (200 ms ease-out)
- List is **newest-first** (prepend, not append) so the top item is always the latest discovery
- Show max 50 entries; existing entries appear immediately as a pre-filled muted list below
  any new discoveries
- `ListView` with `shrinkWrap: false`, constrained by `Flexible(flex: 45)`

Remove `_DiscoveryCard` and `_DiscoveryCardState`. Add `_DiscoveryChip` (stateful for slide-in
animation on new entries).

Files: `scan_screen.dart` — replace `_DiscoveryFeed`/`_DiscoveryCard` internals; keep the class
names `_DiscoveryFeed` and `_DiscoveryFeedState` for minimal diff at call sites.

---

### T2 — Confetti priority tiers

Replace the single undifferentiated confetti burst with three priority levels:

```dart
enum _CelebrationLevel { micro, medium, full }
```

| Level | Trigger | Duration | Particles | Emission |
|---|---|---|---|---|
| `micro` | Any new country | 400 ms | 6 | 0.4 |
| `medium` | First country in a new continent | 800 ms | 18 | 0.6 |
| `full` | Major threshold (10 / 25 / 50 countries) | 1 400 ms | 35 | 0.8 |

Implementation:
- Keep a single `ConfettiController` but replace its `duration` by calling `.stop()` +
  reinitialising or by switching to a `_pendingLevel` queue approach: store the highest-priority
  pending level, play it once previous finishes.
- Simpler: use `_confettiCtrl?.stop(); _confettiCtrl?.duration = ...; _confettiCtrl?.play()`.
  The confetti package accepts duration changes before `play()`.
- `_maybeBurst(level)` replaces the current zero-arg `_maybeBurst()`.
- Continent detection: extract the continent from `kCountryContinent[isoCode]` (already imported
  via `region_lookup`). Track `_continentsSeenDuringScan: Set<String>` on `_ScanningViewState`.
  When a new entry arrives, check if its continent is already in the set; if not, upgrade to
  `medium`; add it to the set.
- Major thresholds: check `widget.liveNewEntries.length + widget.existingEntries.length` against
  `{10, 25, 50}` — if crossing a threshold with this batch, upgrade to `full`.
- Remove the current 5-burst cap and 8 s cooldown (no longer needed with priority gating —
  `micro` still rate-limits to one burst per new entry, not per second).
- Reduce-motion guard unchanged (skip all bursts if `MediaQuery.disableAnimationsOf`).

Files: `scan_screen.dart` — `_ScanningViewState` confetti logic, `_maybeBurst(level)` refactor.

---

### T3 — Live scan stats bar

Add a compact `_ScanStatsBar` widget that sits between the phase-copy header and the globe,
showing live counts during scanning:

```
  14 countries   •   3 continents   •   1,204 photos
```

Spec:
- Single `Row` with `MainAxisAlignment.center`, `Text` items separated by `Text(' · ')`.
- Typography: `labelMedium`, `onSurface` at 70 % opacity.
- Only shown when `isScanning == true` (hide at rest to keep the non-scanning view clean).
- `countriesCount` = `liveNewEntries.length + existingEntries.length`.
- `continentsCount` = count of distinct continents across all entries using `kCountryContinent`.
- `photosCount` = sum of `photoCount` across all entries.
- Updates on every `setState` triggered by new entries — no additional timer needed.
- Animate in with `AnimatedOpacity` (200 ms) when scan starts; fade out when scan ends.

Files: `scan_screen.dart` — new `_ScanStatsBar` widget; wire into `_ScanningView.build()`.

---

### T4 — Compact scan mode selector

The current `SegmentedButton<bool>` label reads `"New photos (since 24 May 2026)"` — wide and
heavy. Replace with a compact label pair:

- Segment 1: `"New"` with `Icons.update` icon; subtitle below toggle (separate `Text`, `labelSmall`)
  reading `"Since {_fmtDate(_lastScanAt!)}"` — moved out of the button label.
- Segment 2: `"All"` with `Icons.refresh` icon.

The `SegmentedButton` itself gains `style: SegmentedButton.styleFrom(...)` with:
- `minimumSize: Size(0, 32)` to reduce tap target height to 32 px (meets minimum 24 px visual).
- `textStyle: labelMedium` via `ButtonStyle`.

Layout change: move the last-scan date to a `Text` subtitle below the `SegmentedButton`:
```
  [New] [All]
  Last scanned: 24 May 2026
```

Files: `scan_screen.dart` — `SegmentedButton` call site at line ~824; `_ScanScreenState` build.

---

### T5 — Discovery toast rate-limiting

Currently, rapid country discoveries can queue multiple toasts. The toast uses a single-slot
approach (new toast cancels the previous) but the `_showToast()` call in `didUpdateWidget` may
be called multiple times in rapid succession if `liveNewEntries` gains 2+ entries between frames.

Fix: in `_ScanningViewState.didUpdateWidget`, only show the toast for the **most recently added**
entry if multiple new entries arrive at once (compare lengths, show only if exactly one new entry
arrived, or show the last new entry if multiple). This prevents stacked toast calls.

Also cap toast visibility: if `_toastTimer?.isActive == true` when a new toast is requested,
cancel the current one immediately and replace — the current behaviour — but add a minimum display
time of 500 ms before replacement (don't flash toast for < 500 ms). Track `_toastShownAt`
timestamp.

Files: `scan_screen.dart` — `_ScanningViewState._showToast()` + `didUpdateWidget`.

---

## Scope Out

| Feature | Reason |
|---|---|
| Heritage achievements during scan | Requires wiring `WorldHeritageLookupService` into the scan loop + live UNESCO site detection — separate milestone |
| Sound design | Needs audio asset pipeline (OGG slots, `audioplayers` integration for scan events) — separate milestone |
| Trip count live display | Trips are inferred post-scan from `inferTrips()` — not available live |
| Achievements display during scan | Achievement detection also runs post-scan — separate milestone |
| Scan velocity / burst drama | Photo scan stream timing is platform-controlled; we cannot artificially pace it |
| Rovy mascot | Needs mascot system + asset pipeline |
| Android / web | iOS-first per project policy |

---

## Acceptance Criteria

- [ ] Discovery chips are compact rows (height ~40 px), newest-first vertical list.
- [ ] Each chip shows: flag emoji, country name, year (if known), photo count right-aligned.
- [ ] Newest chip has a left accent bar in primary colour; no full border.
- [ ] Existing (pre-scan) chips visible immediately at scan start as muted rows.
- [ ] New chips slide in from bottom (200 ms) as countries are discovered.
- [ ] Confetti uses micro burst for new countries (400 ms, 6 particles).
- [ ] Confetti uses medium burst when first country in a continent is found (800 ms, 18 particles).
- [ ] Confetti uses full burst when crossing 10 / 25 / 50 total countries (1400 ms, 35 particles).
- [ ] Reduce-motion skips all confetti bursts.
- [ ] Live stats bar ("14 countries · 3 continents · 1,204 photos") visible during scan.
- [ ] Stats bar hidden at rest (not scanning).
- [ ] Scan mode selector is compact (32 px height); "Since {date}" moved below as subtitle text.
- [ ] Toast rate-limiting: rapid multi-country batches show only the last new entry's toast;
      no toast replaced in less than 500 ms of display.
- [ ] `flutter analyze` — 0 new errors or warnings.
- [ ] Globe `Flexible(flex: 55)` layout from M121 unchanged.
- [ ] All M121 acceptance criteria still met.

---

## Technical Notes

### Continent detection

`kCountryContinent` is already imported via `region_lookup` (used in `region_repository.dart`).
It maps ISO-3166-1 alpha-2 → continent string. Access it directly in `_ScanningViewState`:

```dart
import 'package:region_lookup/region_lookup.dart'; // already in scan_screen.dart imports
// kCountryContinent['JP'] → 'Asia'
```

Track `_continentsSeenDuringScan = <String>{}` on `_ScanningViewState` — reset on scan start.

### Confetti controller duration change

The `confetti` package's `ConfettiController` exposes `duration` as a mutable field. The pattern:

```dart
void _burst(_CelebrationLevel level) {
  if (reduceMotion) return;
  _confettiCtrl?.stop();
  _confettiCtrl?.duration = _durationFor(level);
  _confettiCtrl?.play();
}
```

This avoids creating/disposing multiple controllers. Verify with package source that `.stop()`
then `.duration =` then `.play()` works correctly before finalising — if not, create a separate
controller per level (3 total) and play only the appropriate one.

### Discovery chip slide-in direction

Chips are newest-first (prepended). New chips enter from the top (slide down 0.3 → 0.0 on Y
axis), not from the bottom, to match the natural read direction of a newest-first list.

```dart
_slide = Tween<Offset>(begin: const Offset(0, -0.5), end: Offset.zero)
    .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
```

### Stats bar photo count

Sum across both `existingEntries` and `liveNewEntries` during scan. Note: `existingEntries` photo
counts come from `EffectiveVisitedCountry.photoCount` (persisted, correct). `liveNewEntries` photo
counts come from `CountryAccum.photoCount` accumulated during the current scan batch — these are
new-only counts, not totals. Display as "N new photos" during scan if that's cleaner, or sum
both for a combined total (whichever reads more naturally in context — implement and review).

---

## Risks

| Risk | Mitigation |
|---|---|
| Newest-first chip list jumps layout on every new entry | Use `AnimatedList` or prepend with slide animation to avoid abrupt reflow |
| Confetti controller `stop()` + `duration` change behaves unexpectedly | Fall back to 3 separate controllers (micro/medium/full) if single-controller approach misbehaves |
| Stats bar photo count misleading (showing partial scan counts) | Label clearly as "photos found so far" or simply omit photo count from stats bar if it's noisy |
| Compact segmented button conflicts with current `SegmentedButton.styleFrom` call site | Check for existing `style` override before adding; override only what's needed |

---

## ADR-169

**Scan screen: proportional celebration and compact discovery density (M122)**

Decision: Replace the uniform confetti intensity with three priority tiers (micro/medium/full)
keyed to event significance (country/continent/major milestone). Convert the horizontal
`_DiscoveryCard` scroll to a compact vertical `_DiscoveryChip` list (newest-first, 40 px rows).
Add a live `_ScanStatsBar` (countries · continents · photos) visible during scanning.

Rationale: Uniform maximum-intensity confetti for every country cheapens the celebration of
genuinely rare events (first continent, 50 countries) and creates visual noise that competes with
the globe. Compact chips allow more simultaneous discoveries to be visible, creating a denser,
richer sense of exploration. The stats bar satisfies the user's need for progression breadth
without adding UI chrome that persists at rest.

Status: Accepted
