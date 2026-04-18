# Current Task

**Task:** M72 — Country Celebration Carousel + Navigation Bug Fixes
**Status:** 🔄 In Progress
**Milestone:** M72
**Branch:** `milestone/m72-celebration-carousel`

---

## 1. Milestone Name
M72 — Country Celebration Carousel + Navigation Bug Fixes

## 2. Milestone Goal
Fix three critical bugs in the post-scan country celebration flow (Skip All blank screen, flicker back to scan summary, double-pop navigation) and replace the repeated push/pop screen model with a single horizontally-scrollable carousel. Improve globe animation quality (reduce spin, easterly travel, premium easing).

## 3. Current Bugs

| # | Bug | Root Cause |
|---|---|---|
| B1 | Skip All → blank screen | `_handleSkipAll` calls `Navigator.pop()` **after** `onSkipAll` already calls `Navigator.pop()`. Two pops: first removes the overlay, second removes `ScanSummaryScreen`, leaving a broken state. The for-loop then hits `if (!mounted) return` and never calls `widget.onDone()`. |
| B2 | Flicker back to scan summary | Between each overlay, the for-loop `await`s a 300ms gap while `ScanSummaryScreen` is visible. User sees the summary momentarily between every country. |
| B3 | Screen push per country | 13 countries = 13 Navigator pushes. Each push/pop cycle is visible and creates jarring navigation history. |
| B4 | Globe over-spins | Phase 1 spins 1.5 full rotations (540°) in 810ms via `easeIn`. Visually excessive. |
| B5 | Abrupt easing | `easeIn` for spin and `easeInOut` for travel feel mechanical, not premium. |

## 4. Why Current UX is Poor

- Repeated `Navigator.push` creates a fragile navigation stack with N overlays; popping them creates flicker and is the source of the blank-screen bug.
- The 300ms gap between celebrations was a workaround — now unnecessary with a carousel.
- 540° initial spin is disorientating and repetitive for users with many countries.
- The celebration should feel like *one continuous experience*, not 13 separate screens.

## 5. Proposed New Celebration Flow

```
ScanSummaryScreen
  → user taps "Explore your map"
  → push ONE CountryCelebrationCarousel screen
      → Page 1: Country 1  (globe animates, confetti, name, XP)
      → Page 2: Country 2  (same, globe re-animates)
      → ...
      → Page N: Last country → "Done" → pop carousel → widget.onDone()
      → Skip All (any page) → pop carousel → widget.onDone()
```

Single push, single pop. No intermediate screens.

## 6. Navigation Architecture Changes

**Old:** `ScanSummaryScreen._pushDiscoveryOverlays()` loops and pushes N `DiscoveryOverlay` routes.

**New:** Push a single `CountryCelebrationCarousel` route. All page progression happens inside the carousel using `PageView` — no Navigator involvement per country.

`DiscoveryOverlay` is retained for single-country discovery (no carousel needed) with the double-pop bug fixed.

## 7. Carousel UX Design

- **Widget:** `CountryCelebrationCarousel` — full-screen, orange-gold gradient background (matches `DiscoveryOverlay`).
- **Layout:** `PageView.builder` with `physics: const ClampingScrollPhysics()` (no rubber-band overshoot at ends).
- **Each page:** Globe (260px) → flag emoji → "Country N of M" → country name → XP → first visited date.
- **Progress:** `AnimatedContainer` dot indicators at the bottom edge (like iOS page dots) — up to 10 dots; for >10 use "N of M" text only.
- **Navigation:**
  - "Next →" button advances `PageController.nextPage()` with 350ms `easeInOut`.
  - "Done" on last page calls `widget.onDone()`.
  - "Skip all" top-right calls `widget.onDone()` directly (single pop).
  - Swipe is enabled but secondary — button is the primary CTA.
- **Globe:** `CelebrationGlobeWidget` with `key: ValueKey(isoCode)` per page — recreated per country so animation plays fresh.
- **Confetti:** Per page, fires 1.8s after page becomes active.
- **Audio + haptics:** On `onPageChanged` settle.

## 8. Globe Animation Behaviour

**Old Phase 1:** 1.5 rotations × 360° = 540° in 810ms with `easeIn`. ❌

