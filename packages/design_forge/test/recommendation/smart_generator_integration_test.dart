import 'package:design_forge/design_forge.dart';
import 'package:test/test.dart';

/// Minimal stand-in for LabSmartGenerator logic that doesn't depend on
/// Flutter or the Design Lab's LabShowcaseGenerator. Tests the full pipeline:
/// StratifiedSampler → pool generation → PreferenceScorer → DiversitySelector.
void main() {
  group('Smart generator pipeline (integration)', () {
    test('preferences → diverse set of 8 recipes', () {
      final prefs = DesignPreferences(
        styleWeights: {
          StyleCluster.bold: 3.0,
          StyleCluster.vintage: 2.0,
        },
        shapeWeights: {
          ShapePreference.geometric: 2.0,
          ShapePreference.silhouette: 1.5,
        },
        prefersDarkGarment: true,
      );

      // 1. Allocate.
      const sampler = StratifiedSampler();
      final rng = DeterministicRng(42);
      final allocation =
          sampler.allocate(prefs, poolSize: 60, rng: rng.stream('alloc'));

      // Verify allocation.
      expect(allocation[StyleCluster.bold]!,
          greaterThan(allocation[StyleCluster.clean]!));

      // 2. Simulate pool generation (fake recipes from each cluster).
      final pool = <DesignRecipe>[];
      final shapes = [
        'circle', 'heart', 'diamond', 'animalSilhouette',
        'text', 'countryOutline', 'compass', 'hexagon',
      ];
      final families = [
        DesignFamily.singleHero,
        DesignFamily.duoBlend,
        DesignFamily.grid,
        DesignFamily.badge,
        DesignFamily.typographic,
        DesignFamily.tornHero,
      ];
      var seedCounter = 1;
      for (final entry in allocation.entries) {
        final cluster = entry.key;
        final labStyles = kClusterToLabStyles[cluster] ?? [];
        final styleName = labStyles.isNotEmpty ? labStyles.first : 'showcase';
        for (var i = 0; i < entry.value; i++) {
          pool.add(DesignRecipe(
            seed: seedCounter++,
            content: const RecipeContent(flags: [FlagRef('jp')]),
            composition: Composition(
                family: families[seedCounter % families.length]),
            clip: Clip(shapeId: shapes[seedCounter % shapes.length]),
            palette: Palette(
              garmentColour:
                  seedCounter.isEven ? '#1A1A1A' : '#FFFFFF',
              vintageGrade: (seedCounter % 10) / 10,
            ),
            provenance: RecipeProvenance(generator: 'lab:$styleName'),
          ));
        }
      }

      expect(pool.length, greaterThanOrEqualTo(60));

      // 3. Score.
      const scorer = PreferenceScorer();
      final scored = pool
          .map((r) => (r, scorer.score(r, prefs)))
          .toList()
        ..sort((a, b) => b.$2.compareTo(a.$2));

      // Best scores should come from preferred clusters.
      final topCluster = _clusterOf(scored.first.$1);
      expect(
        topCluster == StyleCluster.bold || topCluster == StyleCluster.vintage,
        isTrue,
        reason: 'Top-scored recipe should be from a preferred cluster',
      );

      // 4. Diversity select.
      const selector = DiversitySelector();
      final result = selector.select(scored, count: 8);

      expect(result.length, lessThanOrEqualTo(8));
      expect(result.length, greaterThanOrEqualTo(2));

      // Verify style diversity: no more than 2 per cluster.
      final styleTally = <StyleCluster, int>{};
      for (final r in result) {
        final c = _clusterOf(r);
        if (c != null) styleTally[c] = (styleTally[c] ?? 0) + 1;
      }
      for (final entry in styleTally.entries) {
        expect(entry.value, lessThanOrEqualTo(2),
            reason: '${entry.key.name} should have at most 2');
      }

      // Verify composition diversity: no more than 1 per family.
      final familyTally = <DesignFamily, int>{};
      for (final r in result) {
        familyTally[r.composition.family] =
            (familyTally[r.composition.family] ?? 0) + 1;
      }
      for (final entry in familyTally.entries) {
        expect(entry.value, lessThanOrEqualTo(1),
            reason: '${entry.key.name} should have at most 1');
      }
    });

    test('neutral preferences still produce diverse output', () {
      final prefs = DesignPreferences.neutral;
      const sampler = StratifiedSampler();
      final rng = DeterministicRng(1);
      final allocation =
          sampler.allocate(prefs, poolSize: 30, rng: rng);

      // All clusters should get some allocation.
      for (final c in StyleCluster.values) {
        expect(allocation[c], greaterThanOrEqualTo(1));
      }
    });
  });
}

StyleCluster? _clusterOf(DesignRecipe r) {
  final gen = r.provenance?.generator;
  if (gen == null || !gen.startsWith('lab:')) return null;
  final styleName = gen.substring(4);
  for (final entry in kClusterToLabStyles.entries) {
    if (entry.value.contains(styleName)) return entry.key;
  }
  return null;
}
