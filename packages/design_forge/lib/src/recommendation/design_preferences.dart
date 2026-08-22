import 'dart:convert';

import 'style_cluster.dart';
import 'shape_preference.dart';

/// User taste profile used to weight recipe generation and scoring.
///
/// All weight maps use multiplicative values around 1.0 (neutral).
/// Values > 1.0 mean the user prefers that axis; < 1.0 means they
/// dis-prefer it. Clamped to [kClampMin..kClampMax].
class DesignPreferences {
  const DesignPreferences({
    this.styleWeights = const {},
    this.shapeWeights = const {},
    this.prefersDarkGarment,
    this.prefersVibrant,
    this.sampleCount = 0,
    this.explorationRate = 0.35,
  });

  /// Multiplicative weight per style cluster (default 1.0 = neutral).
  final Map<StyleCluster, double> styleWeights;

  /// Multiplicative weight per shape preference (default 1.0 = neutral).
  final Map<ShapePreference, double> shapeWeights;

  /// `true` → dark garments preferred, `false` → light, `null` → no pref.
  final bool? prefersDarkGarment;

  /// `true` → vibrant/saturated, `false` → muted/vintage, `null` → no pref.
  final bool? prefersVibrant;

  /// How many interaction signals have been observed (for decay/confidence).
  final int sampleCount;

  /// Fraction of the pool reserved for exploration (styles the user hasn't
  /// explicitly preferred). Floor is 0.15; ceiling is 0.60.
  final double explorationRate;

  static const double kClampMin = 0.15;
  static const double kClampMax = 6.0;
  static const neutral = DesignPreferences();

  /// Effective weight for a style cluster (defaults to 1.0).
  double weightFor(StyleCluster c) => styleWeights[c] ?? 1.0;

  /// Effective weight for a shape preference (defaults to 1.0).
  double shapeWeightFor(ShapePreference s) => shapeWeights[s] ?? 1.0;

  /// Returns a copy with the given fields replaced.
  DesignPreferences copyWith({
    Map<StyleCluster, double>? styleWeights,
    Map<ShapePreference, double>? shapeWeights,
    bool? Function()? prefersDarkGarment,
    bool? Function()? prefersVibrant,
    int? sampleCount,
    double? explorationRate,
  }) =>
      DesignPreferences(
        styleWeights: styleWeights ?? this.styleWeights,
        shapeWeights: shapeWeights ?? this.shapeWeights,
        prefersDarkGarment: prefersDarkGarment != null
            ? prefersDarkGarment()
            : this.prefersDarkGarment,
        prefersVibrant:
            prefersVibrant != null ? prefersVibrant() : this.prefersVibrant,
        sampleCount: sampleCount ?? this.sampleCount,
        explorationRate: explorationRate ?? this.explorationRate,
      );

  // ── JSON serialisation ──────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'styleWeights': {
          for (final e in styleWeights.entries) e.key.name: e.value,
        },
        'shapeWeights': {
          for (final e in shapeWeights.entries) e.key.name: e.value,
        },
        if (prefersDarkGarment != null)
          'prefersDarkGarment': prefersDarkGarment,
        if (prefersVibrant != null) 'prefersVibrant': prefersVibrant,
        'sampleCount': sampleCount,
        'explorationRate': explorationRate,
      };

  factory DesignPreferences.fromJson(Map<String, dynamic> j) {
    final styleMap = <StyleCluster, double>{};
    final rawStyle = j['styleWeights'] as Map<String, dynamic>? ?? {};
    for (final e in rawStyle.entries) {
      final c = StyleCluster.values.where((v) => v.name == e.key).firstOrNull;
      if (c != null) styleMap[c] = (e.value as num).toDouble();
    }

    final shapeMap = <ShapePreference, double>{};
    final rawShape = j['shapeWeights'] as Map<String, dynamic>? ?? {};
    for (final e in rawShape.entries) {
      final s =
          ShapePreference.values.where((v) => v.name == e.key).firstOrNull;
      if (s != null) shapeMap[s] = (e.value as num).toDouble();
    }

    return DesignPreferences(
      styleWeights: styleMap,
      shapeWeights: shapeMap,
      prefersDarkGarment: j['prefersDarkGarment'] as bool?,
      prefersVibrant: j['prefersVibrant'] as bool?,
      sampleCount: (j['sampleCount'] as num?)?.toInt() ?? 0,
      explorationRate: (j['explorationRate'] as num?)?.toDouble() ?? 0.35,
    );
  }

  String encode() => jsonEncode(toJson());

  factory DesignPreferences.decode(String jsonStr) =>
      DesignPreferences.fromJson(
          jsonDecode(jsonStr) as Map<String, dynamic>);
}
