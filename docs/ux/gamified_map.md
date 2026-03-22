# Gamified Map — UX & Flutter Architecture Spec

**Status:** Planning
**Phase:** Phase 11
**Last updated:** 2026-03-22

---

## Section 1 — Diagnosis: Why the Current Map Feels Flat

The current map is a correct implementation of the wrong metaphor. It answers the question "which countries have I visited?" and stops there. It does not say "look how far you've come," "look what's next," or "this moment matters." The specific failures:

**No visual differentiation between countries.** Every visited country renders with the same fill colour, the same opacity, and the same border weight. A user who has visited 3 countries sees almost the same map as a user who has visited 47. The map does not communicate scale of achievement. There is no gradient, no luminance shift, no weight to the data.

**No sense of achievement.** The map silently adds a country. There is no moment. The polygon just appears. Users who complete the scan and see France appear alongside Norway alongside Thailand have no event to anchor to — no celebration, no punctuation. The map treats discovering Thailand for the first time identically to discovering it for the tenth time.

**No progression suggestion.** The map never hints at what is possible. It never shows the user that they have 4 out of 5 Nordic countries and could complete a region. It never highlights that completing South East Asia would require only Vietnam. The unvisited space is a uniform dark void — not a canvas of possibility but a blank wall.

**Polygon-only rendering.** The current layer is a single `PolygonLayer` with a single visual style. There are no overlays, no markers, no chip annotations, no depth cues. The map is topographically indifferent — a country visited once looks identical to a country visited twenty times. The 3D metaphor of geography — oceans, landmasses, topography — is reduced to flat, monochrome shapes.

**No emotional peak moments.** The app has no "wow" moment. First scan delivers no ceremony. A new country arriving post-scan gets a `SnackBar`. The gap between the emotional weight of travel — the memories, the effort, the meaning — and the map's response to it is enormous. Users open the app, see their countries, and think "hm, neat." They should think "I did all of that."

**No depth cues.** The basemap is dark. The polygons are a single tone of green. There is no visual hierarchy — no sense that visited countries are alive and the rest is waiting. No shadow, no glow, no bloom. The map lacks depth cues that would make it read as a three-dimensional world being revealed.

---

## Section 2 — New Map Vision

**Emotional target per moment:**

- **Opening the app:** A sense of ownership. The map loads and the user's visited countries light up gently — not a jarring flash, but a warm reveal, like switching on lamps in a room you know well. The feeling is: "This is mine. I built this."
- **Seeing their map:** Pride proportional to their travel. A user with 5 countries sees a map that is mostly dark but with bright anchors — the contrast between filled and empty is motivating, not discouraging. A user with 50 countries sees a world that is substantially illuminated, and the glow is satisfying. The map conveys their travel identity without a single word.
- **Discovering a new country:** Ceremony. The app stops, marks the moment, names the country, awards XP, and moves on. It is a 3-second pause in a long journey. The user feels recognised.
- **Completing a region:** Satisfaction. A region completion is a collected set — Nordic, South East Asia, Benelux — and finishing it is closure. The app marks it with a bottom sheet, a checkmark on the arc, and a share invitation. The feeling is: "I finished something."

**Tone for a visual designer:** Premium outdoor-expedition aesthetics meets minimal digital clarity. Think the warmth of aged leather and amber light — not neon, not pastels, not corporate blue. The map is a treasure map that the user is filling in, not a corporate dashboard tracking KPIs. Every pixel should feel considered.

---

## Section 3 — Map Screen Layout

The map is the hero. Every overlay exists to serve the map, not to compete with it. The following layers are stacked in z-order from bottom to top:

**Basemap (z: 0):** CartoDB Dark Matter tiles (offline fallback: plain `#0d1117` background). Dark basemap ensures visited countries, which will be amber/gold, have maximum contrast. Ocean is near-black. Country borders that are unvisited bleed into the basemap.

**Country polygon layer (z: 1):** `PolygonLayer` rendering all country polygons with `CountryVisualState`-derived fill and border. This is the primary data layer.

**Target country layer (z: 2):** A separate `PolygonLayer` rendering only countries that are one-away from completing a partially-done region. Dotted amber border, animated. Kept separate so its animated polygons do not force a full `PolygonLayer` rebuild.

**Region chips marker layer (z: 3):** `MarkerLayer` placing progress chips at region centroids. Only visible at zoom level ≥ 4. Chips are small, circular, and positioned to float above the relevant geographic area without overlapping country labels.

**Top area — XP Level Bar (z: overlay, top):** A persistent strip anchored to the top of the safe area. Not part of the map's z-stack — it is a `Positioned` widget in the outer `Stack`. Contains: level badge (number + label), linear progress bar toward next level, current XP count. Height: 48 logical pixels plus top safe area padding. Fully opaque — it is not a glass overlay. Uses a solid background that matches the app's dark surface colour.

**Floating action button (z: overlay, bottom-right):** Standard `FloatingActionButton` positioned at `bottom: 16, right: 16`, above the bottom safe area. Icon: `+` with a globe stroke. Action: quick-add country sheet. Does not appear when a bottom sheet is open.

**Bottom sheet area (conditional):** `CountryDetailSheet`, `RegionDetailSheet`, or `UnvisitedCountrySheet` presented as a `DraggableScrollableSheet` anchored to the bottom. The map remains visible and interactive behind the peek state of the sheet (initial child size: 0.35). The sheet does not cover the XP bar.

**Rovy bubble (z: overlay, bottom-right above FAB):** `Positioned(bottom: 120, right: 16)`. A small quokka avatar with a speech bubble extending left. Appears conditionally, auto-dismisses after 4 seconds. The quokka avatar is 48×48px. The speech bubble is a `Container` with a `BorderRadius` and a max width of 180px. Only one bubble is ever visible. It does not block the region chips or the FAB in normal operation.

**Overlay region (z: overlay, full-screen):** `DiscoveryOverlay` and `MilestoneCard` are not in the map's `Stack` at all. They are pushed as routes or presented via `showGeneralDialog`, occupying the full screen. They are not "overlaid" on the map — they replace it temporarily.

