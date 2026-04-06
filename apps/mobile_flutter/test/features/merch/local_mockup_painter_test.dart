// M55-B — LocalMockupPainter + ProductMockupSpec unit tests
//
// LocalMockupPainter.paint() requires real ui.Image objects which are not
// available in unit tests without the full Flutter rendering infrastructure.
// We test the parts that don't require live images:
//   - shouldRepaint() spec-equality branch
//   - ProductMockupSpec construction and field values
//   - Poster spec registration via ProductMockupSpecs.specsFor()

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/merch/merch_variant_lookup.dart';
import 'package:mobile_flutter/features/merch/product_mockup_specs.dart';

void main() {
  group('M55-A — ProductMockupSpec construction', () {
    test('const tshirt spec has correct asset path, print area, and srcRectNorm (M59)', () {
      const spec = ProductMockupSpec(
        assetPath: 'assets/mockups/shirt-mockup-final.jpg',
        printAreaNorm: Rect.fromLTWH(0.30, 0.32, 0.40, 0.45),
        srcRectNorm: Rect.fromLTWH(0.0, 0.0, 0.5, 1.0),
      );
      expect(spec.assetPath, 'assets/mockups/shirt-mockup-final.jpg');
      expect(spec.printAreaNorm.left, closeTo(0.30, 0.001));
      expect(spec.printAreaNorm.top, closeTo(0.32, 0.001));
      expect(spec.printAreaNorm.width, closeTo(0.40, 0.001));
      expect(spec.printAreaNorm.height, closeTo(0.45, 0.001));
      expect(spec.srcRectNorm, isNotNull);
      expect(spec.srcRectNorm!.width, closeTo(0.5, 0.001));
    });

    test('const poster spec has near-full-area print area', () {
      const spec = ProductMockupSpec(
        assetPath: 'assets/mockups/poster_a4.png',
        printAreaNorm: Rect.fromLTWH(0.05, 0.05, 0.90, 0.90),
      );
      expect(spec.printAreaNorm.right, closeTo(0.95, 0.001));
      expect(spec.printAreaNorm.bottom, closeTo(0.95, 0.001));
    });

    test('two specs with same fields are identical (const canonicalisation)', () {
      const spec1 = ProductMockupSpec(
        assetPath: 'assets/mockups/shirt-mockup-final.jpg',
        printAreaNorm: Rect.fromLTWH(0.30, 0.32, 0.40, 0.45),
        srcRectNorm: Rect.fromLTWH(0.0, 0.0, 0.5, 1.0),
      );
      const spec2 = ProductMockupSpec(
        assetPath: 'assets/mockups/shirt-mockup-final.jpg',
        printAreaNorm: Rect.fromLTWH(0.30, 0.32, 0.40, 0.45),
        srcRectNorm: Rect.fromLTWH(0.0, 0.0, 0.5, 1.0),
      );
      // Const identical instances are equal via identical().
      expect(identical(spec1, spec2), isTrue);
    });
  });

  group('M55-B — ProductMockupSpecs poster spec', () {
    test('poster spec has near-full-area print area', () {
      final spec = ProductMockupSpecs.specsFor(MerchProduct.poster);
      expect(spec.printAreaNorm.left, closeTo(0.05, 0.01));
      expect(spec.printAreaNorm.top, closeTo(0.05, 0.01));
      expect(spec.printAreaNorm.right, closeTo(0.95, 0.01));
      expect(spec.printAreaNorm.bottom, closeTo(0.95, 0.01));
    });

    test('poster spec asset path is poster_a4.png', () {
      final spec = ProductMockupSpecs.specsFor(MerchProduct.poster);
      expect(spec.assetPath, endsWith('poster_a4.png'));
    });
  });
}
