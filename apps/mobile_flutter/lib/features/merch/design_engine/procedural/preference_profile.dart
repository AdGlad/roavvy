import 'dart:math' as math;

import 'package:design_forge/design_forge.dart' as forge;

import 'procedural_recipe.dart';

/// Behavioural signals we translate into design preference. Ordered weakest →
/// strongest positive; [rejected] is the sole negative.
enum PreferenceSignal {
  /// The design was shown and dwelt on (weak positive).
  viewed,

  /// Style/filter deliberately chosen (targeted positive on the treatment).
  styleChosen,

  /// Saved / favourited (positive).
  saved,

  /// Taken into the mockup editor (strongest positive — intent to buy).
  selectedForMockup,

  /// Explicitly dismissed (negative).
  rejected,
}

/// Tunable knobs for preference learning + exploration. The
/// exploration/exploitation ratio is [explorationInitial] decaying toward
/// [explorationFloor] as evidence accrues, and is fully configurable.
class PreferenceConfig {
  const PreferenceConfig({
    this.learningRate = 0.15,
    this.clampMin = 0.25,
    this.clampMax = 4.0,
    this.explorationInitial = 0.2,
    this.explorationFloor = 0.05,
    this.halfLifeSamples = 40,
  });
  final double learningRate;
  final double clampMin;
  final double clampMax;
  final double explorationInitial;
  final double explorationFloor;
  final int halfLifeSamples;
}

/// A lightweight, on-device profile of one user's design taste. Holds
/// multiplicative weights (≈0.25..4, 1.0 neutral) over the categorical design
/// characteristics we can observe. **Deliberately separate from quality**:
/// quality is "is this a good graphic?"; preference is "does THIS user like it?"
class UserDesignPreferenceProfile {
  const UserDesignPreferenceProfile({
    this.family = const {},
    this.template = const {},
    this.mask = const {},
    this.printStyle = const {},
    this.colour = const {},
    this.sampleCount = 0,
    this.explorationRate = 0.2,
  });

  final Map<String, double> family;
  final Map<String, double> template;
  final Map<String, double> mask;
  final Map<String, double> printStyle;
  final Map<String, double> colour;
  final int sampleCount;

  /// Current exploration probability (share of shown designs chosen off-profile
  /// to keep discovering taste). Decays as [sampleCount] grows.
  final double explorationRate;

  static const neutral = UserDesignPreferenceProfile();

  double _w(Map<String, double> m, String k) => m[k] ?? 1.0;

  UserDesignPreferenceProfile copyWith({
    Map<String, double>? family,
    Map<String, double>? template,
    Map<String, double>? mask,
    Map<String, double>? printStyle,
    Map<String, double>? colour,
    int? sampleCount,
    double? explorationRate,
  }) => UserDesignPreferenceProfile(
    family: family ?? this.family,
    template: template ?? this.template,
    mask: mask ?? this.mask,
    printStyle: printStyle ?? this.printStyle,
    colour: colour ?? this.colour,
    sampleCount: sampleCount ?? this.sampleCount,
    explorationRate: explorationRate ?? this.explorationRate,
  );

  Map<String, dynamic> toJson() => {
    'family': family,
    'template': template,
    'mask': mask,
    'printStyle': printStyle,
    'colour': colour,
    'sampleCount': sampleCount,
    'explorationRate': explorationRate,
  };

  /// Convert to the forge-level [forge.DesignPreferences] for use with the
  /// shared recommendation pipeline.
  forge.DesignPreferences toDesignPreferences() {
    return const PreferenceBridgeHelper().toForge(this);
  }

  /// Create from forge-level preferences, merging into [existing].
  factory UserDesignPreferenceProfile.fromDesignPreferences(
    forge.DesignPreferences forgePrefs, {
    UserDesignPreferenceProfile existing = neutral,
  }) {
    return const PreferenceBridgeHelper().toMobile(forgePrefs, existing);
  }

  factory UserDesignPreferenceProfile.fromJson(Map<String, dynamic> j) {
    Map<String, double> m(String k) => {
      for (final e in ((j[k] as Map?) ?? {}).entries)
        e.key as String: (e.value as num).toDouble(),
    };
    return UserDesignPreferenceProfile(
      family: m('family'),
      template: m('template'),
      mask: m('mask'),
      printStyle: m('printStyle'),
      colour: m('colour'),
      sampleCount: (j['sampleCount'] as num?)?.toInt() ?? 0,
      explorationRate: (j['explorationRate'] as num?)?.toDouble() ?? 0.2,
    );
  }
}