**Principle:** The map's data surface (polygons, chips, markers) must remain interactive. Do not place any non-transparent overlay on top of the map that would capture taps without `IgnorePointer`. The XP bar and Rovy bubble are the only persistent overlays, and neither is large.

---

## Section 4 — Core UI Components

### 4.1 XP + Level Bar

**Purpose:** Persistent signal of progression. Tells the user how far they are in the Roavvy progression system at a glance.

**Visual design:** Full-width strip, 48px tall (plus safe area). Dark surface colour (`#1a1a2e` or matching app theme). Left side: circular level badge — filled amber circle, white level number (16sp bold), label beneath ("Explorer", 10sp, muted white). Right of badge: linear progress bar spanning 85% of the remaining width. Bar track: 20% white opacity. Bar fill: amber/gold gradient. Bar height: 6px, rounded caps. Right of bar: small XP count in muted white ("1240 XP", 11sp). No divider line — the dark background separates it from the map naturally.

**Data it needs:** `XpState { totalXp: int, level: int, levelLabel: String, progressFraction: double, xpToNextLevel: int }` from `XpNotifier`.

**Interaction behaviour:** Non-interactive for MVP. Tapping anywhere on the bar does nothing in MVP. Later: tap → XP history sheet. On XP earn events, a "+N XP" text animates upward from the XP count position and fades. The progress bar animates from its previous fill position to the new position over 600ms.

---

### 4.2 Region Progress Chip

**Purpose:** Surface region completion progress without the user needing to drill in. Creates goal salience — "I'm 4/5, I should get that last one."

**Visual design:** Pill-shaped container, 32px height, min-width 80px. Dark surface with 85% opacity (so basemap shows faintly behind). Left: a thin circular arc (22px diameter, 2px stroke, amber fill) showing completion fraction — `CustomPainter` drawing a `Canvas.drawArc`. Center: text "4/5 Nordic" in white, 11sp. Condensed font preferred for the N/M fraction. The arc is positioned to the left of the text. When complete (N == M), the arc becomes a full circle with a white checkmark icon (16px) inside.

**Data it needs:** `RegionProgressData { regionCode: String, regionName: String, visitedCount: int, totalCount: int, centroidLat: double, centroidLng: double }` from `RegionProgressNotifier`.

**Interaction behaviour:** Tap → `RegionDetailSheet` slides up, showing the region's countries in two groups: visited and unvisited. Tap should have a scale-down press animation (0.95 scale, 100ms). Chip is rendered as a `MarkerLayer` `Marker` widget on the `FlutterMap` — it is positioned by latitude/longitude on the map and moves with map pan/zoom.

---

### 4.3 Country Node Overlay

**Purpose:** Visual state encoding on each polygon. The core data layer. Every country is always visible in some state.

**Visual design:** Defined fully in Section 5. The "overlay" concept here is the combination of fill colour + border + animation that together communicate state. There is no separate node widget — the `PolygonLayer` itself is the overlay.

**Data it needs:** `Map<String, CountryVisualState>` from `countryVisualStateProvider`. The GeoJSON polygon points are pre-loaded at app start from the bundled Natural Earth GeoJSON.

**Interaction behaviour:** Tap on a polygon → see Section 7 (tapping visited / unvisited country). The `flutter_map` `PolygonLayer` supports `onTap` callbacks per polygon via `PolygonLayer.polygons[i].onTap`.

---

### 4.4 Discovery Overlay Card

**Purpose:** Mark the moment a new country is found. The emotional peak of a scan. This must not be understated.

**Visual design:** Full-screen surface, dark navy background (`#0d1117`). Center of screen, vertically: large country flag emoji (64sp), country name (28sp bold white), "just discovered" label (14sp muted amber), "+50 XP" in amber (22sp bold) with a brief scale-bounce animation. Below: single CTA button "Explore your map" (amber fill, full-width, 48px height, 12px radius). Top-right: thin `×` close button (always available — never trap the user). No countdown timer forces close — user dismisses intentionally.

**Data it needs:** `{ countryCode: String, countryName: String, flagEmoji: String, xpEarned: int }`. Passed as route arguments when `showGeneralDialog` is called.

**Interaction behaviour:** Shown via `showGeneralDialog` with `barrierDismissible: false`. Tapping the CTA or the `×` closes the dialog and returns to the map. If multiple new countries are discovered in one scan, overlays are queued and shown sequentially — one per country, with the user explicitly dismissing each. The map zooms to the newly discovered country behind the overlay (the overlay is transparent enough during the entrance animation that the map pan is perceptible, creating a sense of "going there").

---

### 4.5 Rovy Bubble

**Purpose:** Contextual personality. Rovy the quokka provides encouragement, celebration, and nudges at key moments. He is never in the way.

**Visual design:** Quokka avatar SVG/PNG, 48×48px, circular clip with a 2px amber border. Speech bubble extending left from the avatar: rounded rectangle (12px radius), white fill, 1px amber border, max-width 180px, padding 8px. Text is 13sp dark text. The bubble has a small triangular tail pointing right toward the quokka's face. The entire unit (avatar + bubble) is positioned `bottom: 120, right: 16` in the outer Stack.

**Data it needs:** `RovyMessage? { text: String, trigger: RovyTrigger, emoji: String? }` from `rovyMessageProvider` (StateProvider<RovyMessage?>). When the provider value is null, the bubble is not rendered (replaced by `SizedBox.shrink()`).

**Interaction behaviour:** Tap on the bubble → dismisses immediately (sets provider to null). After 4 seconds with no tap → auto-dismisses via `Timer`. Never blocks other interactions — uses `IgnorePointer` on the avatar itself (only the bubble text area accepts taps). Maximum one bubble visible at a time. If a new message fires while one is showing, the old message is replaced without animation (swap in place). Rovy appears after: new country discovered (celebration), region 1-away (nudge), 10th country (milestone), post-share (thanks). He does not appear during first-time scan — do not interrupt the scan reveal.

