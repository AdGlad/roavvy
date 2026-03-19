# UX Spec — Milestone 18: Celebrations & Delight

**Date:** 2026-03-19
**Tasks:** 50 (Onboarding), 51 (Scan summary), 52 (Celebration animation), 53 (Achievement unlock sheet)
**Principles in force:** Design Principle 2 (privacy is a feature), Principle 5 (delight is earned), Principle 6 (accessible by default)

---

## Task 50 — Onboarding flow

### Flow

```
Flow: First-launch onboarding
Entry point: app launch when hasSeenOnboarding = false AND no existing visits
Steps:
  1. Welcome screen
  2. Privacy screen
  3. Ready screen → exits to Scan tab
Exit: user understands the value proposition and privacy model; lands on Scan tab ready to scan (or Map tab if skipped)
Edge cases:
  - User has existing visits (reinstall): skip onboarding entirely → go to Map tab
  - User taps Skip on any screen: mark hasSeenOnboarding = true → go to Map tab
  - reduceMotion: no slide transition between screens; instant cut
```

### Screen 1 — Welcome

```
Component: OnboardingWelcomeScreen
Layout (top → bottom):
  - Illustration placeholder: rounded rect, colorScheme.primaryContainer, 240 × 200 pt
  - Title: "Your travels, discovered"  [headlineMedium, bold, center]
  - Body: "Roavvy finds every country you've visited — automatically,
           using the photos already on your phone."  [bodyMedium, center, onSurfaceVariant]
  - Spacer
  - FilledButton (full width): "Get started"  → Screen 2
  - TextButton: "Skip"  → Map tab; hasSeenOnboarding = true

Progress indicator: 3 dots below illustration. Dot 1 filled (primary), dots 2–3 outlined.
```

### Screen 2 — Privacy

```
Component: OnboardingPrivacyScreen
Layout (top → bottom):
  - Illustration placeholder: rounded rect, colorScheme.secondaryContainer, 240 × 200 pt
    (visual: shield or lock motif — placeholder colour only, no actual icon required)
  - Title: "Your photos never leave your phone"  [headlineMedium, bold, center]
  - Body: "Roavvy reads only location and date from your photos —
           not the images themselves. Nothing is uploaded.
           Your travel data stays on your device."  [bodyMedium, center, onSurfaceVariant]
  - Spacer
  - FilledButton (full width): "Got it"  → Screen 3
  - TextButton: "Skip"  → Map tab; hasSeenOnboarding = true

Progress indicator: dot 2 filled, dots 1 and 3 outlined.
```

### Screen 3 — Ready to scan

```
Component: OnboardingReadyScreen
Layout (top → bottom):
  - Illustration placeholder: rounded rect, colorScheme.tertiaryContainer, 240 × 200 pt
  - Title: "Ready to discover your travels?"  [headlineMedium, bold, center]
  - Body: "Scanning usually takes a few minutes.
           You can explore the app while it runs."  [bodyMedium, center, onSurfaceVariant]
  - Spacer
  - FilledButton (full width): "Scan my photos"  → Scan tab (index 3); hasSeenOnboarding = true
  - TextButton: "Not now"  → Map tab; hasSeenOnboarding = true
    (copy change: "Not now" instead of "Skip" because user is choosing to defer, not escape)

Progress indicator: dot 3 filled, dots 1–2 outlined.
```

### Copy

| Element | String |
|---|---|
| Screen 1 title | "Your travels, discovered" |
| Screen 1 body | "Roavvy finds every country you've visited — automatically, using the photos already on your phone." |
| Screen 1 CTA | "Get started" |
| Screen 2 title | "Your photos never leave your phone" |
| Screen 2 body | "Roavvy reads only location and date from your photos — not the images themselves. Nothing is uploaded. Your travel data stays on your device." |
| Screen 2 CTA | "Got it" |
| Screen 3 title | "Ready to discover your travels?" |
| Screen 3 body | "Scanning usually takes a few minutes. You can explore the app while it runs." |
| Screen 3 CTA | "Scan my photos" |
| Screens 1–2 skip | "Skip" |
| Screen 3 skip | "Not now" |

### Accessibility

- Each screen is a single semantic page; VoiceOver reads title then body then CTA then skip link.
- Progress dots: `Semantics(label: 'Step [n] of 3')` on the filled dot only.
- All buttons: 44 × 44 pt minimum.
- Illustrations: `excludeSemantics: true` (decorative).
- Screen transition: `PageRouteBuilder` with zero-duration when `MediaQuery.disableAnimations`.

---

## Task 51 — Scan summary screen

### Flow

