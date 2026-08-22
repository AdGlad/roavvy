import '../recipe/design_recipe.dart';
import 'shape_preference.dart';
import 'style_cluster.dart';

/// Greedy constraint-based picker that selects a diverse final set from a
/// scored pool.
///
/// Constraints:
/// - Max 2 designs per style cluster
/// - Max 2 designs per shape preference family
/// - Max 1 per composition family
/// - At least 1 exploration pick (from a non-top-2 cluster)
class DiversitySelector {
  const DiversitySelector();

  /// Selects [count] designs from [scored], enforcing diversity constraints.
  ///
  /// [scored] must be pre-sorted by score descending (best first).
  /// Each entry is (recipe, score).
  List<DesignRecipe> select(
    List<(DesignRecipe, double)> scored, {
    int count = 8,
    int maxPerStyle = 2,
    int maxPerShape = 2,
    int maxPerComposition = 1,
  }) {
    if (scored.isEmpty) return [];
    if (scored.length <= count) return scored.map((e) => e.$1).toList();

    // Determine top-2 clusters by weight for exploration tracking.
    final clusterCounts = <StyleCluster, int>{};
    for (final (r, _) in scored) {
      final c = _clusterOf(r);
      if (c != null) clusterCounts[c] = (clusterCounts[c] ?? 0) + 1;
    }
    final topClusters = (clusterCounts.keys.toList()
          ..sort((a, b) =>
              (clusterCounts[b] ?? 0).compareTo(clusterCounts[a] ?? 0)))
        .take(2)
        .toSet();

    final selected = <DesignRecipe>[];
    final styleTally = <StyleCluster, int>{};
    final shapeTally = <ShapePreference, int>{};
    final compositionTally = <DesignFamily, int>{};
    bool hasExploration = false;

    for (final (recipe, _) in scored) {
      if (selected.length >= count) break;

      final cluster = _clusterOf(recipe);
      final shape = _shapeOf(recipe);
      final family = recipe.composition.family;

      // Check constraints.
      if (cluster != null &&
          (styleTally[cluster] ?? 0) >= maxPerStyle) continue;
      if (shape != null &&
          (shapeTally[shape] ?? 0) >= maxPerShape) continue;
      if ((compositionTally[family] ?? 0) >= maxPerComposition) continue;

      selected.add(recipe);
      if (cluster != null) {
        styleTally[cluster] = (styleTally[cluster] ?? 0) + 1;
        if (!topClusters.contains(cluster)) hasExploration = true;
      }
      if (shape != null) {
        shapeTally[shape] = (shapeTally[shape] ?? 0) + 1;
      }
      compositionTally[family] = (compositionTally[family] ?? 0) + 1;
    }

    // Ensure at least 1 exploration pick if we haven't got one.
    if (!hasExploration && selected.length >= 2) {
      for (final (recipe, _) in scored) {
        if (selected.contains(recipe)) continue;
        final cluster = _clusterOf(recipe);
        if (cluster != null && !topClusters.contains(cluster)) {
          // Replace the last selected item with this exploration pick.
          selected[selected.length - 1] = recipe;
          break;
        }
      }
    }

    return selected;
  }

  static StyleCluster? _clusterOf(DesignRecipe r) {
    final gen = r.provenance?.generator;
    if (gen == null || !gen.startsWith('lab:')) return null;
    final styleName = gen.substring(4);
    for (final entry in kClusterToLabStyles.entries) {
      if (entry.value.contains(styleName)) return entry.key;
    }
    return null;
  }

  static ShapePreference? _shapeOf(DesignRecipe r) {
    final shapeId = r.clip?.shapeId;
    if (shapeId == null) return ShapePreference.noClip;
    return shapePreferenceFor(shapeId);
  }
}