---

### 4.6 Milestone Card

**Purpose:** Celebrate round-number achievements. 5th, 10th, 25th, 50th, 100th countries.

**Visual design:** `DraggableScrollableSheet` with initial child size 0.45, anchored at bottom. Dark surface, rounded top corners (16px). Header row: milestone badge icon (SVG, 48px) + title "10 countries!" (22sp bold). Subtitle: "You've visited 10 countries. You're officially a Seasoned Traveller." (14sp muted). Below: narrow row showing the three most recent countries in this milestone (flags row). Share button: amber fill, "Share your milestone", full-width. Confetti fires from `ConfettiWidget` anchored at the top of the card on entry.

**Data it needs:** `{ countryCount: int, badgeId: String, badgeLabel: String, recentCountries: List<String> }`. Triggered by `XpNotifier` detecting a milestone threshold.

**Interaction behaviour:** Appears as a `DraggableScrollableSheet` pushed from outside the map. Can be dragged down to dismiss. Share button → `share_plus` share sheet with a pre-composed message and optionally a generated travel card image. After dismiss, the XP bar animates to reflect the XP earned by this milestone.

---

### 4.7 Region Completion Sheet

**Purpose:** Celebrate finishing a region. Stronger than a chip update, less than a full-screen takeover.

**Visual design:** `DraggableScrollableSheet`, initial child size 0.5. Header: region name (24sp bold), "Complete!" badge (amber pill). Below: compact list of all countries in the region (flag + name, 2-column grid). Each country row has a small amber checkmark. Confetti fires from `ConfettiWidget` at the top of the sheet. Share button: "Share your [Region] collection". Dismiss: drag down or tap outside.

**Data it needs:** `{ regionName: String, countries: List<{ code: String, name: String, flagEmoji: String }> }`. Triggered when `RegionProgressNotifier` detects a region moving from partial to complete.

**Interaction behaviour:** The region progress chip on the map transitions (behind the sheet, partially visible) from an arc to a full circle with checkmark — visible in the peek state where the map shows above the sheet. Share → `share_plus`. After dismiss, the chip on the map remains as a full-ring checkmark.

---

## Section 5 — Country Visual States (CRITICAL)

### The `CountryVisualState` Enum

```dart
enum CountryVisualState {
  unvisited,       // not in effective visits; no recent discovery
  visited,         // in effective visits; not recently discovered; not reviewed
  reviewed,        // user explicitly confirmed or edited this country
  newlyDiscovered, // added to effective visits within last 24 hours
  milestoneCountry,// is the 5th, 10th, 25th, 50th, or 100th visited country
  targetCountry,   // unvisited; 1 country remaining in a partially-done region
}
```

### State Derivation

`countryVisualStateProvider` derives state from three inputs:
1. `effectiveVisitsProvider` — the merged set of inferred + user-added − user-removed country codes
2. `recentDiscoveriesProvider` — `Set<String>` of ISO codes added to effective visits within the last 24 hours, persisted across sessions
3. `achievementRepositoryProvider` — to identify milestone countries (the Nth country added to effective visits)

Priority order (highest wins): `newlyDiscovered` > `milestoneCountry` > `reviewed` > `visited` > `targetCountry` > `unvisited`.

### Per-State Visual Definition

**1. Unvisited**
- Fill colour: `#1a1f2e` (very dark navy — slightly lighter than the basemap so country borders are faintly visible)
- Fill opacity: 0.4
- Border colour: `#2a3040` (slightly lighter than fill)
- Border width: 0.5px
- Animation: none
- Purpose: the unvisited world reads as a dark, quiet canvas. Most of the map is this state. It should recede, not assert.

**2. Visited**
- Fill colour: `#C8892A` (warm amber — the primary visited colour)
- Fill opacity: 0.65
- Border colour: `#E8A93A` (lighter amber)
- Border width: 1.0px
- Animation: none
- Purpose: clear, warm presence. Multiple visited countries together create a warm amber glow across the map. Not the blunt green of "you were here" — amber suggests memory, warmth, light.

**3. Reviewed** (user explicitly confirmed or edited)
- Fill colour: `#D4941A` (slightly deeper amber/gold than visited — more saturated)
- Fill opacity: 0.80
- Border colour: `#F0B030` (bright gold)
- Border width: 1.5px
- Inner glow: a subtle second polygon rendered at 30% opacity, 4px smaller than the actual border, `#F0B030` — creates an inner ring glow effect without requiring a shader
- Animation: none
- Purpose: reviewed countries feel more owned. The user has made a deliberate decision about this country. That deliberateness is reflected in slightly higher visual weight.

**4. Newly Discovered** (added to effective visits within last 24 hours)
- Fill colour: `#FFD060` (bright golden yellow — noticeably lighter than visited amber)
- Fill opacity: 0.90
- Border colour: `#FFE08A` (near-white gold)
- Border width: 2.0px
- Animation: `AnimationController` looping, duration 1200ms, `Curves.easeInOut`. Polygon scale oscillates 1.0 → 1.03 → 1.0. Implemented by scaling the fill opacity: 0.75 → 0.95 → 0.75 (opacity pulse is more performant than geometry scale on `PolygonLayer`). Stops after 24 hours or on next app open after the 24h window expires.
- Purpose: the eye is immediately drawn to newly discovered countries. The pulsing is gentle but unmistakable. This is the visual "still glowing" state.

**5. Milestone Country** (the 5th, 10th, 25th, 50th, or 100th visited country)
- Fill colour: `#D4941A` (same as reviewed)
- Fill opacity: 0.85
- Border colour: `#FFD060` (bright gold — same as newly-discovered border)
- Border width: 2.5px
- Special: a `Marker` is placed at the country's centroid with a gold star SVG icon (16px). This is rendered in a separate `MarkerLayer` above the polygon layer. The star is the visual differentiator — not polygon-native.
- Animation: none (the star is the indicator; animation would be too much for a persistent state)
- Purpose: milestone countries are special. The star is a permanent marker that says "this one mattered."

