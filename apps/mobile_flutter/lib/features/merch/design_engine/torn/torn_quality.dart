import 'torn_geometry_generator.dart';
import 'torn_recipe.dart';

/// Objective quality metrics for a generated [TornMask], derived from the traits
/// of the liked references in `design_studio/reference_images/liked/torn/`:
/// damage concentrated on the outer edges, a pristine central body, separated
/// ragged fingers, and (usually) a clearly more-torn fly edge than hoist.
///
/// These back both the Design Studio scoring report (M6) and the regression
/// gates that keep the engine at reference quality as it is tuned.
class TornQualityMetrics {
  const TornQualityMetrics({
    required this.interiorClean,
    required this.edgeConcentration,
    required this.removedFraction,
    required this.fingerTransitions,
    required this.asymmetry,
  });

  /// Fraction of the inner [0.35, 0.65]² region left intact (1.0 == pristine).
  final double interiorClean;

  /// Fraction of removed pixels lying within the outer edge band (1.0 == every
  /// tear originates from an edge; no floating centre holes).
  final double edgeConcentration;

  /// Fraction of the whole design torn away.
  final double removedFraction;

  /// Kept↔torn transitions along the most-damaged edge — evidence of separated
  /// fingers rather than one solid bite.
  final int fingerTransitions;

  /// Directional lopsidedness of damage, 0 (even) … 1 (all on one side).
  final double asymmetry;

  /// Composite 0..1 quality score. A breached interior or a centre hole is
  /// disqualifying (hard zero on the respective factor); otherwise the score
  /// rewards separated fingers and a sensible amount of removed material.
  double get score {
    final interior = interiorClean; // 1.0 unless the body is breached
    final concentration = edgeConcentration; // 1.0 unless a centre hole appears
    // Reward a visible-but-not-destructive amount of tearing (~2%..30%).
    final amount =
        removedFraction < 0.01
            ? removedFraction / 0.01
            : removedFraction > 0.34
            ? (1.0 - (removedFraction - 0.34) / 0.34).clamp(0.0, 1.0)
            : 1.0;
    // Reward finger separation, saturating around a dozen transitions.
    final fingers = (fingerTransitions / 12).clamp(0.0, 1.0);
    return interior * concentration * (0.55 + 0.25 * fingers + 0.20 * amount);
  }
}

/// Computes [TornQualityMetrics] for [mask]. [recipe] is used only to orient the
/// asymmetry measurement (fly = right vs hoist = left).
TornQualityMetrics measureTornQuality(TornMask mask, TornRecipe recipe) {
  final w = mask.width;
  final h = mask.height;

  var removed = 0;
  var removedInBand = 0;
  var interiorKept = 0;
  var interiorTotal = 0;

  const band = kMaxPenetration; // outer band width as a fraction
  for (var y = 0; y < h; y++) {
    final ny = y / (h - 1);
    final inYband = ny < band || ny > 1 - band;
    final inYinner = ny >= 0.35 && ny <= 0.65;
    for (var x = 0; x < w; x++) {
      final kept = mask.alphaAt(x, y) > 127;
      final nx = x / (w - 1);
      if (!kept) {
        removed++;
        if (inYband || nx < band || nx > 1 - band) removedInBand++;
      }
      if (inYinner && nx >= 0.35 && nx <= 0.65) {
        interiorTotal++;
        if (kept) interiorKept++;
      }
    }
  }

  final total = w * h;
  final interiorClean = interiorTotal == 0 ? 1.0 : interiorKept / interiorTotal;
  final edgeConcentration = removed == 0 ? 1.0 : removedInBand / removed;

  // Most-damaged edge → count transitions along a line just inside it.
  final flyRemoved = _edgeRemoved(mask, _Edge.right);
  final hoistRemoved = _edgeRemoved(mask, _Edge.left);
  final topRemoved = _edgeRemoved(mask, _Edge.top);
  final bottomRemoved = _edgeRemoved(mask, _Edge.bottom);
  final heaviest =
      <_Edge, int>{
        _Edge.right: flyRemoved,
        _Edge.left: hoistRemoved,
        _Edge.top: topRemoved,
        _Edge.bottom: bottomRemoved,
      }.entries.reduce((a, b) => a.value >= b.value ? a : b).key;

  return TornQualityMetrics(
    interiorClean: interiorClean,
    edgeConcentration: edgeConcentration,
    removedFraction: removed / total,
    fingerTransitions: _transitions(mask, heaviest),
    asymmetry:
        (flyRemoved - hoistRemoved).abs() / (flyRemoved + hoistRemoved + 1),
  );
}

enum _Edge { top, bottom, left, right }

/// Removed-pixel count in the outer 15% strip of an edge.
int _edgeRemoved(TornMask m, _Edge e) {
  final w = m.width, h = m.height;
  var n = 0;
  switch (e) {
    case _Edge.left:
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w * 0.15; x++) {
          if (m.alphaAt(x.toInt(), y) <= 127) n++;
        }
      }
    case _Edge.right:
      for (var y = 0; y < h; y++) {
        for (var x = (w * 0.85).toInt(); x < w; x++) {
          if (m.alphaAt(x, y) <= 127) n++;
        }
      }
    case _Edge.top:
      for (var y = 0; y < h * 0.15; y++) {
        for (var x = 0; x < w; x++) {
          if (m.alphaAt(x, y.toInt()) <= 127) n++;
        }
      }
    case _Edge.bottom:
      for (var y = (h * 0.85).toInt(); y < h; y++) {
        for (var x = 0; x < w; x++) {
          if (m.alphaAt(x, y) <= 127) n++;
        }
      }
  }
  return n;
}

/// Best kept↔torn transition count across several scan lines through the edge's
/// damaged band. Fingers separate most clearly partway into the band (near the
/// tips they have tapered to points), so the max over depths is the fair signal.
int _transitions(TornMask m, _Edge e) {
  final w = m.width, h = m.height;
  var best = 0;
  for (final pen in const [0.02, 0.035, 0.05, 0.09, 0.14, 0.20]) {
    final samples = <bool>[];
    switch (e) {
      case _Edge.left:
        final x = (w * pen).round().clamp(0, w - 1);
        for (var y = 0; y < h; y++) {
          samples.add(m.alphaAt(x, y) > 127);
        }
      case _Edge.right:
        final x = (w * (1 - pen)).round().clamp(0, w - 1);
        for (var y = 0; y < h; y++) {
          samples.add(m.alphaAt(x, y) > 127);
        }
      case _Edge.top:
        final y = (h * pen).round().clamp(0, h - 1);
        for (var x = 0; x < w; x++) {
          samples.add(m.alphaAt(x, y) > 127);
        }
      case _Edge.bottom:
        final y = (h * (1 - pen)).round().clamp(0, h - 1);
        for (var x = 0; x < w; x++) {
          samples.add(m.alphaAt(x, y) > 127);
        }
    }
    var t = 0;
    for (var i = 1; i < samples.length; i++) {
      if (samples[i] != samples[i - 1]) t++;
    }
    if (t > best) best = t;
  }
  return best;
}
