import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/cards/stamp_shape_distorter.dart';

void main() {
  group('StampShapeDistorter.distortedCircle', () {
    test('returns a closed path (non-empty)', () {
      final path = StampShapeDistorter.distortedCircle(Offset.zero, 40.0, 42);
      expect(path.getBounds().isEmpty, isFalse);
    });

    test('same seed produces identical bounding boxes', () {
      final a = StampShapeDistorter.distortedCircle(Offset.zero, 40.0, 42);
      final b = StampShapeDistorter.distortedCircle(Offset.zero, 40.0, 42);
      expect(a.getBounds(), b.getBounds());
    });

    test('different seeds produce different bounding boxes', () {
      final a = StampShapeDistorter.distortedCircle(Offset.zero, 40.0, 42);
      final b = StampShapeDistorter.distortedCircle(Offset.zero, 40.0, 99);
      expect(a.getBounds(), isNot(b.getBounds()));
    });

    test('bounding box is close to circle diameter (within 3%)', () {
      const radius = 40.0;
      final path = StampShapeDistorter.distortedCircle(Offset.zero, radius, 1);
      final bounds = path.getBounds();
      final expectedDiameter = radius * 2;
      // Allow ±3% (max distortion is 2.5% of radius per vertex)
      expect(bounds.width, closeTo(expectedDiameter, expectedDiameter * 0.06));
      expect(bounds.height, closeTo(expectedDiameter, expectedDiameter * 0.06));
    });
  });

  group('StampShapeDistorter.distortedRect', () {
    test('returns an RRect with bounds matching the input rect', () {
      const rect = Rect.fromLTWH(0, 0, 100, 60);
      final rrect = StampShapeDistorter.distortedRect(rect, 8.0, 42);
      expect(rrect.outerRect, rect);
    });

    test('corner radii deviate at most 2px from nominal', () {
      const nominal = 8.0;
      const rect = Rect.fromLTWH(0, 0, 100, 60);
      final rrect = StampShapeDistorter.distortedRect(rect, nominal, 42);
      for (final r in [
        rrect.tlRadiusX,
        rrect.trRadiusX,
        rrect.blRadiusX,
        rrect.brRadiusX,
      ]) {
        expect(r, greaterThanOrEqualTo(0));
        expect((r - nominal).abs(), lessThanOrEqualTo(2.1));
      }
    });

    test('same seed produces same corner radii', () {
      const rect = Rect.fromLTWH(0, 0, 100, 60);
      final a = StampShapeDistorter.distortedRect(rect, 8.0, 42);
      final b = StampShapeDistorter.distortedRect(rect, 8.0, 42);
      expect(a.tlRadiusX, b.tlRadiusX);
      expect(a.brRadiusX, b.brRadiusX);
    });
  });

  group('StampShapeDistorter.distortedBorderWidth', () {
    test('variation stays within ±15% of nominal', () {
      const nominal = 2.0;
      for (var side = 0; side < 4; side++) {
        final w = StampShapeDistorter.distortedBorderWidth(nominal, 42, side);
        expect(w, greaterThanOrEqualTo(nominal * 0.85));
        expect(w, lessThanOrEqualTo(nominal * 1.15));
      }
    });

    test('different sides produce different widths', () {
      const nominal = 2.0;
      final widths = List.generate(
        4,
        (i) => StampShapeDistorter.distortedBorderWidth(nominal, 42, i),
      ).toSet();
      expect(widths.length, greaterThanOrEqualTo(2));
    });
  });
}
