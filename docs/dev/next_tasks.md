# M43 — Scan Delight: Real-Time Discovery

**Goal:** Make every scan feel alive — each new country triggers an animated discovery toast, a world map grows in real-time, micro-confetti fires per country, and the post-scan summary shows a dramatic flag timeline. On app open after 7+ days, the user is prompted to scan.

**Branch:** `milestone/m43-scan-delight`

---

## Scope

### Included
- Fix confetti clipping in `ScanSummaryScreen` (already applied — `Stack clipBehavior: Clip.none`)
- `_DiscoveryToastOverlay` animated banner in `_ScanningView` per new country during scan
- `_ScanLiveMap` inline FlutterMap in `_ScanningView` with amber highlights and auto-camera per country
- Micro-confetti per discovery in `_ScanningView` (capped at 5 per scan, 500ms debounce, reduce-motion guard)
- Post-scan flag timeline — `ScanSummaryScreen` State A: larger flag emoji cards with staggered reveal
- App-open scan prompt — `DiscoverNewCountriesSheet` shown when `lastScanAt == null || daysSince > 7` and onboarding complete

### Excluded
- Sound effects
- Map screen continent rings / dashboard circles
- Confetti for 6th+ country in a single scan (performance cap)
- Trip timeline sidebar on map screen

---

## Tasks

### Task 145 — Fix confetti clipping in ScanSummaryScreen ✅ Done

**Deliverable:** `Stack` in `_NewDiscoveriesState.build()` gets `clipBehavior: Clip.none` so particles fall across the full screen.

**Acceptance criteria:**
- Confetti particles visibly fall down the screen after scan (not cut off at top)
- Existing confetti tests in `scan_summary_screen_test.dart` still pass

---

### Task 146 — `_DiscoveryToastOverlay`: animated banner in `_ScanningView`

**Deliverable:** `_ScanningView` converted from `StatelessWidget` to `StatefulWidget`. `_DiscoveryToastOverlay` — a `StatefulWidget` that sits in a `Stack` over the scan content and shows a slide-in banner ("🎉 New Country! {flag} {name}") when a new code is added to `liveNewCodes`. Banner slides in from top, holds 2.5s, slides out. Non-blocking.

**Acceptance criteria:**
- When `liveNewCodes` grows (widget rebuilds with a longer list), the banner fires for the latest code
- Banner auto-dismisses after 2.5s
- If `MediaQuery.disableAnimationsOf` is true, no banner is shown
- Widget test: banner appears when `liveNewCodes` gains a new entry

---

### Task 147 — `_ScanLiveMap`: inline world map in `_ScanningView`

**Deliverable:** `_ScanLiveMap` — a `ConsumerStatefulWidget` with fixed height 220px; embeds `FlutterMap` (non-interactive) using `polygonsProvider`; discovered countries rendered amber (`Color(0xFFD4A017)`); unvisited countries dark navy (`Color(0xFF1E3A5F)`); `MapController` auto-fits to each new country's polygon bounds (debounced 800ms). Placed above live country rows. Hidden (`SizedBox.shrink()`) when `polygonsProvider` is empty.

**Acceptance criteria:**
- Map renders at 220px height inside the scan view
- Amber polygons appear for each entry in `liveNewCodes`
- Camera moves to each new country (debounced)
- Map absent if polygon data unavailable
- Widget test: map widget present when polygons non-empty

---

### Task 148 — Micro-confetti per discovery in `_ScanningView`

**Deliverable:** `ConfettiController` managed in `_ScanningViewState`; fires a short burst on each new country in `liveNewCodes`; capped at 5 per scan; minimum 500ms gap between bursts; `ConfettiWidget` anchored top-center in `_ScanningView`'s Stack with `clipBehavior: Clip.none`; reduced-motion guard.

**Acceptance criteria:**
- Confetti fires when `liveNewCodes` grows (up to 5 times)
- No confetti if `MediaQuery.disableAnimationsOf` is true
- No crash if scan cancelled mid-burst (dispose guard)
- Widget test: ConfettiWidget present in scanning view when new codes exist

---

### Task 149 — Post-scan flag timeline in `ScanSummaryScreen` State A

**Deliverable:** Replace `_CountryList` compact text list with `_FlagTimelineList` — vertically scrolling cards, one per new country. Each card: flag emoji (40px), country name (bold 16pt), continent label (muted). Discovery-order preserved. Staggered reveal using existing `_rowOpacities` animation. `ScanRevealMiniMap` remains at top.

**Acceptance criteria:**
- State A shows flag cards with large emoji
- Cards reveal in staggered order
- Reduce-motion: all cards at full opacity immediately
- Widget test: flag emoji visible for 'GB' → '🇬🇧'

---

### Task 150 — App-open scan prompt (`DiscoverNewCountriesSheet`)

**Deliverable:** `DiscoverNewCountriesSheet` modal bottom sheet. Shown from `MapScreen` when onboarding complete AND (`lastScanAt == null` OR `daysSince > 7`). Content: scan icon, headline, body, "Scan now" → navigate to scan tab, "Later" → dismiss. Dismissed-today state persisted to SharedPreferences (`scan_prompt_dismissed_at`); skipped if dismissed today.

**Acceptance criteria:**
- Sheet shown when `lastScanAt` is null and onboarding complete
- Sheet shown when `lastScanAt` > 7 days ago
- Sheet NOT shown when `lastScanAt` within 7 days
- Sheet NOT shown before onboarding complete
- Sheet NOT shown again same calendar day it was dismissed
- "Scan now" navigates to Scan tab
- Widget tests covering each condition

---

## Dependencies

- `confetti`: already in `pubspec.yaml`
- `polygonsProvider`: already in `providers.dart`
- `lastScanAtProvider`: already in `providers.dart`
- `onboardingCompleteProvider`: already in `providers.dart`
- `SharedPreferences`: already a dependency

## Risks

| Risk | Mitigation |
|---|---|
| `fitCamera` during rapid discovery causes jank | Debounce to max one move per 800ms; queue latest code only |
| `ConfettiController.play()` on disposed widget | Guard with `mounted`; cancel burst Timer in `dispose()` |
| App-open prompt on first launch | Only show when `onboardingCompleteProvider` is true |
| `_ScanningView` → Stateful breaks existing tests | No existing test targets `_ScanningView` directly |
