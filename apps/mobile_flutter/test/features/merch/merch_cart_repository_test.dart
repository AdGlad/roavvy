// T3.1 — MerchCartRepository service tests
//
// Uses FakeFirebaseFirestore — no real Firestore call is made.

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/merch/merch_cart_item.dart';
import 'package:mobile_flutter/features/merch/merch_cart_repository.dart';

const _uid = 'user-001';

MerchCartItem _item({
  String id = 'cart-item-1',
  MerchCartItemStatus status = MerchCartItemStatus.mockupGenerating,
  String productType = 'tshirt',
  String colour = 'Black',
  String size = 'L',
}) {
  final now = DateTime.utc(2026, 1, 1);
  return MerchCartItem(
    id: id,
    status: status,
    productType: productType,
    variantId: 'gid://shopify/ProductVariant/99',
    templateType: 'grid',
    colour: colour,
    size: size,
    frontPosition: 'center',
    backPosition: 'none',
    selectedCountryCodes: const ['GB', 'FR'],
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  // ── create / loadActive ────────────────────────────────────────────────────

  group('MerchCartRepository.create', () {
    test('creates item — loadActive returns it', () async {
      final fs = FakeFirebaseFirestore();
      final repo = MerchCartRepository(fs);

      await repo.create(_uid, _item());

      final active = await repo.loadActive(_uid);
      expect(active, hasLength(1));
      expect(active.first.id, 'cart-item-1');
    });

    test('returns the item id', () async {
      final fs = FakeFirebaseFirestore();
      final repo = MerchCartRepository(fs);

      final returned = await repo.create(_uid, _item(id: 'cart-abc'));
      expect(returned, 'cart-abc');
    });

    test('create preserves productType, colour, size', () async {
      final fs = FakeFirebaseFirestore();
      final repo = MerchCartRepository(fs);

      await repo.create(
        _uid,
        _item(productType: 'poster', colour: 'White', size: 'A3'),
      );

      final items = await repo.loadActive(_uid);
      expect(items.first.productType, 'poster');
      expect(items.first.colour, 'White');
      expect(items.first.size, 'A3');
    });

    test('two different items both appear in loadActive', () async {
      final fs = FakeFirebaseFirestore();
      final repo = MerchCartRepository(fs);

      await repo.create(_uid, _item(id: 'item-a'));
      await repo.create(_uid, _item(id: 'item-b'));

      final active = await repo.loadActive(_uid);
      expect(active.map((i) => i.id), containsAll(['item-a', 'item-b']));
    });

    test(
      'creating item for different uid does not appear in first uid',
      () async {
        final fs = FakeFirebaseFirestore();
        final repo = MerchCartRepository(fs);

        await repo.create('user-other', _item(id: 'other-item'));

        final active = await repo.loadActive(_uid);
        expect(active, isEmpty);
      },
    );
  });

  // ── loadActive — purchased exclusion ──────────────────────────────────────

  group('MerchCartRepository.loadActive — purchased exclusion', () {
    test('purchased item is excluded from loadActive', () async {
      final fs = FakeFirebaseFirestore();
      final repo = MerchCartRepository(fs);

      await repo.create(
        _uid,
        _item(id: 'purchased-item', status: MerchCartItemStatus.purchased),
      );
      await repo.create(
        _uid,
        _item(id: 'active-item', status: MerchCartItemStatus.mockupReady),
      );

      final active = await repo.loadActive(_uid);
      expect(active.map((i) => i.id), isNot(contains('purchased-item')));
      expect(active.map((i) => i.id), contains('active-item'));
    });

    test('empty cart returns empty list', () async {
      final fs = FakeFirebaseFirestore();
      final repo = MerchCartRepository(fs);

      expect(await repo.loadActive(_uid), isEmpty);
    });

    test('all statuses except purchased are returned', () async {
      final fs = FakeFirebaseFirestore();
      final repo = MerchCartRepository(fs);

      for (final status in MerchCartItemStatus.values) {
        if (status == MerchCartItemStatus.purchased) continue;
        await repo.create(
          _uid,
          _item(id: 'item-${status.name}', status: status),
        );
      }

      final active = await repo.loadActive(_uid);
      // All non-purchased statuses should appear.
      expect(active.length, equals(MerchCartItemStatus.values.length - 1));
    });
  });

  // ── delete ─────────────────────────────────────────────────────────────────

  group('MerchCartRepository.delete', () {
    test('delete removes item from loadActive', () async {
      final fs = FakeFirebaseFirestore();
      final repo = MerchCartRepository(fs);

      await repo.create(_uid, _item(id: 'to-delete'));
      await repo.create(_uid, _item(id: 'to-keep'));

      await repo.delete(_uid, 'to-delete');

      final active = await repo.loadActive(_uid);
      expect(active.map((i) => i.id), isNot(contains('to-delete')));
      expect(active.map((i) => i.id), contains('to-keep'));
    });

    test('deleting non-existent item does not throw', () async {
      final fs = FakeFirebaseFirestore();
      final repo = MerchCartRepository(fs);

      await expectLater(repo.delete(_uid, 'ghost-item'), completes);
    });
  });

  // ── status transitions ─────────────────────────────────────────────────────

  group('MerchCartRepository status transitions', () {
    test('markMockupReady updates status and checkoutUrl', () async {
      final fs = FakeFirebaseFirestore();
      final repo = MerchCartRepository(fs);

      await repo.create(_uid, _item(id: 'item-1'));
      await repo.markMockupReady(
        _uid,
        'item-1',
        checkoutUrl: 'https://shop.example.com/checkout',
        frontMockupUrl: 'https://cdn.example.com/front.png',
        backMockupUrl: null,
        merchConfigId: 'mc-001',
      );

      final doc =
          await fs
              .collection('users')
              .doc(_uid)
              .collection('cartItems')
              .doc('item-1')
              .get();

      expect(doc.data()!['status'], MerchCartItemStatus.mockupReady.value);
      expect(doc.data()!['checkoutUrl'], 'https://shop.example.com/checkout');
      expect(
        doc.data()!['frontMockupUrl'],
        'https://cdn.example.com/front.png',
      );
      expect(doc.data()!.containsKey('backMockupUrl'), isFalse);
    });

    test('markFailed updates status and failureReason', () async {
      final fs = FakeFirebaseFirestore();
      final repo = MerchCartRepository(fs);

      await repo.create(_uid, _item(id: 'item-2'));
      await repo.markFailed(_uid, 'item-2', reason: 'Printful timeout');

      final doc =
          await fs
              .collection('users')
              .doc(_uid)
              .collection('cartItems')
              .doc('item-2')
              .get();

      expect(doc.data()!['status'], MerchCartItemStatus.failed.value);
      expect(doc.data()!['failureReason'], 'Printful timeout');
    });

    test(
      'markFailed without reason does not write failureReason key',
      () async {
        final fs = FakeFirebaseFirestore();
        final repo = MerchCartRepository(fs);

        await repo.create(_uid, _item(id: 'item-3'));
        await repo.markFailed(_uid, 'item-3');

        final doc =
            await fs
                .collection('users')
                .doc(_uid)
                .collection('cartItems')
                .doc('item-3')
                .get();

        expect(doc.data()!['status'], MerchCartItemStatus.failed.value);
        expect(doc.data()!.containsKey('failureReason'), isFalse);
      },
    );

    test('markCheckoutStarted updates status', () async {
      final fs = FakeFirebaseFirestore();
      final repo = MerchCartRepository(fs);

      await repo.create(
        _uid,
        _item(id: 'item-4', status: MerchCartItemStatus.mockupReady),
      );
      await repo.markCheckoutStarted(_uid, 'item-4');

      final doc =
          await fs
              .collection('users')
              .doc(_uid)
              .collection('cartItems')
              .doc('item-4')
              .get();

      expect(doc.data()!['status'], MerchCartItemStatus.checkoutStarted.value);
    });
  });

  // ── update ─────────────────────────────────────────────────────────────────

  group('MerchCartRepository.update', () {
    test('update merges custom fields into existing document', () async {
      final fs = FakeFirebaseFirestore();
      final repo = MerchCartRepository(fs);

      await repo.create(_uid, _item(id: 'item-5'));
      await repo.update(_uid, 'item-5', {'title': 'My World Tour'});

      final doc =
          await fs
              .collection('users')
              .doc(_uid)
              .collection('cartItems')
              .doc('item-5')
              .get();

      expect(doc.data()!['title'], 'My World Tour');
      // Original fields preserved.
      expect(doc.data()!['productType'], 'tshirt');
    });

    test('update sets updatedAt timestamp', () async {
      final fs = FakeFirebaseFirestore();
      final repo = MerchCartRepository(fs);

      await repo.create(_uid, _item(id: 'item-6'));
      await repo.update(_uid, 'item-6', {'colour': 'Navy'});

      final doc =
          await fs
              .collection('users')
              .doc(_uid)
              .collection('cartItems')
              .doc('item-6')
              .get();

      expect(doc.data()!.containsKey('updatedAt'), isTrue);
    });
  });
}
