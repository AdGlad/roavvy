import 'package:design_forge/design_forge.dart';
import 'package:test/test.dart';

void main() {
  group('StratifiedSampler', () {
    const sampler = StratifiedSampler();

    test('allocation sums to poolSize', () {
      final rng = DeterministicRng(42);
      final alloc = sampler.allocate(
        DesignPreferences.neutral,
        poolSize: 150,
        rng: rng,
      );
      final total = alloc.values.fold<int>(0, (s, v) => s + v);
      // May exceed poolSize slightly due to the "at least 1" floor.
      expect(total, greaterThanOrEqualTo(150));
    });

    test('every cluster gets at least 1 recipe', () {
      final rng = DeterministicRng(1);
      final alloc = sampler.allocate(
        DesignPreferences.neutral,
        poolSize: 12,
        rng: rng,
      );
      for (final c in StyleCluster.values) {
        expect(alloc[c], greaterThanOrEqualTo(1),
            reason: '${c.name} should get at least 1');
      }
    });

    test('preferred cluster gets more allocation', () {
      final rng = DeterministicRng(7);
      final prefs = DesignPreferences(
        styleWeights: {StyleCluster.bold: 5.0, StyleCluster.clean: 0.2},
      );
      final alloc = sampler.allocate(prefs, poolSize: 100, rng: rng);
      expect(alloc[StyleCluster.bold]!, greaterThan(alloc[StyleCluster.clean]!));
    });

    test('deterministic: same seed produces same allocation', () {
      final prefs = DesignPreferences(
        styleWeights: {StyleCluster.vintage: 3.0},
      );
      final a = sampler.allocate(prefs, poolSize: 100, rng: DeterministicRng(99));
      final b = sampler.allocate(prefs, poolSize: 100, rng: DeterministicRng(99));
      for (final c in StyleCluster.values) {
        expect(a[c], equals(b[c]));
      }
    });
  });
}