**6. Target Country** (unvisited; would complete a partially-finished region if visited)
- Fill colour: `#2A2F3E` (slightly brighter than unvisited — just enough to read as differentiated)
- Fill opacity: 0.55
- Border colour: `#C8892A` (amber — same as visited, creating a visual hint of "you could make this amber")
- Border width: 1.5px
- Border style: dashed — achieved by rendering the border as a series of short `Canvas.drawLine` segments in a `CustomPainter` placed in the `TargetCountryLayer`. The `PolygonLayer` itself does not support dashed borders natively.
- Animation: opacity breathing — 0.40 → 0.65 → 0.40, 2400ms loop, `Curves.easeInOut`. Slower than the newly-discovered pulse. Conveys possibility rather than urgency.
- Purpose: the target country is a gentle invitation. It does not shout — it glows faintly in the dark, suggesting "come here." It appears only when the user is close to completing a region.

### Implementation Note on Rendering Performance

Split into three `PolygonLayer` instances:
1. Unvisited + visited + reviewed (static — no animation; render once)
2. Newly discovered (animated — repaints on each animation tick)
3. Target countries are in `TargetCountryLayer`, a separate `PolygonLayer` with a custom dashed-border `CustomPainter`

This avoids forcing a full `PolygonLayer` rebuild when only the animated subset changes.

---

## Section 6 — Progress Path Integration

### The Core Metaphor

The Roavvy map is not a Duolingo node path. Countries are not nodes on a line. The progression system lives in the map itself — countries are darker or brighter based on state, and regions are annotated with arc progress chips. The map IS the path.

### Zoom Thresholds

Three zoom levels define what the user sees:

| Zoom range | Name | What's shown |
|---|---|---|
| zoom < 4 | World | Continent-level arc progress rings; no individual country chips; country polygons show visited/unvisited states |
| zoom 4–6 | Region | Individual country polygons at full resolution; region progress chips at centroids; target country highlights; no continent rings |
| zoom > 6 | Country | Single country fills the viewport; chip hidden (not meaningful at this scale); country name label if available |

### World Zoom (zoom < 4)

At world zoom, the individual region progress chips are hidden. Instead, continent-level progress is shown. This is rendered not as chips but as a `MarkerLayer` with larger continent-level annotation widgets placed at continent centroids (e.g., Europe at approximately 50°N, 10°E). Each annotation shows "Europe: 12/44" in a small pill. The pill uses the same arc ring style as region chips but with a larger arc diameter (28px).

The polygon visual states remain active at world zoom — the user can see the pattern of amber countries spread across the map. At this zoom level the amber clusters tell the story at a glance. No interaction mode change is required.

### Region Zoom (zoom 4–6)

Individual country outlines are clear. Region progress chips float over region centroids (one chip per region that has at least one visited country). The target country layer activates — countries that would complete a partially-done region show the dashed amber border and breathing animation.

The region progress chip at this zoom level is the primary navigational affordance. Tapping it opens the `RegionDetailSheet` which lists all countries in the region, visited and unvisited, and calls out the one-away nudge if applicable.

### Country Zoom (zoom > 6)

At this zoom, the user is examining a specific country. Region chips are hidden (they are not meaningful when looking at a single country). The country's polygon fills the viewport in its visual state colour. If the user taps the polygon, `CountryDetailSheet` opens as normal.

### "Next Target" Highlighting

When a user has visited N-1 of a region's countries (where N is the total), the remaining country enters the `targetCountry` visual state. This is computed in `countryVisualStateProvider` by cross-referencing `RegionProgressNotifier`'s data. The threshold for "target" state is: region has ≥ 2 countries visited AND exactly 1 country remaining unvisited. A region with 0 or 1 visited countries does not trigger the target state — the nudge is meaningful only when the goal is close.

---

## Section 7 — Key User Interactions

### 7.1 First Scan Reveal

After the first successful scan completes (and the user has never had a scan before), the map does not simply update silently.

The `ScanSummaryScreen` is shown as normal. When the user taps "Explore your map" on the summary, the map screen loads. At this moment:
1. All newly discovered countries are in the `newlyDiscovered` visual state and pulsing.
2. If there are 3 or more new countries, the map auto-pans to fit all of them within the viewport, then slowly zooms to world view over 1.2 seconds.
3. Rovy appears with: "Look at all those stamps! You've been busy." — auto-dismisses after 4s.
4. The XP Level Bar animates its fill from 0 to the earned XP over 800ms.

Countries do not appear one-by-one during this reveal in MVP (that is deferred to Later). The reveal is the whole-map state appearing with pulse animations already running.

### 7.2 Tapping a Visited Country

1. The tapped polygon scales up briefly: 1.0 → 1.04 → 1.0, 150ms, `Curves.easeOut`. Achieved by temporarily replacing the polygon's `CountryPolygonData` with a slightly expanded bounding state and reverting after 150ms. In practice this may not be achievable natively in `PolygonLayer` — an alternative is a `ScaleTransition` on the `CountryDetailSheet` entrance which gives a similar effect without polygon-level animation.
2. `CountryDetailSheet` slides up as a `DraggableScrollableSheet`. This is existing behaviour preserved from the current implementation.
3. No other change to the map while the sheet is open.

### 7.3 Tapping an Unvisited Country

1. The tapped polygon briefly increases its fill opacity: 0.40 → 0.70 → 0.40, 200ms, `Curves.easeOut`. This is an opacity animation, not a geometry change — achievable by briefly swapping the country's visual state to a "tapped-unvisited" transient state for 200ms.
2. A bottom sheet slides up: `UnvisitedCountrySheet`. Content: country flag emoji (large), country name (20sp bold), "You haven't visited [Country] yet." (14sp muted), "Add manually" button (outlined amber), "Dismiss" text button.
3. The "Add manually" button → existing add-country flow.

### 7.4 New Country Unlocked (post-scan)

This is the most important interaction in the app. It must be right.

