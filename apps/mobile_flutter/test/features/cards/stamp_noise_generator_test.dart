import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/cards/stamp_noise_generator.dart';

void main() {
  group('StampNoiseGenerator', () {
    test('bleedSigma returns value in [1.0, 3.0]', () {
      for (final seed in [0, 42, 999, -1, 0xDEAD]) {
        final sigma = StampNoiseGenerator.bleedSigma(seed);
        expect(sigma, greaterThanOrEqualTo(1.0));
        expect(sigma, lessThanOrEqualTo(3.0));
      }
    });

    test('bleedSigma is deterministic for same seed', () {
      expect(
        StampNoiseGenerator.bleedSigma(42),
        StampNoiseGenerator.bleedSigma(42),
      );
    });

    test('bleedSigma differs for different seeds (probabilistically)', () {
      final values = {0, 42, 999, 12345, 0xBEEF}
          .map(StampNoiseGenerator.bleedSigma)
          .toSet();
      // With 5 different seeds, expect at least 3 distinct sigma values
      expect(values.length, greaterThanOrEqualTo(3));
    });
  });
}
