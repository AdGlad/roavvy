# M122 — Scan: Momentum & Discovery Density

**Branch:** milestone/m122-scan-momentum-discovery-density
**Status:** In Progress

## Tasks

- [ ] T1 — Compact discovery chips
       Replace `_DiscoveryCard`/`_DiscoveryCardState` with `_DiscoveryChip` (StatefulWidget).
       Vertical `ListView` (newest-first), `itemExtent: 40`.
       Each row: flag (20px) · country name · year label · photo count right-aligned.
       New chips slide in from top (Y offset -0.5 → 0, 200ms ease-out).
       Newest chip: 2px left accent bar in primary colour. Existing: 40% opacity.
       Keep class name `_DiscoveryFeed`/`_DiscoveryFeedState` at call sites.

- [ ] T2 — Confetti priority tiers
       Add `enum _CelebrationLevel { micro, medium, full }`.
       `_maybeBurst(_CelebrationLevel level)` replaces zero-arg `_maybeBurst()`.
       micro: 400ms, 6 particles, freq 0.4 — fires for every new country.
       medium: 800ms, 18 particles, freq 0.6 — fires when a new continent is first seen.
       full: 1400ms, 35 particles, freq 0.8 — fires when total countries crosses 10/25/50.
       Track `_continentsSeenDuringScan: Set<String>` on `_ScanningViewState`.
       Use `kCountryContinent` from `region_lookup` for continent lookup.
       Remove 5-burst cap and 8s cooldown; rate-limit naturally via priority gate.

- [ ] T3 — Live scan stats bar
       New `_ScanStatsBar` widget: `"14 countries · 3 continents · 1,204 photos"` row.
       Only visible when `isScanning == true`; `AnimatedOpacity` fade in/out (200ms).
       `countriesCount` = liveNewEntries.length + existingEntries.length.
       `continentsCount` = distinct continents via `kCountryContinent`.
       `photosCount` = sum photoCount across all entries.
       Position: between phase-copy header and globe in `_ScanningView.build()`.

- [ ] T4 — Compact scan mode selector
       Shorten `SegmentedButton` labels to `"New"` / `"All"` (icons kept).
       Add `style` override: `minimumSize: Size(0, 32)`, `textStyle: labelMedium`.
       Move last-scan date out of button label; show as `labelSmall` subtitle below toggle:
       `"Last scanned: 24 May 2026"` — only when `_lastScanAt != null`.

- [ ] T5 — Toast rate-limiting + docs
       In `didUpdateWidget`: if multiple new entries arrived in one update, toast only the
       last new entry. Track `_toastShownAt: DateTime?`; if toast was shown < 500ms ago,
       delay replacement until 500ms has elapsed (use `Future.delayed`).
       Update milestone doc status + `current_task.md` + `backlog_active.md`.
       Run `flutter analyze 2>/tmp/analyze.txt; tail /tmp/analyze.txt`.
       Run `python3 scripts/index_docs.py` in background.
