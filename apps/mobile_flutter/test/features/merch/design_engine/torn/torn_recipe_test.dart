import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/merch/design_engine/torn/torn_recipe.dart';

void main() {
  test('a curated family exists for every TearStyle', () {
    for (final s in TearStyle.values) {
      expect(kTornFamilies[s], isNotNull, reason: s.name);
    }
  });

  test('sampling is deterministic and reproducible', () {
    for (final s in TearStyle.values) {
      final a = sampleTornRecipe(s, 42);
      final b = sampleTornRecipe(s, 42);
      expect(a.tornId, b.tornId, reason: s.name);
    }
  });

  test('different seeds give materially different recipes', () {
    final a = sampleTornRecipe(TearStyle.ragged, 1);
    final b = sampleTornRecipe(TearStyle.ragged, 2);
    expect(a.tornId, isNot(b.tornId));
  });

  test('all sampled params are within sane bounds', () {
    for (final s in TearStyle.values) {
      for (var seed = 0; seed < 8; seed++) {
        final r = sampleTornRecipe(s, seed);
        for (final e in FlagEdge.values) {
          expect(r.edgeWeight(e), inInclusiveRange(0.0, 1.0));
        }
        expect(r.edgeDamageAmount, inInclusiveRange(0.0, 1.0));
        expect(r.maxTearDepth, inInclusiveRange(0.0, 0.45));
        expect(r.asymmetry, inInclusiveRange(0.0, 1.0));
        expect(r.frayAmount, inInclusiveRange(0.0, 1.0));
      }
    }
  });

  test('asymmetricTear concentrates damage on one edge', () {
    // Across seeds, the right (fly) edge should dominate the least-torn edge.
    var wins = 0;
    for (var seed = 0; seed < 12; seed++) {
      final r = sampleTornRecipe(TearStyle.asymmetricTear, seed);
      final maxW =
          FlagEdge.values.map(r.edgeWeight).reduce((a, b) => a > b ? a : b);
      final minW =
          FlagEdge.values.map(r.edgeWeight).reduce((a, b) => a < b ? a : b);
      if (maxW - minW > 0.5) wins++;
    }
    expect(wins, greaterThan(9), reason: 'asymmetric should be lopsided');
  });

  test('heavyEdgeDamage spreads damage across all edges', () {
    for (var seed = 0; seed < 8; seed++) {
      final r = sampleTornRecipe(TearStyle.heavyEdgeDamage, seed);
      for (final e in FlagEdge.values) {
        expect(r.edgeWeight(e), greaterThan(0.5), reason: '${e.name} @$seed');
      }
    }
  });

  test('lightlyWorn keeps a low-damage edge (asymmetry preserved)', () {
    // The hoist/top should stay much less torn than the fly/bottom.
    final r = sampleTornRecipe(TearStyle.lightlyWorn, 3);
    final primary = [r.edgeWeight(FlagEdge.right), r.edgeWeight(FlagEdge.bottom)]
        .reduce((a, b) => a > b ? a : b);
    final secondary = [r.edgeWeight(FlagEdge.left), r.edgeWeight(FlagEdge.top)]
        .reduce((a, b) => a < b ? a : b);
    expect(primary, greaterThan(secondary));
  });

  test('toJson carries the fields', () {
    final j = sampleTornRecipe(TearStyle.battleWorn, 7).toJson();
    expect(j.keys, containsAll(['style', 'edgeWeights', 'maxTearDepth', 'seed']));
    expect((j['edgeWeights'] as Map).length, 4);
  });
}
