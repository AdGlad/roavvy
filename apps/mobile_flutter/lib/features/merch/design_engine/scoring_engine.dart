import 'package:shared_models/shared_models.dart';

import 'analytic_scorers.dart';
import 'design_engine_contracts.dart';
import 'design_params.dart';
import 'printability.dart';
import 'travel_profile.dart';

/// M198 — the pure analytic scoring entry point (§6). Runs the printability gate
/// first (a hard reject), then sums the weighted aesthetic scorers into a
/// [DesignScore]. Fully dependency-injectable: pass custom [constraints] /
/// [scorers] / [profileScorer] for tuning or tests. M199 will wrap this with the
/// pixel tier + the optimisation loop.
///
/// Contract:
///   • Non-printable → [DesignScore.printable] false, [DesignScore.total] == 0.
///   • Printable → aesthetic = weighted mean of [scorers] (each in [0,1]),
///     profileFit = [profileScorer] output, printabilityMargin = headroom above
///     the min-feature threshold (a tie-breaker).
DesignScore analyticScore(
  DesignParams params,
  TravelProfile profile, {
  List<PrintabilityConstraint> constraints = kDefaultPrintabilityConstraints,
  List<DesignScorer> scorers = kDefaultAnalyticScorers,
  DesignScorer profileScorer = kDefaultProfileScorer,
}) {
  final reason = PrintabilityGate(constraints).firstViolation(params, profile);
  if (reason != null) {
    return DesignScore(printable: false, rejectionReason: reason);
  }

  var acc = 0.0;
  var wsum = 0.0;
  for (final s in scorers) {
    final v = s.score(params, profile).clamp(0.0, 1.0);
    acc += s.weight * v;
    wsum += s.weight;
  }
  final aesthetic = wsum > 0 ? (acc / wsum).clamp(0.0, 1.0) : 0.0;
  final profileFit = profileScorer.score(params, profile).clamp(0.0, 1.0);

  return DesignScore(
    printable: true,
    aesthetic: aesthetic,
    profileFit: profileFit,
    printabilityMargin: _printabilityMargin(params),
  );
}

/// Headroom above the printability minimums (0..1), used only as a tie-breaker
/// between two otherwise equal designs. For the grid template it is how far the
/// smallest tile sits above [kMinFeaturePx]; other templates use a mid default.
double _printabilityMargin(DesignParams params) {
  if (params.template != CardTemplateType.grid) return 0.5;
  final tiles = printGridTiles(params);
  if (tiles.isEmpty) return 0.0;
  var minDim = double.infinity;
  for (final t in tiles) {
    final d = t.rect.width < t.rect.height ? t.rect.width : t.rect.height;
    if (d < minDim) minDim = d;
  }
  return ((minDim - kMinFeaturePx) / kMinFeaturePx).clamp(0.0, 1.0);
}
