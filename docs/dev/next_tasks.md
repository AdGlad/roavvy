# M123 — Scan: Live Heritage Discovery & Stats Totals

**Branch:** milestone/m123-scan-live-heritage-stats-totals
**Status:** In Progress

## Tasks

- [ ] T1 — `WorldHeritageLookupService.totalSiteCount` getter
       Add `static int get totalSiteCount` to `WorldHeritageLookupService`.
       Returns sum of all sites across `_index` values.
       File: `apps/mobile_flutter/lib/features/heritage/world_heritage_lookup_service.dart`

- [ ] T2 — Live heritage count in scan state
       Add `_liveHeritageCount: int` to `_ScanScreenState`. Reset to 0 at scan start.
       Update `_liveHeritageCount = whsAccum.length` inside each batch setState call.
       Add `liveHeritageCount: int` prop to `_ScanningView`.
       Pass it down to `_ScanStatsBar`.
       File: `scan_screen.dart`

- [ ] T3 — Stats bar with totals
       Update `_ScanStatsBar` to show "14/244 countries · 3/7 continents [· 7/1,223 heritage sites]".
       `countriesTotal` = `kCountryContinent.length`.
       `continentsTotal` = 7.
       Heritage segment shown only when `liveHeritageCount > 0`.
       Format large numbers with comma separator.
       File: `scan_screen.dart`

- [ ] T4 — Dedicated heritage discovery toast + docs
       Add `_HeritageToastBanner` widget (gold / amber background).
       Add heritage toast state fields to `_ScanningViewState`.
       Add `_showHeritageToast(List<String> siteNames)` method.
       In `didUpdateWidget`: when new entry has `heritageSiteNames.isNotEmpty`, fire heritage
       toast 400ms after country toast.
       Position below country toast (top: 68) when both active simultaneously.
       Auto-dismiss after 3s. Respects reduce-motion (skip if disabled).
       Update milestone doc, `current_task.md`, `backlog_active.md`.
       Run `flutter analyze 2>/tmp/analyze.txt; tail /tmp/analyze.txt`.
       Run `python3 scripts/index_docs.py`.
       File: `scan_screen.dart`, milestone doc, docs.
