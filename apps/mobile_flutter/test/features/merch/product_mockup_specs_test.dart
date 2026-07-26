import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/merch/merch_variant_lookup.dart';
import 'package:mobile_flutter/features/merch/product_mockup_specs.dart';

void main() {
  group('M55-A — ProductMockupSpecs registry', () {
    test(
      'specsFor returns a spec for all tshirt colour × placement combos',
      () {
        const colours = ['Black', 'White', 'Blue', 'Grey', 'Red'];
        const placements = ['front', 'back'];
        for (final colour in colours) {
          for (final placement in placements) {
            final spec = ProductMockupSpecs.specsFor(
              MerchProduct.tshirt,
              colour: colour,
              placement: placement,
            );
            expect(
              spec.assetPath,
              isNotEmpty,
              reason: 'assetPath must be non-empty for $colour/$placement',
            );
            expect(
              spec.assetPath,
              contains('mockups/'),
              reason: 'assetPath must reference assets/mockups/',
            );
            expect(spec.printAreaNorm.left, greaterThanOrEqualTo(0.0));
            expect(spec.printAreaNorm.top, greaterThanOrEqualTo(0.0));
            expect(spec.printAreaNorm.right, lessThanOrEqualTo(1.0));
            expect(spec.printAreaNorm.bottom, lessThanOrEqualTo(1.0));
          }
        }
      },
    );

    test('specsFor poster returns a spec regardless of colour/placement', () {
      final spec = ProductMockupSpecs.specsFor(MerchProduct.poster);
      expect(spec.assetPath, contains('poster_a4.png'));
      expect(spec.printAreaNorm.left, greaterThanOrEqualTo(0.0));
      expect(spec.printAreaNorm.bottom, lessThanOrEqualTo(1.0));
    });

    test('specsFor poster ignores colour and placement params', () {
      final spec1 = ProductMockupSpecs.specsFor(
        MerchProduct.poster,
        colour: 'Black',
        placement: 'front',
      );
      final spec2 = ProductMockupSpecs.specsFor(
        MerchProduct.poster,
        colour: 'White',
        placement: 'back',
      );
      expect(spec1.assetPath, equals(spec2.assetPath));
    });

    test('specsFor tshirt Black/front returns per-colour front JPEG asset', () {
      final spec = ProductMockupSpecs.specsFor(
        MerchProduct.tshirt,
        colour: 'Black',
        placement: 'front',
      );
      expect(spec.assetPath, 'assets/mockups/Black-tshirt-front.jpeg');
      expect(
        spec.printAreaNorm,
        equals(const Rect.fromLTWH(0.55, 0.25, 0.18, 0.25)),
      );
      expect(spec.srcRectNorm, isNull);
    });

    test('specsFor tshirt Grey/back uses per-colour back JPEG asset', () {
      final spec = ProductMockupSpecs.specsFor(
        MerchProduct.tshirt,
        colour: 'Grey',
        placement: 'back',
      );
      expect(spec.assetPath, 'assets/mockups/Grey-tshirt-back.jpeg');
      expect(spec.srcRectNorm, isNull);
    });

    test('specsFor throws ArgumentError for unknown tshirt combination', () {
      expect(
        () => ProductMockupSpecs.specsFor(
          MerchProduct.tshirt,
          colour: 'Purple',
          placement: 'front',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('printAreaNorm stays within unit square', () {
      const colours = ['Black', 'White', 'Blue', 'Grey', 'Red'];
      for (final colour in colours) {
        final spec = ProductMockupSpecs.specsFor(
          MerchProduct.tshirt,
          colour: colour,
          placement: 'front',
        );
        expect(spec.printAreaNorm.left, greaterThanOrEqualTo(0.0));
        expect(spec.printAreaNorm.top, greaterThanOrEqualTo(0.0));
        expect(spec.printAreaNorm.right, lessThanOrEqualTo(1.0));
        expect(spec.printAreaNorm.bottom, lessThanOrEqualTo(1.0));
      }
    });
  });

  // ── M189 — Image Size (Small / Medium / Large) print scale ─────────────────

  group('M189 — ImageSize.scaleMultiplier', () {
    test('medium is exactly the identity multiplier', () {
      expect(ImageSize.medium.scaleMultiplier, 1.0);
    });

    test('small shrinks and large grows relative to medium', () {
      expect(ImageSize.small.scaleMultiplier, lessThan(1.0));
      expect(ImageSize.large.scaleMultiplier, greaterThan(1.0));
    });

    test('fromName tolerates missing / unknown values → medium', () {
      expect(ImageSize.fromName('small'), ImageSize.small);
      expect(ImageSize.fromName('medium'), ImageSize.medium);
      expect(ImageSize.fromName('large'), ImageSize.large);
      expect(ImageSize.fromName(null), ImageSize.medium);
      expect(ImageSize.fromName('gigantic'), ImageSize.medium);
    });
  });

  group('M189 — specsFor imageSize scaling', () {
    // Base constants (mirrors product_mockup_specs.dart).
    const leftChest = Rect.fromLTWH(0.55, 0.25, 0.18, 0.25);
    const center = Rect.fromLTWH(0.25, 0.22, 0.50, 0.40);
    const rightChest = Rect.fromLTWH(0.27, 0.25, 0.18, 0.25);
    const back = Rect.fromLTWH(0.30, 0.22, 0.40, 0.50);

    Rect areaFor(
      String placement,
      String frontPosition,
      ImageSize size,
    ) => ProductMockupSpecs.specsFor(
      MerchProduct.tshirt,
      colour: 'Black',
      placement: placement,
      frontPosition: frontPosition,
      imageSize: size,
    ).printAreaNorm;

    Offset centreOf(Rect r) => Offset(r.left + r.width / 2, r.top + r.height / 2);

    void expectOffsetClose(Offset a, Offset b) {
      expect(a.dx, closeTo(b.dx, 1e-9));
      expect(a.dy, closeTo(b.dy, 1e-9));
    }

    test('(a) Medium == current constants exactly for every placement', () {
      expect(areaFor('front', 'left_chest', ImageSize.medium), leftChest);
      expect(areaFor('front', 'center', ImageSize.medium), center);
      expect(areaFor('front', 'right_chest', ImageSize.medium), rightChest);
      expect(areaFor('back', 'center', ImageSize.medium), back);
    });

    test('(a) Medium is the default when imageSize is omitted', () {
      final spec = ProductMockupSpecs.specsFor(
        MerchProduct.tshirt,
        colour: 'Black',
        placement: 'front',
        frontPosition: 'center',
      );
      expect(spec.printAreaNorm, center);
    });

    test('(b) Small shrinks about the same centre', () {
      for (final entry in <(String, String, Rect)>[
        ('front', 'left_chest', leftChest),
        ('front', 'center', center),
        ('front', 'right_chest', rightChest),
        ('back', 'center', back),
      ]) {
        final small = areaFor(entry.$1, entry.$2, ImageSize.small);
        final base = entry.$3;
        expect(
          small.width,
          lessThan(base.width),
          reason: '${entry.$2} Small width should shrink',
        );
        expect(small.height, lessThan(base.height));
        expectOffsetClose(centreOf(small), centreOf(base));
      }
    });

    test('(c) Large grows about the same centre and stays in [0,1]', () {
      for (final entry in <(String, String, Rect)>[
        ('front', 'center', center),
        ('back', 'center', back),
      ]) {
        final large = areaFor(entry.$1, entry.$2, ImageSize.large);
        final base = entry.$3;
        expect(large.width, greaterThan(base.width));
        expect(large.height, greaterThan(base.height));
        expectOffsetClose(centreOf(large), centreOf(base));
        expect(large.left, greaterThanOrEqualTo(0.0));
        expect(large.top, greaterThanOrEqualTo(0.0));
        expect(large.right, lessThanOrEqualTo(1.0));
        expect(large.bottom, lessThanOrEqualTo(1.0));
      }
    });

    test('(d) left-chest Large is capped below the raw 1.3x and stays in [0,1]',
        () {
      final large = areaFor('front', 'left_chest', ImageSize.large);
      // Raw 1.3x would be 0.234 x 0.325; the per-placement cap holds it smaller.
      expect(large.width, lessThan(leftChest.width * 1.3));
      expect(large.height, lessThan(leftChest.height * 1.3));
      // Still bigger than Medium, and centred on the same point.
      expect(large.width, greaterThan(leftChest.width));
      expectOffsetClose(centreOf(large), centreOf(leftChest));
      // On-garment: within the unit square.
      expect(large.left, greaterThanOrEqualTo(0.0));
      expect(large.top, greaterThanOrEqualTo(0.0));
      expect(large.right, lessThanOrEqualTo(1.0));
      expect(large.bottom, lessThanOrEqualTo(1.0));
    });

    test('right-chest Large is likewise capped and stays in [0,1]', () {
      final large = areaFor('front', 'right_chest', ImageSize.large);
      expect(large.width, lessThan(rightChest.width * 1.3));
      expect(large.height, lessThan(rightChest.height * 1.3));
      expectOffsetClose(centreOf(large), centreOf(rightChest));
      expect(large.left, greaterThanOrEqualTo(0.0));
      expect(large.right, lessThanOrEqualTo(1.0));
      expect(large.bottom, lessThanOrEqualTo(1.0));
    });

    test('every placement × size stays within the unit square', () {
      for (final placement in ['front', 'back']) {
        for (final pos in ['left_chest', 'center', 'right_chest']) {
          for (final size in ImageSize.values) {
            final r = areaFor(placement, pos, size);
            expect(r.left, greaterThanOrEqualTo(0.0));
            expect(r.top, greaterThanOrEqualTo(0.0));
            expect(r.right, lessThanOrEqualTo(1.0));
            expect(r.bottom, lessThanOrEqualTo(1.0));
          }
        }
      }
    });
  });
}
