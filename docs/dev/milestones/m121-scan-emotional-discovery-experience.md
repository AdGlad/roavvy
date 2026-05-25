# M121 — Scan: Emotional Discovery Experience

**Status:** Complete (2026-05-25)
**Branch:** `milestone/m121-scan-emotional-discovery-experience`
**Phase:** 25 — Scan UX Transformation

---

## Goal

Transform the scan screen from a functional photo-indexing progress display into an emotional
travel discovery experience. The user should feel **curiosity → discovery → nostalgia → reward**
as their scan runs — not "waiting for a process to finish".

The scan is Roavvy's emotional engine. Right now it communicates what the app is doing
technically. After this milestone it should communicate what the user is *experiencing* — the
story of their life as a traveller, revealed in real time.

---

## Design Principles

- **Globe first.** The animated globe is the centrepiece; everything else supports it.
- **Discoveries happen live.** Every new country is a moment worth celebrating *during* the scan,
  not just at the end.
- **Emotional language.** Replace all technical progress copy with exploratory, human phrasing.
- **Story over stats.** "You first visited Switzerland in 2019" beats "14,329 photos scanned".
- **No dead time.** The screen must feel alive even between discoveries.

---

## What Exists Today

| Element | Current state |
|---|---|
| Globe widget | 260 px fixed height, idle spin, travel animation, pulse halo on newest country, confetti |
| Discovery toast | Slide-in banner: "New Country! + flag + name" — 2.5 s auto-dismiss |
| Progress copy | `"X photos processed…"` or `"Starting scan…"` below a LinearProgressIndicator |
| Left panel | Animated country list rows — existing (greyed) + new (slide-in) |
| Right panel | Passport stamp preview using full country list |
| Post-scan | Navigates to `ScanSummaryScreen` — unchanged by this milestone |

---

## Scope In

### T1 — Emotional progress copy & phase messaging

Replace the technical `"X photos processed…"` text and bare `LinearProgressIndicator`
with a two-line discovery header that evolves through three scan phases:

**Phase 1 — Discovery** (scan start until first 50 % of photos or first 3 countries found):
```
Discovering your world…
```

**Phase 2 — Building** (50 %+ photos processed or 3+ countries found):
```
Building your travel story…
[flag] [flag] [flag]  +N more countries
```

**Phase 3 — Wrapping up** (stream ended, finalising):
```
Almost there…
Saving your travel history
```

The `LinearProgressIndicator` becomes a thin accent line (height 2, primary colour, no value
label) that sits below the header text. Remove the raw photo count entirely during normal scan.
Show `"X countries found"` as a live counter instead.

Files: `scan_screen.dart` (`_ScanningView._buildHeader()` new helper, `_ScanProgress`
extended with `countriesFound` field).

---

### T2 — Globe as dominant hero

Increase the globe from its fixed `height: 260` to a flexible `Flexible(flex: 5)` within
`_ScanningView`'s column, so it occupies roughly 55 % of available vertical space on any device.
The bottom panel (discovery feed, T3) takes the remaining `Flexible(flex: 3)`.

This makes the globe the unambiguous focal point rather than one element among equals.

Files: `scan_screen.dart` (`_ScanningView.build()` layout change, `_ScanGlobeWidget` remove
fixed `SizedBox(height: 260)` wrapper).

---

### T3 — Unified discovery feed (replaces split panel)

Replace the two-column layout (country list left / passport stamps right) with a single
horizontal `ListView` of "discovery cards" that scroll left-to-right as new countries arrive.

Each card (`_DiscoveryCard`):

```
┌─────────────────────┐
│  🇬🇷               │
│  Greece             │
│  First visit: 2018  │
│  124 photos         │
└─────────────────────┘
  width ≈ 120, height fills panel
```

- Cards animate in from the right (slide + fade, 300 ms) when a country is found.
- Existing countries (pre-scan) appear immediately on scan start as muted grey cards.
- Newest discovery card is highlighted (primary colour border, slightly larger scale).
- Scroll automatically snaps to the newest card.
- Photo count comes from `CountryAccum.photoCount` (already available).
- First visit year comes from `CountryAccum.firstSeen?.year` (already available).
- Contextual year label: `firstSeen == null` → omit year row; year == current year →
  show "This year"; year present → "First visit: {year}".

