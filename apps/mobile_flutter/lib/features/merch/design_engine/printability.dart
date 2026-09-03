import 'dart:ui' show Rect, Size;

import 'package:shared_models/shared_models.dart';

import '../../cards/flag_grid_layout_engine.dart';
import '../merch_preset.dart';
import '../product_mockup_specs.dart';
import 'design_engine_contracts.dart';
import 'design_params.dart';
import 'travel_profile.dart';

/// M198 — the printability gate: a set of [PrintabilityConstraint]s that decide,
/// *analytically* (before any raster), whether a [DesignParams] can be printed
/// on the real product. Grounded in the Printful back-DTG pipeline:
///
///   • Printfile: 1800×2400 px @ 150 DPI (12″×16″, aspect 0.75) — see
///     `MerchPrintDimensions` in merch_variant_lookup.dart.
///   • Print area / scale: [ImageSize.fillFraction] shrinks the artwork inside
///     that printfile (M190 `_kTshirtBackPrintArea`), so the print canvas the
///     design actually occupies is `fillFraction × (1800×2400)`.
///   • Garment: the 5 supported `tshirtColors`, whose luminance drives contrast.
///
/// Everything here is pure + isolate-safe (no rendering) so hundreds of
/// candidates can be gated cheaply on a background isolate (§6.1 / §8).

// ── Print-pipeline geometry constants ────────────────────────────────────────

/// Printful back-DTG printfile, verified via `GET /mockup-generator/printfiles/12`
/// (printfile_id 1: 1800×2400 @ 150 DPI). Mirrors `_tshirtDims`.
const double kPrintfileWidthPx = 1800;
const double kPrintfileHeightPx = 2400;
const int kPrintDpi = 150;

/// Vertical fractions the card templates reserve for the title / branding zones
/// (matches the CardTextRenderer zones the real renderer draws). Used so the
/// analytic grid layout sees the same drawable region the renderer will.
const double kTitleReserveFrac = 0.10;
const double kBrandingReserveFrac = 0.05;

/// Smallest legible feature on the printfile. 90 px @ 150 DPI ≈ 0.6″ — below
/// this a detailed flag/element degrades to an unrecognisable smudge on DTG.
const double kMinFeaturePx = 90.0;

/// Analytic ink-coverage window, relative to the fill-scaled print canvas. Below
/// [kMinCoverage] the artwork is near-empty (wasted garment); above
/// [kMaxCoverage] it is an edge-to-edge slab with no breathing room.
const double kMinCoverage = 0.12;
const double kMaxCoverage = 0.98;

/// Minimum garment↔ink lightness separation (ΔL, 0..1) for the design to be
/// visible on the shirt. Mirrors the spirit of the M193 adaptive palette
/// (resolveTimelinePalette): never dark ink on a dark garment.
const double kMinGarmentContrastL = 0.30;

/// The concrete pixel canvas the artwork occupies on the printfile for a given
/// [ImageSize]. Large fills the whole printfile; smaller sizes fill a centred
/// fraction of it (M190).
Size printCanvasFor(ImageSize size) => Size(
  kPrintfileWidthPx * size.fillFraction,
  kPrintfileHeightPx * size.fillFraction,
);

/// Flag-grid tile rects for [params], mapped onto the print canvas — the exact
/// geometry the renderer would lay out (drives min-feature + coverage + the
/// analytic scorers). Empty for non-grid templates / empty sets.
List<FlagGridTile> printGridTiles(DesignParams params) {
  if (params.template != CardTemplateType.grid) return const [];
  final canvas = printCanvasFor(params.imageSize);
  return FlagGridLayoutEngine.compute(
    codes: params.countryCodes,
    canvasSize: canvas,
    topOffset: canvas.height * kTitleReserveFrac,
    bottomOffset: canvas.height * kBrandingReserveFrac,
    mode: params.gridLayoutMode,
    rowCount: params.rowCount,
    seed: params.seed,
  );
}

