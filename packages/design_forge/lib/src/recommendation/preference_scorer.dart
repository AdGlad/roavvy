import 'dart:math' as math;

import '../recipe/design_recipe.dart';
import 'design_preferences.dart';
import 'shape_preference.dart';
import 'style_cluster.dart';

/// Scores a [DesignRecipe] against [DesignPreferences] → 0..1.
///
/// Uses a geometric-mean approach (same philosophy as mobile's
/// `PreferenceScorer`) so that a single strong mismatch drags the score
/// down more than an arithmetic mean would.
class PreferenceScorer {
  const PreferenceScorer();

  /// Score a recipe against preferences. Returns 0..1 where 0.5 = neutral.
  double score(DesignRecipe recipe, DesignPreferences prefs) {
    final weights = <double>[];

    // 1. Style cluster affinity (from provenance generator tag).
    final cluster = _clusterFromProvenance(recipe.provenance?.generator);
    if (cluster != null) {
      weights.add(prefs.weightFor(cluster));
    }

    // 2. Shape preference affinity.
    final shapeId = recipe.clip?.shapeId;
    if (shapeId != null) {
      final shapePref = shapePreferenceFor(shapeId);
      if (shapePref != null) {
        weights.add(prefs.shapeWeightFor(shapePref));
      }
    } else {
      // No clip → noClip preference.
      weights.add(prefs.shapeWeightFor(ShapePreference.noClip));
    }

    // 3. Garment tone affinity.
    if (prefs.prefersDarkGarment != null && recipe.palette != null) {
      final garment = recipe.palette!.garmentColour;
      if (garment != null) {
        final isDark = _isDarkGarment(garment);
        final match = isDark == prefs.prefersDarkGarment!;
        weights.add(match ? 1.4 : 0.7);
      }
    }

    // 4. Color vibrancy affinity.
    if (prefs.prefersVibrant != null && recipe.palette != null) {
      final isVibrant = recipe.palette!.vintageGrade < 0.3;
      final match = isVibrant == prefs.prefersVibrant!;
      weights.add(match ? 1.3 : 0.75);
    }

    if (weights.isEmpty) return 0.5;

    // Geometric mean → logistic squash to 0..1.
    final logSum = weights.fold<double>(0, (s, w) => s + math.log(w));
    final geoMean = math.exp(logSum / weights.length);
    return geoMean / (geoMean + 1);
  }

  /// Blends a quality score with a preference score.
  ///
  /// [prefBlend] controls how much preference matters (0 = quality only,
  /// 1 = preference only). Default 0.35 leans toward quality.
  double combined(
    double quality,
    double preference, {
    double prefBlend = 0.35,
  }) =>
      quality * (1 - prefBlend) + preference * prefBlend;

  // ── helpers ──

  static StyleCluster? _clusterFromProvenance(String? generator) {
    if (generator == null || !generator.startsWith('lab:')) return null;
    final styleName = generator.substring(4);
    for (final entry in kClusterToLabStyles.entries) {
      if (entry.value.contains(styleName)) return entry.key;
    }
    return null;
  }

  static bool _isDarkGarment(String hex) {
    final clean = hex.replaceFirst('#', '');
    if (clean.length < 6) return false;
    final r = int.parse(clean.substring(0, 2), radix: 16);
    final g = int.parse(clean.substring(2, 4), radix: 16);
    final b = int.parse(clean.substring(4, 6), radix: 16);
    // Relative luminance approximation.
    final lum = 0.299 * r + 0.587 * g + 0.114 * b;
    return lum < 128;
  }
}