/// Folds behavioural signals into a [UserDesignPreferenceProfile]. Pure: returns
/// a new profile; never mutates in place, so it composes with any store.
class PreferenceLearner {
  const PreferenceLearner({this.config = const PreferenceConfig()});
  final PreferenceConfig config;

  double _delta(PreferenceSignal s) => switch (s) {
    PreferenceSignal.viewed => 0.2,
    PreferenceSignal.styleChosen => 0.8,
    PreferenceSignal.saved => 1.0,
    PreferenceSignal.selectedForMockup => 1.5,
    PreferenceSignal.rejected => -1.2,
  };

  Map<String, double> _bump(Map<String, double> m, String key, double d) {
    final next = Map<String, double>.of(m);
    final w = (next[key] ?? 1.0) * math.exp(config.learningRate * d);
    next[key] = w.clamp(config.clampMin, config.clampMax);
    return next;
  }

  /// Update [profile] from one [signal] about [recipe].
  ///
  /// A [PreferenceSignal.styleChosen] only moves the treatment weights (that's
  /// what the user actually acted on); other signals move all characteristics.
  UserDesignPreferenceProfile observe(
    UserDesignPreferenceProfile profile,
    ProceduralDesignRecipe recipe,
    PreferenceSignal signal,
  ) {
    final d = _delta(signal);
    final styleOnly = signal == PreferenceSignal.styleChosen;

    final printStyle = _bump(profile.printStyle, recipe.printStyle.name, d);
    final colour = _bump(profile.colour, recipe.colourTreatment.name, d);
    if (styleOnly) {
      return profile.copyWith(
        printStyle: printStyle,
        colour: colour,
        sampleCount: profile.sampleCount + 1,
        explorationRate: _explorationFor(profile.sampleCount + 1),
      );
    }
    return profile.copyWith(
      family: _bump(profile.family, recipe.family.name, d),
      template: _bump(profile.template, recipe.template.name, d),
      mask: _bump(profile.mask, recipe.mask.name, d),
      printStyle: printStyle,
      colour: colour,
      sampleCount: profile.sampleCount + 1,
      explorationRate: _explorationFor(profile.sampleCount + 1),
    );
  }

  double _explorationFor(int samples) {
    final decay = math.pow(0.5, samples / config.halfLifeSamples).toDouble();
    return (config.explorationFloor +
            (config.explorationInitial - config.explorationFloor) * decay)
        .clamp(config.explorationFloor, config.explorationInitial);
  }
}

/// Scores how well a recipe matches a user's learned taste, in 0..1 (0.5 =
/// neutral / no evidence). This is the USER PREFERENCE SCORE — reported and
/// blended separately from the intrinsic QUALITY SCORE so the two never conflate.
class PreferenceScorer {
  const PreferenceScorer();

  double score(ProceduralDesignRecipe r, UserDesignPreferenceProfile p) {
    final weights = <double>[
      p._w(p.family, r.family.name),
      p._w(p.template, r.template.name),
      p._w(p.mask, r.mask.name),
      p._w(p.printStyle, r.printStyle.name),
      p._w(p.colour, r.colourTreatment.name),
    ];
    // Geometric mean of weights, squashed to 0..1 (neutral 1.0 → 0.5).
    var logSum = 0.0;
    for (final w in weights) {
      logSum += math.log(w);
    }
    final g = math.exp(logSum / weights.length);
    return g / (g + 1);
  }

  /// Blend quality and preference into a single ranking score. [prefBlend] is
  /// the exploitation weight on preference (0 = pure quality). Kept explicit so
  /// callers can tune the exploration/exploitation balance at the call site.
  double combined(
    double quality,
    double preference, {
    double prefBlend = 0.35,
  }) => ((1 - prefBlend) * quality + prefBlend * preference).clamp(0.0, 1.0);
}

/// Inline helper to convert between mobile and forge preference types.
/// Kept in this file to avoid a circular import with preference_bridge.dart.
class PreferenceBridgeHelper {
  const PreferenceBridgeHelper();

