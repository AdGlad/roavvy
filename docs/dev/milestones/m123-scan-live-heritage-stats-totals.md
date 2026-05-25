# M123 — Scan: Live Heritage Discovery & Stats Totals

**Status:** Complete (2026-05-25)
**Branch:** `milestone/m123-scan-live-heritage-stats-totals`
**Phase:** 25 — Scan UX Transformation

---

## Goal

Close the two remaining gaps from the M121/M122 design brief:

1. **Stats bar totals** — replace "14 countries · 3 continents" with "14/244 countries ·
   3/7 continents · 7/1,223 heritage sites" so the user can feel progression against a
   known scale.
2. **Dedicated heritage discovery toast** — when a new UNESCO World Heritage Site is found
   during a scan, fire a separate gold-themed toast ("🏛 Acropolis of Athens") distinct from
   the country discovery toast. Heritage is already detected live (M119 wiring in `whsAccum`);
   it just isn't surfaced to the user in real time.

---

## What Exists Today (post-M122)

| Element | Current state |
|---|---|
| `_ScanStatsBar` | Shows "N countries · N continents · N photos" (no totals, no heritage) |
| `_DiscoveryEntry.heritageSiteNames` | Populated per-country from `whsAccum` during scan; shown as a 🏛 badge in chip and site names in country toast |
| Heritage detection | `WorldHeritageLookupService.findBatch()` runs in scan loop; `whsAccum` accumulates per batch |
| Total site count | Not exposed — `WorldHeritageLookupService._index` is private; no `totalSiteCount` getter |
| Heritage toast | None — heritage appears only as a footnote in the country toast |

---

## Scope In

### T1 — `WorldHeritageLookupService.totalSiteCount` getter

Add a `static int get totalSiteCount` to `WorldHeritageLookupService`:

```dart
static int get totalSiteCount =>
    _index.values.fold(0, (sum, list) => sum + list.length);
```

This is safe to call after `init()`. Returns 0 before initialisation (acceptable — stats bar
only shows during scanning, by which point init has completed).

Files: `apps/mobile_flutter/lib/features/heritage/world_heritage_lookup_service.dart`

---

### T2 — Live heritage count threaded through scan state

`whsAccum` is a local variable in `_ScanScreenState._scan()`. To surface a live heritage count
to `_ScanStatsBar`, track it on state:

```dart
// _ScanScreenState
int _liveHeritageCount = 0;
```

In the scan loop, after each batch, update:

```dart
_liveHeritageCount = whsAccum.length;
```

Inside the `if (mounted) setState(...)` call that already runs after each batch.

Reset `_liveHeritageCount = 0` at scan start (alongside `_liveNewEntries.clear()`).

Pass to `_ScanningView`:

```dart
_ScanningView(
  ...
  liveHeritageCount: _liveHeritageCount,
)
```

`_ScanningView` passes it to `_ScanStatsBar`.

Files: `scan_screen.dart` — `_ScanScreenState`, `_ScanningView` props, `_ScanStatsBar`.

---

### T3 — Stats bar with totals

Update `_ScanStatsBar` to show counts against known totals:

```
14/244 countries  ·  3/7 continents  ·  7/1,223 heritage sites
```

- `countriesTotal` = `kCountryContinent.length` (244, from `shared_models`)
- `continentsTotal` = 7 (hardcoded — there are always 7 continents in the dataset)
- `heritageSitesTotal` = `WorldHeritageLookupService.totalSiteCount`
- Heritage segment only shown when `liveHeritageCount > 0` (not everyone will find sites)
- Format numbers ≥ 1000 with comma separator (Dart's `NumberFormat` from `intl`, already a
  dependency, or manual `toString()` with insertion)

Updated `_ScanStatsBar` signature:

```dart
class _ScanStatsBar extends StatelessWidget {
  const _ScanStatsBar({
    required this.liveNewEntries,
    required this.existingEntries,
    required this.liveHeritageCount,
    required this.visible,
  });
  final int liveHeritageCount;
  // ... existing fields
}
```

Files: `scan_screen.dart` — `_ScanStatsBar.build()`, constructor.

---

### T4 — Dedicated heritage discovery toast

Add `_HeritageToastBanner` widget — gold-themed, distinct from `_DiscoveryToastBanner`:

```
┌─────────────────────────────────────────┐
│  🏛  World Heritage Site               │
│     Acropolis of Athens                 │
└─────────────────────────────────────────┘
```

Spec:
- Background: `Colors.amber[700]` at 95% opacity (gold, distinct from primary-colour country toast)
- Icon: `🏛` at 20px
- Title: `"World Heritage Site"` in `labelMedium` bold white
- Subtitle: site name in `bodySmall` white at 85% opacity
- If multiple sites in one batch: show first site name + `"+N more"` suffix
- Auto-dismiss: 3 s (slightly longer than country toast 2.5 s — heritage is rarer and worth reading)
- Slide in from top (same mechanics as `_DiscoveryToastBanner`)
- Stacks after country toast: fires 400 ms after the country toast appears (if same batch has
  both a new country and new heritage sites), so they don't overlap simultaneously

**Data flow:**

