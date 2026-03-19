# Roavvy Mobile — UX & UI Specification

**Scope:** iOS Flutter app, Phases 5–9 (Trip Intelligence through App Store Readiness)
**Principle:** The map is the anchor. Depth is revealed progressively. Every screen has one job.

---

## Navigation Architecture

### Bottom Tab Bar (4 tabs)

```
[ Map ]  [ Journal ]  [ Stats ]  [ Scan ]
```

| Tab | Icon | Badge | Role |
|---|---|---|---|
| **Map** | globe | country count | Primary experience; world map |
| **Journal** | open book | — | All trips, chronological |
| **Stats** | bar chart | new achievement | Stats + achievement gallery |
| **Scan** | camera | — | Photo scanner |

**Rules:**
- Map is the default landing tab on every launch.
- `IndexedStack` keeps all tabs alive (existing pattern — no change).
- Badge on Stats tab appears when a new achievement has been unlocked but not yet viewed.
- No nested bottom bars. All depth is push navigation or modal sheets within tabs.

---

## Map Tab

### World Map Screen

The primary screen. A flutter_map canvas showing all country polygons.

**Visual system:**

| State | Fill colour | Label |
|---|---|---|
| Unvisited | `#D1D5DB` (grey) | — |
| Visited, 1 trip | `#74C69D` (light green) | — |
| Visited, 2–4 trips | `#2D6A4F` (mid green) | — |
| Visited, 5+ trips | `#1B4332` (deep green) | — |
| Suppressed (AQ) | hidden | — |

**Zoom levels:**
- **World (zoom < 4):** Continent name labels overlay each continent. Stats strip visible at bottom.
- **Continent (4–6):** Country polygons visible. Tapping a country opens Country Detail.
- **Country (> 6):** Region polygons visible within the tapped country. Regions coloured by visit status.

**Overlay elements:**

```
┌─────────────────────────────────┐
│  [⋮]                            │  ← top-right overflow menu
│                                 │
│        [world map canvas]       │
│                                 │
│  [+]                            │  ← floating action: quick-add country
│─────────────────────────────────│
│  47 countries · 6 continents · 112 trips   │  ← stats strip
└─────────────────────────────────┘
```

**Stats strip (bottom):**
- Three stats inline: `[flag emoji] X countries · X continents · X trips`
- Tapping the strip navigates to the Stats tab.

**Overflow menu (⋮):**
- Share travel card
- Privacy & account

**Floating action button (+):**
- Opens quick-add country modal (search field → ISO lookup → adds `UserAddedCountry`).

**Empty state (no visits yet):**
- Centred card: "Your photos already know where you've been" + [Scan Photos] button.
- [Scan Photos] navigates to Scan tab.

---

## Country Detail Screen

Full-screen push from Map (tapping a country polygon).

### Header

```
┌─────────────────────────────────┐
│ ← Back                [Edit]   │
│                                 │
│  🇫🇷  France                    │
│  4 trips  ·  First visited 2015 │
│  Last visited July 2023         │
│                                 │
│ [ Overview | Trips | Regions | Photos ]  ← tab bar
└─────────────────────────────────┘
```

**Celebration badge (conditional):**
- If this country was the Nth that triggered an achievement, show a small badge beneath the flag: "Your 25th country 🎉 — Globetrotter unlocked"

### Overview Tab

- Trip count card: "4 trips · 47 days total"
- Continent pill: "Europe"
- Date range: "First: March 2015 · Most recent: July 2023"
- Regions explored: "6 of 13 regions"
- Most visited region: "Île-de-France"
- Achievements this country contributed to (inline chips)
- [Share this country] button → generates a country-specific share card

### Trips Tab

Chronological list of trips, most recent first.

Each trip card:
```
┌─────────────────────────────────┐
│ 14 Jul – 28 Jul 2023  (14 days) │
│ Provence · Côte d'Azur          │  ← regions on this trip
│ 📷 43 photos                    │
│                              >  │
└─────────────────────────────────┘
```
Tap → Trip Detail Screen.

Footer: [+ Add trip manually] — opens date-picker sheet for manual trip entry.

### Regions Tab

List of regions detected within this country, sorted by visit count.

Each row:
- Region name (e.g., "Île-de-France")
- Visit count: "3 trips"
- Date range of visits

Footer: "X of Y regions explored" progress bar.

### Photos Tab

