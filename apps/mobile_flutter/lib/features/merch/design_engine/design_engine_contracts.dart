import 'dart:math' as math;
import 'dart:typed_data';

import 'package:shared_models/shared_models.dart';

import 'design_params.dart';
import 'travel_profile.dart';

/// The result of scoring one [DesignParams]. [printable] is the hard gate — a
/// design that fails it is never presented, regardless of aesthetics (M197/§6).
class DesignScore {
  const DesignScore({
    required this.printable,
    this.aesthetic = 0.0,
    this.profileFit = 0.0,
    this.printabilityMargin = 0.0,
    this.rejectionReason,
  });

  /// Passed the printability gate.
  final bool printable;

  /// Aesthetic quality in [0, 1] (higher is better). 0 when not printable.
  final double aesthetic;

  /// How well the design matches the traveller's profile, [0, 1].
  final double profileFit;

  /// Headroom above the printability minimums, [0, 1] (used as a tie-breaker).
  final double printabilityMargin;

  /// Why a non-printable design was rejected (for telemetry/debug).
  final String? rejectionReason;

  /// A rejected design scores 0 so it sorts last / is filtered out.
  double total({double wAesthetic = 0.7, double wFit = 0.3}) =>
      printable ? (wAesthetic * aesthetic + wFit * profileFit) : 0.0;

  static const DesignScore rejected = DesignScore(printable: false);

  DesignScore reject(String reason) =>
      DesignScore(printable: false, rejectionReason: reason);
}

/// A single hard printability rule. Returns null when the design is printable,
/// or a human-readable reason when it is not (checked BEFORE any raster).
abstract class PrintabilityConstraint {
  String get name;

  /// null == OK; non-null == violated (the reason).
  String? violation(DesignParams params, TravelProfile profile);
}

/// A composable aesthetic/fit scorer. The engine sums a weighted list of these.
/// Implementations must be pure + isolate-safe (no rendering) for the analytic
/// tier; the pixel tier receives optional rendered bytes.
abstract class DesignScorer {
  String get name;

  /// Weight applied to this scorer's contribution (from RemoteConfig later).
  double get weight;

  /// Score in [0, 1]. [thumbnail] is provided only in the pixel tier (may be
  /// null in the analytic tier).
  double score(
    DesignParams params,
    TravelProfile profile, {
    Uint8List? thumbnail,
  });
}

/// Produces an initial + ongoing supply of *valid* candidate genomes.
abstract class CandidateGenerator {
  /// Seed population for [profile]. Implementations should return normalized,
  /// valid [DesignParams] and inject diversity across country-sets/templates.
  List<DesignParams> seed(TravelProfile profile, {int count});
}

/// Genome perturbation for the evolutionary loop. Output must be normalized.
abstract class Mutator {
  DesignParams mutate(
    DesignParams params,
    TravelProfile profile,
    math.Random rng,
  );
  DesignParams crossover(DesignParams a, DesignParams b, math.Random rng);
}

/// Renders a genome to PNG bytes. The concrete implementation wraps
/// `CardImageRenderer` on the UI thread via a throttled queue (M200); the
/// engine only depends on this interface so the loop stays testable.
abstract class DesignRenderer {
  /// Low-resolution thumbnail for scoring / gallery (transparent background).
  Future<Uint8List> renderThumbnail(
    DesignParams params,
    List<TripRecord> trips,
  );
}