/// Estimated ink coverage of [params] as a fraction (0..1) of the fill-scaled
/// print canvas. For the grid template this is measured from the real tile
/// rects (clamped to the canvas so overlap/overflow saturate at 1.0); for the
/// other templates it is a per-template analytic estimate from element count +
/// density. Used by [CoverageBoundsConstraint] and the whitespace scorer.
double estimateInkCoverage(DesignParams params) {
  final canvas = printCanvasFor(params.imageSize);
  final canvasArea = canvas.width * canvas.height;
  if (canvasArea <= 0) return 0;
  final n = params.countryCodes.length;
  if (n == 0) return 0;

  if (params.template == CardTemplateType.grid) {
    final tiles = printGridTiles(params);
    if (tiles.isEmpty) return 0;
    final bounds = Rect.fromLTWH(0, 0, canvas.width, canvas.height);
    var sum = 0.0;
    for (final t in tiles) {
      final r = t.rect.intersect(bounds);
      if (r.width > 0 && r.height > 0) sum += r.width * r.height;
    }
    return (sum / canvasArea).clamp(0.0, 1.0);
  }

  double cov;
  switch (params.template) {
    case CardTemplateType.passport:
      final stamps = n * (params.stampMode == MerchStampMode.entryExit ? 2 : 1);
      final per = switch (params.density) {
        MerchDensity.sparse => 0.045,
        MerchDensity.balanced => 0.060,
        MerchDensity.dense => 0.075,
      };
      cov = stamps * per;
    case CardTemplateType.timeline:
      cov = 0.10 + 0.045 * n;
    case CardTemplateType.typography:
      cov = 0.12 + 0.055 * n;
    case CardTemplateType.wordCloud:
      cov = 0.22 + 0.030 * n;
    case CardTemplateType.landmark:
      cov = 0.08 * n;
    case CardTemplateType.journeys:
      cov = 0.10 + 0.03 * n; // flag discs + dotted route
    case CardTemplateType.heart:
      cov = 0.35 + 0.030 * n;
    case CardTemplateType.frontRibbon:
      cov = 0.30 + 0.030 * n;
    case CardTemplateType.badge:
      cov = 0.40;
    case CardTemplateType.grid:
      cov = 0.0; // handled above
  }
  return cov.clamp(0.0, 1.0);
}

// ── Garment contrast helpers ─────────────────────────────────────────────────

/// Relative luminance (0 = black … 1 = white) of a supported garment colour, or
/// null when the colour isn't one we can print/contrast-check.
double? garmentLuminance(String shirtColour) => switch (shirtColour) {
  'Black' => 0.05,
  'White' => 1.00,
  'Blue' => 0.18,
  'Grey' => 0.50,
  'Red' => 0.30,
  _ => null,
};

/// Resolves an ink luminance for [params] over its garment (0..1).
typedef InkLuminanceResolver = double Function(DesignParams params);

/// Default, adaptive ink model — mirrors the M193 palette logic
/// (resolveTimelinePalette): a dark garment gets light ink, a light garment
/// gets dark ink, so a valid genome always contrasts by construction. The gate
/// stays honest because [GarmentContrastConstraint] takes this as an injectable
/// dependency — a future template that pins a colour supplies its own resolver.
double adaptiveInkLuminanceFor(DesignParams params) {
  final g = garmentLuminance(params.shirtColour);
  if (g == null) return 0.5;
  return g > 0.5 ? 0.05 : 0.95;
}

// ── Constraints ──────────────────────────────────────────────────────────────

/// Rejects genomes that are illegal or empty (the [DesignParams.isValid] gate).
class GenomeValidityConstraint implements PrintabilityConstraint {
  const GenomeValidityConstraint();

  @override
  String get name => 'GenomeValidity';

  @override
  String? violation(DesignParams params, TravelProfile profile) {
    if (params.countryCodes.isEmpty) return 'empty country set';
    if (!params.isValid) return 'illegal gene combination (not normalized)';
    return null;
  }
}

/// Rejects designs whose smallest printed element falls below [kMinFeaturePx]
/// once mapped onto the 1800×2400 printfile — i.e. sub-pixel / illegible detail.
/// Measured from the real flag-grid tile rects; non-grid templates auto-scale
/// their own text/icons and are left to their template logic.
class MinFeatureSizeConstraint implements PrintabilityConstraint {
  const MinFeatureSizeConstraint({this.minFeaturePx = kMinFeaturePx});