On-device photo grid (loaded via PhotoKit by stored local identifiers).
- Masonry grid, 3 columns.
- Grouped by trip (sticky header per trip showing dates).
- Tap photo → full-screen viewer (system share sheet available).
- Empty state if no photo identifiers stored (edge case: manual-add country).

---

## Trip Detail Screen

Push from Country Detail → Trips tab.

```
┌─────────────────────────────────┐
│ ← France                [Edit] │
│                                 │
│  Trip to France                 │
│  14 Jul – 28 Jul 2023           │
│  14 days                        │
│                                 │
│ [mini-map: France with regions  │
│  highlighted for this trip]     │
│                                 │
│ Regions                         │
│  · Provence-Alpes-Côte d'Azur  │
│  · Occitanie                    │
│                                 │
│ Cities                          │
│  · Nice  · Marseille  · Arles   │
│                                 │
│ Photos (43)                     │
│ [photo grid]                    │
└─────────────────────────────────┘
```

**Edit sheet** (tapping [Edit]):
- Date range pickers (start / end)
- [Merge with adjacent trip] if trips are close in time
- [Delete trip] (destructive, confirmation required)

---

## Journal Tab

Chronological list of all trips across all countries.

### Layout

```
┌─────────────────────────────────┐
│ Journal            [Filter ▾]  │
│─────────────────────────────────│
│ 2023  —  14 trips · 8 countries │  ← sticky year header
│─────────────────────────────────│
│ 🇫🇷  France                    │
│ 14–28 Jul 2023 · 14 days        │
│ Provence · Côte d'Azur          │
│ [thumbnail]                 >   │
│─────────────────────────────────│
│ 🇯🇵  Japan                      │
│ 2–15 Apr 2023 · 13 days         │
│ Kansai · Kantō                  │
│ [thumbnail]                 >   │
│─────────────────────────────────│
│ 2022  —  9 trips · 6 countries  │
│─────────────────────────────────│
│  ...                            │
└─────────────────────────────────┘
```

**Sticky year headers** with trip count and country count for that year.

**Filter sheet** (tapping Filter):
- By continent (multi-select)
- By country (searchable list)
- By year (range slider)

**Tap a row** → Trip Detail Screen.

**Empty state:** "Scan your photos to discover your trips."

---

## Stats Tab

Two sections: Stats panel (top) and Achievements (scrollable below).

### Stats Panel

```
┌─────────────────────────────────┐
│ Your travel, by the numbers     │
│─────────────────────────────────│
│  47          6           112    │
│ countries  continents   trips   │
│─────────────────────────────────│
│  2009        2023       14 days │
│ first trip  last trip  longest  │
│─────────────────────────────────│
│ Continent breakdown             │
│  🌍 Africa      3 / 54          │
│  🌎 Americas   11 / 35          │
│  🌏 Asia       18 / 47          │
│  🌍 Europe     14 / 44          │
│  🌏 Oceania     1 / 14          │
│                                 │
│ Countries visited by year ────  │
│ [bar chart: 2009–2024]          │
│                                 │
│ Most visited  France (4 trips)  │
│ Longest trip  Japan · 14 days   │
└─────────────────────────────────┘
```

### Achievements Gallery

Grid (2 columns) of all achievements.

**Unlocked achievement card:**
```
┌──────────────┐
│   🌍 ✓       │
│ Globetrotter │
│ 25 countries │
│ Aug 2021     │  ← unlock date
│ [Share]      │
└──────────────┘
```

**Locked achievement card:**
```
┌──────────────┐
│   🔒         │
│ World        │
│ Explorer     │
│ Visit 50     │
│ countries    │
└──────────────┘
```

Tapping an unlocked achievement → Achievement Detail sheet:
- Full achievement name + description
- Unlock date + which country triggered it
- [Share achievement] → generates share image (achievement card)
- Inline achievement card preview

---

## Scan Tab

Existing scan flow. Extended for trip and region awareness.

### Scan Screen (updated states)

1. **Ready:** "Scan for new photos" + last-scanned date + [Scan] button
2. **Scanning:** Progress bar + "Inspected X of Y photos · X countries found so far"
3. **Done → Scan Summary Screen** (new full-screen modal)

### Scan Summary Screen (new — Phase 8)

Shown after every scan that finds something new. Replaces the current inline summary.

