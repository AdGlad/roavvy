import 'package:shared_models/shared_models.dart';

/// Supported source labels reported in [TitleGenerationResult].
enum TitleSource { ai, fallback }

/// Input to [TitleGenerationService.generate].
class TitleGenerationRequest {
  const TitleGenerationRequest({
    required this.countryCodes,
    required this.countryNames,
    required this.regionNames,
    this.startYear,
    this.endYear,
    required this.cardType,
    this.heroLabels,
  });

  final List<String> countryCodes; // ISO 3166-1 alpha-2
  final List<String> countryNames; // human-readable, same order
  final List<String> regionNames; // e.g. ["Europe", "Asia"]
  final int? startYear;
  final int? endYear;
  final CardTemplateType cardType;

  /// Hero image labels from M89 analysis, one per trip. Optional — when null
  /// or empty the generator falls back to geography-based titles (ADR-137).
  final List<HeroLabels>? heroLabels;
}

/// Aggregated label summary derived from multiple hero images (M92, ADR-137).
///
/// Each field holds the most-frequently-occurring value across all supplied
/// hero images, weighted by label confidence.
class AggregatedLabels {
  const AggregatedLabels({
    this.primaryScene,
    this.mood,
    this.activity,
  });

  final String? primaryScene;
  final String? mood;
  final String? activity;

  bool get hasAny => primaryScene != null || mood != null || activity != null;
}

/// Reduces a list of per-trip [HeroLabels] into a single [AggregatedLabels]
/// for label-based title lookup (M92, ADR-137).
///
/// Dominant values are chosen by confidence-weighted frequency.
/// Returns null when [labels] is empty or yields no non-null fields.
class HeroLabelAggregator {
  static AggregatedLabels? aggregate(List<HeroLabels> labels) {
    if (labels.isEmpty) return null;

    final sceneCounts = <String, double>{};
    final moodCounts = <String, double>{};
    final actCounts = <String, double>{};

    for (final l in labels) {
      // Weight by confidence + 1 so even zero-confidence labels contribute.
      final w = l.confidence + 1.0;
      if (l.primaryScene != null) {
        sceneCounts[l.primaryScene!] =
            (sceneCounts[l.primaryScene!] ?? 0) + w;
      }
      for (final m in l.mood) {
        moodCounts[m] = (moodCounts[m] ?? 0) + w;
      }
      for (final a in l.activity) {
        actCounts[a] = (actCounts[a] ?? 0) + w;
      }
    }

    String? topKey(Map<String, double> counts) {
      if (counts.isEmpty) return null;
      return counts.entries
          .reduce((a, b) => a.value >= b.value ? a : b)
          .key;
    }

    final agg = AggregatedLabels(
      primaryScene: topKey(sceneCounts),
      mood: topKey(moodCounts),
      activity: topKey(actCounts),
    );
    return agg.hasAny ? agg : null;
  }
}

/// Output of [TitleGenerationService.generate].
class TitleGenerationResult {
  const TitleGenerationResult({
    required this.title,
    required this.source,
  });

  final String title;
  final TitleSource source;
}
