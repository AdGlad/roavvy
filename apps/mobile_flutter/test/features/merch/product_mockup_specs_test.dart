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
      // At Large the print area equals the placement's full printable rect.
      final large = ProductMockupSpecs.specsFor(
        MerchProduct.tshirt,
        colour: 'Black',
        placement: 'front',
        frontPosition: 'left_chest',
        imageSize: ImageSize.large,
      );
      expect(
        large.printAreaNorm,
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

  // ── M190 — Image Size as a fill fraction of a fixed printable area ─────────

  group('M190 — ImageSize.fillFraction', () {
    test('large fills the whole printable area (1.0)', () {
      expect(ImageSize.large.fillFraction, 1.0);
    });

    test('small < medium < large, all within (0, 1]', () {
      expect(ImageSize.small.fillFraction, lessThan(ImageSize.medium.fillFraction));
      expect(ImageSize.medium.fillFraction, lessThan(ImageSize.large.fillFraction));
      for (final s in ImageSize.values) {
        expect(s.fillFraction, greaterThan(0.0));
        expect(s.fillFraction, lessThanOrEqualTo(1.0));
      }
    });

    test('fromName tolerates missing / unknown values → medium', () {
      expect(ImageSize.fromName('small'), ImageSize.small);
      expect(ImageSize.fromName('medium'), ImageSize.medium);
      expect(ImageSize.fromName('large'), ImageSize.large);
      expect(ImageSize.fromName(null), ImageSize.medium);
      expect(ImageSize.fromName('gigantic'), ImageSize.medium);
    });
  });

  group('M190 — specsFor image size within a fixed printable area', () {
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

    const placements = <(String, String)>[
      ('front', 'left_chest'),
      ('front', 'center'),
      ('front', 'right_chest'),
      ('back', 'center'),
    ];

    test('Large equals the full printable area; Medium/Small are smaller', () {
      for (final p in placements) {
        final large = areaFor(p.$1, p.$2, ImageSize.large);
        final medium = areaFor(p.$1, p.$2, ImageSize.medium);
        final small = areaFor(p.$1, p.$2, ImageSize.small);
        expect(small.width, lessThan(medium.width), reason: '${p.$2} S<M');
        expect(medium.width, lessThan(large.width), reason: '${p.$2} M<L');
        // Never exceeds the printable (Large) area.
        expect(medium.width, lessThanOrEqualTo(large.width));
        expect(large.height, lessThanOrEqualTo(1.0));
      }
    });

    test('every size is centred on the same point (scaled about the centre)', () {
      for (final p in placements) {
        final large = areaFor(p.$1, p.$2, ImageSize.large);
        for (final size in ImageSize.values) {
          expectOffsetClose(centreOf(areaFor(p.$1, p.$2, size)), centreOf(large));
        }
      }
    });

    test('aspect ratio is preserved across sizes (uniform scaling)', () {
      for (final p in placements) {
        final large = areaFor(p.$1, p.$2, ImageSize.large);
        final largeAr = large.width / large.height;
        for (final size in ImageSize.values) {
          final r = areaFor(p.$1, p.$2, size);
          expect(r.width / r.height, closeTo(largeAr, 1e-9));
        }
      }
    });

    test('back printable area matches the Printful 12x16 aspect (0.75)', () {
      final back = areaFor('back', 'center', ImageSize.large);
      expect(back.width / back.height, closeTo(0.75, 1e-3));
    });

    test('Medium is the default when imageSize is omitted', () {
      final spec = ProductMockupSpecs.specsFor(
        MerchProduct.tshirt,
        colour: 'Black',
        placement: 'back',
      );
      expect(spec.printAreaNorm, areaFor('back', 'center', ImageSize.medium));
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