Passport stamp preview is retired from the scan screen (it remains in its own card template
context). The discovery feed is more emotionally direct.

Files: `scan_screen.dart` — remove `_LiveCountryList`, `_ScanPassportPreview`, `_LiveCountryRow`;
add `_DiscoveryFeed`, `_DiscoveryCard`, `_DiscoveryCardData` (simple value class holding
`isoCode`, `photoCount`, `firstSeenYear`, `isNew`). `_ScanningView` wiring updated.

The `CountryAccum` data must be passed down so `_DiscoveryFeed` can show photo count and year.
Extend `_ScanningView` props: replace `liveNewCodes: List<String>` with
`liveNewEntries: List<_DiscoveryEntry>` and `existingEntries: List<_DiscoveryEntry>` where
`_DiscoveryEntry` = `{isoCode, photoCount, firstSeenYear}`. Update `ScanScreenState._scan()`
to build these lists from `CountryAccum` data as it arrives.

---

### T4 — First-country cinematic overlay

When the very first country is discovered during a scan (i.e. `_liveNewCodes` grows from 0 to 1
**and** `_existingCodesAtScanStart` is empty — meaning the user has never scanned before, or
is doing a full rescan with no prior data), show a full-screen cinematic overlay:

```
[dark semi-transparent scrim over the entire scan screen]

       Welcome to your world.

       🇬🇷  Greece

       [auto-dismisses after 2.5 s]
```

- Fade in over 400 ms, hold 1.5 s, fade out 400 ms.
- Country name and flag centred, large typography (`headlineMedium` bold).
- Only fires once per scan (guard: `_firstCountryCinematicShown` bool on state).
- Respects `MediaQuery.disableAnimationsOf` — if reduce-motion is on, skip the overlay
  entirely and let the toast handle it.
- Does NOT fire on incremental scans where `_existingCodesAtScanStart` is non-empty
  (the user already has countries — this cinematic is for first-time magic only).

Files: `scan_screen.dart` — `_FirstCountryCinematic` overlay widget + show/hide logic in
`_ScanningViewState.didUpdateWidget`.

---

### T5 — Enhanced discovery toast

The existing `_DiscoveryToastBanner` shows: `"New Country! + flag + name"`.

Enhance it to show a contextual subtitle drawn from `CountryAccum.firstSeen`:

```
🎉  New Country!  🇮🇹 Italy
     First discovered in 2019
```

If `firstSeen` is null or is the current year, show `"First discovery!"` instead.

The toast already receives `code` — it needs `firstSeenYear: int?` added as a parameter.
`_ScanningViewState._showToast()` needs to receive this alongside the code.
`_ScanningView` needs `liveNewEntries` (from T3) so it can look up firstSeenYear when calling
`_showToast`.

Files: `scan_screen.dart` — `_DiscoveryToastBanner(code, firstSeenYear)` + call site updates.

---

### T6 — Emotional empty / idle states

Update the two non-scanning hint widgets to match the new emotional tone:

**`_NoScanYetHint`** (first launch, never scanned):

```
Your travel story is waiting.

Tap "Scan my photos" to discover
the countries hidden in your photo library.

Photos never leave your device.
```

**`_EmptyResultsHint`** (scanned but no geotagged photos):

```
No travel photos found yet.

Make sure Location is enabled on your camera
and try scanning again — or add countries
manually using Review & Edit.
```

Files: `scan_screen.dart` — update widget `build()` methods.

---

## Scope Out

| Feature | Reason |
|---|---|
| Rovy the Quokka mascot | Needs a mascot system + asset pipeline — separate milestone |
| Travel Identity Score | Requires its own data model + scoring engine |
| Background scan mode | Major platform feature (BGProcessingTask on iOS) |
| Audio / sound effects | Depends on audio asset pipeline (see M111) |
| Memory Pulse moments during scan | Complex service coordination — post-scan pulse already exists |
| Scan velocity changes (burst / pause drama) | Photo scan stream timing is platform-controlled |
| "Spotify Wrapped"-style stats reveal | Belongs in ScanSummaryScreen, not scan-in-progress |
| Stamp layout packing engine improvements | Stamp preview removed from scan screen in T3 |
| Web scan screen | Web fallback `_WebFallbackView` is unchanged |
| Android | iOS-first per project policy |

---

## Acceptance Criteria