1. Haptic feedback fires immediately: `HapticFeedback.heavyImpact()`.
2. The `DiscoveryOverlay` is presented via `showGeneralDialog`. It covers the full screen.
3. During the overlay's 300ms entrance animation (slide up + fade in), the map behind animates: `MapController.animateCamera` to the discovered country's centroid at zoom level 5, 800ms, `Curves.easeInOut`. The map animation plays behind the overlay — slightly visible through the entrance animation's opacity fade, creating a sense of "arriving."
4. The user reads the overlay (country name, flag, XP earned) and taps "Explore your map."
5. On dismiss, the map is at the discovered country's zoom level. The country is now in `newlyDiscovered` state and pulsing.
6. After a 1.5s delay, the map zooms back out to world level (if there are more countries to discover) or remains at the country zoom (if this was the only new country).
7. If multiple countries were discovered in one scan, the queue is shown sequentially. After all overlays are dismissed, the map zooms to fit all new countries.
8. The `XpLevelBar` animates its fill after the last overlay is dismissed.

### 7.5 Region Completion

1. `RegionProgressNotifier` detects a region moving from (N-1)/N to N/N.
2. The region progress chip on the map transitions: the arc fills from ~(N-1)/N to full in 500ms, then the arc becomes a full ring, then a white checkmark fades in over 300ms.
3. After a 400ms delay (to let the chip animation play), `RegionDetailSheet` slides up with confetti.
4. Rovy appears (above the sheet) with: "You've collected all of [Region]! ✨" — visible in the peeking map area above the sheet bottom.
5. Share button in the sheet → `share_plus`.
6. On dismiss, the chip remains as a full-ring checkmark.

### 7.6 Rescan

When the user triggers a scan (not their first), the scan pipeline runs in the background. On completion:
1. Only newly-found countries (not previously in effective visits) trigger `DiscoveryOverlay` presentations.
2. Countries already in effective visits that are re-detected: no visual change, no event.
3. The map updates its polygon states incrementally — only the changed countries re-render. The overall map does not flicker or re-draw.
4. If zero new countries found: Rovy appears briefly: "All caught up! No new countries this time." — auto-dismisses.
5. The XP bar animates if new XP was earned (scan completion: +25 XP regardless; +50 XP per new country).

### 7.7 Timeline Mode (Later)

A scrubber appears at the bottom of the map screen. The scrubber is a horizontal `Slider` widget positioned in a `Positioned(bottom: 80, left: 16, right: 16)` widget, above the FAB area. It ranges from the user's earliest-visit year to the current year.

As the scrubber moves, countries that have no first-visit date before the selected year fade out: their `CountryVisualState` overrides to a faded version of their normal state, with opacity dropping to 0.15 and fill colour muted to near-unvisited. Countries that were visited before the scrubber year remain at their normal visual state.

The fade transition uses an `AnimatedOpacity` wrapper on each polygon's fill — not a full repaint. This requires the `CountryPolygonLayer` to accept an additional `timelineFilterYear: int?` parameter that gates opacity per country based on the `effectiveVisits` first-visit date.

Timeline mode is activated via a button in the map's `⋮` overflow menu. When active, the scrubber is shown and the FAB is hidden.

---

## Section 8 — Motion & Delight

All animations must be gated on `MediaQuery.disableAnimations`. Check `MediaQuery.disableAnimationsOf(context)` before starting any `AnimationController`. If true, skip to the final animation value immediately.

**Polygon pulse (newly discovered):**
`AnimationController(duration: 1200ms, vsync: this)`, repeat with `reverse: true`. Drives fill opacity: 0.75 → 0.95 → 0.75. Easing: `Curves.easeInOut`. The controller lives in `CountryPolygonLayer` which is a `StatefulWidget` with `SingleTickerProviderStateMixin`. Stops when the `newlyDiscovered` set becomes empty (all countries pass the 24h window).

**Discovery overlay entrance:**
`showGeneralDialog` with a custom `pageBuilder` that wraps `DiscoveryOverlayPage` in a `SlideTransition` + `FadeTransition`. Slide: `Tween<Offset>(begin: Offset(0, 0.3), end: Offset.zero)`. Duration: 300ms, `Curves.easeOutCubic`. Country flag inside the overlay: `ScaleTransition` from 0.8 → 1.0 with a `SpringSimulation` (mass: 1.0, stiffness: 200, damping: 20). "+N XP" text: `SlideTransition` from 0.0 → -0.5 (upward) + `FadeTransition` from 1.0 → 0.0, 400ms, delayed 200ms after overlay entrance.

**XP bar fill:**
`AnimatedLinearProgressIndicator` — a custom widget wrapping `TweenAnimationBuilder<double>` with target value `progressFraction`. Duration: 600ms, `Curves.easeOut`. "+N XP" earned flash: a `Text` widget positioned at the right end of the bar, driven by `SlideTransition` (upward) + `FadeTransition`, 400ms, `Curves.easeOut`. Text appears immediately on XP earn, animates for 400ms, then is removed from the tree.

**Region arc progress:**
The arc in `RegionProgressChip` is drawn by a `CustomPainter` that receives `progressFraction` (a `double`). Wrap the chip in `TweenAnimationBuilder<double>` with the new fraction as target. Duration: 500ms, `Curves.easeOut`. On region completion, the arc animates from `(N-1)/N` to 1.0 in 500ms, then the painter switches to render a full-ring checkmark with a `FadeTransition` (the checkmark fades in over 300ms while the arc fades out).

**Milestone card entrance:**
`DraggableScrollableSheet` with `initialChildSize: 0.0`, animated programmatically to `0.45` using `DraggableScrollableController.animateTo`, duration: 350ms, `Curves.easeOutCubic`. `ConfettiWidget` from `confetti ^0.7.0` positioned at the top edge of the sheet, fires a 2-second burst of amber and gold confetti particles (`colors: [Color(0xFFFFD060), Color(0xFFC8892A), Color(0xFFFFFFFF)]`). Confetti emission count: 30. Blast direction: `pi / 2` (downward from top).

