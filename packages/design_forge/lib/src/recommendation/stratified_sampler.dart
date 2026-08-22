import 'dart:math' as math;

import '../determinism/deterministic_rng.dart';
import 'design_preferences.dart';
import 'style_cluster.dart';

/// Allocates a recipe-pool budget across [StyleCluster] values, weighted by
/// [DesignPreferences], with a guaranteed exploration floor.
///
/// The exploration floor ensures that even strongly-preferred profiles still
/// see some designs from less-preferred clusters.
class StratifiedSampler {
  const StratifiedSampler();

  /// Returns a map of cluster → recipe count that sums to [poolSize].
  ///
  /// [rng] is used to break ties and jitter allocations slightly.
  Map<StyleCluster, int> allocate(
    DesignPreferences prefs, {
    required int poolSize,
    required DeterministicRng rng,
  }) {
    final clusters = StyleCluster.values;
    final explorationRate = prefs.explorationRate.clamp(0.15, 0.60);

    // Split budget into preference-driven and exploration pools.
    final explorationBudget = (poolSize * explorationRate).round();
    final preferenceBudget = poolSize - explorationBudget;

    // ── Preference-driven allocation ──
    // Weight each cluster by user preference.
    final weights = <StyleCluster, double>{};
    double totalWeight = 0;
    for (final c in clusters) {
      final w = prefs.weightFor(c);
      weights[c] = w;
      totalWeight += w;
    }

    final allocation = <StyleCluster, int>{};
    int prefAllocated = 0;

    // Proportional allocation (floor).
    for (final c in clusters) {
      final share = (weights[c]! / totalWeight * preferenceBudget).floor();
      allocation[c] = share;
      prefAllocated += share;
    }

    // Distribute remainder to highest-weight clusters.
    var remainder = preferenceBudget - prefAllocated;
    final ranked = clusters.toList()
      ..sort((a, b) => weights[b]!.compareTo(weights[a]!));
    for (final c in ranked) {
      if (remainder <= 0) break;
      allocation[c] = allocation[c]! + 1;
      remainder--;
    }

    // ── Exploration allocation ──
    // Spread evenly across all clusters with slight jitter.
    final base = explorationBudget ~/ clusters.length;
    var explRemainder = explorationBudget - base * clusters.length;
    final shuffled = rng.shuffled(clusters.toList());
    for (final c in shuffled) {
      allocation[c] = allocation[c]! + base;
      if (explRemainder > 0) {
        allocation[c] = allocation[c]! + 1;
        explRemainder--;
      }
    }

    // Ensure every cluster gets at least 1 recipe.
    for (final c in clusters) {
      allocation[c] = math.max(1, allocation[c]!);
    }

    return allocation;
  }
}
