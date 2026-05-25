# M121 — Scan: Emotional Discovery Experience

**Branch:** milestone/m121-scan-emotional-discovery-experience
**Status:** In Progress

## Tasks

- [ ] T1 — Emotional progress copy & phase messaging
       Replace `"X photos processed…"` with phase-aware discovery language.
       Add `countriesFound` to `_ScanProgress`. Add `_buildScanHeader()` helper to `_ScanningView`.
       Three phases: Discovering / Building / Almost there.

- [ ] T2 — Globe as dominant hero
       Remove fixed `SizedBox(height: 260)` from `_ScanGlobeWidget.build()`.
       In `_ScanningView`, wrap globe in `Flexible(flex: 55)` and discovery feed in `Flexible(flex: 45)`.

- [ ] T3 — _DiscoveryEntry data class + wiring
       Add `_DiscoveryEntry {isoCode, photoCount, firstSeenYear}` private class.
       Change `_liveNewCodes: List<String>` → `_liveNewEntries: List<_DiscoveryEntry>`.
       Change `_existingCodesAtScanStart: List<String>` → `_existingEntriesAtScanStart: List<_DiscoveryEntry>`.
       Build existing entries from `_effectiveVisits` at scan start.
       Build live entries from `CountryAccum` as scan runs.
       Update `_ScanningView` props + all call sites.
       Extract codes for `_ScanGlobeWidget` from entries.

- [ ] T4 — _DiscoveryFeed + _DiscoveryCard widgets
       Horizontal `ListView` of `_DiscoveryCard` widgets.
       Existing entries → muted grey cards. New entries → primary-colour border, slide+fade in.
       Auto-scroll to newest card on arrival.
       Remove `_LiveCountryList`, `_ScanPassportPreview`, `_LiveCountryRow`.

- [ ] T5 — First-country cinematic overlay
       `_FirstCountryCinematic` widget: dark scrim + "Welcome to your world." + flag + country name.
       Fire only when `_existingEntriesAtScanStart.isEmpty` and first entry arrives.
       Auto-dismiss after 2.5 s (400 ms fade in + 1.5 s hold + 400 ms fade out).
       `_firstCountryCinematicShown` bool guard. Respects reduce-motion (skip if enabled).

- [ ] T6 — Enhanced discovery toast
       Add `firstSeenYear: int?` to `_DiscoveryToastBanner`.
       Show subtitle: "First discovered in {year}" or "First discovery!" for new/null year.
       Pass firstSeenYear from `_liveNewEntries.last` in `_ScanningViewState.didUpdateWidget`.

- [ ] T7 — Emotional empty states + docs
       `_NoScanYetHint`: "Your travel story is waiting." copy.
       `_EmptyResultsHint`: "No travel photos found yet." copy.
       Update milestone doc status + `current_task.md` + `backlog_active.md`.
       Run `flutter analyze` and `python3 scripts/index_docs.py`.
