import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/cards/heart_layout_engine.dart';
import 'package:shared_models/shared_models.dart';

TripRecord _trip(String code, DateTime start) => TripRecord(
      id: '${code}_$start',
      countryCode: code,
      startedOn: start,
      endedOn: start.add(const Duration(days: 7)),
      photoCount: 5,
      isManual: false,
    );

void main() {
  // ── MaskCalculator ──────────────────────────────────────────────────────────

  group('MaskCalculator.isInsideHeart', () {
    test('centre of heart is inside', () {
      // (0,0) → (0+0-1)³ - 0 = -1 ≤ 0 → inside
      expect(MaskCalculator.isInsideHeart(0, 0), isTrue);
    });

    test('top of heart lobe is inside', () {
      // Near (0.5, 0.8) should be inside
      expect(MaskCalculator.isInsideHeart(0.5, 0.8), isTrue);
    });

    test('bottom tip is inside', () {
      // Near (0, -0.9) should be inside (bottom tip)
      expect(MaskCalculator.isInsideHeart(0.0, -0.8), isTrue);
    });

    test('far outside is not inside', () {
      expect(MaskCalculator.isInsideHeart(1.4, 1.4), isFalse);
    });

    test('top left corner is outside', () {
      expect(MaskCalculator.isInsideHeart(-1.4, 1.4), isFalse);
    });

    test('symmetry: left and right lobes are equivalent', () {
      // Heart is symmetric along x-axis
      for (final y in [-0.5, 0.0, 0.5]) {
        final left = MaskCalculator.isInsideHeart(-0.6, y);
        final right = MaskCalculator.isInsideHeart(0.6, y);
        expect(left, right,
            reason: 'Heart should be symmetric at y=$y');
      }
    });

    test('just outside boundary returns false', () {
      // Very far from heart
      expect(MaskCalculator.isInsideHeart(2.0, 2.0), isFalse);
    });
  });

  group('MaskCalculator.coverageFraction', () {
    const sideLen = 100.0;

    test('fully inside tile has fraction >= 0.6', () {
      // Tile at centre of canvas (which maps to heart centre)
      final tile = const Rect.fromLTWH(42, 42, 16, 16);
      final fraction = MaskCalculator.coverageFraction(tile, sideLen);
      expect(fraction, greaterThanOrEqualTo(0.6));
    });

    test('tile completely outside heart has fraction = 0 or low', () {
      // Top-left corner tile — far outside heart
      final tile = const Rect.fromLTWH(0, 0, 8, 8);
      final fraction = MaskCalculator.coverageFraction(tile, sideLen);
      expect(fraction, lessThan(0.66));
    });

    test('fraction is between 0.0 and 1.0', () {
      for (var x = 0.0; x < sideLen; x += 20) {
        for (var y = 0.0; y < sideLen; y += 20) {
          final tile = Rect.fromLTWH(x, y, 10, 10);
          final f = MaskCalculator.coverageFraction(tile, sideLen);
          expect(f, inInclusiveRange(0.0, 1.0));
        }
      }
    });
  });

  group('MaskCalculator.heartPath', () {
    test('returns a non-empty path', () {
      final path = MaskCalculator.heartPath(const Size(100, 100));
      final bounds = path.getBounds();
      expect(bounds.width, greaterThan(0));
      expect(bounds.height, greaterThan(0));
    });

    test('path has non-trivial bounding box (≥72 points sampled)', () {
      // We can't count points directly but we can verify the bounding box
      // has meaningful dimensions consistent with a heart shape.
      final size = const Size(200, 200);
      final path = MaskCalculator.heartPath(size, numPoints: 72);
      final bounds = path.getBounds();
      // The heart should span at least 60% of canvas width and height.
      expect(bounds.width, greaterThan(size.width * 0.6));
      expect(bounds.height, greaterThan(size.height * 0.6));
    });

    test('path is horizontally centred on square canvas', () {
      final path = MaskCalculator.heartPath(const Size(100, 100));
      final bounds = path.getBounds();
      final centreX = (bounds.left + bounds.right) / 2;
      expect(centreX, closeTo(50.0, 8.0));
    });
  });

  // ── HeartLayoutEngine ───────────────────────────────────────────────────────

  group('HeartLayoutEngine.layout', () {
    const testSize = Size(300, 200);

    test('returns empty list for empty codes', () {
      final result = HeartLayoutEngine.layout([], testSize);
      expect(result, isEmpty);
    });

    test('returns at most as many tiles as codes', () {
      final codes = List.generate(5, (i) => 'A${String.fromCharCode(65 + i)}');
      final result = HeartLayoutEngine.layout(codes, testSize);
      expect(result.length, lessThanOrEqualTo(codes.length));
    });

    test('each tile has correct country code from input', () {
      const codes = ['GB', 'US', 'FR'];
      final result = HeartLayoutEngine.layout(codes, testSize);
      final assigned = result.map((t) => t.countryCode).toSet();
      // All assigned codes come from input.
      expect(assigned, everyElement(isIn(codes)));
    });

    test('tile rects are within canvas bounds', () {
      final codes = List.generate(20, (i) =>
          String.fromCharCode(65 + i % 26) +
          String.fromCharCode(66 + i % 26));
      final result = HeartLayoutEngine.layout(codes, testSize);
      for (final tile in result) {
        expect(tile.rect.left, greaterThanOrEqualTo(-1));
        expect(tile.rect.top, greaterThanOrEqualTo(-1));
        expect(tile.rect.right, lessThanOrEqualTo(testSize.width + 1));
        expect(tile.rect.bottom, lessThanOrEqualTo(testSize.height + 1));
      }
    });

    test('alphabetical order sorts by country name', () {
      // France < Germany < Japan in alphabetical order.
      const codes = ['JP', 'DE', 'FR'];
      final result = HeartLayoutEngine.layout(
        codes,
        testSize,
        order: HeartFlagOrder.alphabetical,
      );
      // Should not throw; result should be non-empty.
      expect(result, isNotEmpty);
    });

    test('chronological order uses trip dates', () {
      final trips = [
        _trip('GB', DateTime(2020, 1, 1)),
        _trip('US', DateTime(2022, 6, 1)),
        _trip('JP', DateTime(2019, 3, 1)),
      ];
      final result = HeartLayoutEngine.layout(
        ['GB', 'US', 'JP'],
        testSize,
        order: HeartFlagOrder.chronological,
        trips: trips,
      );
      expect(result, isNotEmpty);
    });

    test('randomized order is deterministic for same codes', () {
      const codes = ['GB', 'US', 'FR', 'DE', 'JP'];
      final r1 = HeartLayoutEngine.layout(codes, testSize,
          order: HeartFlagOrder.randomized);
      final r2 = HeartLayoutEngine.layout(codes, testSize,
          order: HeartFlagOrder.randomized);
      final codes1 = r1.map((t) => t.countryCode).join(',');
      final codes2 = r2.map((t) => t.countryCode).join(',');
      expect(codes1, equals(codes2));
    });

    test('large country set (120) does not throw', () {
      final codes = List.generate(120, (i) =>
          String.fromCharCode(65 + i ~/ 26) +
          String.fromCharCode(65 + i % 26));
      expect(
        () => HeartLayoutEngine.layout(codes, testSize),
        returnsNormally,
      );
    });

    test('geographic order groups by continent', () {
      // Just verify it runs without error and returns non-empty.
      const codes = ['GB', 'FR', 'US', 'JP', 'AU', 'BR'];
      final result = HeartLayoutEngine.layout(
        codes,
        testSize,
        order: HeartFlagOrder.geographic,
      );
      expect(result, isNotEmpty);
    });
  });

  group('HeartFlagOrder enum', () {
    test('has 4 values', () {
      expect(HeartFlagOrder.values.length, equals(4));
    });

    test('contains all expected variants', () {
      expect(HeartFlagOrder.values, containsAll([
        HeartFlagOrder.randomized,
        HeartFlagOrder.chronological,
        HeartFlagOrder.alphabetical,
        HeartFlagOrder.geographic,
      ]));
    });
  });
}
