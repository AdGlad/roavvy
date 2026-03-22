# M22 — Phase 11 Slice 1: Visual States + XP Foundation

**Planner:** 2026-03-22
**Branch:** `milestone/m22-visual-states-xp`

---

## Goal

The map visually encodes a user's travel progress. Visited countries look different from unvisited. XP is earned and tracked. New country discovery has a proper emotional moment.

---

## Scope

**Included:**
- `CountryVisualState` enum + `countryVisualStateProvider` (derives state from effective visits + recency)
- `CountryPolygonLayer` widget — replaces the current bare `PolygonLayer` call in `MapScreen`; applies fill/border/opacity per visual state; performance-split by static vs animated groups
- `recentDiscoveriesProvider` — ISO codes discovered in the last 24h, persisted to SharedPreferences
- `XpEvent` domain model + `xp_events` Drift table (schema v10) + `XpRepository`
- `XpNotifier` (StateNotifier) — total XP, current level (8 thresholds), progress-to-next-level fraction
- `XpLevelBar` widget — top strip on `MapScreen`; level badge, label, linear progress bar; "+N XP" flash animation on earn
- `DiscoveryOverlay` — full-screen route pushed post-scan when new countries are found; country name, flag emoji, XP earned, "Explore your map" CTA; `HeavyImpact` haptic
- XP award wired at four write sites: new country (+50 XP), region completed (+150 XP), scan completed (+25 XP), share (+30 XP)

**Excluded:**
- Region progress chips (M23)
- Rovy mascot (M23)
- Social ranking (later)
- Discovery overlay animation polish (later)
- Firestore sync for XP events (later)

---

## Tasks

### Task 81 — `CountryVisualState` + providers

**Deliverable:**
- `lib/features/map/country_visual_state.dart` — `CountryVisualState` enum with 5 values: `unvisited`, `visited`, `reviewed`, `newlyDiscovered`, `target`
- `countryVisualStateProvider(String isoCode)` — family provider that derives state for a given ISO code from `effectiveVisitsProvider` + `recentDiscoveriesProvider`
- `recentDiscoveriesProvider` — `StateNotifierProvider<RecentDiscoveriesNotifier, Set<String>>` backed by SharedPreferences key `recent_discoveries_v1` (JSON list of `{isoCode, discoveredAt}` objects); filters out entries older than 24h on load; exposes `add(String isoCode)` and `clear()` methods

**Acceptance criteria:**
- An ISO code present in `effectiveVisitsProvider` AND in `recentDiscoveriesProvider` → `newlyDiscovered`
- An ISO code present in `effectiveVisitsProvider` AND `firstSeen == lastSeen` (single trip, reviewed) → `reviewed` (lower priority than `newlyDiscovered`)
- An ISO code present in `effectiveVisitsProvider` → `visited`
- All other codes → `unvisited`
- `recentDiscoveriesProvider` loads from SharedPreferences on first access; entries older than 24h are silently dropped
- `recentDiscoveriesProvider.add()` persists immediately to SharedPreferences
- Unit tests: `countryVisualStateProvider` state derivation for all 5 state transitions; `RecentDiscoveriesNotifier` load + expiry filtering

**Dependencies:** SharedPreferences already in pubspec. No new packages needed.

---

### Task 82 — `CountryPolygonLayer`

**Deliverable:**
- `lib/features/map/country_polygon_layer.dart` — `CountryPolygonLayer` ConsumerWidget
- Replaces the existing `PolygonLayer` call inside `MapScreen`
- Splits polygons into two `PolygonLayer` instances:
  1. **Static group** (`unvisited`, `visited`, `reviewed`) — rebuilt only when `effectiveVisitsProvider` changes
  2. **Animated group** (`newlyDiscovered`) — rebuilt on each animation tick; amber pulse (opacity 0.55–0.85, 1200ms `AnimationController` with `Curves.easeInOut`, repeating)
- Colour spec:
  - `unvisited`: fill `Colors.grey.shade200`, border `Colors.grey.shade400`, opacity 0.6
  - `visited`: fill `Color(0xFFFFB300)` (amber 700), border `Color(0xFFFF8F00)` (amber 900), opacity 0.75
  - `reviewed`: fill `Color(0xFFFFCA28)` (amber 400), border `Color(0xFFFFB300)` (amber 700), opacity 0.75
  - `newlyDiscovered`: fill `Color(0xFFFFD54F)` (amber 300), border `Color(0xFFFFCA28)` (amber 400), animated opacity
  - `target`: deferred to M23; render same as `visited` for now

**Acceptance criteria:**
- `MapScreen` no longer calls `PolygonLayer` directly — all polygon rendering delegated to `CountryPolygonLayer`
- `MapScreen._init()`, `_mapPolygons`, and the `_loading` flag driven by polygon init are removed; `_visitedByCode` is computed from `ref.watch(effectiveVisitsProvider)` in `build()` (ADR-066)
- All existing tests still pass (`flutter test`)
- `flutter analyze` zero issues
- Animated amber pulse is visible on newly-discovered countries
- Widget test: correct colour applied per visual state

**Dependencies:** Task 81.

---

### Task 83 — XP engine (`XpEvent`, `XpRepository`, `XpNotifier`)

