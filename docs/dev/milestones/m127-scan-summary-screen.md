# M127 — Scan Summary Screen

**Status:** Complete (2026-05-25)
**Phase:** Scan UX
**Depends on:** M121 ✅, M122 ✅, M123 ✅, M125 ✅, M126 ✅

---

## Goal

After the scan completes, show a "Spotify Wrapped"-style summary screen that reveals the user's results with drama and delight — new countries, new continents, new heritage sites, achievements unlocked, and total trip count.

---

## Background

M121 scoped out `ScanSummaryScreen` explicitly:

> "Post-scan: Navigates to `ScanSummaryScreen` — unchanged by this milestone"
> "'Spotify Wrapped'-style stats reveal: Belongs in ScanSummaryScreen, not scan-in-progress"

The current scan flow ends with a plain completion state on the scan screen. This milestone replaces that with a rich reveal screen.

---

## Scope In

### Navigation
- When scan finishes (state transitions to `ScanState.done`), navigate to `ScanSummaryScreen` instead of showing inline completion UI
- Back/dismiss returns user to the main map screen

### Summary Data
The screen receives a `ScanSummaryData` object built from the scan results:
- `newCountries: List<String>` — ISO codes discovered this scan
- `newContinents: List<String>` — continent names discovered this scan
- `newHeritageSites: List<WhsSite>` — heritage sites found this scan
- `achievementsUnlocked: List<String>` — achievement IDs unlocked this scan
- `totalCountries: int` — cumulative total after scan
- `totalTrips: int` — total trips inferred after scan
- `totalHeritageSites: int` — cumulative total after scan

### Reveal Sequence (animated, staged)
1. **Hero stat** — large animated number: "You've visited N countries" with a celebratory confetti burst if any new country was found
2. **New discoveries row** — horizontally scrollable flag chips for newly found countries (if any)
3. **New continents** — continent name badges (if any new continent unlocked)
4. **Heritage sites** — site name list (if any new heritage sites)
5. **Achievements** — achievement badge cards for each achievement unlocked this scan (if any)
6. **Trips stat** — "Across N trips" subtitle

Each section animates in sequentially with a short stagger delay (~200 ms per section).

### CTA
- "Explore your map" button — navigates to main map screen
- "Share" button — navigates to share card screen (existing `ShareCardScreen`)

### Edge Case: Nothing New
If no new countries, continents, heritage sites, or achievements were found (re-scan of existing data):
- Show a simple "All up to date" card with current totals
- No confetti, no staged reveal

---

## Scope Out

- "Year in Review" breakdown by year (→ M94)
- Animated globe flyover on the summary screen
- Word cloud of visited places
- Rovy mascot appearance
- Detailed per-trip breakdown

---

## Files to Create / Modify

| File | Change |
|------|--------|
| `lib/features/scan/scan_summary_screen.dart` | New — full summary screen widget |
| `lib/features/scan/scan_screen.dart` | Navigate to `ScanSummaryScreen` on completion |
| `lib/router.dart` | Add `/scan-summary` route |

---

## Acceptance Criteria

- [ ] Completing a scan navigates to `ScanSummaryScreen`
- [ ] New countries shown as flag chips with country name
- [ ] New continents shown if any discovered
- [ ] New heritage sites listed if any discovered
- [ ] Achievements shown as styled badge cards if unlocked
- [ ] Confetti fires when at least one new country found
- [ ] "All up to date" state shown when nothing new
- [ ] "Explore your map" CTA navigates to map screen
- [ ] "Share" CTA navigates to share card screen
- [ ] No `flutter analyze` warnings introduced