**Rovy bubble:**
`AnimatedSwitcher` wrapping the `RovyBubble` widget. When the `rovyMessageProvider` changes from null to a message, `AnimatedSwitcher` plays a `ScaleTransition` from 0.0 → 1.0 with transform origin at the bubble's right edge (the quokka's mouth position). Duration: 250ms, spring physics via a `SpringSimulation`. On dismiss (4s timer or tap), the bubble fades out via `FadeTransition`, 150ms.

**Map zoom on discover:**
After `showGeneralDialog` is called (not after dismiss — during the overlay entrance), call `mapController.animateCamera` to the discovered country's bounds with padding 60px on all sides. Duration: 800ms, `Curves.easeInOut`. Implementation: `flutter_map`'s `MapController` exposes `animateCamera` if using `flutter_map_animations` package, or can be driven manually with a `LatLngTween` and an `AnimationController`. After 1.5 seconds, if the user has not interacted with the map, zoom back to world bounds with the same 800ms duration.

**Bottom sheet entrance (CountryDetailSheet, RegionDetailSheet):**
Existing `DraggableScrollableSheet` with `initialChildSize: 0.35`. Entrance via `showModalBottomSheet`. This is existing behaviour — no change.

---

## Section 9 — Flutter Implementation Approach

### Polygon Rendering

The `flutter_map` `PolygonLayer` accepts `List<Polygon>` where each `Polygon` has `points`, `color`, `borderColor`, `borderStrokeWidth`, and `onTap`. The current implementation passes a flat list of all country polygons.

The new implementation introduces `CountryPolygonData`:

```dart
class CountryPolygonData {
  final String isoCode;
  final List<LatLng> points;
  final CountryVisualState state;
  CountryPolygonData({ required this.isoCode, required this.points, required this.state });
}
```

`CountryPolygonLayer` is a `ConsumerStatefulWidget` with `SingleTickerProviderStateMixin`. It watches `countryVisualStateProvider` and the `_newlyDiscoveredAnimationController`. On each frame tick (for animated states), it rebuilds only the polygons in the `newlyDiscovered` state. Non-animated polygons (unvisited, visited, reviewed) are built once and cached in a `List<Polygon>` that is only rebuilt when `countryVisualStateProvider` emits a new value.

Split into three `PolygonLayer` instances inside `CountryPolygonLayer`:
```dart
Stack(children: [
  PolygonLayer(polygons: _staticPolygons),           // unvisited + visited + reviewed
  PolygonLayer(polygons: _newlyDiscoveredPolygons),  // animated; rebuilt each tick
])
```

`TargetCountryLayer` is a separate widget (also a `ConsumerStatefulWidget`) that renders the dashed-border target countries using a `CustomPaint` widget overlaid on a transparent `PolygonLayer`. The dashed border is drawn by a `CustomPainter` that converts `LatLng` points to screen coordinates using the `FlutterMap`'s `MapCamera.latLngToScreenPoint`.

### State Management

New provider: `mapStateProvider` (`StateNotifierProvider<MapStateNotifier, MapState>`):

```dart
class MapState {
  final Map<String, CountryVisualState> countryStates;
  final double zoomLevel;
  final String? activeRegion;
}
```

`MapStateNotifier` watches `effectiveVisitsProvider`, `achievementRepositoryProvider`, and `recentDiscoveriesProvider`. It recomputes `countryStates` whenever any of these change. This is the single source of truth for polygon rendering.

`recentDiscoveriesProvider` is a `StateNotifierProvider<RecentDiscoveriesNotifier, Set<String>>`. `RecentDiscoveriesNotifier` loads its initial state from `SharedPreferences` (key: `recent_discoveries_v1`, value: a JSON list of `{ isoCode, discoveredAt }` pairs). On each load, it filters out entries older than 24 hours. On new discovery, it adds to the set and persists. It does not use Drift — this is lightweight metadata, not relational data, and SharedPreferences is sufficient.

### XP System

`XpEvent` domain model:
```dart
class XpEvent {
  final String id;           // UUID
  final XpEventType type;    // newCountry | regionComplete | scanComplete | share
  final int xpDelta;
  final String? countryCode; // nullable — region/scan events don't have a country
  final DateTime createdAt;
}
```

`xp_events` Drift table: `id TEXT PK, event_type TEXT, xp_delta INTEGER, country_code TEXT NULLABLE, created_at TEXT`. Schema version: to be determined when XP system is introduced (will be schema v10 or later).

`XpRepository`:
- `Future<void> award(XpEvent event)` — inserts into `xp_events`
- `Future<int> totalXp()` — `SELECT SUM(xp_delta) FROM xp_events`
- `Stream<int> watchTotalXp()` — Drift watch query
- `Future<List<XpEvent>> loadAll()` — for history sheet (Later)

`XpNotifier` (`StateNotifier<XpState>`):
```dart
class XpState {
  final int totalXp;
  final int level;
  final String levelLabel;
  final double progressFraction;  // 0.0 → 1.0 within current level
  final int xpToNextLevel;
}
```

Level thresholds (XP required to reach each level):
| Level | XP Required | Label |
|---|---|---|
| 1 | 0 | Wanderer |
| 2 | 100 | Explorer |
| 3 | 250 | Voyager |
| 4 | 500 | Adventurer |
| 5 | 1,000 | Globetrotter |
| 6 | 2,000 | Trailblazer |
| 7 | 3,500 | Pathfinder |
| 8 | 5,000 | Legend |

Level 8 is the max. Above 5,000 XP: level stays at 8, progress bar stays full. `XpNotifier` subscribes to `XpRepository.watchTotalXp()` and recomputes `XpState` on each emission.

**XP award rules:**
| Event | XP |
|---|---|
| New country discovered (scan) | +50 |
| New country added manually | +30 |
| Region completed | +150 |
| Scan completed (any) | +25 |
| Travel card shared | +30 |
| Milestone reached (5th, 10th, 25th, 50th, 100th country) | +100 |

XP is awarded by calling `XpRepository.award()` at the existing write sites. These are:
- `ScanService` on completing a scan that produces new countries
- `VisitRepository.addCountry` for manual additions
- `RegionProgressNotifier` on detecting region completion
- Share flow (wherever `share_plus` is called for a travel card)

