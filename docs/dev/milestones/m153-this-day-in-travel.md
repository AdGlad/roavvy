# M153 — This Day in Travel

**Branch:** `milestone/m153-this-day-in-travel`
**Phase:** 22 — Stats Depth
**Depends on:** M147
**Status:** Backlog

---

## Goal

On anniversary dates, users see a "X years ago today you visited Country" card on the Stats screen — a delightful moment of nostalgia that deepens the app's daily value and encourages return visits.

---

## Screen Layout

```
ThisDayInTravelCard (inline on Stats screen, top of list when active — between Hero and StatsGrid)
  Warm amber/gold gradient card
  "On this day" header with calendar icon
  "X years ago" subheader
  Flag emoji + country name (large)
  "Your first visit to [Country]" or "You were in [Country]"
  [Dismiss] button — suppresses card for 24h (stored in SharedPreferences)
```

---

## Scope

### In
- `lib/features/stats/widgets/this_day_card.dart` — card widget
- Match logic: find visits where `firstSeen.month == today.month && firstSeen.day == today.day`, within ±2 days
- If multiple matches, show the most recent anniversary (highest year gap >= 1)
- Dismiss: write suppression timestamp to `SharedPreferences`; card reappears after 24h
- Card only shown if anniversary year gap >= 1 (no same-year matches)
- Country name from `kCountryNames`

### Out
- Push notification for anniversary (deferred — privacy sensitive)
- Multiple anniversary cards stacked
- Web version

---

## Acceptance Criteria

- [ ] Given a visit to France on 15 Mar 2022, on 15 Mar 2026 the card shows "4 years ago · France".
- [ ] Given a visit within ±2 days of today (but not exact), card still appears.
- [ ] Given the user taps Dismiss, card does not reappear for 24 hours.
- [ ] Given no visit anniversary within ±2 days of today, card is not shown.
- [ ] Card never shows for visits in the current calendar year (gap must be >= 1).

---

## Technical Notes

- Match window: `(today - visit.firstSeen).inDays.abs() <= 2` AND `today.year - visit.firstSeen.year >= 1`.
- If multiple matches: pick the one with the largest year gap for maximum nostalgia impact.
- Suppression key: `SharedPreferences` key `"this_day_dismissed_at"` → ISO timestamp string. Compare to `DateTime.now().subtract(const Duration(hours: 24))`.
- Country name: `kCountryNames[countryCode] ?? countryCode`.
- ±2 day window handles weekends and timezone drift without being too loose.

---

## Dependencies

- Depends on: M147
- Blocks: nothing

---

## Definition of Done

- [ ] `flutter analyze` — no new issues.
- [ ] Unit tests: anniversary match logic with edge cases (leap years, ±2 day window, same-year suppression).
- [ ] Widget test: dismiss button writes suppression and card disappears.
- [ ] `current_state.md` updated.