**Deliverable:**
- `lib/features/xp/xp_event.dart` — `XpEvent` domain model: `id` (UUID), `reason` (enum: `newCountry`, `regionCompleted`, `scanCompleted`, `share`), `amount` (int), `awardedAt` (DateTime UTC)
- `lib/data/db/roavvy_database.dart` — `XpEvents` Drift table added; schema bumped to v10; migration from v9 adds the `xp_events` table
- `lib/data/xp_repository.dart` — `XpRepository`: `award(XpEvent)`, `loadAll()`, `totalXp()`, `clearAll()`
- `lib/features/xp/xp_notifier.dart` — `XpNotifier extends StateNotifier<XpState>`:
  - `XpState`: `{ totalXp: int, level: int, levelLabel: String, progressFraction: double, xpToNextLevel: int }`
  - 8 level thresholds: L1=0, L2=100, L3=250, L4=500, L5=1000, L6=2000, L7=4000, L8=8000 XP
  - Level labels: Explorer, Adventurer, Globetrotter, Wanderer, Pathfinder, Voyager, Pioneer, Legend
  - `award(XpEvent event)` — inserts via `XpRepository.award()`, recomputes state, emits on a `Stream<int> xpEarned` stream
- Providers in `lib/core/providers.dart`: `xpRepositoryProvider`, `xpNotifierProvider`

**Acceptance criteria:**
- `XpRepository.award()` writes to Drift `xp_events` table
- `XpNotifier` correctly computes level and progress fraction for all 8 thresholds
- `XpNotifier.award()` is safe to call with `unawaited()` — if it throws, caller is unaffected
- Schema v9 → v10 migration runs without data loss
- Unit tests: level computation at every threshold boundary; `XpRepository` insert + `totalXp()`

**Dependencies:** None (parallel with Tasks 81/82).

---

### Task 84 — `XpLevelBar` + XP award wiring

**Deliverable:**
- `lib/features/map/xp_level_bar.dart` — `XpLevelBar` ConsumerWidget:
  - Top strip on `MapScreen` (below safe area, above map)
  - Shows: circular amber level badge, level label, `LinearProgressIndicator` (amber), next-level label at right
  - On `xpNotifier.xpEarned` stream: flashes "+N XP" text for 1500ms via `AnimatedOpacity`
  - Height 44pt
- `MapScreen` updated to include `XpLevelBar` at the top of its `Stack`
- XP award calls wired with `unawaited()` at:
  1. `ReviewScreen._save()` — new country delta > 0: `+50 XP per new country`
  2. `ReviewScreen._save()` — after a region completion check: `+150 XP per completed region`
  3. Scan completion path: `+25 XP`
  4. `TravelCardWidget` share action: `+30 XP`

**Acceptance criteria:**
- `XpLevelBar` renders at top of map without overlapping controls
- "+N XP" flash appears after scan that adds new countries
- All four award sites call `xpNotifierProvider.notifier.award(...)` with `unawaited()`
- `flutter analyze` zero issues; all existing tests pass

**Dependencies:** Task 83.

---

### Task 85 — `DiscoveryOverlay`

**Deliverable:**
- `lib/features/map/discovery_overlay.dart` — `DiscoveryOverlay` StatelessWidget:
  - Full-screen `Scaffold` with amber gradient background
  - Shows: flag emoji (font size 64), country name, "You discovered [Country]!" headline, XP earned "+50 XP", `FilledButton` "Explore your map"
  - On build: `HapticFeedback.heavyImpact()`
  - Route name: `'/discovery'`
  - "Explore your map" CTA calls `Navigator.of(context).popUntil(ModalRoute.withName('/'))` — clears full scan stack (ADR-068)
- Wired into `ScanSummaryScreen._handleDone()` (ADR-068):
  - `ScanSummaryScreen` receives `List<String> newCodes` parameter (the newly discovered ISO codes)
  - If `newCodes.isNotEmpty`: push `DiscoveryOverlay` for `newCodes.first` (sorted alphabetically for determinism)
  - `recentDiscoveriesProvider.add(isoCode)` called for **all** codes in `newCodes` (not just the displayed one) so all get the amber pulse

**Acceptance criteria:**
- Overlay is pushed from `ScanSummaryScreen._handleDone()` after a scan with at least one new country
- Haptic fires on screen appear
- "Explore your map" CTA uses `popUntil('/')` and lands on Map tab
- `recentDiscoveriesProvider` contains all new ISO codes after the overlay appears
- `CountryPolygonLayer` renders newly discovered countries with amber pulse after return to map
- Widget tests: overlay renders correctly; CTA triggers `popUntil`; haptic called
- `flutter analyze` zero issues; all tests pass

**Dependencies:** Tasks 81, 82, 84.

---

## Build Order

```
Task 81 (no deps)  ─┬─► Task 82 ─────────────────────────────┐
                    │                                          ▼
Task 83 (no deps)  ─┴─► Task 84 ──────────────────────► Task 85
```

Implement in order: 81 → 83 → 82 → 84 → 85.

---

## Risks

1. **Polygon animation performance** — split static/animated `PolygonLayer` groups. Profile on device with 50+ countries before shipping Task 82.
2. **SharedPreferences expiry filtering** — load + filter on first access; do not block the UI thread.
3. **XP write sites must not break scan** — `unawaited()` + catch-and-swallow at every XP call site.
4. **Schema v9 → v10 migration** — test migration path before shipping Task 83.
5. **`DiscoveryOverlay` stacking** — push only one overlay per scan even if multiple countries discovered.
