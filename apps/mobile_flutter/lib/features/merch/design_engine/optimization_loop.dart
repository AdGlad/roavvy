import 'dart:math' as math;
import 'dart:typed_data';

import 'package:shared_models/shared_models.dart';

import 'design_engine_contracts.dart';
import 'design_params.dart';
import 'travel_profile.dart';

/// One evaluated design in the search: its genome, its [DesignScore], and (once
/// rendered) a low-res thumbnail used by the pixel scorers and the gallery.
class DesignCandidate {
  const DesignCandidate({
    required this.params,
    required this.score,
    this.thumbnail,
  });

  final DesignParams params;
  final DesignScore score;
  final Uint8List? thumbnail;

  double get total => score.total();

  DesignCandidate copyWith({DesignScore? score, Uint8List? thumbnail}) =>
      DesignCandidate(
        params: params,
        score: score ?? this.score,
        thumbnail: thumbnail ?? this.thumbnail,
      );
}

/// Wall-clock and population caps for the loop (architecture §9 — the ≤5 s
/// budget). The loop stops at whichever limit is hit first (or convergence).
class DesignEngineBudget {
  const DesignEngineBudget({
    this.maxDuration = const Duration(seconds: 3),
    this.maxGenerations = 6,
    this.populationSize = 60,
    this.topK = 10,
    this.eliteCount = 4,
  });

  /// Wall-clock cap for the whole loop (time-to-first-result guard).
  final Duration maxDuration;

  /// Hard cap on evolutionary generations.
  final int maxGenerations;

  /// Target initial + injected population size.
  final int populationSize;

  /// How many analytic survivors get rendered + pixel-scored per generation.
  final int topK;

  /// How many top-ranked candidates seed the next generation.
  final int eliteCount;
}

/// A trivial cooperative cancellation signal (architecture §9 — cancel when the
/// user leaves). Checked between generations and between renders.
class CancellationToken {
  bool _cancelled = false;
  bool get isCancelled => _cancelled;
  void cancel() => _cancelled = true;
}

/// The evolutionary / guided-search optimisation loop (architecture §7).
///
/// Funnel per generation: seed → **printability gate** → analytic score (no
/// render) → top-K → render thumbnails (injected, throttled by the caller) →
/// pixel score → keep elites → mutate + crossover + diversity injection. Stops
/// on convergence, [DesignEngineBudget], or cancellation, and returns the
/// diversity-filtered **top 3** distinct genomes. Deterministic for a fixed
/// [rng] and a deterministic renderer/scorer.
class OptimizationLoop {
  const OptimizationLoop();

  /// Score improvement below this between generations counts as a plateau.
  static const double _convergenceEps = 1e-3;

  /// Consecutive plateaued generations before declaring convergence.
  static const int _maxStagnantGenerations = 2;

  /// Minimum number of differing meaningful genes for two designs to count as
  /// distinct *ideas* in the diversity filter.
  static const int _minGenomeDistance = 2;

  /// Cap on the accumulated elite pool (bounds memory across generations).
  static const int _bestPoolCap = 32;

  /// Number of designs to present (architecture §16 — exactly 3).
  static const int _resultCount = 3;

  Future<List<DesignCandidate>> run({
    required TravelProfile profile,
    required List<TripRecord> trips,
    required CandidateGenerator generator,
    required List<PrintabilityConstraint> constraints,
    required List<DesignScorer> analyticScorers,
    required List<DesignScorer> pixelScorers,
    required DesignRenderer renderer,
    required Mutator mutator,
    DesignEngineBudget budget = const DesignEngineBudget(),
    CancellationToken? cancel,
    void Function(List<DesignCandidate>)? onProgress,
    math.Random? rng,
  }) async {
    final random = rng ?? math.Random(0);
    final stopwatch = Stopwatch()..start();

    bool budgetHit() =>
        stopwatch.elapsed >= budget.maxDuration ||
        (cancel?.isCancelled ?? false);

    var population = generator.seed(profile, count: budget.populationSize);
    var best = <DesignCandidate>[];
    double? lastBestTotal;
    var stagnant = 0;

    for (var gen = 0; gen < budget.maxGenerations; gen++) {
      if (budgetHit()) break;

      // ── Printability gate (hard) + analytic score (no raster). ──────────────
      final analytic = <DesignCandidate>[];
      for (final p in population) {
        final reason = _gate(p, profile, constraints);
        if (reason != null) continue;
        analytic.add(
          DesignCandidate(
            params: p,
            score: _aggregate(p, profile, analyticScorers, null),
          ),
        );
      }

      if (analytic.isEmpty) {
        // Nothing printable this round — inject fresh diversity and retry within
        // the generation cap. Guarantees graceful handling of a generator that
        // only produces invalid/unprintable genomes (loop simply drains to []).
        population = generator.seed(profile, count: budget.populationSize);
        continue;
      }

      analytic.sort((a, b) => b.total.compareTo(a.total));
      final topK = analytic.take(budget.topK).toList();

      // ── Render survivors + pixel score. ─────────────────────────────────────
      final ranked = <DesignCandidate>[];
      for (final candidate in topK) {
        if (budgetHit()) break;
        Uint8List? thumbnail;
        try {
          thumbnail = await renderer.renderThumbnail(candidate.params, trips);
        } catch (_) {
          thumbnail = null; // a render failure must not abort the loop
        }
        final score = pixelScorers.isEmpty
            ? candidate.score
            : _aggregate(candidate.params, profile, pixelScorers, thumbnail);
        ranked.add(
          DesignCandidate(
            params: candidate.params,
            score: score,
            thumbnail: thumbnail,
          ),
        );
      }
      // If the budget cut rendering short, fall back to the analytic survivors.
      final generationResults = ranked.isEmpty ? topK : ranked;

      // ── Elitism across generations + progressive best-3. ────────────────────
      best = _mergeElites(best, generationResults);
      final progress = _diverseTop(best, _resultCount);
      onProgress?.call(progress);

      // ── Convergence check. ──────────────────────────────────────────────────
      final bestTotal = progress.isEmpty ? 0.0 : progress.first.total;
      if (lastBestTotal != null &&
          (bestTotal - lastBestTotal) < _convergenceEps) {
        stagnant++;
      } else {
        stagnant = 0;
      }
      lastBestTotal = bestTotal;
      if (stagnant >= _maxStagnantGenerations) break;
      if (budgetHit()) break;

      // ── Breed next generation: elites + mutate + crossover + diversity. ─────
      final elites =
          generationResults.take(budget.eliteCount).map((c) => c.params).toList();
      final next = <DesignParams>{...elites}; // Set dedupes by contentHash

      for (final elite in elites) {
        next.add(mutator.mutate(elite, profile, random));
      }
      for (var i = 0; i < elites.length; i++) {
        final a = elites[i];
        final b = elites[(i + 1) % elites.length];
        next.add(mutator.crossover(a, b, random));
      }
      next.addAll(
        generator.seed(profile, count: math.max(1, budget.populationSize ~/ 2)),
      );
      population = next.toList();
    }

    return _diverseTop(best, _resultCount);
  }

