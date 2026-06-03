// T2.3 — Merch variant lookup unit tests

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/merch/merch_variant_lookup.dart';

void main() {
  group('tshirtGids', () {
    test('contains entries for all colours × all sizes', () {
      for (final colour in tshirtColors) {
        for (final size in tshirtSizes) {
          expect(
            tshirtGids.containsKey((colour, size)),
            isTrue,
            reason: 'Missing t-shirt GID for ($colour, $size)',
          );
        }
      }
    });

    test('all GIDs are non-empty Shopify variant GID strings', () {
      for (final entry in tshirtGids.entries) {
        expect(
          entry.value.startsWith('gid://shopify/ProductVariant/'),
          isTrue,
          reason: 'Invalid GID format for ${entry.key}: ${entry.value}',
        );
      }
    });

    test('all GIDs are unique (no duplicate variant IDs)', () {
      final values = tshirtGids.values.toList();
      final unique = values.toSet();
      expect(
        unique.length,
        equals(values.length),
        reason: 'Duplicate Shopify GIDs found in tshirtGids',
      );
    });

    test('has correct total count: 5 colours × 5 sizes = 25', () {
      expect(tshirtGids.length, equals(25));
    });
  });

  group('posterGids', () {
    test('contains entries for all papers × all sizes', () {
      for (final paper in posterPapers) {
        for (final size in posterSizes) {
          expect(
            posterGids.containsKey((paper, size)),
            isTrue,
            reason: 'Missing poster GID for ($paper, $size)',
          );
        }
      }
    });

    test('all GIDs are non-empty Shopify variant GID strings', () {
      for (final entry in posterGids.entries) {
        expect(
          entry.value.startsWith('gid://shopify/ProductVariant/'),
          isTrue,
          reason: 'Invalid GID format for ${entry.key}: ${entry.value}',
        );
      }
    });

    test('all GIDs are unique', () {
      final values = posterGids.values.toList();
      final unique = values.toSet();
      expect(
        unique.length,
        equals(values.length),
        reason: 'Duplicate Shopify GIDs found in posterGids',
      );
    });

    test('has correct total count: 3 papers × 5 sizes = 15', () {
      expect(posterGids.length, equals(15));
    });
  });

  group('resolveVariantGid — t-shirt', () {
    test('resolves known Black L combination', () {
      final gid = resolveVariantGid(
        product: MerchProduct.tshirt,
        colour: 'Black',
        size: 'L',
      );
      expect(gid, equals(tshirtGids[('Black', 'L')]));
    });

    test('resolves known White S combination', () {
      final gid = resolveVariantGid(
        product: MerchProduct.tshirt,
        colour: 'White',
        size: 'S',
      );
      expect(gid, equals(tshirtGids[('White', 'S')]));
    });

    test('all t-shirt colour/size combos resolve without fallback', () {
      for (final colour in tshirtColors) {
        for (final size in tshirtSizes) {
          final gid = resolveVariantGid(
            product: MerchProduct.tshirt,
            colour: colour,
            size: size,
          );
          expect(
            gid,
            equals(tshirtGids[(colour, size)]),
            reason: 'Unexpected fallback for ($colour, $size)',
          );
        }
      }
    });

    test('unknown combination returns a non-empty fallback GID', () {
      final gid = resolveVariantGid(
        product: MerchProduct.tshirt,
        colour: 'Pink',
        size: '3XL',
      );
      expect(gid, isNotEmpty);
      expect(gid.startsWith('gid://shopify/ProductVariant/'), isTrue);
    });
  });

  group('resolveVariantGid — poster', () {
    test('resolves known Enhanced Matte A4 combination', () {
      final gid = resolveVariantGid(
        product: MerchProduct.poster,
        colour: '',
        size: 'A4',
        paper: 'Enhanced Matte',
      );
      expect(gid, equals(posterGids[('Enhanced Matte', 'A4')]));
    });

    test('all poster paper/size combos resolve without fallback', () {
      for (final paper in posterPapers) {
        for (final size in posterSizes) {
          final gid = resolveVariantGid(
            product: MerchProduct.poster,
            colour: '',
            size: size,
            paper: paper,
          );
          expect(
            gid,
            equals(posterGids[(paper, size)]),
            reason: 'Unexpected fallback for ($paper, $size)',
          );
        }
      }
    });
  });

  group('MerchProduct enum', () {
    test('tshirt has non-empty GID', () {
      expect(MerchProduct.tshirt.gid, startsWith('gid://shopify/Product/'));
    });

    test('poster has non-empty GID', () {
      expect(MerchProduct.poster.gid, startsWith('gid://shopify/Product/'));
    });

    test('product GIDs are distinct', () {
      expect(MerchProduct.tshirt.gid, isNot(equals(MerchProduct.poster.gid)));
    });
  });
}
