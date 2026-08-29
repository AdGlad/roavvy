import 'package:design_forge/design_forge.dart';

import '../travel_profile.dart';
import 'preference_profile.dart';

/// Bidirectional bridge between the mobile [UserDesignPreferenceProfile]
/// and the shared [DesignPreferences] from the forge recommendation engine.
///
/// The mobile profile tracks fine-grained axes (family, template, mask,
/// printStyle, colour) while the forge profile tracks coarser buckets
/// (style clusters, shape preferences, garment/color booleans). The bridge
/// maps between them heuristically — exact round-tripping is not required,
/// just behavioural equivalence.
class PreferenceBridge {
  const PreferenceBridge();

  /// Convert mobile preferences + travel data to forge [DesignPreferences].
  DesignPreferences toForgePreferences(
    UserDesignPreferenceProfile mobile,
    TravelProfile? travel,
  ) {
    // Map mobile family weights → forge style cluster weights.
    final styleWeights = <StyleCluster, double>{};
    // CompositionFamily names: singleHero, flagBlend, grid, passport, timeline,
    //   typographic, badge, wordCloud, landmark, journey, artistic.
    // Map heuristically to clusters.
    _mapWeight(mobile.family, ['singleHero'], StyleCluster.clean, styleWeights);
    _mapWeight(mobile.family, ['passport', 'timeline'], StyleCluster.vintage, styleWeights);
    _mapWeight(mobile.family, ['badge', 'wordCloud'], StyleCluster.bold, styleWeights);
    _mapWeight(mobile.family, ['flagBlend', 'grid'], StyleCluster.relaxed, styleWeights);
    _mapWeight(mobile.family, ['artistic', 'landmark'], StyleCluster.artistic, styleWeights);
    _mapWeight(mobile.family, ['typographic'], StyleCluster.typographic, styleWeights);

    // Map mobile mask weights → forge shape preferences.
    final shapeWeights = <ShapePreference, double>{};
    _mapWeight(mobile.mask, ['none', 'noClip'], ShapePreference.noClip, shapeWeights);
    _mapWeight(mobile.mask, ['country', 'countryOutline', 'continent'], ShapePreference.countryOutline, shapeWeights);
    _mapWeight(mobile.mask, ['animal', 'plant', 'landmark'], ShapePreference.silhouette, shapeWeights);
    _mapWeight(mobile.mask, ['circle', 'oval', 'diamond', 'heart', 'hexagon', 'shield', 'star'], ShapePreference.geometric, shapeWeights);
    _mapWeight(mobile.mask, ['compass', 'ticket', 'badge', 'mapPin', 'stamp'], ShapePreference.travelIcon, shapeWeights);
    _mapWeight(mobile.mask, ['text'], ShapePreference.textMask, shapeWeights);

    // Garment tone: check if the mobile colour weights suggest a dark preference.
    bool? darkGarment;
    final darkWeight = (mobile.colour['dark'] ?? 1.0);
    final lightWeight = (mobile.colour['light'] ?? 1.0);
    if ((darkWeight - lightWeight).abs() > 0.3) {
      darkGarment = darkWeight > lightWeight;
    }

    // Vibrancy: check print style weights.
    bool? vibrant;
    final vintageWeight = (mobile.printStyle['vintage'] ?? 1.0) +
        (mobile.printStyle['retro'] ?? 1.0);
    final boldWeight = (mobile.printStyle['bold'] ?? 1.0) +
        (mobile.printStyle['vibrant'] ?? 1.0);
    if ((boldWeight - vintageWeight).abs() > 0.5) {
      vibrant = boldWeight > vintageWeight;
    }

    return DesignPreferences(
      styleWeights: styleWeights,
      shapeWeights: shapeWeights,
      prefersDarkGarment: darkGarment,
      prefersVibrant: vibrant,
      sampleCount: mobile.sampleCount,
      explorationRate: mobile.explorationRate.clamp(0.15, 0.60),
    );
  }

  /// Convert forge [DesignPreferences] back to a mobile profile.
  ///
  /// Approximate inverse of [toForgePreferences]. Used when the forge
  /// recommendation engine has updated preferences and the mobile system
  /// needs to reflect them.
  UserDesignPreferenceProfile toMobileProfile(
    DesignPreferences forge,
    UserDesignPreferenceProfile existing,
  ) {
    // Propagate the forge's style cluster weights into the mobile family map.
    final family = Map<String, double>.from(existing.family);
    _reverseMapWeight(forge.styleWeights, StyleCluster.clean, ['singleHero'], family);
    _reverseMapWeight(forge.styleWeights, StyleCluster.vintage, ['passport', 'timeline'], family);
    _reverseMapWeight(forge.styleWeights, StyleCluster.bold, ['badge', 'wordCloud'], family);
    _reverseMapWeight(forge.styleWeights, StyleCluster.relaxed, ['flagBlend', 'grid'], family);
    _reverseMapWeight(forge.styleWeights, StyleCluster.artistic, ['artistic', 'landmark'], family);
    _reverseMapWeight(forge.styleWeights, StyleCluster.typographic, ['typographic'], family);

    // Propagate shape weights into the mask map.
    final mask = Map<String, double>.from(existing.mask);
    _reverseMapWeight(forge.shapeWeights, ShapePreference.noClip, ['none'], mask);
    _reverseMapWeight(forge.shapeWeights, ShapePreference.countryOutline, ['country', 'continent'], mask);
    _reverseMapWeight(forge.shapeWeights, ShapePreference.silhouette, ['animal', 'plant', 'landmark'], mask);
    _reverseMapWeight(forge.shapeWeights, ShapePreference.geometric, ['circle', 'diamond', 'heart'], mask);
    _reverseMapWeight(forge.shapeWeights, ShapePreference.travelIcon, ['compass', 'ticket', 'badge'], mask);
    _reverseMapWeight(forge.shapeWeights, ShapePreference.textMask, ['text'], mask);

    return existing.copyWith(
      family: family,
      mask: mask,
      sampleCount: forge.sampleCount,
      explorationRate: forge.explorationRate,
    );
  }

  /// Build a [DesignContext] from a [TravelProfile].
  DesignContext contextFromTravel(TravelProfile travel,
      {List<String>? overrideCodes}) {
    final codes = overrideCodes ?? travel.allCodes;
    return DesignContext(
      flagCodes: codes.isEmpty ? ['us'] : codes,
      scopeKey: travel.persona.name,
    );
  }

  // ── helpers ──

  /// Aggregate mobile weight keys into a single forge enum weight.
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
    if (count > 0) {
      dest[target] = sum / count;
    }
  }

  /// Spread a forge enum weight back to multiple mobile keys.
  static void _reverseMapWeight<T>(
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
