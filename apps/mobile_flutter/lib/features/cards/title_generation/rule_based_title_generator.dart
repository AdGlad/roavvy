import 'dart:math';

import 'package:shared_models/shared_models.dart';

import '../../../core/country_names.dart';
import 'title_generation_models.dart';
import 'title_generation_service.dart';

// ── Label-based title tables (M92, ADR-137) ────────────────────────────────

/// (primaryScene, mood) → title options.
///
/// Checked first; most specific path through the label priority chain.
const _kSceneMoodTitles = <(String, String), List<String>>{
  ('beach', 'sunset'): ['Aegean Sunset', 'Shore at Dusk', 'Golden Coastline'],
  ('beach', 'golden_hour'): ['Golden Shore', 'Coast at Golden Hour', 'Warm Tides'],
  ('beach', 'sunrise'): ['Dawn on the Shore', 'Morning Tide', 'First Light Coast'],
  ('mountain', 'snow'): ['Alpine Snowfields', 'Peak Season', 'White Summits'],
  ('mountain', 'sunrise'): ['Mountain Dawn', 'Summit Light', 'Above the Clouds'],
  ('mountain', 'golden_hour'): ['Alpine Gold', 'Mountain at Dusk', 'Peaks at Sunset'],
  ('city', 'night'): ['City After Dark', 'Neon Nights', 'Night in the City'],
  ('city', 'golden_hour'): ['Golden Streets', 'City at Dusk', 'Urban Gold'],
  ('desert', 'sunset'): ['Desert Gold', 'Sand at Dusk', 'Sahara Sunset'],
  ('desert', 'golden_hour'): ['Dunes at Golden Hour', 'Desert Glow', 'Sand and Light'],
  ('forest', 'sunrise'): ['Forest Dawn', 'Morning in the Trees', 'First Light Forest'],
  ('snow', 'sunrise'): ['Frozen Dawn', 'Winter Light', 'Snow at Sunrise'],
  ('island', 'sunset'): ['Island Sunset', 'Tropical Dusk', 'Offshore Gold'],
  ('island', 'golden_hour'): ['Golden Island', 'Island at Dusk', 'Tropical Gold'],
  ('lake', 'sunrise'): ['Still Water Dawn', 'Lake at Sunrise', 'Morning Reflections'],
  ('coast', 'golden_hour'): ['Golden Cliffs', 'Coastal Glow', 'Light on the Coast'],
};

/// (primaryScene, activity) → title options.
const _kSceneActivityTitles = <(String, String), List<String>>{
  ('mountain', 'hiking'): ['Trail Blazer', 'Into the Mountains', 'High Country'],
  ('mountain', 'skiing'): ['Powder Days', 'Off Piste', 'White Run'],
  ('coast', 'boat'): ['Under Sail', 'Blue Water Run', 'Open Horizon'],
  ('beach', 'boat'): ['Island Hopping', 'Sailing the Coast', 'Blue Lagoon'],
  ('city', 'food'): ['Food and City', 'Urban Feast', 'City Bites'],
  ('forest', 'hiking'): ['Deep Woods', 'Through the Trees', 'Green Trail'],
  ('island', 'boat'): ['Island to Island', 'Archipelago Run', 'Between the Islands'],
  ('countryside', 'roadtrip'): ['Open Road', 'Rolling Hills', 'Country Miles'],
  ('desert', 'roadtrip'): ['Desert Drive', 'Dust Road', 'Endless Miles'],
};

