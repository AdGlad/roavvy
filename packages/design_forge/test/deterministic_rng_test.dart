import 'package:design_forge/design_forge.dart';
import 'package:test/test.dart';

void main() {
  group('DeterministicRng', () {
    test('same seed reproduces the same sequence', () {
      final a = DeterministicRng(42);
      final b = DeterministicRng(42);
      final seqA = [for (var i = 0; i < 50; i++) a.nextInt(1000)];
      final seqB = [for (var i = 0; i < 50; i++) b.nextInt(1000)];
      expect(seqA, seqB);
    });

    test('different seeds diverge', () {
      final ra = DeterministicRng(1);
      final rb = DeterministicRng(2);
      final a = [for (var i = 0; i < 20; i++) ra.nextInt(1 << 30)];
      final b = [for (var i = 0; i < 20; i++) rb.nextInt(1 << 30)];
      expect(a, isNot(equals(b)));
    });

    test('named sub-streams are independent and reproducible', () {
      final root = DeterministicRng(7);
      final layout1 = root.stream('layout');
      final layout2 = DeterministicRng(7).stream('layout');
      final palette = DeterministicRng(7).stream('palette');

      final l1 = [for (var i = 0; i < 10; i++) layout1.nextDouble()];
      final l2 = [for (var i = 0; i < 10; i++) layout2.nextDouble()];
      final p = [for (var i = 0; i < 10; i++) palette.nextDouble()];

      expect(l1, l2, reason: 'same name + seed reproduces');
      expect(l1, isNot(equals(p)), reason: 'different names diverge');
    });

    test('nextDouble stays in [0,1) and weighted pick respects zero weights',
        () {
      final r = DeterministicRng(99);
      for (var i = 0; i < 200; i++) {
        final d = r.nextDouble();
        expect(d, greaterThanOrEqualTo(0.0));
        expect(d, lessThan(1.0));
      }
      // weight 0 for index 0 should never be chosen.
      final counts = [0, 0, 0];
      final rr = DeterministicRng(5);
      for (var i = 0; i < 500; i++) {
        counts[rr.pickWeightedIndex(const [0.0, 1.0, 3.0])]++;
      }
      expect(counts[0], 0);
      expect(counts[2], greaterThan(counts[1]));
    });

    test('hashString is stable', () {
      expect(DeterministicRng.hashString('europe:2024'),
          DeterministicRng.hashString('europe:2024'));
    });
  });
}
