import 'package:shared_models/shared_models.dart';

import '../../../core/country_names.dart';
import 'title_generation_models.dart';
import 'title_generation_service.dart';

/// Sub-regional country clusters — checked before continent fallback.
const _kSubRegions = <String, Set<String>>{
  'Nordic Escape': {'NO', 'SE', 'FI', 'IS', 'DK'},
  'Mediterranean Escape': {'GR', 'CY', 'MT'},
  'East Asia': {'JP', 'KR', 'CN', 'TW'},
  'Southern Europe': {'IT', 'ES', 'PT', 'FR'},
};

const _kContinentTitles = <String, String>{
  'Europe': 'Euro Tour',
  'Asia': 'Asian Adventure',
  'North America': 'Americas',
  'South America': 'South America',
  'Africa': 'African Journey',
  'Oceania': 'Pacific Escape',
};

/// Deterministic rule-based title generator used as fallback when on-device AI
/// is unavailable (ADR-124).
class RuleBasedTitleGenerator implements TitleGenerationService {
  @override
  Future<TitleGenerationResult> generate(TitleGenerationRequest request) async {
    final title = _compute(request);
    return TitleGenerationResult(title: title, source: TitleSource.fallback);
  }

  String _compute(TitleGenerationRequest request) {
    final codes = request.countryCodes;
    if (codes.isEmpty) return 'My Travels';

    final yearSuffix = _yearSuffix(request.startYear, request.endYear);

    // 1. Single country
    if (codes.length == 1) {
      final name = kCountryNames[codes.first] ?? codes.first;
      return yearSuffix.isEmpty ? name : '$name $yearSuffix';
    }

    final codeSet = codes.toSet();

    // 2. Sub-regional override — all codes must be a subset of the cluster
    for (final entry in _kSubRegions.entries) {
      if (codeSet.isNotEmpty && codeSet.every(entry.value.contains)) {
        final base = entry.key;
        return yearSuffix.isEmpty ? base : '$base $yearSuffix';
      }
    }

    // 3. Dominant continent
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
      final base = _kContinentTitles[dominant] ?? dominant;
      return yearSuffix.isEmpty ? base : '$base $yearSuffix';
    }

    // Safe default
    return yearSuffix.isEmpty ? 'My Travels' : 'My Travels $yearSuffix';
  }

  String _yearSuffix(int? startYear, int? endYear) {
    if (startYear == null) return '';
    if (endYear == null || endYear == startYear) return '$startYear';
    return '$startYear\u2013$endYear'; // en dash
  }
}