/// primaryScene solo fallback when no mood/activity combo matches.
const _kSceneTitles = <String, List<String>>{
  'beach': ['Shoreline', 'Sandy Days', 'Coast Life'],
  'city': ['Urban Escape', 'City Break', 'Streets and Stories'],
  'mountain': ['High Country', 'Mountain Air', 'Above It All'],
  'island': ['Island Escape', 'Island Life', 'Off the Map'],
  'coast': ['Clifftop Views', 'Coastal Drive', 'Edge of Land'],
  'desert': ['Dust and Gold', 'Arid Days', 'Desert Crossing'],
  'forest': ['Into the Trees', 'Green Escape', 'Forest Road'],
  'snow': ['Winter Escape', 'Cold and Clear', 'Snow Days'],
  'lake': ['Still Waters', 'Lakeside', 'By the Lake'],
  'countryside': ['Rolling Hills', 'Rural Escape', 'Field and Sky'],
};

/// mood solo fallback when no scene is present.
const _kMoodTitles = <String, List<String>>{
  'sunset': ['Golden Hour', 'Last Light', 'Chasing Sunsets'],
  'sunrise': ['Early Light', 'Dawn Patrol', 'First Light'],
  'golden_hour': ['Golden Hour', 'Warm Light', 'The Golden Hour'],
  'night': ['After Dark', 'Night Moves', 'Midnight Run'],
};

// ── Sub-regional country clusters — checked before continent fallback. ─────
///
/// Each cluster maps a set of country codes to a list of title options.
/// A random option is chosen on each call so the title varies when the
/// user taps Shuffle or changes the date range (ADR-125).
///
/// The rule: *all* codes in the user's set must be a subset of the cluster
/// for the cluster to fire. Order matters — more specific clusters first.
const _kSubRegions = <List<String>, Set<String>>{
  // Northern Europe
  ['Nordic Wander', 'Northern Lights', 'Fjord Life']: {'NO', 'SE', 'FI', 'IS', 'DK'},
  ['Baltic Loop', 'Baltic Run', 'Coast to Coast']: {'EE', 'LV', 'LT'},
  ['British Isles', 'Island Hopping', 'Tea and Moors']: {'GB', 'IE'},
  // Western / Southern Europe
  ['Iberian Road', 'Sun and Tapas', 'Atlantic Drive']: {'ES', 'PT'},
  ['Alpine Escape', 'Peak Season', 'Above the Clouds']: {'CH', 'AT', 'LI'},
  ['Benelux', 'Low Country High', 'Canal Circuit']: {'BE', 'NL', 'LU'},
  ['Mediterranean Escape', 'Blue Water Run', 'Island Life']: {'GR', 'CY', 'MT'},
  ['Southern Europe', 'Sun Chaser', 'Olive Trail']: {'IT', 'ES', 'PT', 'FR', 'MT'},
  ['Balkan Trail', 'Balkan Road', 'Old Town Circuit']: {'HR', 'BA', 'ME', 'RS', 'MK', 'AL', 'SI'},
  // Asia
  ['East Asia', 'Far East Fix', 'Neon and Temples']: {'JP', 'KR', 'CN', 'TW'},
  ['Southeast Asia', 'Spice Route', 'Island Hopper']: {
    'TH', 'VN', 'KH', 'LA', 'MM', 'SG', 'MY', 'ID', 'PH'
  },
  ['Indian Subcontinent', 'Monsoon Run', 'Spice and Spirit']: {'IN', 'LK', 'NP', 'BD', 'BT'},
  // Oceans
  ['Indian Ocean', 'Turquoise Run', 'Island Escape']: {'MV', 'SC', 'MU', 'RE', 'YT'},
  ['Pacific Islands', 'Island Life', 'Blue Horizon']: {
    'FJ', 'WS', 'TO', 'VU', 'PG', 'SB', 'CK', 'NU'
  },
  // Americas
  ['Central America', 'Jungle Run', 'Pacific Swing']: {
    'MX', 'GT', 'BZ', 'HN', 'SV', 'NI', 'CR', 'PA'
  },
  ['Caribbean Hop', 'Island Circuit', 'Rum and Sun']: {
    'CU', 'JM', 'HT', 'DO', 'TT', 'BB', 'LC', 'VC', 'GD', 'AG', 'DM', 'KN'
  },
};