`_ScanningViewState` needs to know when new heritage sites arrive. Currently `heritageSiteNames`
is bundled into `_DiscoveryEntry` per country. This is sufficient: in `didUpdateWidget`, when
a new entry arrives with `newEntry.heritageSiteNames.isNotEmpty`, fire the heritage toast.

Track:
```dart
// _ScanningViewState
String? _heritageToastSiteName;
int _heritageToastExtraCount = 0;
AnimationController? _heritageToastCtrl;
Animation<Offset>? _heritageToastSlide;
Timer? _heritageToastTimer;
```

`_showHeritageToast(List<String> siteNames)` — mirrors `_doShowToast` pattern.

In `didUpdateWidget`:
```dart
if (newEntry.heritageSiteNames.isNotEmpty && !MediaQuery.disableAnimationsOf(context)) {
  // Delay 400ms so country toast renders first.
  Future.delayed(const Duration(milliseconds: 400), () {
    if (mounted) _showHeritageToast(newEntry.heritageSiteNames);
  });
}
```

In `build`, render below the country toast overlay:
```dart
if (_heritageToastSiteName != null && _heritageToastSlide != null)
  Positioned(
    top: _toastEntry != null ? 72 : 0, // below country toast if both active
    left: 0,
    right: 0,
    child: SlideTransition(
      position: _heritageToastSlide!,
      child: _HeritageToastBanner(
        siteName: _heritageToastSiteName!,
        extraCount: _heritageToastExtraCount,
      ),
    ),
  ),
```

Files: `scan_screen.dart` — `_HeritageToastBanner`, `_ScanningViewState` heritage toast state +
`_showHeritageToast()`, `didUpdateWidget`, `build`, `dispose`.

---

### T5 — Docs

- Update milestone status to Complete
- Update `current_task.md` and `backlog_active.md`
- Run `flutter analyze 2>/tmp/analyze.txt; tail /tmp/analyze.txt`
- Run `python3 scripts/index_docs.py`

---

## Scope Out

| Feature | Reason |
|---|---|
| Sound design | Needs audio asset pipeline — separate milestone |
| Achievements display during scan | Achievement detection runs post-scan; would require major scan loop restructure |
| Heritage progress widget (7/25 persistent bar) | Achievement-style tracker — separate milestone post sound |
| "Gold pulse" map icon on heritage discovery | Requires heritage overlay layer on the globe — separate milestone |
| Trips live display | Trips inferred post-scan from `inferTrips()` — not available live |

---

## Acceptance Criteria

- [ ] `WorldHeritageLookupService.totalSiteCount` returns correct count (> 0 after init).
- [ ] Stats bar shows "14/244 countries · 3/7 continents" format during scanning.
- [ ] Heritage segment ("7/1,223 heritage sites") appears in stats bar only when
      `liveHeritageCount > 0`.
- [ ] Large numbers use comma separator (e.g. "1,223").
- [ ] `_HeritageToastBanner` fires when a new `_DiscoveryEntry` has non-empty `heritageSiteNames`.
- [ ] Heritage toast is gold-themed (amber background), distinct from country toast (primary).
- [ ] Heritage toast shows site name; multiple sites in one batch show first + "+N more".
- [ ] Heritage toast fires 400 ms after country toast when both occur in same batch.
- [ ] Heritage toast auto-dismisses after 3 s.
- [ ] Reduce-motion skips heritage toast animation (but may still show statically — omit entirely
      if `disableAnimationsOf` is true, consistent with country toast behaviour).
- [ ] `_liveHeritageCount` resets to 0 at scan start.
- [ ] `flutter analyze` — 0 new errors or warnings.
- [ ] All M121/M122 acceptance criteria still met.

---

## Technical Notes

### Number formatting

`intl` is already a dependency. For comma-separated thousands:

```dart
import 'package:intl/intl.dart';
final _fmt = NumberFormat('#,###');
_fmt.format(1223) // → "1,223"
```

Or without intl (simpler for isolated use):
```dart
String _fmtN(int n) {
  final s = n.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}
```

### Heritage toast top offset

When both `_toastEntry` (country) and `_heritageToastSiteName` (heritage) are active
simultaneously, the heritage toast is positioned below the country toast. Country toast height
is approximately 56–64 px. Use `top: 68` as a safe offset — no need to measure dynamically.

### `_liveHeritageCount` vs `whsAccum.length`

`whsAccum` counts unique site IDs (not countries). A country with 3 heritage sites contributes
3 to `whsAccum.length`. This is the correct denominator for "N/1,223 heritage sites" — it matches
the UNESCO total which counts individual sites, not countries.

---

## ADR-170

**Scan screen: live heritage toast and stats-bar totals (M123)**

Decision: Surface live heritage site discoveries as a dedicated gold `_HeritageToastBanner`
fired 400 ms after the country toast. Show stats-bar counts against fixed totals
(244 countries, 7 continents, `WorldHeritageLookupService.totalSiteCount` heritage sites).

Rationale: Heritage site discovery is meaningfully rarer than country discovery and deserves its
own celebration signal. Showing counts against totals ("14/244") creates a gamification hook —
the user immediately understands the scale of what remains — which drives re-scan motivation.

Status: Accepted
