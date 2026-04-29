# M92 — Label-Powered Auto Titles

**Branch:** `milestone/m92-label-powered-titles`
**Phase:** 19 — Personalisation & Memory
**Depends on:** M89 (HeroLabels stored per trip)
**Status:** Not started

---

## 1. Milestone Goal

Enrich the existing rule-based title generator with scene and mood labels from the hero image system so card titles are more vivid and specific than geography alone allows.

Currently `"Greece 2024"` or `"Mediterranean Escape"`. After M92: `"Aegean Sunset"`, `"Alpine Snowfields"`, `"Desert Gold"`, `"Jungle and Coast"`.

---

## 2. Product Value

Title generation is one of the most-touched interactions in the card editor (shuffle button). Labels unlock a new dimension: the *feeling* of a trip, not just its geography. This directly enriches share cards, Memory Pulse copy, and travel journal headers.

---

## 3. Scope

**In:**
- `lib/features/cards/title_generation/rule_based_title_generator.dart`
- `lib/features/cards/title_generation/title_generation_models.dart` (extend `TitleRequest`)
- `lib/features/cards/title_generation/title_generation_service.dart`
- `lib/features/cards/card_editor_screen.dart` (pass hero labels into title generation)

**Out:** AI title plugin changes, web title generation, Memory Pulse copy (M91 owns its own copy system), new card templates.

---

## 4. Label → Title Mapping

### Priority order

Title selection follows this priority chain:
1. **Label combo match** (scene + mood or scene + activity): most specific, highest quality
2. **Label solo match** (scene only, or mood only): good fallback
3. **Sub-region match** (existing `_kSubRegions`): geography cluster
4. **Continent match** (existing `_kContinentTitles`): broadest fallback
5. **Single country** (existing logic)

### Label combo title table

```dart
// (primaryScene, mood) → titles
const _kSceneMoodTitles = <(String, String), List<String>>{
  ('beach',      'sunset')      : ['Aegean Sunset', 'Shore at Dusk', 'Golden Coastline'],
  ('beach',      'golden_hour') : ['Golden Shore', 'Coast at Golden Hour', 'Warm Tides'],
  ('beach',      'sunrise')     : ['Dawn on the Shore', 'Morning Tide', 'First Light Coast'],
  ('mountain',   'snow')        : ['Alpine Snowfields', 'Peak Season', 'White Summits'],
  ('mountain',   'sunrise')     : ['Mountain Dawn', 'Summit Light', 'Above the Clouds'],
  ('mountain',   'golden_hour') : ['Alpine Gold', 'Mountain at Dusk', 'Peaks at Sunset'],
  ('city',       'night')       : ['City After Dark', 'Neon Nights', 'Night in the City'],
  ('city',       'golden_hour') : ['Golden Streets', 'City at Dusk', 'Urban Gold'],
  ('desert',     'sunset')      : ['Desert Gold', 'Sand at Dusk', 'Sahara Sunset'],
  ('desert',     'golden_hour') : ['Dunes at Golden Hour', 'Desert Glow', 'Sand and Light'],
  ('forest',     'sunrise')     : ['Forest Dawn', 'Morning in the Trees', 'First Light Forest'],
  ('snow',       'sunrise')     : ['Frozen Dawn', 'Winter Light', 'Snow at Sunrise'],
  ('island',     'sunset')      : ['Island Sunset', 'Tropical Dusk', 'Offshore Gold'],
  ('island',     'golden_hour') : ['Golden Island', 'Island at Dusk', 'Tropical Gold'],
  ('lake',       'sunrise')     : ['Still Water Dawn', 'Lake at Sunrise', 'Morning Reflections'],
  ('coast',      'golden_hour') : ['Golden Cliffs', 'Coastal Glow', 'Light on the Coast'],
};

// (primaryScene, activity) → titles
const _kSceneActivityTitles = <(String, String), List<String>>{
  ('mountain',  'hiking')  : ['Trail Blazer', 'Into the Mountains', 'High Country'],
  ('mountain',  'skiing')  : ['Powder Days', 'Off Piste', 'White Run'],
  ('coast',     'boat')    : ['Under Sail', 'Blue Water Run', 'Open Horizon'],
  ('beach',     'boat')    : ['Island Hopping', 'Sailing the Coast', 'Blue Lagoon'],
  ('city',      'food')    : ['Food and City', 'Urban Feast', 'City Bites'],
  ('forest',    'hiking')  : ['Deep Woods', 'Through the Trees', 'Green Trail'],
  ('island',    'boat')    : ['Island to Island', 'Archipelago Run', 'Between the Islands'],
  ('countryside','roadtrip'): ['Open Road', 'Rolling Hills', 'Country Miles'],
  ('desert',    'roadtrip'): ['Desert Drive', 'Dust Road', 'Endless Miles'],
};

// primaryScene solo fallback
const _kSceneTitles = <String, List<String>>{
  'beach'       : ['Shoreline', 'Sandy Days', 'Coast Life'],
  'city'        : ['Urban Escape', 'City Break', 'Streets and Stories'],
  'mountain'    : ['High Country', 'Mountain Air', 'Above It All'],
  'island'      : ['Island Escape', 'Island Life', 'Off the Map'],
  'coast'       : ['Clifftop Views', 'Coastal Drive', 'Edge of Land'],
  'desert'      : ['Dust and Gold', 'Arid Days', 'Desert Crossing'],
  'forest'      : ['Into the Trees', 'Green Escape', 'Forest Road'],
  'snow'        : ['Winter Escape', 'Cold and Clear', 'Snow Days'],
  'lake'        : ['Still Waters', 'Lakeside', 'By the Lake'],
  'countryside' : ['Rolling Hills', 'Rural Escape', 'Field and Sky'],
};

// mood solo fallback
const _kMoodTitles = <String, List<String>>{
  'sunset'      : ['Golden Hour', 'Last Light', 'Chasing Sunsets'],
  'sunrise'     : ['Early Light', 'Dawn Patrol', 'First Light'],
  'golden_hour' : ['Golden Hour', 'Warm Light', 'The Golden Hour'],
  'night'       : ['After Dark', 'Night Moves', 'Midnight Run'],
};
```