const _kContinentTitles = <String, List<String>>{
  'Europe': ['Euro Wander', 'Old World Run', 'Across Europe'],
  'Asia': ['Asian Escape', 'East of Everything', 'Far East Road'],
  'North America': ['American Road', 'Wide Open West', 'Cross Country'],
  'South America': ['South American Journey', 'Down South', 'Jungle and Coast'],
  'Africa': ['African Adventure', 'Safari Bound', 'Across Africa'],
  'Oceania': ['Pacific Escape', 'Down Under', 'Island Bound'],
};

/// Randomised rule-based title generator used as fallback when on-device AI
/// is unavailable (ADR-124 / ADR-125).
///
/// Titles vary on each call via [Random] so tapping Shuffle or changing
/// the date range always produces a fresh suggestion.
class RuleBasedTitleGenerator implements TitleGenerationService {
  RuleBasedTitleGenerator({Random? random}) : _random = random ?? Random();

  final Random _random;

  String _pick(List<String> options) => options[_random.nextInt(options.length)];

  /// Resolves a label-based title from [aggregated] using the priority chain:
  /// scene+mood combo → scene+activity combo → scene solo → mood solo.
  /// Returns null when no table entry matches.
  String? _labelTitle(AggregatedLabels aggregated) {
    final scene = aggregated.primaryScene;
    final mood = aggregated.mood;
    final activity = aggregated.activity;

    // 1. scene + mood combo
    if (scene != null && mood != null) {
      final titles = _kSceneMoodTitles[(scene, mood)];
      if (titles != null) return _pick(titles);
    }

    // 2. scene + activity combo
    if (scene != null && activity != null) {
      final titles = _kSceneActivityTitles[(scene, activity)];
      if (titles != null) return _pick(titles);
    }

    // 3. scene solo
    if (scene != null) {
      final titles = _kSceneTitles[scene];
      if (titles != null) return _pick(titles);
    }

    // 4. mood solo
    if (mood != null) {
      final titles = _kMoodTitles[mood];
      if (titles != null) return _pick(titles);
    }

    return null;
  }

  @override
  Future<TitleGenerationResult> generate(TitleGenerationRequest request) async {
    final title = _compute(request);
    return TitleGenerationResult(title: title, source: TitleSource.fallback);
  }

  String _compute(TitleGenerationRequest request) {
    final codes = request.countryCodes;
    if (codes.isEmpty) return _pick(['World Tour', 'Everywhere', 'Global Wander']);

    // 1. Label-based title — runs before geography (ADR-137).
    if (request.heroLabels != null) {
      final aggregated = HeroLabelAggregator.aggregate(request.heroLabels!);
      if (aggregated != null) {
        final labelTitle = _labelTitle(aggregated);
        if (labelTitle != null) return labelTitle;
      }
    }

    // 2. Single country — return its name directly.
    if (codes.length == 1) {
      return kCountryNames[codes.first] ?? codes.first;
    }

    final codeSet = codes.toSet();

    // 3. Sub-regional override — all codes must be a subset of the cluster.
    for (final entry in _kSubRegions.entries) {
      if (codeSet.isNotEmpty && codeSet.every(entry.value.contains)) {
        return _pick(entry.key);
      }
    }

    // 4. Dominant continent.
    final continentCounts = <String, int>{};
    for (final code in codes) {
      final continent = kCountryContinent[code];
      if (continent != null) {
        continentCounts[continent] = (continentCounts[continent] ?? 0) + 1;
      }
    }

    if (continentCounts.isNotEmpty) {
      final dominant = continentCounts.entries
          .reduce((a, b) => a.value >= b.value ? a : b)
          .key;
      final options = _kContinentTitles[dominant];
      if (options != null) return _pick(options);
      return dominant;
    }

    // Safe default — also randomised.
    return _pick(['World Tour', 'Everywhere', 'Global Wander']);
  }
}
