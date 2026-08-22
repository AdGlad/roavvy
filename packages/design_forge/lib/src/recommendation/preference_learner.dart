import 'dart:math' as math;

import '../recipe/design_recipe.dart';
import 'design_preferences.dart';
import 'shape_preference.dart';
import 'style_cluster.dart';

/// Interaction signal types with implicit strength.
enum PreferenceSignal {
  viewed(0.1),
  styleChosen(0.3),
  saved(0.4),
  selectedForMockup(0.6),
  rejected(-0.5);

  const PreferenceSignal(this.delta);
  final double delta;
}

/// Updates [DesignPreferences] based on observed user interactions.
///
/// Port of the mobile `PreferenceLearner` adapted for [DesignRecipe].
class PreferenceLearner {
  const PreferenceLearner({this.learningRate = 0.15});

  final double learningRate;

  /// Returns updated preferences after observing [signal] on [recipe].
  DesignPreferences observe(
    DesignPreferences prefs,
    DesignRecipe recipe,
    PreferenceSignal signal,
  ) {
    final delta = signal.delta;

    // Style cluster update.
    final cluster = _clusterFromRecipe(recipe);
    final newStyleWeights =
        Map<StyleCluster, double>.from(prefs.styleWeights);
    if (cluster != null) {
      final old = prefs.weightFor(cluster);
      newStyleWeights[cluster] = _update(old, delta);
    }

    // Shape preference update.
    final shape = _shapeFromRecipe(recipe);
    final newShapeWeights =
        Map<ShapePreference, double>.from(prefs.shapeWeights);
    if (shape != null) {
      final old = prefs.shapeWeightFor(shape);
      newShapeWeights[shape] = _update(old, delta);
    }

    return prefs.copyWith(
      styleWeights: newStyleWeights,
      shapeWeights: newShapeWeights,
      sampleCount: prefs.sampleCount + 1,
    );
  }

  double _update(double current, double delta) {
    return (current * math.exp(learningRate * delta))
        .clamp(DesignPreferences.kClampMin, DesignPreferences.kClampMax);
  }

  static StyleCluster? _clusterFromRecipe(DesignRecipe r) {
    final gen = r.provenance?.generator;
    if (gen == null || !gen.startsWith('lab:')) return null;
    final styleName = gen.substring(4);
    for (final entry in kClusterToLabStyles.entries) {
      if (entry.value.contains(styleName)) return entry.key;
    }
    return null;
  }

  static ShapePreference? _shapeFromRecipe(DesignRecipe r) {
    final shapeId = r.clip?.shapeId;
    if (shapeId == null) return ShapePreference.noClip;
    return shapePreferenceFor(shapeId);
  }
}
