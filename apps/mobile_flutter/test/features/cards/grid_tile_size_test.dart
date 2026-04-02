import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/cards/card_templates.dart';

void main() {
  group('gridTileSize (ADR-102 M50-C1)', () {
    // Formula: clamp(floor(sqrt(canvasArea / n) * 0.85), 28, 90)

    test('N=1 on square 100×100 canvas fills >80% of canvas width', () {
      const canvasW = 100.0;
      final ts = gridTileSize(canvasW * canvasW, 1);
      // floor(sqrt(10000) * 0.85) = floor(85) = 85 → clamp(85,28,90)=85
      expect(ts, equals(85.0));
      expect(ts / canvasW, greaterThan(0.8));
    });

    test('N=5: tile size at maximum (90)', () {
      // sqrt(300*200/5)*0.85 = sqrt(12000)*0.85 ≈ 93 → clamped to 90
      final ts = gridTileSize(300.0 * 200.0, 5);
      expect(ts, equals(90.0));
    });

    test('N=20: tile size in range', () {
      // sqrt(300*200/20)*0.85 = sqrt(3000)*0.85 ≈ 46.6 → floor=46
      final ts = gridTileSize(300.0 * 200.0, 20);
      expect(ts, equals(46.0));
    });

    test('N=50: tile size near minimum', () {
      // sqrt(300*200/50)*0.85 = sqrt(1200)*0.85 ≈ 29.4 → floor=29
      final ts = gridTileSize(300.0 * 200.0, 50);
      expect(ts, equals(29.0));
    });

    test('N=100: tile size at minimum (28)', () {
      // sqrt(300*200/100)*0.85 = sqrt(600)*0.85 ≈ 20.8 → floor=20 → clamp=28
      final ts = gridTileSize(300.0 * 200.0, 100);
      expect(ts, equals(28.0));
    });

    test('N=200: tile size at minimum (28)', () {
      // sqrt(300*200/200)*0.85 = sqrt(300)*0.85 ≈ 14.7 → floor=14 → clamp=28
      final ts = gridTileSize(300.0 * 200.0, 200);
      expect(ts, equals(28.0));
    });

    test('minimum tile is always ≥28', () {
      for (final n in [1, 5, 20, 50, 100, 200, 500]) {
        final ts = gridTileSize(300.0 * 200.0, n);
        expect(ts, greaterThanOrEqualTo(28.0),
            reason: 'N=$n must produce tileSize ≥ 28');
      }
    });

    test('maximum tile is always ≤90', () {
      for (final n in [1, 2, 3]) {
        final ts = gridTileSize(300.0 * 200.0, n);
        expect(ts, lessThanOrEqualTo(90.0),
            reason: 'N=$n must produce tileSize ≤ 90');
      }
    });
  });
}
