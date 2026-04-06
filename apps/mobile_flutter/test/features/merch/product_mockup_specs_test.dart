// M55-A — ProductMockupSpecs registry unit tests

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/merch/merch_variant_lookup.dart';
import 'package:mobile_flutter/features/merch/product_mockup_specs.dart';

void main() {
  group('M55-A — ProductMockupSpecs registry', () {
    test('specsFor returns a spec for all tshirt colour × placement combos', () {
      const colours = ['Black', 'White', 'Navy', 'Heather Grey', 'Red'];
      const placements = ['front', 'back'];
      for (final colour in colours) {
        for (final placement in placements) {
          final spec = ProductMockupSpecs.specsFor(
            MerchProduct.tshirt,
            colour: colour,
            placement: placement,
          );
          expect(spec.assetPath, isNotEmpty,
              reason: 'assetPath must be non-empty for $colour/$placement');
          expect(spec.assetPath, contains('mockups/'),
              reason: 'assetPath must reference assets/mockups/');
          expect(spec.printAreaNorm.left, greaterThanOrEqualTo(0.0));
          expect(spec.printAreaNorm.top, greaterThanOrEqualTo(0.0));
          expect(spec.printAreaNorm.right, lessThanOrEqualTo(1.0));
          expect(spec.printAreaNorm.bottom, lessThanOrEqualTo(1.0));
        }
      }
    });

    test('specsFor poster returns a spec regardless of colour/placement', () {
      final spec = ProductMockupSpecs.specsFor(MerchProduct.poster);
      expect(spec.assetPath, contains('poster_a4.png'));
      expect(spec.printAreaNorm.left, greaterThanOrEqualTo(0.0));
      expect(spec.printAreaNorm.bottom, lessThanOrEqualTo(1.0));
    });

    test('specsFor poster ignores colour and placement params', () {
      final spec1 = ProductMockupSpecs.specsFor(MerchProduct.poster,
          colour: 'Black', placement: 'front');
      final spec2 = ProductMockupSpecs.specsFor(MerchProduct.poster,
          colour: 'White', placement: 'back');
      expect(spec1.assetPath, equals(spec2.assetPath));
    });

    test('specsFor tshirt Black/front returns photoreal JPG asset (M59)', () {
      final spec = ProductMockupSpecs.specsFor(MerchProduct.tshirt,
          colour: 'Black', placement: 'front');
      expect(spec.assetPath, 'assets/mockups/shirt-mockup-final.jpg');
      expect(spec.printAreaNorm, equals(const Rect.fromLTWH(0.30, 0.32, 0.40, 0.45)));
      expect(spec.srcRectNorm, equals(const Rect.fromLTWH(0.0, 0.0, 0.5, 1.0)));
    });

    test('specsFor tshirt Heather Grey/back uses same JPG asset (M59)', () {
      final spec = ProductMockupSpecs.specsFor(MerchProduct.tshirt,
          colour: 'Heather Grey', placement: 'back');
      expect(spec.assetPath, 'assets/mockups/shirt-mockup-final.jpg');
      expect(spec.srcRectNorm, equals(const Rect.fromLTWH(0.5, 0.0, 0.5, 1.0)));
    });

    test('specsFor throws ArgumentError for unknown tshirt combination', () {
      expect(
        () => ProductMockupSpecs.specsFor(MerchProduct.tshirt,
            colour: 'Purple', placement: 'front'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('printAreaNorm stays within unit square', () {
      const colours = ['Black', 'White', 'Navy', 'Heather Grey', 'Red'];
      for (final colour in colours) {
        final spec = ProductMockupSpecs.specsFor(MerchProduct.tshirt,
            colour: colour, placement: 'front');
        expect(spec.printAreaNorm.left, greaterThanOrEqualTo(0.0));
        expect(spec.printAreaNorm.top, greaterThanOrEqualTo(0.0));
        expect(spec.printAreaNorm.right, lessThanOrEqualTo(1.0));
        expect(spec.printAreaNorm.bottom, lessThanOrEqualTo(1.0));
      }
    });
  });
}