```
┌─────────────────────────────────┐
│                                 │
│  ✈️  Scan complete              │
│                                 │
│  [ animated map showing new     │
│    countries highlighting ]     │
│                                 │
│  New countries (2)              │
│   🇮🇸 Iceland                   │
│   🇵🇹 Portugal                  │
│                                 │
│  New trips (4)                  │
│   France · Jul 2023             │
│   Iceland · Aug 2023            │
│   ...                           │
│                                 │
│  Achievement unlocked! ──────── │
│  [achievement card animation]   │
│  "Seasoned Traveller"           │
│  10 countries visited           │
│  [Share achievement]            │
│                                 │
│  [View my map]                  │
└─────────────────────────────────┘
```

**If nothing new:** Compact inline state ("No new photos since [date]"). No full-screen modal.

---

## Celebration Moments

### New Country (Phase 8)

Triggered when a scan or manual add results in a country not previously in the effective set.

- Full-screen confetti overlay (1.5 seconds)
- Country flag animates in from centre
- Copy: "New country! 🇮🇸 Iceland"
- If this country triggers an achievement, the achievement unlocks immediately after (sequential)
- [Continue] dismisses

### New Continent (Phase 8)

Triggered when first country on a new continent is detected.

- Special animation (globe spinning to that continent)
- Copy: "First country in Asia! Your 4th continent."
- [Continue] dismisses

### Achievement Unlock (Phase 8)

Triggered post-scan and post-review whenever a new ID appears in the unlocked set.

- Slide-up sheet (not full-screen) with achievement badge animation
- Achievement title + description
- Unlock date
- [Share] button → share card image
- Auto-dismisses after 5 seconds or on tap

---

## Onboarding Flow (Phase 8)

Shown on first launch only. Stored in shared preferences: `onboardingComplete: true`.

### Screen 1 — Welcome
```
[Roavvy logo]
Your photos already know
where you've been.

[Get Started →]
```

### Screen 2 — Permission Rationale
```
[illustration: photo + lock icon]

Roavvy reads GPS data from
your photos to build your map.

Your photos never leave your
device. Nothing is uploaded.

[Allow Photo Access]
[Not now]  ← skips to Screen 4 with empty state
```

### Screen 3 — Scanning (transition)
- Auto-triggers scan after permission granted.
- Live progress: animated world map with countries highlighting as they are found.
- Copy: "Discovering your world..."

### Screen 4 — Map Reveal
- Countries animate in one by one (staggered, 50ms apart).
- Stats strip counts up.
- If achievements unlocked: achievement sheet fires after reveal.
- [Explore your map] button appears after animation completes.

---

## Sharing

### Travel Card Share (existing, extended)

Current: country count + date range + world map thumbnail.
Extended (Phase 7+):
- Country count + continent count + trip count
- Top 3 most visited countries shown as flags
- "Via Roavvy" watermark

### Achievement Share Card (Phase 8)

- Achievement badge (large, centred)
- Achievement title + description
- "Unlocked on [date]"
- User's country count at time of unlock
- "Via Roavvy" watermark

### Country Share Card (Phase 7)

- Country flag (large)
- Country name
- "X trips · First visited [year]"
- Top regions visited
- "Via Roavvy" watermark

---

## Settings & Account

Accessed via ⋮ menu on Map screen (no dedicated settings tab — keeps nav simple).

**Privacy & account screen (existing, extended):**
- Signed-in state (Apple or anonymous)
- [Revoke all share tokens]
- [Delete all travel history]
- [Delete account]
- Privacy policy link

---

## Error States

| Scenario | UI |
|---|---|
| Scan fails mid-way | Inline error banner: "Scan stopped. [Retry]" |
| Photo permission denied | Persistent prompt with [Open Settings] deep link |
| Firestore sync failed | Silent — local data is source of truth; no user-visible error |
| Photo grid fails to load | Placeholder tiles with retry |
| Offline | App fully functional (all core features are offline-first) |

---

## Typography & Colour System

This spec intentionally defers final visual design to the iOS designer persona. The following are constraints, not final values.

**Constraints:**
- Use system fonts (SF Pro) — no custom typeface in v1.
- Primary brand green: `#2D6A4F` (existing map colour).
- Destructive actions: `Colors.red.shade600` (existing pattern).
- All interactive elements meet WCAG AA contrast minimum.
- Support iOS Dynamic Type for accessibility.

---

## Accessibility

- All country polygons have semantic labels for VoiceOver ("France, visited, 4 trips").
- Achievement cards read as "Achievement: Globetrotter, unlocked August 2021" or "Achievement: World Explorer, locked, visit 50 countries to unlock".
- All custom animations respect `UIAccessibilityIsReduceMotionEnabled`.
- Photo grids load progressively; thumbnails have alt text with capture date.