**New Animation (total 2800ms):**
- **Phase 1 (0–15%, 420ms):** 0.33 rotations eastward (120°) with `easeOut`. Brief "flick" that establishes eastward momentum. `_kSpinEndLng = 2π/3`.
- **Phase 2 (15–80%, 1820ms):** Smooth travel from spin-end to target centroid with `Curves.easeInOutCubic`. Always travels east (if target is west of spin-end, normalise by adding 2π so the globe completes the eastward journey).
- **Phase 3 (80%+, 560ms):** Settled on centroid, pulsing halo begins. Pulse repeats at 900ms.

**Easing quality:** Replace `easeIn`/`easeInOut` with `Curves.easeOut` (Phase 1) and `Curves.easeInOutCubic` (Phase 2) for a more premium, deceleration-forward feel.

## 9. Skip All Behaviour and Destination

- **Skip All** in `CountryCelebrationCarousel`: calls `widget.onDone()` which was provided by `ScanSummaryScreen._pushDiscoveryOverlays` as `() => Navigator.pop()`. This pops the carousel and resumes `_pushDiscoveryOverlays` → `widget.onDone()` → navigates to map.
- **Skip All fix in `DiscoveryOverlay`** (single-country path): Remove the extra `Navigator.pop()` from `_handleSkipAll`. The `onSkipAll` callback (set in `ScanSummaryScreen`) already pops.

**Destination after all celebrations or Skip All:** Map screen (existing behaviour via `ScanSummaryScreen.widget.onDone`).

## 10. Risks / Edge Cases

| Risk | Mitigation |
|---|---|
| PageView pre-builds adjacent pages → globe auto-starts before page is visible | Use `PageController.addListener` + `_currentPage` state to gate globe animation start; only the active page receives `autoStart: true` |
| User swipes back to previous country — globe has already finished | Globe stays settled on centroid; no re-trigger on swipe-back (acceptable) |
| Confetti fires on swipe-back | Guard confetti with a `_confettiFired` flag per page |
| Very large country count (50+) — dots overflow | Show "N of M" text for >10 countries instead of dots |
| Single-country scan still uses `DiscoveryOverlay` | Kept; just fix the double-pop bug |
| `DiscoveryOverlay` double-pop | Fix: remove `Navigator.pop()` from `_handleSkipAll`; let `onSkipAll` callback handle it |

## 11. Acceptance Criteria

- [ ] Skip All never goes to blank screen
- [ ] Skip All exits to map correctly (via `onDone`)
- [ ] No flicker back to scan summary between country celebrations
- [ ] Countries presented in a horizontal carousel (single push/pop)
- [ ] Globe spins ≤ 120° eastward in Phase 1
- [ ] Globe settles on target country with `easeInOutCubic` in Phase 2
- [ ] No extra spin after country is centred
- [ ] Confetti fires per country on first view
- [ ] Audio + haptics fire on carousel page settle
- [ ] "N of M" indicator visible throughout
- [ ] DiscoveryOverlay retained for single-country flow
- [ ] Tests updated

## 12. Implementation Tasks

| # | Task | File(s) | Est |
|---|---|---|---|
| 1 | Fix `DiscoveryOverlay` double-pop bug | `discovery_overlay.dart` | 15m |
| 2 | Create `CountryCelebrationCarousel` widget | `country_celebration_carousel.dart` (new) | 2h |
| 3 | Replace `_pushDiscoveryOverlays` with carousel push | `scan_summary_screen.dart` | 30m |
| 4 | Fix globe animation (Phase 1 spin, Phase 2 easing) | `celebration_globe_widget.dart` | 45m |
| 5 | Update/add tests | `*_test.dart` | 45m |
| 6 | Create ADR-126 | `docs/architecture/decisions.md` | 15m |

## 13. Recommended Build Order

1. **Task 1** — Fix double-pop (smallest, unblocks manual testing of existing flow)
2. **Task 4** — Fix globe animation (independent, no deps)
3. **Task 2** — Build `CountryCelebrationCarousel` (largest; depends on globe widget)
4. **Task 3** — Wire carousel into `ScanSummaryScreen` (depends on Task 2)
5. **Task 5** — Tests
6. **Task 6** — ADR