Award calls are fire-and-forget — wrap in `unawaited()` and catch errors silently. Do not block the primary flow.

### Overlays

All overlays in `MapScreen` are in a `Stack` above the `FlutterMap`. Structure:

```dart
Stack(
  children: [
    FlutterMap(...),
    Positioned(top: MediaQuery.of(context).padding.top, left: 0, right: 0,
      child: XpLevelBar()),
    if (rovyMessage != null)
      Positioned(bottom: 120, right: 16,
        child: RovyBubble(message: rovyMessage!)),
    // DiscoveryOverlay: shown via showGeneralDialog — NOT in this Stack
    // MilestoneCard: shown via showModalBottomSheet — NOT in this Stack
  ],
)
```

`IgnorePointer` wraps the `XpLevelBar` in MVP (non-interactive). `RovyBubble` uses `GestureDetector` for tap-to-dismiss but `IgnorePointer` on the quokka avatar itself so taps on the avatar fall through to the map.

### Rovy Bubble

`RovyBubble` is a `ConsumerStatefulWidget`. It reads `rovyMessageProvider`. On receiving a non-null message, it starts a 4-second `Timer`. On timer completion, it calls `ref.read(rovyMessageProvider.notifier).state = null`. On tap, same. The bubble uses `AnimatedSwitcher` to animate between null (invisible) and a message state.

`rovyMessageProvider` is a `StateProvider<RovyMessage?>`, initialized to null. It is set by various event handlers: `XpNotifier` (on XP earn), `RegionProgressNotifier` (on 1-away detection), scan completion handler.

### Discovery Overlay

`DiscoveryOverlay` is not a widget in the `Stack`. It is presented with:

```dart
showGeneralDialog(
  context: context,
  barrierDismissible: false,
  barrierColor: Colors.transparent,
  pageBuilder: (context, animation, secondaryAnimation) {
    return DiscoveryOverlayPage(
      countryCode: code,
      countryName: name,
      flagEmoji: flag,
      xpEarned: xp,
    );
  },
  transitionBuilder: (context, animation, secondaryAnimation, child) {
    return SlideTransition(
      position: Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
          .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
      child: FadeTransition(opacity: animation, child: child),
    );
  },
  transitionDuration: const Duration(milliseconds: 300),
);
```

`DiscoveryOverlayPage` is a plain `StatefulWidget` (not a `ConsumerWidget` — it receives all data via constructor). It does not interact with Riverpod directly. The calling site (wherever scan completion is handled) is responsible for dispatching the overlays in sequence.

### Region Progress Chips

Region chips are `Marker` objects in a `flutter_map` `MarkerLayer`. Each `Marker` has a `LatLng` (the region centroid) and a `builder` that returns `RegionProgressChip(data: progressData)`.

The centroid coordinates for each region are hardcoded in a `regionCentroids` map (`Map<String, LatLng>`) in `lib/features/map/region_centroids.dart`. This is a static lookup — no computation required at runtime.

Chips are hidden at zoom < 4. The `RegionChipsMarkerLayer` widget watches the map's zoom level (via `MapController.mapEventStream`) and returns an empty `MarkerLayer` when zoom < 4.

### Animation Controllers

- `CountryPolygonLayer` owns its pulse `AnimationController` — `SingleTickerProviderStateMixin`
- `TargetCountryLayer` owns its breathing `AnimationController` — `SingleTickerProviderStateMixin`
- `DiscoveryOverlayPage` owns the flag scale `AnimationController` — `SingleTickerProviderStateMixin`
- `XpLevelBar` uses `TweenAnimationBuilder` — no explicit controller needed
- `RegionProgressChip` uses `TweenAnimationBuilder` — no explicit controller needed
- `RovyBubble` uses `AnimatedSwitcher` — no explicit controller needed

No `AnimationController` lives in a Riverpod provider. Providers are for application state, not UI animation state.

---

## Section 10 — Widget Tree

```
MapScreen (ConsumerStatefulWidget)
└── Scaffold
    └── Stack
        ├── FlutterMap
        │   ├── TileLayer                        CartoDB Dark Matter (or plain dark colour fallback)
        │   ├── CountryPolygonLayer               ConsumerStatefulWidget; splits into static + animated PolygonLayers
        │   │   ├── PolygonLayer (static)         unvisited + visited + reviewed polygons; rebuilt only on state change
        │   │   └── PolygonLayer (animated)       newlyDiscovered polygons; rebuilds on each animation tick
        │   ├── TargetCountryLayer                ConsumerStatefulWidget; dashed-border polygons for 1-away countries
        │   ├── RegionChipsMarkerLayer            ConsumerWidget; MarkerLayer with RegionProgressChip per region; zoom-gated
        │   └── MilestoneStarMarkerLayer          MarkerLayer; gold star icon at centroid of milestone countries (Later)
        │
        ├── Positioned (top: safeAreaTop, left:0, right:0)
        │   └── XpLevelBar                        ConsumerWidget; reads XpState from XpNotifier
        │
        └── Positioned (bottom: 120, right: 16)   conditional on rovyMessageProvider != null
            └── RovyBubble                        ConsumerStatefulWidget; AnimatedSwitcher; 4s auto-dismiss Timer

    ├── FloatingActionButton                      quick-add country; hidden when bottom sheet is open
    │
    └── [Modal layers — presented separately, not in Stack]
        ├── DiscoveryOverlayPage                  showGeneralDialog; full-screen; not a Stack child
        ├── CountryDetailSheet                    showModalBottomSheet; DraggableScrollableSheet
        ├── RegionDetailSheet                     showModalBottomSheet; DraggableScrollableSheet
        ├── UnvisitedCountrySheet                 showModalBottomSheet; DraggableScrollableSheet
        └── MilestoneCard                         showModalBottomSheet; DraggableScrollableSheet; confetti
```

