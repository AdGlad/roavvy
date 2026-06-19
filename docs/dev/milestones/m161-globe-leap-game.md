# M161 — Globe Leap: Daily Slingshot Game (MVP)

**Status: Complete**

## Goal

A daily arcade game where every player starts from the same country and launches Roavvy around the globe with a slingshot mechanic. Land on new countries, collect bonuses from nearby UNESCO World Heritage Sites, and keep jumping until you hit water or revisit a country. One run per day, globally seeded.

**Core complexity:** Making the flight path feel good on a 3D globe. This is not a physics simulation — it is a deterministic arc. The player pulls back, the engine calculates direction + power + destination, then Roavvy animates along a great-circle path. All the effort goes into the feel of that animation.

**Prerequisites:** Flutter interactive globe (country polygons, visited-country state), UNESCO heritage site data (M119), daily challenge logic pattern (M133), mascot sprite/Lottie asset, existing confetti/sound patterns.

---

## Implementation Approach: Deterministic Arc, Not Physics

On release the engine computes once:

1. Bearing from swipe vector
2. Distance from drag power (quadratic curve)
3. Destination lat/lng (inverse Haversine)
4. Is destination land or water? (`country_lookup`)
5. Which country was hit?
6. Previously visited this run?
7. Nearest UNESCO site and proximity tier
8. Score delta

Then Roavvy animates along the pre-calculated great-circle arc. There is no mid-air physics — the outcome is known before the animation starts. This avoids messy simulation while still feeling like a catapult game.

---

## Feasibility

| Version | Feasibility |
|---|---|
| MVP (this milestone) | High — all geography primitives exist |
| Polished (smooth camera-follow, 3D-attached mascot, full audio) | Medium — tuning-heavy; deferred to M160 |

---

## Main Risks

**Risk 1 — Globe lat/lng picking.** The biggest technical question is whether the current globe implementation can report the geographic coordinates of any 2D screen point. The flight animation needs to place Roavvy at an intermediate lat/lng each frame to follow the arc. Investigate the existing `GlobeController`/`GlobeWidget` API before building the animation layer.

**Risk 2 — Power feel.** If the power curve is too linear, short pulls and long pulls feel the same. If it maps too tightly to exact distance, the game feels like a calculator. Quadratic mapping (small pulls stay short, big pulls need real commitment) with a visible aim-arc preview is the recommended starting point; expect tuning iterations.

---

## Required Components

### 1. Input

`GestureDetector` on the slingshot widget:

- `onPanStart` — anchor the pull origin
- `onPanUpdate` — track drag delta; update aim-arc preview in real time
- `onPanEnd` — compute bearing + power from final delta; trigger engine

Bearing: 2D screen drag vector rotated by current globe heading → geographic bearing (degrees).
Power: `min(dragDistance / maxDragPx, 1.0)` → `powerToDistanceKm(p) = p * p * 18000` (quadratic, km).

### 2. Geography Engine (`GlobeLeapEngine`)

Pure Dart, no Flutter dependencies.

| Step | Source |
|---|---|
| Current lat/lng | Engine state (starts at seed centroid) |
| Destination lat/lng | Inverse Haversine: `computeDestination(lat, lng, bearingDeg, distanceKm)` |
| Water check | `country_lookup` — no country resolved → ocean |
| Visited check | `Set<String>` of country codes visited this run |
| Distance | Haversine between current and destination |
| Nearest UNESCO site | Linear scan of bundled WHS dataset; compute distance to each site |
| Continent bonus | `kCountryContinent` map (already in `shared_models`) |
| Score delta | Sum of all applicable bonuses |

### 3. Animation

**For MVP:** Roavvy is a 2D overlay (`Stack`) animating over the globe widget. The globe itself rotates to follow; Roavvy's screen position is computed by projecting his current lat/lng through the globe's projection matrix.

**Globe camera:** During flight, call `GlobeController.flyTo(midpointLat, midpointLng)` to keep the arc visible. On landing, fly to destination.