```
Flow: Post-scan summary
Entry point: ReviewScreen save completes (user taps "Save" after reviewing detected countries)
Steps:
  1. ScanSummaryScreen shown (replaces navigate-to-Map)
  2a. New discoveries variant: user sees count, country list, achievements; taps "Explore your map"
  2b. Nothing new variant: user sees "All up to date"; taps "Back to map"
Exit: user lands on Map tab (index 0)
Edge cases:
  - 1 new country: singular copy ("1 new country")
  - 10+ new countries: list scrolls; hero count still prominent
  - New countries AND new continent: continent callout inline (see below)
  - Achievements unlocked: shown below country list
  - No achievements unlocked: achievement section hidden entirely
  - reduceMotion: instant render, no confetti, no stagger
```

### State A — New discoveries

```
Component: ScanSummaryScreen (new discoveries)
Layout (scrollable, top → bottom):
  - [Confetti animation layer — see Task 52]
  - Hero block (non-scrolling, top 40% of screen):
      - Large number: "[N]"  [displayLarge, bold, colorScheme.primary]
      - Label below number: "new countr[y/ies] discovered"  [titleMedium, onSurfaceVariant]
      - If any trips were inferred: subtitle "[T] trip[s] found"  [bodySmall, onSurfaceVariant]
  - Country list (scrolls):
      Each row:
        - Flag emoji  [fontSize 28]
        - Country name (full English name, not ISO code)  [bodyLarge]
        - If first country on this continent:
            Continent badge below country name:
            "🌍 First country in [Continent]"  [labelSmall, colorScheme.tertiary]
            (use appropriate continent emoji: Africa 🌍, Asia 🌏, Americas 🌎, Europe 🌍, Oceania 🌏, Antarctica 🧊)
  - Achievements section (shown only when newAchievementIds.isNotEmpty):
      - Section header: "Achievement[s] unlocked"  [titleSmall, bold]
      - Each achievement: chip with emoji_events_outlined icon + title
        Tapping chip → opens AchievementUnlockSheet (Task 53)
  - Sticky bottom bar (not scrolling):
      - FilledButton (full width): "Explore your map"  → navigate to Map tab; pop ScanSummaryScreen
```

### State B — Nothing new

```
Component: ScanSummaryScreen (nothing new)
Layout (centered, non-scrolling):
  - Icon: check_circle_outline, 48pt, colorScheme.onSurfaceVariant
  - Title: "All up to date"  [headlineSmall, bold, center]
  - Body: "No new countries found this time."  [bodyMedium, onSurfaceVariant, center]
  - Last scan line: "Last scanned [day] [month] [year]"  [bodySmall, onSurfaceVariant, center]
  - Spacer
  - FilledButton (full width): "Back to map"  → navigate to Map tab
```

### Copy

| Element | String |
|---|---|
| Hero label (1 country) | "1 new country discovered" |
| Hero label (N countries) | "[N] new countries discovered" |
| Trip subtitle (1 trip) | "1 trip found" |
| Trip subtitle (N trips) | "[N] trips found" |
| Continent badge | "First country in [Continent name]" |
| Achievements header (1) | "Achievement unlocked" |
| Achievements header (N) | "Achievements unlocked" |
| Main CTA | "Explore your map" |
| Nothing new title | "All up to date" |
| Nothing new body | "No new countries found this time." |
| Nothing new last scan | "Last scanned [d] [Mon] [yyyy]" |
| Nothing new CTA | "Back to map" |

### Accessibility

- Hero count: `Semantics(label: '[N] new countries discovered')` wraps the number + label.
- Country rows: `Semantics(label: '[Country name]. First country in [Continent].')` when continent badge shown; otherwise `Semantics(label: '[Country name]')`.
- Achievement chips: `Semantics(label: '[Achievement title] achievement unlocked. Tap to view.')`.
- "Explore your map" / "Back to map": standard button semantics.
- Screen announced on entry: VoiceOver reads the hero label first.

---

## Task 52 — Celebration animation

### Confetti (ScanSummaryScreen, new discoveries variant only)

```
Component: confetti overlay on ScanSummaryScreen
Behaviour:
  - Fires once on screen mount (AnimationController forward in initState)
  - Emitter position: top-center of screen
  - Direction: downward fan (blastDirectionality: BlastDirectionality.explosive, emissionFrequency: 0.04)
  - Duration: 2.5 seconds, then stops
  - Colours: [colorScheme.primary, colorScheme.secondary, Colors.amber[400], Colors.amber[700]]
  - Gravity: 0.2 (gentle fall)
  - Does NOT loop
  - Does NOT replay if user scrolls or returns to this screen (one-shot, controller disposed)

reduceMotion: ConfettiWidget not added to widget tree at all when MediaQuery.disableAnimations == true
```

