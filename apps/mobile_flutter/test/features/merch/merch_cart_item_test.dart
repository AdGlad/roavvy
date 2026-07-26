// M189 — MerchCartItem serialization tests, focused on the imageSize field.
//
// toMap → fromDoc round-trips through the same map shape written to Firestore
// (Timestamps included), so no real Firestore call is made.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/merch/merch_cart_item.dart';
import 'package:mobile_flutter/features/merch/product_mockup_specs.dart';

MerchCartItem _item({ImageSize imageSize = ImageSize.medium}) {
  final now = DateTime.utc(2026, 1, 1);
  return MerchCartItem(
    id: 'cart-1',
    status: MerchCartItemStatus.mockupReady,
    productType: 'tshirt',
    variantId: 'gid://shopify/ProductVariant/99',
    templateType: 'grid',
    colour: 'Black',
    size: 'L',
    frontPosition: 'center',
    backPosition: 'none',
    imageSize: imageSize,
    selectedCountryCodes: const ['GB', 'FR'],
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('MerchCartItem.imageSize', () {
    test('defaults to medium when not provided', () {
      expect(_item().imageSize, ImageSize.medium);
    });

    test('toMap serializes imageSize as the enum name', () {
      expect(_item(imageSize: ImageSize.large).toMap()['imageSize'], 'large');
      expect(_item(imageSize: ImageSize.small).toMap()['imageSize'], 'small');
      expect(_item().toMap()['imageSize'], 'medium');
    });

    test('toMap → fromDoc round-trips imageSize for every size', () {
      for (final size in ImageSize.values) {
        final original = _item(imageSize: size);
        final restored = MerchCartItem.fromDoc(original.id, original.toMap());
        expect(restored.imageSize, size, reason: 'round-trip for $size');
      }
    });

    test('fromDoc tolerates a missing imageSize key (backward compat) → medium',
        () {
      final data = _item(imageSize: ImageSize.large).toMap()
        ..remove('imageSize');
      expect(data.containsKey('imageSize'), isFalse);
      final restored = MerchCartItem.fromDoc('cart-1', data);
      expect(restored.imageSize, ImageSize.medium);
    });

    test('fromDoc tolerates an unknown imageSize value → medium', () {
      final data = _item().toMap()..['imageSize'] = 'gigantic';
      final restored = MerchCartItem.fromDoc('cart-1', data);
      expect(restored.imageSize, ImageSize.medium);
    });

    test('copyWith overrides imageSize and preserves it otherwise', () {
      final base = _item(imageSize: ImageSize.small);
      expect(base.copyWith(imageSize: ImageSize.large).imageSize,
          ImageSize.large);
      // Unrelated copyWith keeps the existing imageSize.
      expect(
        base.copyWith(status: MerchCartItemStatus.checkoutStarted).imageSize,
        ImageSize.small,
      );
    });

    test('other fields survive the round-trip unchanged', () {
      final original = _item(imageSize: ImageSize.large);
      final restored = MerchCartItem.fromDoc(original.id, original.toMap());
      expect(restored.productType, 'tshirt');
      expect(restored.colour, 'Black');
      expect(restored.size, 'L');
      expect(restored.frontPosition, 'center');
      expect(restored.backPosition, 'none');
      expect(restored.selectedCountryCodes, ['GB', 'FR']);
      expect(restored.createdAt, DateTime.utc(2026, 1, 1));
    });

    test('createdAt/updatedAt serialize as Firestore Timestamps', () {
      final map = _item().toMap();
      expect(map['createdAt'], isA<Timestamp>());
      expect(map['updatedAt'], isA<Timestamp>());
    });
  });
}