**Arc path:** Interpolate `t` from 0.0 → 1.0 along the great-circle between source and destination. At each frame, compute the intermediate lat/lng, project to screen coordinates, position Roavvy.

**Roavvy behaviour during flight:**
- Rotation: spins continuously; speed proportional to `distanceKm`
- Wings: flap animation (Lottie loop or AnimationController)
- Trail: list of fading dots at previous frame positions (simple `CustomPaint`)

**Landing impact:**
- New country: brief glow burst at destination; score delta toast animates in; confetti burst (reuse existing confetti pattern)
- Ocean: splash ripple animation; Roavvy sinks; game over
- Revisit: red flash on country polygon; game over

**Sound cues** (use existing audio service pattern):
- Slingshot stretch: rubber-band creak (short, pitch-varies with power)
- Release: whoosh
- Mid-flight: wind rush (loops for flight duration)
- Land on country: satisfying thud + chime
- Heritage bonus: sparkle sting
- Ocean: splash
- Revisit: thud + wrong-answer tone

### 4. Daily Game State

Same Firestore pattern as M133 daily challenge:

- Cloud Function seeds `globe_leap/{YYYY-MM-DD}` at 00:01 UTC
- Local Drift table stores today's completed run
- If a run for today exists on open → show read-only results
- One attempt per day; no retry

---

## Scoring

| Event | Points |
|---|---|
| New country landed | +100 |
| Distance bonus | +1 per 100 km |
| Nearest UNESCO site < 500 km | +50 |
| Nearest UNESCO site < 50 km | +100 |
| Nearest UNESCO site < 10 km (direct hit) | +250 |
| First landing on new continent | +250 |
| Jump > 8,000 km | +200 |
| Jump > 12,000 km | +500 (replaces 8k bonus) |

Heritage bonus: one site per jump (the nearest one wins).

---

## Death Conditions

| Condition | Visual |
|---|---|
| Ocean landing | Splash animation; Roavvy sinks |
| Revisit (country already in this run) | Red polygon flash |

---

## Phases & Tasks

### T1 — Cloud Function: daily seed

- New Scheduled Function `publishGlobeLeapSeed` — 00:01 UTC daily.
- Deterministic PRNG keyed on days-since-epoch; picks from bundled `centroid_seeds.json` (~250 entries, ISO 3166-1 alpha-2 → `{lat, lng, name}`).
- Writes `globe_leap/{YYYY-MM-DD}` → `{ countryCode, countryName, centroidLat, centroidLng, generatedAt }`.
- Deploy to dev; run manual invocation test.

### T2 — `shared_models`: data types

New `globe_leap.dart`:

```dart
class GlobeLeapSeed {
  final String countryCode;
  final String countryName;
  final double centroidLat;
  final double centroidLng;
  final DateTime date;
}

class GlobeLeapJump {
  final String countryCode;
  final String countryName;
  final double landLat;
  final double landLng;
  final double distanceKm;
  final int scoreEarned;
  final int? heritageBonus;       // null if no site nearby
  final String? nearestSiteName;
  final bool newContinent;
  final bool longShot;
}

class GlobeLeapRun {
  final String date;              // YYYY-MM-DD
  final String startCountryCode;
  final List<GlobeLeapJump> jumps;
  final int totalScore;
  final DeathReason deathReason;
  final DateTime completedAt;
}

enum DeathReason { ocean, revisit, abandoned }
```

### T3 — Drift: `globe_leap_runs` table (schema v16)

```
globe_leap_runs
  date           TEXT PK    -- YYYY-MM-DD
  total_score    INTEGER
  jumps_json     TEXT       -- JSON-encoded List<GlobeLeapJump>
  death_reason   TEXT
  completed_at   INTEGER    -- Unix ms
```

`GlobeLeapRepository`: `getTodayRun()`, `saveRun(run)`.

### T4 — `GlobeLeapEngine` (pure Dart)

`features/globe_leap/globe_leap_engine.dart`

