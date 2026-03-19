# UX Design — Milestone 17: Navigation Redesign

**Tasks covered:** 47 (4-tab shell), 48 (Journal screen), 49 (Stats & Achievements screen)

---

## Task 47 — 4-Tab Navigation Shell

### Tab Bar Spec

```
Component: Bottom NavigationBar
Tabs (left to right): Map · Journal · Stats · Scan
```

| Tab | Icon | Selected Icon | Label |
|-----|------|---------------|-------|
| Map | `Icons.map_outlined` | `Icons.map` | "Map" |
| Journal | `Icons.list_alt_outlined` | `Icons.list_alt` | "Journal" |
| Stats | `Icons.leaderboard_outlined` | `Icons.leaderboard` | "Stats" |
| Scan | `Icons.camera_alt_outlined` | `Icons.camera_alt` | "Scan" |

**Rationale:**
- `list_alt` evokes a chronological record — more specific than a generic list.
- `leaderboard` pairs naturally with stats and achievements without being literal ("bar_chart" feels spreadsheet-y; "leaderboard" feels aspirational).
- All icons use the `_outlined` variant when unselected and the filled variant when selected — standard Material 3 NavigationBar behaviour.

### Interaction States

- **Default:** Map tab selected (index 0). This preserves the existing launch behaviour.
- **Tab switch:** `IndexedStack` keeps all four screens alive. Scroll position and state are preserved on return.
- **Scan complete:** app programmatically returns to Map tab (index 0). Same behaviour as current 2-tab shell.
- **Badge:** no notification badges in M17.

### Accessibility

- Each `NavigationDestination` label is always visible (not icon-only).
- VoiceOver reads: "Map, tab, 1 of 4" etc.
- Touch target for each tab destination is at least 44 × 44 pt (Material NavigationBar default meets this).

---

## Task 48 — Journal Screen

```
Flow: Browse trip history
Entry point: Journal tab (index 1)
User goal: "I want to see where I've been and when."
```

### States

```
Component: JournalScreen
States: loading | empty | populated
```

**loading:**
Since trip data is read from local SQLite, reads are near-instant. A loading state is not shown explicitly — the `FutureBuilder` resolves fast enough that no spinner is perceived. If data has not arrived within a single frame, render nothing (blank) rather than a spinner. Principle 3: "Never show a loading spinner for data that is already in the local DB."

**empty:**
```
[Centred in the body, vertically middle of screen]

  ✈️  (travel icon — `Icons.flight_takeoff`, 48pt, secondary colour)

  "Your journal is empty"
  (headline style, centred)

  "Scan your photos to build your travel history."
  (body style, centred, secondary colour, max 2 lines)

  [Scan Photos]
  (FilledButton, centred, navigates to Scan tab index 3)
```

**populated:**

AppBar: title "Journal", no actions.

Body: `SliverList` with sticky year section headers.

Section header format: `"2024  ·  5 trips"` (year in title style, trip count in body/secondary).

Trip row:

```
┌────────────────────────────────────────┐
│  🇯🇵  Japan                     →      │   ← flag emoji + country name + trailing chevron
│      3 Jan – 17 Jan 2024  ·  15 days  │   ← date range + duration, secondary colour
│      📷 82 photos                      │   ← photo count, secondary colour (omit if 0)
│      [Added manually]                  │   ← Chip, only shown if isManual == true
└────────────────────────────────────────┘
```

- **Flag emoji:** derived from ISO 3166-1 alpha-2 code at display time (e.g., `"GB"` → 🇬🇧). Renders natively on iOS without assets.
- **Trailing chevron:** `Icons.chevron_right`, secondary colour, 20pt. Signals tappability.
- **Row tap:** opens `CountryDetailSheet` as a modal bottom sheet for the corresponding country. `EffectiveVisitedCountry?` is obtained by looking up the trip's `countryCode` in the `effectiveVisitsProvider` result set.
- **Row height:** at minimum 56pt (Material list tile standard). With two body lines + optional chip, expect ~72–88pt.
- **Dividers:** subtle `Divider` between rows within a section; no divider between the last row and the next section header.

### Edge Cases

- **Country code not in `kCountryNames`:** display the raw code (same fallback as CountryDetailSheet).
- **Trip with `photoCount == 0`:** omit the photo count line entirely (manually added trips with no photos).
- **Trip spanning two calendar years:** group by `startedOn.year`. A Dec 2023 – Jan 2024 trip appears in the 2023 section.
- **Single trip in a year:** section header reads "2021  ·  1 trip" (singular).
- **Very long country name:** truncate with ellipsis at 1 line; tooltip not needed.

### Copy

| Location | String |
|----------|--------|
| AppBar title | "Journal" |
| Empty heading | "Your journal is empty" |
| Empty body | "Scan your photos to build your travel history." |
| Empty CTA | "Scan Photos" |
| Section header format | "[YEAR]  ·  [N] trip[s]" |
| Photo count | "📷 [N] photo[s]" |
| Manual trip badge | "Added manually" |

### Accessibility

- VoiceOver for a trip row: "[Country name], [date range], [N] days, [N] photos[, added manually]". Use `Semantics(label: ...)` to combine the sub-elements into one meaningful label.
- Flag emoji: include `Semantics(label: "[Country name] flag, ")` or suppress the emoji from VoiceOver (it reads as "[Country name] flag" already on iOS — verify on device).
- Section headers: `Semantics(header: true)`.

---

## Task 49 — Stats & Achievements Screen

```
Flow: View travel stats and achievements
Entry point: Stats tab (index 2)
User goal: "I want to know how much I've travelled and what I've achieved."
```

### States

```
Component: StatsScreen
States: loading | empty | populated
```

