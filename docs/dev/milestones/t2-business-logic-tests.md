# T2 — Business Logic Tests

**Depends on:** T1 complete (zero test failures, coverage baseline recorded)

## Goal

Achieve 85%+ coverage of all pure business logic. No Flutter framework, no Firebase, no Drift. Every test in this milestone is a plain Dart unit test that runs in milliseconds.

---

## Why This Layer First

Business logic defects are the most expensive — they corrupt data silently. A bug in `printful_placement_mapper.dart` produces a wrong product that a real user receives. A bug in `achievement_repository.dart` awards a badge incorrectly and undermines trust. These functions are also the easiest to test: fixed inputs, fixed expected outputs, no external dependencies.

---

## Approach

Work through each source file in priority order. For each:
1. Read the source file.
2. Identify every public method and every meaningful branch.
3. Write a `group()` block per method, `test()` per branch.
4. Run the new tests: `flutter test test/features/merch/printful_placement_mapper_test.dart`.
5. Verify pass. Add to the next file.

Do not write all tests at once. Complete each file before moving to the next.

---

## Tasks

### T2.1 — Merch: Printful placement mapper (Priority 1 — Critical)

**New file:** `test/features/merch/printful_placement_mapper_test.dart`

Cover:
- Every product type maps to the correct Printful placement ID
- Front/back placement coordinates are within expected bounds
- Invalid product type throws or returns a documented sentinel

---

### T2.2 — Merch: Template ranker (Priority 1 — Critical)

**New file:** `test/features/merch/merch_template_ranker_test.dart`

Cover:
- Solo country → returns correct ranked template list
- Small set (2–5) → grid templates ranked above passport
- Large set (15+) → badge template excluded per ADR-153 rule
- `MerchDensityClass` is correct for boundary country counts (1, 2, 5, 6, 15, 16)
- Excluded templates are correctly marked

---

### T2.3 — Merch: Variant lookup (Priority 1)

**New file:** `test/features/merch/merch_variant_lookup_test.dart`

Cover:
- Known size + colour combination returns the correct Printful variant ID
- Unknown combination returns expected error or null
- All sizes in the product catalogue resolve without error

---

### T2.4 — Merch: Travel identity (Priority 1)

**New file:** `test/features/merch/travel_identity_test.dart`

Cover:
- Empty country set produces empty/default identity
- Single country produces single-country identity
- Multi-continent set produces correct continent list
- Identity components (title, countries, continents) are correct for fixture inputs

---

### T2.5 — Challenge: Guess normaliser (Priority 2 — extend existing)

**Edit:** `test/features/challenge/guess_normalizer_test.dart` (or nearest equivalent)

Add missing branches:
- Unicode diacritics stripped before comparison
- Leading/trailing whitespace ignored
- Case-insensitive match
- Partial match threshold (if applicable)
- Empty string input handled

---

### T2.6 — Challenge: Hot/cold feedback (Priority 2 — extend existing)

**Edit:** `test/features/challenge/hot_cold_feedback_test.dart` (or nearest equivalent)

Add missing branches:
- Distance exactly at each threshold boundary
- Distance just below and just above each boundary
- Correct feedback label for every defined threshold band

---

### T2.7 — Challenge: Daily challenge stats (Priority 2)

**New file:** `test/features/challenge/daily_challenge_stats_test.dart`

Cover:
- Streak increments on consecutive day
- Streak resets after a missed day
- Win rate calculation: 0 wins, partial wins, all wins
- Stats are correct after N-day sequence of win/loss

---

### T2.8 — Data: XP thresholds (Priority 2)

**Edit:** `test/data/xp_repository_test.dart` (extend existing)

Cover:
- Exactly at a level boundary returns the correct level
- One below a boundary returns the previous level
- One above a boundary returns the next level
- XP award amounts are correct for each event type
- Total XP accumulation is additive and deterministic

---

### T2.9 — Data: Achievement qualification (Priority 2 — extend existing)

**Edit:** `test/data/achievement_evaluation_test.dart` or `test/data/achievement_repository_test.dart`

For each achievement in `AchievementEngine.evaluate()`, verify:
- Qualification condition passes at the exact threshold
- Qualification condition fails one unit below the threshold
- Multi-condition achievements require all conditions to be met

---

### T2.10 — Cards: Grid math engine (Priority 3 — extend existing)

**Edit:** existing grid math test

Add missing branches:
- Boundary country counts that trigger layout changes
- Grid stays within expected column/row bounds for all counts 1–200

---

### T2.11 — Cards: Title generation rules (Priority 3 — extend existing)

**Edit:** existing title generation test

Add:
- Single country produces single-country form (not a list)
- Multi-country produces comma or grouped form
- Continent grouping fires at the correct country count
- No title is identical between consecutive calls on different country sets

---

### T2.12 — Map: Globe projection (Priority 3 — extend existing)

**Edit:** existing globe projection test

Add:
- Known lat/lng pairs produce known screen coordinates (regression anchors)
- Antimeridian crossing is handled without infinite or NaN coordinates
- Projection is consistent under 360° longitude rotation

---

### T2.13 — Map: Country visual state (Priority 3)

**New file:** `test/features/map/country_visual_state_test.dart`

Cover:
- Unvisited → no highlight state
- Visited → correct colour/opacity state
- Selected/highlighted → distinct visual state
- State transitions are deterministic given the same input

---

## File Map

```
test/
  features/
    merch/
      printful_placement_mapper_test.dart   NEW
      merch_template_ranker_test.dart       NEW
      merch_variant_lookup_test.dart        NEW
      travel_identity_test.dart             NEW
    challenge/
      guess_normalizer_test.dart            EDIT — extend
      hot_cold_feedback_test.dart           EDIT — extend
      daily_challenge_stats_test.dart       NEW
    map/
      country_visual_state_test.dart        NEW
      globe_projection_test.dart            EDIT — extend
    cards/
      (grid_math, title_generation)         EDIT — extend existing
  data/
    xp_repository_test.dart                 EDIT — extend
    achievement_evaluation_test.dart        EDIT — extend
```

---

## Definition of Done

- [ ] Business logic coverage ≥ 85% (verify with `make coverage`).
- [ ] All 13 task areas have tests added or extended.
- [ ] `flutter test` exits with zero failures after each task area is completed.
- [ ] No test makes a Firebase call, Drift call, or HTTP call.
- [ ] All test descriptions are complete sentences describing expected outcome.
- [ ] No production Firebase, real payment flow, or live Printful endpoint was used.