- `computeDestination(lat, lng, bearing, distanceKm)` → `(lat, lng)` — inverse Haversine.
- `greatCircleInterpolate(src, dst, t)` → intermediate lat/lng for animation frames.
- `resolveJump(bearing, distanceKm)` → `JumpResult`:
  - `country_lookup` → ocean check → revisit check → bonus calculations → score delta.
- `powerToDistanceKm(power)` → km (quadratic curve).
- Stateful: tracks `currentPosition`, `visitedCodes`, `visitedContinents`, `jumps`, `score`.

**Investigation task:** Audit `GlobeController` / `GlobeWidget` to confirm how to:
  a) project lat/lng → screen `Offset` for Roavvy positioning
  b) drive `flyTo(lat, lng)` during animation

  Document findings in a `## Globe API Notes` section at the bottom of this file before T5/T6 implementation begins.

### T5 — Slingshot gesture widget

`features/globe_leap/globe_leap_slingshot.dart`

- `GlobeLeapSlingshotController` (ChangeNotifier): pan handlers → emits `bearing`, `power`, `previewDestination`.
- `GlobeLeapSlingshotWidget`: rubber-band line from anchor; dotted great-circle aim-arc preview on globe; Roavvy at anchor; power indicator bar.
- Power audio: creak pitch follows drag distance (use existing audio service).

### T6 — Flight animation controller

`features/globe_leap/globe_leap_flight_animation.dart`

- `GlobeLeapFlightController` (TickerProvider): animates `t` 0.0 → 1.0 over `flightDuration`.
- `flightDuration = max(1.2s, distanceKm / 8000 * 3.0s)`.
- Each tick: `greatCircleInterpolate(src, dst, curve.transform(t))` → lat/lng → screen offset → Roavvy position.
- Globe camera: `flyTo(midpoint)` at start; `flyTo(destination)` at `t = 0.85`.
- Trail: ring buffer of last 20 positions, opacity fades with age.
- On complete: call `notifier.onFlightLanded()`.

### T7 — `GlobeLeapNotifier` + state machine

`features/globe_leap/globe_leap_notifier.dart`

```
Loading
  → Seeded(seed, existingRun?)   // existingRun != null → already played today
  → Aiming(engine)               // slingshot visible
  → Flying(engine, jumpSoFar)    // animation running
  → Landed(engine, lastJump)     // 1.5s pause, score toast visible
  → GameOver(run)                // results sheet
```

- `loadTodayGame()`: fetch Firestore seed → check local run → emit `Seeded`.
- `startGame()`: build engine from seed → `Aiming`.
- `submitJump(bearing, distance)`: resolve jump → `Flying`.
- `onFlightLanded()`: game over? → save run → `GameOver`. Else → `Landed` → after 1.5s → `Aiming`.
- `abandonGame()`: save partial run (`deathReason=abandoned`) → `GameOver`.

### T8 — Globe Leap screen

`features/globe_leap/globe_leap_screen.dart`

Stack layers (bottom to top):
1. `GlobeWidget` — existing globe; visited countries glow gold; flight arcs drawn as polylines.
2. `GlobeLeapFlightLayer` — Roavvy sprite + trail (`CustomPaint`); visible during `Flying`.
3. `GlobeLeapSlingshotWidget` — visible during `Aiming`.
4. HUD overlay — score, jump count, continents badge (top corners).
5. Score delta toast — slides in on `Landed`.
6. `_GlobeLeapResultsSheet` — `DraggableScrollableSheet` on `GameOver`:
   - Final score, country list with flags, death reason illustration.
   - Share button: `"I leaped X countries for Y pts! #RoavvyLeap"` → system share sheet.

`Seeded` state with existing run → read-only results summary replaces slingshot.

### T9 — Shell entry point

Add a "Leap" card below the Heritage Challenge card on the existing Daily tab (same approach as the challenge chip). No new nav tab. Shows today's score if played, "Play Today's Leap" if not.

### T10 — Tests

`test/features/globe_leap/`