### Country row stagger (ScanSummaryScreen, new discoveries variant only)

```
Behaviour:
  - Each row fades in + slides up 8pt using AnimatedOpacity + AnimatedSlide (or AnimationController + CurvedAnimation)
  - Stagger: 80 ms delay per row index (row 0 at 0ms, row 1 at 80ms, row 2 at 160ms, …)
  - Duration per row: 250 ms, Curves.easeOut
  - Max stagger cap: if > 8 rows, rows 8+ start immediately after row 7 (avoid > 640ms total wait)

reduceMotion: all rows rendered at full opacity with no translation; no animation controllers started
```

### Notes for Architect / Builder

- `confetti` package preferred over custom `CustomPainter` for time efficiency; verify binary size delta before committing.
- If `confetti` is too large (> 200 KB compiled contribution), implement a simple `CustomPainter` emitting 30 coloured circles falling under gravity — no third-party dependency needed.
- Animation controllers must be disposed in `dispose()`.

---

## Task 53 — Achievement unlock sheet

### Component

```
Component: AchievementUnlockSheet
Trigger A: tap achievement chip on ScanSummaryScreen (first-unlock context)
Trigger B: tap unlocked achievement card on StatsScreen (review context)
Locked cards on StatsScreen: no interaction — ignore tap entirely (no ripple, no sheet)

Layout (bottom sheet, non-scrolling):
  - Drag handle (standard 32×4 pt pill, onSurfaceVariant)
  - Icon: emoji_events_outlined, 56pt, Colors.amber[700], centered
  - Achievement title  [headlineSmall, bold, center]
  - Achievement description  [bodyMedium, onSurfaceVariant, center]
  - Unlock date: "Unlocked [d] [Mon] [yyyy]"  [labelMedium, colorScheme.primary, center]
  - SizedBox(height: 24)
  - FilledButton (full width): "Share achievement"
  - TextButton (full width): "Done"

Share text (iOS share sheet plain text):
  "[Achievement title] — [Achievement description]. Unlocked on [d] [Mon] [yyyy]. Discovered with Roavvy."

isScrollControlled: false (fixed height sheet; content fits without scroll)
```

### States

```
States: default (unlocked achievement data always present — sheet only opens for unlocked achievements)

No loading state required — achievement data is passed in as constructor parameters.
No error state required — sheet is only opened with valid data.
```

### Copy

| Element | String |
|---|---|
| Share button | "Share achievement" |
| Done button | "Done" |
| Unlock date | "Unlocked [d] [Mon] [yyyy]" |
| Share text | "[Title] — [Description]. Unlocked on [d] [Mon] [yyyy]. Discovered with Roavvy." |

### Accessibility

- Sheet announced: `Semantics(label: '[Achievement title] achievement')` on the root.
- Icon: `excludeSemantics: true` (decorative; title conveys identity).
- Share button: `Semantics(label: 'Share [Achievement title] achievement')`.
- Done button: standard dismiss semantics.
- Sheet dismissible by swipe-down and by tapping outside (standard `showModalBottomSheet` behaviour).

---

## Open questions for Architect

1. **Onboarding persistence** — Drift preferred (one `hasSeenOnboarding` boolean column on `scan_metadata` table, schema v8) vs. SharedPreferences (simpler but second persistence mechanism). Recommend Drift for consistency with ADR-003.

2. **Returning user detection** — check `effectiveVisitsProvider` on launch: if non-empty, skip onboarding regardless of `hasSeenOnboarding` flag. Architect to confirm provider availability at app startup before `MainShell` is built.

3. **Pre-save snapshot for delta (Task 51)** — `ReviewScreen` needs to capture the set of effective country codes *before* calling save to compute `newCountries`. Recommended: read `effectiveVisitsProvider` synchronously via `ref.read` before triggering save, capture `Set<String>` of country codes, diff against saved result. Architect to confirm this is race-condition-free given the `IndexedStack` lifecycle.

4. **Continent emoji mapping** — a small `const Map<String, String> kContinentEmoji` in `shared_models` or `core/`: `{'Africa': '🌍', 'Asia': '🌏', 'North America': '🌎', 'South America': '🌎', 'Europe': '🌍', 'Oceania': '🌏'}`. Architect to confirm placement.

5. **`confetti` package size** — Builder should verify with `flutter build ipa --analyze-size` before committing. Fallback: custom 30-circle `CustomPainter` with basic gravity simulation.