- [ ] Progress text never shows raw photo count during scanning; shows phase-appropriate
      discovery copy instead.
- [ ] `"X countries found"` counter updates live as new countries are detected.
- [ ] Globe occupies ~55 % of scan screen height (not a fixed 260 px).
- [ ] Split panel (country list + passport stamps) is replaced by horizontal discovery feed.
- [ ] Discovery cards appear in real time as countries are found; existing cards shown from start.
- [ ] Each card shows: flag emoji, country name, first-visit year (if known), photo count.
- [ ] Newest card is highlighted with primary colour border; feed auto-scrolls to it.
- [ ] First-country cinematic fires only when `existingCodes` is empty and first country arrives.
- [ ] First-country cinematic respects reduce-motion (skipped entirely if enabled).
- [ ] Discovery toast shows contextual first-visit subtitle.
- [ ] `_NoScanYetHint` and `_EmptyResultsHint` use updated emotional copy.
- [ ] Existing scan logic (isolate, batch processing, GPS, achievements, confetti, travel
      animation on globe) unchanged.
- [ ] `flutter analyze` — 0 new errors or warnings.
- [ ] Existing widget tests for `resolveBatch` and `_scan` flow continue to pass.

---

## Technical Notes

### Data flow change for discovery feed (T3)

`CountryAccum` data is available in `_ScanScreenState._scan()` as `accum: Map<String, CountryAccum>`.
Currently only the keys (ISO codes) are forwarded to `_ScanningView` via `liveNewCodes`.

After T3, forward richer data:

```dart
// New value object (private to scan_screen.dart)
class _DiscoveryEntry {
  const _DiscoveryEntry({
    required this.isoCode,
    required this.photoCount,
    this.firstSeenYear,
  });
  final String isoCode;
  final int photoCount;
  final int? firstSeenYear;
}
```

`_ScanScreenState` builds and maintains two lists:
- `_existingEntries` — built once at scan start from `_effectiveVisits` + `_repo.loadFirstSeen()`.
  `firstSeenYear` comes from `EffectiveVisitedCountry.firstSeen?.year`.
- `_liveNewEntries` — appended during scan from `CountryAccum`.

Both passed to `_ScanningView` which passes them to `_DiscoveryFeed`.

### Globe layout change (T2)

`_ScanGlobeWidget` currently wraps itself in `SizedBox(height: 260)` inside its `build()`.
Remove that wrapper and let the parent column control height via `Flexible`:

```dart
// _ScanningView.build() — simplified
Column(children: [
  // header (fixed height)
  _buildScanHeader(),
  // globe — 55% of remaining space
  Flexible(flex: 55, child: _ScanGlobeWidget(...)),
  const SizedBox(height: 8),
  // discovery feed — 45% of remaining space
  Flexible(flex: 45, child: _DiscoveryFeed(...)),
])
```

### First-country cinematic (T4)

Implemented as an `OverlayEntry` inserted into `Overlay.of(context)` from
`_ScanningViewState`, not as a stack child — this ensures it covers the AppBar and scan
controls for maximum drama, then self-removes after the animation completes.

---

## Risks

| Risk | Mitigation |
|---|---|
| Layout regression on small screens (SE size) | Test at 375×667 pt; ensure `Flexible` doesn't overflow |
| `_DiscoveryEntry` data not available at scan start for existing countries | Load `firstSeen` from Drift in `_loadPersisted()` alongside `_effectiveVisits` |
| First-country cinematic triggering unexpectedly on incremental scan | Guard with `_existingCodesAtScanStart.isNotEmpty` check |
| Discovery feed scroll performance with many countries | Use `ListView` with fixed-width items and `itemExtent` for O(1) layout |

---

## ADR-168

**Scan screen: emotional-first layout replacing technical progress display (M121)**

Decision: Replace the split two-panel layout (country list + passport stamps) in `_ScanningView`
with a single horizontal discovery feed of `_DiscoveryCard` widgets. Remove passport stamp
preview from scan screen entirely (it remains in card editor context). Expand globe from fixed
260 px to flexible ~55 % of available height.

Rationale: The split panel divides user attention between two low-emotion data views during the
most impactful moment in the app. A single focused discovery feed keeps attention on the globe
and the moment of country revelation. Passport stamps are better enjoyed in the card editor
where they are interactive and full-width.

Status: Proposed