`globe_leap_engine_test.dart` (30+ cases):
- `computeDestination` accuracy against known lat/lng pairs
- Ocean detection (Pacific mid-point → `DeathReason.ocean`)
- Revisit detection
- Heritage bonus tiers (mocked WHS, distances at 9 km / 49 km / 499 km / 600 km)
- Continent bonus: new vs repeat continent
- Long-shot thresholds (7,999 km → no bonus; 8,001 → +200; 12,001 → +500)
- Score accumulation across 3 sequential jumps
- `powerToDistanceKm` curve: `p=0` → 0 km, `p=0.5` → 4,500 km, `p=1.0` → 18,000 km

`globe_leap_slingshot_test.dart` (10+ cases):
- Bearing computation for cardinal and diagonal drag vectors
- Power clamped to 0.0–1.0

---

## File Map

```
apps/functions/src/
  publishGlobeLeapSeed.ts              NEW
  data/centroid_seeds.json             NEW

packages/shared_models/lib/src/
  globe_leap.dart                      NEW

apps/mobile_flutter/lib/
  data/db/roavvy_database.dart         EDIT — schema v16
  data/globe_leap_repository.dart      NEW
  features/globe_leap/
    globe_leap_engine.dart             NEW
    globe_leap_slingshot.dart          NEW
    globe_leap_flight_animation.dart   NEW
    globe_leap_notifier.dart           NEW
    globe_leap_screen.dart             NEW
  core/providers.dart                  EDIT — provider wiring
  features/shell/main_shell.dart       EDIT — Daily tab entry point

apps/mobile_flutter/test/features/globe_leap/
  globe_leap_engine_test.dart          NEW
  globe_leap_slingshot_test.dart       NEW
```

---

## Firestore Document

`globe_leap/{YYYY-MM-DD}`

```json
{
  "countryCode": "AU",
  "countryName": "Australia",
  "centroidLat": -25.274,
  "centroidLng": 133.775,
  "generatedAt": "<Timestamp>"
}
```

---

## ADRs

- **ADR-004:** Deterministic arc, not physics. Outcome is computed before animation starts. Avoids simulation complexity; full effort goes into animation feel.
- **ADR-005:** `country_lookup` (offline bundled polygons) used for ocean/land detection — no network call during gameplay.
- **ADR-006:** Heritage proximity: linear scan of bundled ~1,200 WHS records per jump. O(n) per jump event is acceptable; no spatial index needed at this scale.
- **ADR-007:** Run data is device-local (Drift only). No Firestore write of run results in this milestone.
- **ADR-008:** Roavvy is a 2D overlay in MVP. True 3D-globe-attached mascot deferred to M160 polish milestone.

---

## Definition of Done

- [ ] `globe_leap/{YYYY-MM-DD}` written by scheduled function at 00:01 UTC
- [ ] Globe API notes documented (lat/lng projection + flyTo confirmed working)
- [ ] Slingshot drag sets bearing + power; aim-arc preview visible on globe in real time
- [ ] On release, Roavvy animates along great-circle arc; globe camera follows
- [ ] Ocean landing → splash animation + game over
- [ ] Revisit → red flash + game over
- [ ] All 5 bonus types calculated; score toast appears on each landing
- [ ] Visited countries glow gold; flight arcs drawn on globe
- [ ] Sound cues for: stretch, release, flight, land, heritage bonus, ocean, revisit
- [ ] Confetti burst on new-country landing (reuse existing confetti system)
- [ ] Game-over results sheet: score, flag list, death reason, share text
- [ ] Already-played today → read-only results on open
- [ ] 30+ engine tests pass; 10+ slingshot tests pass
- [ ] Drift schema v16 migration runs cleanly from v15
- [ ] Zero new `flutter analyze` warnings
- [ ] Entry point wired into Daily tab
- [ ] Docs updated; `index_docs.py` run

---

## Globe API Notes

*(Fill in before T5/T6 implementation — audit `GlobeController` and `GlobeWidget` to confirm: how to project lat/lng → screen Offset, how to drive flyTo, how to draw polyline arcs on the globe surface.)*
