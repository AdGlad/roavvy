import 'dart:math' as math;

import 'package:shared_models/shared_models.dart' show CardTemplateType;

import '../../../cards/flag_grid_layout_engine.dart' show GridClipShape;
import '../printability.dart'
    show kMinFeaturePx, kPrintfileWidthPx, kPrintfileHeightPx;
import 'composition_family.dart';
import 'design_context.dart';
import 'design_dna.dart' show DesignPrinciple;
import 'procedural_recipe.dart';

/// A cheap, recipe-level validity rule. All constraints run on the recipe's
/// parameters alone (no rasterisation), so clearly-invalid designs are rejected
/// before any expensive rendering — the engine's first, fastest gate.
abstract class RecipeConstraint {
  const RecipeConstraint();

  /// Null when satisfied, otherwise a human-readable rejection reason.
  String? check(ProceduralDesignRecipe r, DesignContext ctx);
}

class _NonEmpty extends RecipeConstraint {
  const _NonEmpty();
  @override
  String? check(ProceduralDesignRecipe r, DesignContext ctx) =>
      r.countryCodes.isEmpty ? 'empty country set' : null;
}

class _FamilyAdmitsCount extends RecipeConstraint {
  const _FamilyAdmitsCount();
  @override
  String? check(ProceduralDesignRecipe r, DesignContext ctx) {
    final spec = kCompositionFamilies[r.family]!;
    return spec.admitsCount(r.countryCount)
        ? null
        : 'family ${r.family.name} does not admit ${r.countryCount} countries';
  }
}

/// Clip legality on the RAW recipe (before normalize repairs it) — catches a
/// generator that tried an illegal mask so we can measure/repair it.
class _ClipLegality extends RecipeConstraint {
  const _ClipLegality();
  static const _single = {
    GridClipShape.countryOutline,
    GridClipShape.animalSilhouette,
    GridClipShape.plantSilhouette,
    GridClipShape.landmarkSilhouette,
  };
  @override
  String? check(ProceduralDesignRecipe r, DesignContext ctx) {
    if (r.template != CardTemplateType.grid && r.mask != GridClipShape.none) {
      return 'clip on non-grid template';
    }
    if (_single.contains(r.mask) && r.countryCount != 1) {
      return 'single-country clip on ${r.countryCount}-country set';
    }
    if ((r.mask == GridClipShape.continentOutline ||
            _single.contains(r.mask)) &&
        (r.maskCode == null || r.maskCode!.isEmpty)) {
      return 'clip ${r.mask.name} requires a code';
    }
    return null;
  }
}

/// When the family needs a designated hero for multi-country sets, one must be
/// present and part of the set — otherwise hierarchy silently collapses.
class _HeroPresence extends RecipeConstraint {
  const _HeroPresence();
  @override
  String? check(ProceduralDesignRecipe r, DesignContext ctx) {
    final spec = kCompositionFamilies[r.family]!;
    if (spec.heroRequiredWhenMulti && r.countryCount > 1) {
      if (r.heroCode == null || !r.countryCodes.contains(r.heroCode)) {
        return 'family ${r.family.name} needs a hero for multi-country set';
      }
    }
    return null;
  }
}

/// The mapped genome must be legal on the real renderer (defence in depth).
class _GenomeLegal extends RecipeConstraint {
  const _GenomeLegal();
  @override
  String? check(ProceduralDesignRecipe r, DesignContext ctx) =>
      r.toDesignParams().isValid ? null : 'mapped genome invalid';
}

/// Reject visual clutter: the estimated visual density must stay under a
/// per-family cap. This is what stops "one country → many" from degrading into
/// an unreadable wall of tiny flags in a hero-oriented family.
class _ClutterCap extends RecipeConstraint {
  const _ClutterCap();
  static const _cap = {
    CompositionFamily.singleHero: 0.55,
    CompositionFamily.dominantAccent: 0.78,
    CompositionFamily.radialEmblem: 0.72,
    CompositionFamily.splitField: 0.82,
    CompositionFamily.negativeSpaceCutout: 0.88,
    CompositionFamily.typographicIntegration: 0.92,
    CompositionFamily.chronoSequence: 0.88,
    CompositionFamily.repetitionField: 0.97,
  };
  @override
  String? check(ProceduralDesignRecipe r, DesignContext ctx) {
    final vd = r.estimatePrinciples()[DesignPrinciple.visualDensity]!;
    final cap = _cap[r.family] ?? 0.9;
    return vd > cap
        ? 'visual density ${vd.toStringAsFixed(2)} exceeds ${r.family.name} cap $cap'
        : null;
  }
}

/// Estimated smallest printed flag must clear the minimum feature size, so
/// nothing is too small to print/recognise. Uses a cheap linear estimate.
class _MinFeature extends RecipeConstraint {
  const _MinFeature();
  @override
  String? check(ProceduralDesignRecipe r, DesignContext ctx) {
    final shortPx = math.min(kPrintfileWidthPx, kPrintfileHeightPx);
    final fill = r.imageSize.fillFraction.clamp(0.3, 1.0);
    final n = r.countryCount;
    final double perFlagLinear;
    switch (r.hierarchy) {
      case HierarchyMode.uniform:
        perFlagLinear = 1.0 / (math.sqrt(n) * 1.15 + 0.5);
      case HierarchyMode.dominantAccent:
        final accents = math.max(1, n - 1);
        perFlagLinear = math.min(
          r.heroScale,
          (1 - r.heroScale) / math.sqrt(accents),
        );
      case HierarchyMode.sequence:
        perFlagLinear = 1.0 / (n + 0.5);
      case HierarchyMode.singleFocal:
      case HierarchyMode.radial:
      case HierarchyMode.typeLed:
      case HierarchyMode.dualZone:
        perFlagLinear = math.max(0.12, r.heroScale);
    }
    final smallestPx = shortPx * fill * perFlagLinear;
    return smallestPx < kMinFeaturePx
        ? 'smallest feature ${smallestPx.toStringAsFixed(0)}px < $kMinFeaturePx'
        : null;
  }
}

/// Rotation must stay within the family's legal range.
class _RotationRange extends RecipeConstraint {
  const _RotationRange();
  @override
  String? check(ProceduralDesignRecipe r, DesignContext ctx) {
    final maxDeg = kCompositionFamilies[r.family]!.rotationMaxDeg;
    return r.rotationDeg.abs() > maxDeg + 1e-6
        ? 'rotation ${r.rotationDeg}deg exceeds ${maxDeg}deg'
        : null;
  }
}

/// The default constraint set, cheapest-first (short-circuit on first failure).
const List<RecipeConstraint> kDefaultRecipeConstraints = [
  _NonEmpty(),
  _FamilyAdmitsCount(),
  _ClipLegality(),
  _HeroPresence(),
  _RotationRange(),
  _MinFeature(),
  _ClutterCap(),
  _GenomeLegal(),
];

/// Returns the first violation reason, or null if the recipe is valid.
String? validateRecipe(
  ProceduralDesignRecipe recipe,
  DesignContext context, {
  List<RecipeConstraint> constraints = kDefaultRecipeConstraints,
}) {
  for (final c in constraints) {
    final reason = c.check(recipe, context);
    if (reason != null) return reason;
  }
  return null;
}

/// Convenience: is this recipe valid under the default constraints?
bool isRecipeValid(ProceduralDesignRecipe r, DesignContext ctx) =>
    validateRecipe(r, ctx) == null;
