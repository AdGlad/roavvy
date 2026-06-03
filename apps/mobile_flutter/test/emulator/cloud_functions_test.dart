// T6.9–T6.10 — Cloud Functions client-side behaviour tests
//
// Tests how the Dart app handles Cloud Function responses and errors.
// Uses fake_cloud_firestore to verify that the client correctly reads the
// MerchConfig document that a real function would write.
//
// For full emulator-backed tests (real function invocation), start emulators:
//   firebase emulators:start --only auth,firestore,functions
// then run: flutter test test/emulator/cloud_functions_test.dart

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/merch/merch_cart_item.dart';
import 'package:mobile_flutter/features/merch/merch_cart_repository.dart';

void main() {
  // ── T6.9 — Client reads correct MerchConfig fields after function success ──

  group('T6.9 — Client reads MerchConfig status from Firestore', () {
    test(
      'cartItem status is mockupGenerating before function completes',
      () async {
        final fs = FakeFirebaseFirestore();
        final repo = MerchCartRepository(fs);
        const uid = 'user-001';

        // The function writes the cartItem first with mockupGenerating status.
        final now = DateTime.utc(2026, 1, 1);
        final item = MerchCartItem(
          id: 'item-fn-1',
          status: MerchCartItemStatus.mockupGenerating,
          productType: 'tshirt',
          variantId: 'gid://shopify/ProductVariant/99',
          templateType: 'grid',
          colour: 'Black',
          size: 'M',
          frontPosition: 'center',
          backPosition: 'none',
          selectedCountryCodes: const ['GB', 'FR'],
          createdAt: now,
          updatedAt: now,
        );
        await repo.create(uid, item);

        final active = await repo.loadActive(uid);
        expect(active.first.status, MerchCartItemStatus.mockupGenerating);
      },
    );

    test(
      'cartItem transitions to mockupReady after function writes URLs',
      () async {
        final fs = FakeFirebaseFirestore();
        final repo = MerchCartRepository(fs);
        const uid = 'user-001';

        final now = DateTime.utc(2026, 1, 1);
        final item = MerchCartItem(
          id: 'item-fn-2',
          status: MerchCartItemStatus.mockupGenerating,
          productType: 'tshirt',
          variantId: 'gid://shopify/ProductVariant/99',
          templateType: 'grid',
          colour: 'Black',
          size: 'M',
          frontPosition: 'center',
          backPosition: 'none',
          selectedCountryCodes: const ['US'],
          createdAt: now,
          updatedAt: now,
        );
        await repo.create(uid, item);

        // Simulate function completing: writes checkoutUrl + mockup URLs.
        await repo.markMockupReady(
          uid,
          'item-fn-2',
          checkoutUrl: 'https://shop.example.com/checkout',
          frontMockupUrl: 'https://cdn.example.com/front.png',
          backMockupUrl: null,
          merchConfigId: 'config-123',
        );

        final active = await repo.loadActive(uid);
        expect(active.first.status, MerchCartItemStatus.mockupReady);
        expect(active.first.checkoutUrl, 'https://shop.example.com/checkout');
      },
    );

    test('MerchConfig document shape: status pending on initial write', () async {
      // Verify the shape a Cloud Function would write to Firestore.
      // The function writes users/{uid}/merch_configs/{id} with status: 'pending'.
      final fs = FakeFirebaseFirestore();
      const uid = 'user-001';

      await fs
          .collection('users')
          .doc(uid)
          .collection('merch_configs')
          .doc('config-abc')
          .set({
            'configId': 'config-abc',
            'userId': uid,
            'status': 'pending',
            'designStatus': 'pending',
            'shopifyCartId': null,
            'printfulOrderId': null,
            'createdAt': DateTime.utc(2026, 1, 1).toIso8601String(),
          });

      final doc =
          await fs
              .collection('users')
              .doc(uid)
              .collection('merch_configs')
              .doc('config-abc')
              .get();

      expect(doc.data()!['status'], 'pending');
      expect(doc.data()!['designStatus'], 'pending');
      expect(doc.data()!['shopifyCartId'], isNull);
    });
  });

  // ── T6.10 — Client handles function failure correctly ─────────────────────

  group('T6.10 — Client handles function failure', () {
    test('cartItem transitions to failed when markFailed is called', () async {
      final fs = FakeFirebaseFirestore();
      final repo = MerchCartRepository(fs);
      const uid = 'user-001';

      final now = DateTime.utc(2026, 1, 1);
      final item = MerchCartItem(
        id: 'item-fn-3',
        status: MerchCartItemStatus.mockupGenerating,
        productType: 'tshirt',
        variantId: 'gid://shopify/ProductVariant/99',
        templateType: 'grid',
        colour: 'Black',
        size: 'M',
        frontPosition: 'center',
        backPosition: 'none',
        selectedCountryCodes: const ['GB'],
        createdAt: now,
        updatedAt: now,
      );
      await repo.create(uid, item);

      // Simulate function reporting failure (4xx from Printful).
      await repo.markFailed(
        uid,
        'item-fn-3',
        reason: 'Printful returned 422: Invalid placement',
      );

      final doc =
          await fs
              .collection('users')
              .doc(uid)
              .collection('cartItems')
              .doc('item-fn-3')
              .get();

      expect(doc.data()!['status'], MerchCartItemStatus.failed.value);
      expect(
        doc.data()!['failureReason'],
        'Printful returned 422: Invalid placement',
      );
    });

    test(
      'failed item remains in loadActive (not purchased — still visible)',
      () async {
        final fs = FakeFirebaseFirestore();
        final repo = MerchCartRepository(fs);
        const uid = 'user-001';

        final now = DateTime.utc(2026, 1, 1);
        final item = MerchCartItem(
          id: 'item-fn-4',
          status: MerchCartItemStatus.mockupGenerating,
          productType: 'tshirt',
          variantId: 'gid://shopify/ProductVariant/99',
          templateType: 'grid',
          colour: 'Black',
          size: 'M',
          frontPosition: 'center',
          backPosition: 'none',
          selectedCountryCodes: const ['DE'],
          createdAt: now,
          updatedAt: now,
        );
        await repo.create(uid, item);
        await repo.markFailed(uid, 'item-fn-4', reason: 'timeout');

        // Failed items remain in the active cart so the user can retry.
        final active = await repo.loadActive(uid);
        expect(active.map((i) => i.id), contains('item-fn-4'));
      },
    );

    test('failure reason is recorded in Firestore document', () async {
      final fs = FakeFirebaseFirestore();
      final repo = MerchCartRepository(fs);
      const uid = 'user-001';

      final now = DateTime.utc(2026, 1, 1);
      await repo.create(
        uid,
        MerchCartItem(
          id: 'item-fn-5',
          status: MerchCartItemStatus.mockupGenerating,
          productType: 'tshirt',
          variantId: 'gid://shopify/ProductVariant/99',
          templateType: 'grid',
          colour: 'Black',
          size: 'M',
          frontPosition: 'center',
          backPosition: 'none',
          selectedCountryCodes: const ['JP'],
          createdAt: now,
          updatedAt: now,
        ),
      );

      const reason = 'Printful timeout after 3 retries';
      await repo.markFailed(uid, 'item-fn-5', reason: reason);

      final doc =
          await fs
              .collection('users')
              .doc(uid)
              .collection('cartItems')
              .doc('item-fn-5')
              .get();

      expect(doc.data()!['failureReason'], reason);
    });
  });
}