  forge.DesignPreferences toForge(UserDesignPreferenceProfile mobile) {
    final styleWeights = <forge.StyleCluster, double>{};
    _mapWeight(
      mobile.family,
      ['singleHero'],
      forge.StyleCluster.clean,
      styleWeights,
    );
    _mapWeight(
      mobile.family,
      ['passport', 'timeline'],
      forge.StyleCluster.vintage,
      styleWeights,
    );
    _mapWeight(
      mobile.family,
      ['badge', 'wordCloud'],
      forge.StyleCluster.bold,
      styleWeights,
    );
    _mapWeight(
      mobile.family,
      ['flagBlend', 'grid'],
      forge.StyleCluster.relaxed,
      styleWeights,
    );
    _mapWeight(
      mobile.family,
      ['artistic', 'landmark'],
      forge.StyleCluster.artistic,
      styleWeights,
    );
    _mapWeight(
      mobile.family,
      ['typographic'],
      forge.StyleCluster.typographic,
      styleWeights,
    );

    final shapeWeights = <forge.ShapePreference, double>{};
    _mapWeight(
      mobile.mask,
      ['none'],
      forge.ShapePreference.noClip,
      shapeWeights,
    );
    _mapWeight(
      mobile.mask,
      ['country', 'continent'],
      forge.ShapePreference.countryOutline,
      shapeWeights,
    );
    _mapWeight(
      mobile.mask,
      ['animal', 'plant', 'landmark'],
      forge.ShapePreference.silhouette,
      shapeWeights,
    );
    _mapWeight(
      mobile.mask,
      ['circle', 'diamond', 'heart', 'hexagon'],
      forge.ShapePreference.geometric,
      shapeWeights,
    );
    _mapWeight(
      mobile.mask,
      ['compass', 'ticket', 'badge'],
      forge.ShapePreference.travelIcon,
      shapeWeights,
    );
    _mapWeight(
      mobile.mask,
      ['text'],
      forge.ShapePreference.textMask,
      shapeWeights,
    );

    return forge.DesignPreferences(
      styleWeights: styleWeights,
      shapeWeights: shapeWeights,
      sampleCount: mobile.sampleCount,
      explorationRate: mobile.explorationRate.clamp(0.15, 0.60),
    );
  }

  UserDesignPreferenceProfile toMobile(
    forge.DesignPreferences forgePrefs,
    UserDesignPreferenceProfile existing,
  ) {
    final family = Map<String, double>.from(existing.family);
    _reverseMap(forgePrefs.styleWeights, forge.StyleCluster.clean, [
      'singleHero',
    ], family);
    _reverseMap(forgePrefs.styleWeights, forge.StyleCluster.vintage, [
      'passport',
      'timeline',
    ], family);
    _reverseMap(forgePrefs.styleWeights, forge.StyleCluster.bold, [
      'badge',
      'wordCloud',
    ], family);
    _reverseMap(forgePrefs.styleWeights, forge.StyleCluster.relaxed, [
      'flagBlend',
      'grid',
    ], family);
    _reverseMap(forgePrefs.styleWeights, forge.StyleCluster.artistic, [
      'artistic',
      'landmark',
    ], family);
    _reverseMap(forgePrefs.styleWeights, forge.StyleCluster.typographic, [
      'typographic',
    ], family);

    final mask = Map<String, double>.from(existing.mask);
    _reverseMap(forgePrefs.shapeWeights, forge.ShapePreference.noClip, [
      'none',
    ], mask);
    _reverseMap(forgePrefs.shapeWeights, forge.ShapePreference.countryOutline, [
      'country',
      'continent',
    ], mask);
    _reverseMap(forgePrefs.shapeWeights, forge.ShapePreference.silhouette, [
      'animal',
      'plant',
      'landmark',
    ], mask);
    _reverseMap(forgePrefs.shapeWeights, forge.ShapePreference.geometric, [
      'circle',
      'diamond',
      'heart',
    ], mask);
    _reverseMap(forgePrefs.shapeWeights, forge.ShapePreference.travelIcon, [
      'compass',
      'ticket',
      'badge',
    ], mask);
    _reverseMap(forgePrefs.shapeWeights, forge.ShapePreference.textMask, [
      'text',
    ], mask);

    return existing.copyWith(
      family: family,
      mask: mask,
      sampleCount: forgePrefs.sampleCount,
      explorationRate: forgePrefs.explorationRate,
    );
  }

  static void _mapWeight<T>(
    Map<String, double> source,
    List<String> keys,
    T target,
    Map<T, double> dest,
  ) {
    double sum = 0;
    int count = 0;
    for (final k in keys) {
      if (source.containsKey(k)) {
        sum += source[k]!;
        count++;
      }
    }
    if (count > 0) dest[target] = sum / count;
  }

  static void _reverseMap<T>(
    Map<T, double> source,
    T key,
    List<String> targets,
    Map<String, double> dest,
  ) {
    final w = source[key];
    if (w == null) return;
    for (final t in targets) {
      dest[t] = w;
    }
  }
}