  // ── Scoring ──────────────────────────────────────────────────────────────

  /// Returns the printability rejection reason, or null when the design passes
  /// every constraint (and is a valid genome).
  String? _gate(
    DesignParams params,
    TravelProfile profile,
    List<PrintabilityConstraint> constraints,
  ) {
    if (!params.isValid) return 'invalid genome';
    for (final constraint in constraints) {
      final violation = constraint.violation(params, profile);
      if (violation != null) return violation;
    }
    return null;
  }

  /// Weighted aggregate of [scorers] into a [DesignScore]. Assumes the gate has
  /// already passed (callers gate first); re-checks validity defensively.
  DesignScore _aggregate(
    DesignParams params,
    TravelProfile profile,
    List<DesignScorer> scorers,
    Uint8List? thumbnail,
  ) {
    if (!params.isValid) return DesignScore.rejected.reject('invalid genome');
    if (scorers.isEmpty) {
      return const DesignScore(
        printable: true,
        aesthetic: 0.5,
        profileFit: 0.5,
        printabilityMargin: 1.0,
      );
    }
    var weighted = 0.0;
    var weightSum = 0.0;
    for (final scorer in scorers) {
      final weight = scorer.weight <= 0 ? 1.0 : scorer.weight;
      final value =
          scorer.score(params, profile, thumbnail: thumbnail).clamp(0.0, 1.0);
      weighted += weight * value;
      weightSum += weight;
    }
    final aesthetic = weightSum == 0 ? 0.0 : weighted / weightSum;
    return DesignScore(
      printable: true,
      aesthetic: aesthetic,
      profileFit: aesthetic,
      printabilityMargin: 1.0,
    );
  }

  // ── Selection ──────────────────────────────────────────────────────────────

  /// Merges the running elite pool with this generation's results, keeping the
  /// higher score per genome and capping the pool size.
  List<DesignCandidate> _mergeElites(
    List<DesignCandidate> previous,
    List<DesignCandidate> current,
  ) {
    final byHash = <String, DesignCandidate>{};
    for (final candidate in [...previous, ...current]) {
      final key = candidate.params.contentHash;
      final existing = byHash[key];
      if (existing == null || candidate.total > existing.total) {
        byHash[key] = candidate;
      }
    }
    final merged = byHash.values.toList()
      ..sort((a, b) => b.total.compareTo(a.total));
    return merged.take(_bestPoolCap).toList();
  }

  /// Top-[n] distinct *ideas*: best-first, skipping genomes that are duplicates
  /// (contentHash) or too close (genome distance) to an already-picked design.
  /// Relaxes to distinct-hash-only if strict diversity cannot fill [n].
  List<DesignCandidate> _diverseTop(List<DesignCandidate> pool, int n) {
    final sorted = [...pool]..sort((a, b) => b.total.compareTo(a.total));
    final picked = <DesignCandidate>[];
    final seen = <String>{};

    for (final candidate in sorted) {
      final hash = candidate.params.contentHash;
      if (seen.contains(hash)) continue;
      final tooClose = picked.any(
        (p) => _genomeDistance(p.params, candidate.params) < _minGenomeDistance,
      );
      if (tooClose) continue;
      picked.add(candidate);
      seen.add(hash);
      if (picked.length == n) return picked;
    }

    // Relax: fill remaining slots with any distinct-genome candidates.
    for (final candidate in sorted) {
      if (picked.length == n) break;
      final hash = candidate.params.contentHash;
      if (seen.contains(hash)) continue;
      picked.add(candidate);
      seen.add(hash);
    }
    return picked;
  }

  /// Number of differing meaningful genes between two genomes (a coarse
  /// "different idea" measure for the diversity filter).
  int _genomeDistance(DesignParams a, DesignParams b) {
    var distance = 0;
    if (a.template != b.template) distance++;
    if (a.source != b.source) distance++;
    if (!_sameCodes(a.countryCodes, b.countryCodes)) distance++;
    if (a.gridLayoutMode != b.gridLayoutMode) distance++;
    if (a.clipShape != b.clipShape) distance++;
    if (a.shirtColour != b.shirtColour) distance++;
    if (a.density != b.density) distance++;
    if (a.isPortrait != b.isPortrait) distance++;
    return distance;
  }

  bool _sameCodes(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    return a.toSet().containsAll(b);
  }
}