**Note on z-ordering:** `flutter_map` layers are stacked in declaration order (first = bottom). The order within `FlutterMap` is: `TileLayer` → `CountryPolygonLayer` → `TargetCountryLayer` → `RegionChipsMarkerLayer` → `MilestoneStarMarkerLayer`. Chips and stars are always above polygons.

---

## Section 11 — MVP vs Later

### MVP — Build First

These six items deliver maximum emotional impact with minimum new infrastructure. They are sequenced so that each one builds directly on the previous.

| Feature | Why MVP |
|---|---|
| 5 country visual states (unvisited / visited / reviewed / newly-discovered / target) | Foundation of everything. Every other gamification feature depends on visual state encoding being correct. |
| XP award engine (Drift table + XpNotifier + award rules) | Backend only — no UI required to validate. Unblocks all XP-dependent features. |
| XP Level Bar in map top strip (read-only) | Visible signal of the progression system. Users understand they are earning something. |
| Discovery overlay card (new country moment) | The single highest-impact emotional moment in the app. Low complexity (full-screen route, static content). |
| Region progress chips on map (N/M chips at centroids) | Immediately communicates progress and creates goal salience. Uses data that already exists. |
| Haptic feedback on new country (`HeavyImpact`) | One line of code. Maximum emotional punctuation per effort. |

### Later — Post-MVP

| Feature | Reason Deferred |
|---|---|
| Rovy mascot bubble | Requires content design (what does Rovy say and when). Core product works without it. |
| Milestone cards (5th, 10th, 25th country celebrations) | Nice-to-have ceremony. XP system covers the moment adequately at MVP. |
| Soft social ranking ("more than 72% of users") | Requires aggregate data job on backend. No backend capacity in Slice 1. |
| Timeline scrubber mode | Requires per-country first-visit date filtering in the rendering pipeline. Non-trivial. |
| Progressive scan reveal (countries appear one-by-one) | High complexity — requires scan pipeline to emit per-country events during processing, not just at completion. |
| Animated map zoom on country discover | Map animation behind the discovery overlay. Nice framing but zero impact on core moment. |
| Region completion sheet with confetti | The chip update and Rovy message handle the moment adequately at MVP. Sheet is polish. |
| Milestone star marker layer | Requires `MilestoneStarMarkerLayer` with a separate `MarkerLayer`. Deferred to Slice 2. |

---

## Section 12 — Optional High-Impact Enhancements

These are included because they are genuinely impactful and feasible with the data already in the system. They are not fluff.

### 12.1 "One More" Nudge

When a user has visited N-1 of a region's countries, a small `Callout` widget appears anchored to the region's progress chip on the map. The callout is a small white rounded rectangle with an amber border and an arrow pointing at the chip. Text: "1 more for Scandinavia →". Tapping it expands the `RegionDetailSheet` with the unvisited country highlighted in amber.

This nudge is shown once per region transition (not persistently on every app open — that would be annoying). It is triggered by `RegionProgressNotifier` detecting the N-1 → threshold crossing and emitting a `rovyMessageProvider` update alongside a `targetCountryCalloutProvider` update. It auto-dismisses after 8 seconds.

Implementation: `Positioned` widget in the map `Stack`, anchored relative to the chip's screen position. Computing screen position from `LatLng` requires `MapCamera.latLngToScreenPoint` — available via `MapController`.

### 12.2 Year Filter Overlay

A horizontal `Slider` anchored at the bottom of the map screen (above the FAB row). Range: `[earliestVisitYear, DateTime.now().year]`. As the slider moves, countries whose `first_visit_date` is after the selected year fade out — their opacity animates to 0.15 and fill colour mutes.

The filtering computation is: for each `CountryVisualState` in `mapStateProvider`, look up the country's `first_visit_date` from `effectiveVisitsProvider` (the `EffectiveVisitedCountry` model includes first/last seen dates). If `firstVisitDate.year > selectedYear`, the country renders as faded-unvisited regardless of its actual state.

This is implemented as a `timelineYear` parameter passed into `CountryPolygonLayer`. When `timelineYear` is non-null, the polygon fill derivation checks the date. The `Slider` widget updates a `timelineYearProvider` (StateProvider<int?>). When null, timeline mode is off.

The slider is activated from the `⋮` overflow menu. When active, the FAB is hidden to reduce visual noise.

### 12.3 Country Depth Colouring

Visited countries are coloured by trip frequency — the number of trips to that country (from the `trips` Drift table). This adds a dimension of richness with zero new data collection.

Colour scale:
- 1 trip: `#C8892A` (base amber — current visited colour)
- 2 trips: `#D4941A` (slightly deeper)
- 3 trips: `#E0A010` (deeper gold)
- 4 trips: `#ECA800` (rich gold)
- 5+ trips: `#F8B800` (bright deep gold)

`CountryVisualState` does not need a new enum value. Instead, `CountryPolygonData` gains a `tripCount: int` field. The `CountryPolygonLayer` interpolates the fill colour from the amber scale based on `tripCount`. `CountryVisualState.visited` is the baseline — `tripCount` modulates the colour within that state.

`countryVisualStateProvider` must additionally watch `tripRepository.watchTripCountsByCountry()` to populate `tripCount` per `CountryPolygonData`.

### 12.4 XP Streak

The user earns a streak for scanning their library at least once per calendar month. Streak count is stored in a `app_meta` entry in Drift: `xp_streak_count` (int) and `xp_streak_last_scanned_month` (ISO year-month string, e.g. "2026-03").

On scan completion, `XpNotifier` checks whether `lastScannedMonth` is the current month. If not, and if `lastScannedMonth` is the previous month, the streak increments. If `lastScannedMonth` is more than one month ago, the streak resets to 1.

The streak count is shown in the `XpLevelBar` as a small flame icon + number to the right of the level label. It is not shown if the streak is 0 or 1 (a streak of 1 is just "you scanned once").

On streak loss (first scan in a month where the streak broke): Rovy appears with: "Your streak reset. Start a new one with your next scan." — gentle, not punitive. No XP penalty. Roavvy is not a language learning app.