### Multi-trip / multi-country label aggregation

When a card spans multiple trips or countries, aggregate labels before lookup:

1. Collect all `primaryScene` values from heroes across the selected trips
2. If all trips share the same `primaryScene` → use it
3. If mixed scenes → use the most frequent; tie-break by highest `heroScore`
4. Same logic for `mood`

---

## 5. Integration with Card Editor

The title generation call already receives `List<String> countryCodes` and `List<TripRecord> trips`. M92 adds an optional `List<HeroLabels>? heroLabels` parameter.

```dart
// card_editor_screen.dart — _generateTitle
final heroLabels = await _fetchHeroLabelsForTrips(effectiveTrips);
final title = await TitleGenerationService.generate(
  codes: effectiveCodes,
  trips: effectiveTrips,
  heroLabels: heroLabels,    // NEW
  seed: _titleSeed,
);
```

`_fetchHeroLabelsForTrips` reads from `heroForTripProvider` synchronously if already loaded, returns `null` if no hero data available. The generator degrades gracefully to geography-based titles when `heroLabels` is null or empty — no breaking change.

---

## 6. Implementation Tasks

### T1 — Extend `TitleRequest` / `TitleGenerationService`
**File:** `lib/features/cards/title_generation/title_generation_models.dart`
**Deliverable:** Add optional `List<HeroLabels>? heroLabels` to `TitleRequest`. Add label aggregation helper: `HeroLabelAggregator.aggregate(List<HeroLabels>) → AggregatedLabels(primaryScene, mood, activity)`.
**Acceptance:** Unit tests: aggregation with uniform labels, mixed labels (most-frequent wins), empty list returns null fields.

---

### T2 — Label title tables + selection logic
**File:** `lib/features/cards/title_generation/rule_based_title_generator.dart`
**Deliverable:** Add `_kSceneMoodTitles`, `_kSceneActivityTitles`, `_kSceneTitles`, `_kMoodTitles` tables. Add `_labelTitle(AggregatedLabels, Random) → String?` method that applies priority chain from Section 4. Insert label lookup as the first step in `generate()` before sub-region check.
**Acceptance:** Unit tests for each combo table entry. Test that label lookup fires before sub-region. Test graceful fallback to sub-region when no label match. Existing title tests unchanged (no regression).

---

### T3 — Card editor: fetch labels before title generation
**File:** `lib/features/cards/card_editor_screen.dart`
**Deliverable:** `_fetchHeroLabelsForTrips(List<TripRecord> trips) → Future<List<HeroLabels>?>`. Reads from `heroForTripProvider` for each trip. Returns null if Riverpod cache is empty (not yet analysed). Passes result into `TitleGenerationService.generate`.
**Acceptance:** Title generation still works when heroLabels is null. Title is richer when labels are available. Shuffle button produces different label-aware title on each press (seed varies).

---

## 7. Build Order

```
T1  TitleRequest + aggregator   (foundation)
T2  Label tables + selection    (depends on T1)
T3  Card editor integration     (depends on T2, M89 providers)
```

---

## 8. ADR

**ADR-137 — M92 Hero Label Injection into Title Generator**

`HeroLabels` from M89 are optionally fed into `RuleBasedTitleGenerator` as a new `heroLabels` parameter. Label-based title lookup runs before geography-based lookup (sub-region, continent). When labels are unavailable (no hero data yet) the generator falls back to existing geography logic — no breaking change. Multi-trip label aggregation uses most-frequent `primaryScene` and `mood`, with `heroScore` as tie-breaker. Label title tables are hardcoded in the generator; no dynamic data or network call involved.