  final double minFeaturePx;

  @override
  String get name => 'MinFeatureSize';

  @override
  String? violation(DesignParams params, TravelProfile profile) {
    if (params.template != CardTemplateType.grid) return null;
    final tiles = printGridTiles(params);
    if (tiles.isEmpty) return null; // emptiness handled by GenomeValidity
    var minDim = double.infinity;
    for (final t in tiles) {
      final d = t.rect.width < t.rect.height ? t.rect.width : t.rect.height;
      if (d < minDim) minDim = d;
    }
    if (minDim < minFeaturePx) {
      return 'smallest element ${minDim.toStringAsFixed(0)}px '
          '< ${minFeaturePx.toStringAsFixed(0)}px min at print scale';
    }
    return null;
  }
}

/// Rejects designs whose estimated ink coverage falls outside
/// [[kMinCoverage], [kMaxCoverage]] — near-empty (wasted garment) or a solid
/// edge-to-edge slab.
class CoverageBoundsConstraint implements PrintabilityConstraint {
  const CoverageBoundsConstraint({
    this.minCoverage = kMinCoverage,
    this.maxCoverage = kMaxCoverage,
  });

  final double minCoverage;
  final double maxCoverage;

  @override
  String get name => 'CoverageBounds';

  @override
  String? violation(DesignParams params, TravelProfile profile) {
    final cov = estimateInkCoverage(params);
    if (cov < minCoverage) {
      return 'near-empty (coverage ${cov.toStringAsFixed(2)} '
          '< ${minCoverage.toStringAsFixed(2)})';
    }
    if (cov > maxCoverage) {
      return 'solid slab (coverage ${cov.toStringAsFixed(2)} '
          '> ${maxCoverage.toStringAsFixed(2)})';
    }
    return null;
  }
}

/// Rejects designs that would be invisible on their garment — an unsupported
/// shirt colour, or ink whose lightness is within [kMinGarmentContrastL] of the
/// garment (e.g. dark-on-black). Ink is resolved via an injectable
/// [InkLuminanceResolver] (default: the adaptive M193 palette model).
class GarmentContrastConstraint implements PrintabilityConstraint {
  const GarmentContrastConstraint({
    this.inkLuminance = adaptiveInkLuminanceFor,
    this.minContrastL = kMinGarmentContrastL,
  });

  final InkLuminanceResolver inkLuminance;
  final double minContrastL;

  @override
  String get name => 'GarmentContrast';

  @override
  String? violation(DesignParams params, TravelProfile profile) {
    final g = garmentLuminance(params.shirtColour);
    if (g == null) return 'unsupported shirt colour "${params.shirtColour}"';
    final ink = inkLuminance(params);
    final dL = (g - ink).abs();
    if (dL < minContrastL) {
      return 'insufficient garment contrast (ΔL ${dL.toStringAsFixed(2)} '
          '< ${minContrastL.toStringAsFixed(2)}) on ${params.shirtColour}';
    }
    return null;
  }
}

// ── Gate ─────────────────────────────────────────────────────────────────────

/// Runs a list of [PrintabilityConstraint]s and returns the first violation
/// (or null when the design is printable). Order matters: cheapest / most
/// fundamental checks first.
class PrintabilityGate {
  const PrintabilityGate([this.constraints = kDefaultPrintabilityConstraints]);

  final List<PrintabilityConstraint> constraints;

  /// The first violated constraint's reason (prefixed with its name), or null.
  String? firstViolation(DesignParams params, TravelProfile profile) {
    for (final c in constraints) {
      final r = c.violation(params, profile);
      if (r != null) return '${c.name}: $r';
    }
    return null;
  }

  /// True when [params] passes every constraint.
  bool isPrintable(DesignParams params, TravelProfile profile) =>
      firstViolation(params, profile) == null;
}

/// The default, ordered printability constraint set for the analytic tier.
const List<PrintabilityConstraint> kDefaultPrintabilityConstraints = [
  GenomeValidityConstraint(),
  MinFeatureSizeConstraint(),
  CoverageBoundsConstraint(),
  GarmentContrastConstraint(),
];
