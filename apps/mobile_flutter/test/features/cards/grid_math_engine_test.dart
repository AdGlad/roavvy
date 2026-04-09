import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/cards/grid_math_engine.dart';

void main() {
  group('GridMathEngine', () {
    test('handles 0 items gracefully', () {
      final result = GridMathEngine.calculate(width: 100, height: 100, itemCount: 0);
      expect(result.columns, 0);
      expect(result.rows, 0);
      expect(result.itemWidth, 0);
      expect(result.itemHeight, 0);
    });

    test('handles 1 item in square bounds', () {
      final result = GridMathEngine.calculate(width: 100, height: 100, itemCount: 1);
      expect(result.columns, 1);
      expect(result.rows, 1);
      // aspect ratio is 4:3 (1.333)
      // width bounded by width = 100 -> height = 75
      expect(result.itemWidth, 100);
      expect(result.itemHeight, 75);
    });

    test('handles 2 items in landscape bounds', () {
      final result = GridMathEngine.calculate(width: 200, height: 100, itemCount: 2);
      expect(result.columns, 2);
      expect(result.rows, 1);
      // Each cell gets 100x100 space, so same as 1 item in square bounds
      expect(result.itemWidth, 100);
      expect(result.itemHeight, 75);
    });

    test('calculates optimal layout for a prime number of items (7)', () {
      final result = GridMathEngine.calculate(width: 400, height: 300, itemCount: 7);
      // Available area: 400x300.
      // E.g., 3 cols, 3 rows -> cell width: 400/3=133.3, cell height: 300/3=100.
      // Cell width limited by height: 100 * 4/3 = 133.3.
      // Thus itemWidth is ~133.3.
      expect(result.columns, 3);
      expect(result.rows, 3);
      expect(result.itemWidth, closeTo(133.33, 0.1));
      expect(result.itemHeight, closeTo(100.0, 0.1));
    });

    test('handles wide aspect ratio container with many items', () {
      final result = GridMathEngine.calculate(width: 800, height: 200, itemCount: 20);
      // Extremely wide. We should have many columns and few rows.
      // Let's just ensure it calculated a valid layout.
      expect(result.columns * result.rows, greaterThanOrEqualTo(20));
      expect(result.itemWidth * result.columns, lessThanOrEqualTo(800.001));
      expect(result.itemHeight * result.rows, lessThanOrEqualTo(200.001));
    });
  });
}