**loading:** Same principle as Journal — local data, near-instant. No spinner.

**empty (no visits yet):**
- Stats panel shows: "0 countries · 0 regions · —"
- Achievement gallery shows all achievements in locked state.
- No empty state message needed — the locked achievement gallery communicates "something to work towards."

**populated:**

AppBar: title "Stats", no actions.

---

### Stats Panel

A horizontal row of three stat tiles. Use a `Row` with `Expanded` children or a fixed-width card layout.

```
┌────────────┐  ┌────────────┐  ┌────────────┐
│     42     │  │    187     │  │    2019    │
│  Countries │  │   Regions  │  │   Since    │
└────────────┘  └────────────┘  └────────────┘
```

- **Number:** `displayLarge` or `headlineMedium` text style. Bold weight.
- **Label:** `labelMedium` text style. Secondary colour.
- **Countries:** `effectiveVisitsProvider` result set length.
- **Regions:** `RegionRepository.countUnique()` — distinct `regionCode` values across all trips.
- **Since:** earliest year from `travelSummaryProvider`; display as 4-digit year. If no data: "—".
- **Tile background:** `surfaceVariant` colour. Rounded corners (8pt radius). Equal width.
- Tiles are not tappable in M17.

**Accessibility:**
- VoiceOver for Countries tile: "42 countries visited"
- VoiceOver for Regions tile: "187 regions visited"
- VoiceOver for Since tile: "Travelling since 2019" (or "No travel data yet" if "—")

---

### Achievement Gallery

Section heading: "Achievements" (`titleMedium`, left-aligned, with 16pt top padding).

Layout: 2-column `GridView` with fixed cross-axis count 2. Item aspect ratio ~1.1 (slightly wider than tall).

**Sort order:** unlocked achievements first (sorted by unlock date, most recent first), then locked achievements.

**Achievement card — unlocked:**

```
┌──────────────────────┐
│  🏆  (icon, 28pt)    │   ← amber/gold tint background
│                      │
│  Explorer            │   ← achievement title, bodyMedium bold
│  Visit 10 countries  │   ← description, bodySmall, secondary
│                      │
│  ✓ 14 Jan 2024       │   ← unlock date, labelSmall, primary colour
└──────────────────────┘
```

**Achievement card — locked:**

```
┌──────────────────────┐
│  🔒  (icon, 28pt)    │   ← neutral/surface background, 40% opacity overlay
│                      │
│  Nomad               │   ← title, bodyMedium, secondary colour (dimmed)
│  Visit 25 countries  │   ← description, bodySmall, secondary colour (dimmed)
│                      │
│  (no date)           │
└──────────────────────┘
```

- Locked cards use reduced opacity (`Opacity(opacity: 0.55, child: ...)`) on the entire card, or `onSurface` colour at reduced opacity for text — whichever the theme supports cleanly.
- Locked icon: use `Icons.lock_outline` in place of the achievement icon (or overlay it). This makes the locked state unambiguous without relying on colour alone (Principle 6 — colour is not the only differentiator).
- Cards are not tappable in M17 (achievement detail deferred to M18).

**Achievement icon:** M17 uses the Material icon `Icons.emoji_events_outlined` for all unlocked achievements, and `Icons.lock_outline` for locked. Per-achievement custom icons are a M18 concern.

**Unlock date format:** "Unlocked [d MMM yyyy]" — e.g., "Unlocked 14 Jan 2024".

### Edge Cases

- **No achievements unlocked:** all cards shown in locked state. Gallery is still shown (not hidden). This motivates the user.
- **All achievements unlocked:** gallery shows all in unlocked state.
- **Single achievement in catalogue:** grid renders with one card on the left, empty space on the right. Acceptable.

### Copy

| Location | String |
|----------|--------|
| AppBar title | "Stats" |
| Stats — Countries label | "Countries" |
| Stats — Regions label | "Regions" |
| Stats — Since label | "Since" |
| Stats — Since fallback | "—" |
| Achievements section heading | "Achievements" |
| Unlock date format | "Unlocked [d MMM yyyy]" |

### Accessibility

- Stats panel: each tile has a `Semantics(label: "[N] countries visited")` etc.
- Achievement grid: each card has `Semantics(label: "[Title]. [Description]. [Unlocked on date / Not yet unlocked].")`.
- Locked cards: `Semantics(label: "[Title]. [Description]. Not yet unlocked.")`.

---

## Open Questions Resolved

| Question (from Planner) | Decision |
|-------------------------|----------|
| Tab icons and labels | Map/Journal/Stats/Scan; icons as specified above |
| Show locked achievements? | Yes — all achievements shown; locked state uses lock icon + reduced opacity |
| Achievement gallery layout | 2-column grid; unlocked first |
| Achievement ordering | Unlocked (most recent first), then locked |
| Journal year header format | "[YEAR]  ·  [N] trip[s]" |
| Journal empty state CTA | "Scan Photos" button navigates to Scan tab (index 3) |

---

## UX Sign-off — Milestone 17

**Design complete: 2026-03-19**

All three tasks have complete component specs. Architect may proceed.

Key constraints for the Architect:
1. `IndexedStack` must preserve all four screen states — no rebuilds on tab switch.
2. `JournalScreen` reads `tripRepositoryProvider` (FutureBuilder) and `effectiveVisitsProvider` (watch) — both must be available in the Riverpod scope.
3. `StatsScreen` requires `RegionRepository.countUnique()` — this method must be added in Task 49.
4. Achievement cards are not tappable in M17 — no `GestureDetector` needed.
5. Scan tab index shifts from 1 → 3. The `ScanScreen`'s `onScanComplete` callback must navigate to index 0 (Map), not hardcode a previous index.
