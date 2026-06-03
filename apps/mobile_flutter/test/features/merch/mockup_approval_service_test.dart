import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/merch/mockup_approval_service.dart';
import 'package:shared_models/shared_models.dart';

void main() {
  final confirmedAt = DateTime.utc(2026, 4, 1, 12);

  MockupApproval makeApproval({
    String uid = 'user-001',
    String id = 'ma-001',
    String? artworkConfirmationId = 'ac-001',
    String? placementType = 'front',
  }) => MockupApproval(
    mockupApprovalId: id,
    userId: uid,
    artworkConfirmationId: artworkConfirmationId,
    templateType: CardTemplateType.grid,
    variantId: 'gid://shopify/ProductVariant/12345',
    placementType: placementType,
    confirmedAt: confirmedAt,
  );

  group('MockupApprovalService', () {
    late FakeFirebaseFirestore fakeFirestore;
    late MockupApprovalService service;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      service = MockupApprovalService(fakeFirestore);
    });

    test(
      'create() writes document to users/{uid}/mockup_approvals/{id}',
      () async {
        final approval = makeApproval();
        await service.create(approval);

        final snap =
            await fakeFirestore
                .collection('users')
                .doc('user-001')
                .collection('mockup_approvals')
                .doc('ma-001')
                .get();

        expect(snap.exists, isTrue);
        expect(snap.data()?['mockupApprovalId'], 'ma-001');
      },
    );

    test('create() returns the mockupApprovalId', () async {
      final approval = makeApproval(id: 'ma-999');
      final result = await service.create(approval);
      expect(result, 'ma-999');
    });

    test('create() writes correct Firestore path and data', () async {
      final approval = makeApproval(uid: 'user-xyz', id: 'ma-abc');
      await service.create(approval);

      final snap =
          await fakeFirestore
              .collection('users')
              .doc('user-xyz')
              .collection('mockup_approvals')
              .doc('ma-abc')
              .get();

      final data = snap.data()!;
      expect(data['userId'], 'user-xyz');
      expect(data['templateType'], 'grid');
      expect(data['variantId'], 'gid://shopify/ProductVariant/12345');
      expect(data['placementType'], 'front');
      expect(data['artworkConfirmationId'], 'ac-001');
    });

    test('double create() is idempotent — no error on second call', () async {
      final approval = makeApproval();
      await service.create(approval);
      await expectLater(service.create(approval), completes);

      // Document should still exist with original data.
      final snap =
          await fakeFirestore
              .collection('users')
              .doc('user-001')
              .collection('mockup_approvals')
              .doc('ma-001')
              .get();
      expect(snap.exists, isTrue);
    });

    test('create() with null artworkConfirmationId omits the field', () async {
      final approval = makeApproval(artworkConfirmationId: null);
      await service.create(approval);

      final snap =
          await fakeFirestore
              .collection('users')
              .doc('user-001')
              .collection('mockup_approvals')
              .doc('ma-001')
              .get();

      // toFirestore() uses conditional inclusion — null fields are omitted.
      expect(snap.exists, isTrue);
      expect(snap.data()!.containsKey('artworkConfirmationId'), isFalse);
    });

    test('create() with null placementType omits the field', () async {
      final approval = makeApproval(placementType: null);
      await service.create(approval);

      final snap =
          await fakeFirestore
              .collection('users')
              .doc('user-001')
              .collection('mockup_approvals')
              .doc('ma-001')
              .get();

      expect(snap.data()!.containsKey('placementType'), isFalse);
    });
  });
}
