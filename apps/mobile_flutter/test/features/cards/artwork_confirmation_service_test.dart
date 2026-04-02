import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/cards/artwork_confirmation_service.dart';
import 'package:shared_models/shared_models.dart';

void main() {
  final confirmedAt = DateTime.utc(2026, 3, 31, 12);

  ArtworkConfirmation makeConfirmation({
    String uid = 'user-001',
    String id = 'ac-001',
    ArtworkConfirmationStatus status = ArtworkConfirmationStatus.confirmed,
  }) =>
      ArtworkConfirmation(
        confirmationId: id,
        userId: uid,
        templateType: CardTemplateType.grid,
        aspectRatio: 1.5,
        countryCodes: const ['GB', 'FR'],
        countryCount: 2,
        dateLabel: '2024',
        entryOnly: false,
        imageHash: 'b' * 64,
        renderSchemaVersion: 'v1',
        confirmedAt: confirmedAt,
        status: status,
      );

  group('ArtworkConfirmationService', () {
    late FakeFirebaseFirestore fakeFirestore;
    late ArtworkConfirmationService service;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      service = ArtworkConfirmationService(fakeFirestore);
    });

    test('create() writes document to users/{uid}/artwork_confirmations/{id}',
        () async {
      final confirmation = makeConfirmation();
      await service.create(confirmation);

      final snap = await fakeFirestore
          .collection('users')
          .doc('user-001')
          .collection('artwork_confirmations')
          .doc('ac-001')
          .get();

      expect(snap.exists, isTrue);
      expect(snap.data()?['confirmationId'], 'ac-001');
      expect(snap.data()?['status'], 'confirmed');
      expect(snap.data()?['imageHash'], 'b' * 64);
    });

    test('create() returns the confirmationId', () async {
      final confirmation = makeConfirmation();
      final returnedId = await service.create(confirmation);
      expect(returnedId, 'ac-001');
    });

    test('linkPurchase() updates status to purchase_linked and stores orderId',
        () async {
      final confirmation = makeConfirmation();
      await service.create(confirmation);

      await service.linkPurchase('user-001', 'ac-001', 'order-999');

      final snap = await fakeFirestore
          .collection('users')
          .doc('user-001')
          .collection('artwork_confirmations')
          .doc('ac-001')
          .get();

      expect(snap.data()?['status'], 'purchase_linked');
      expect(snap.data()?['orderId'], 'order-999');
    });

    test('archive() updates status to archived', () async {
      final confirmation = makeConfirmation();
      await service.create(confirmation);

      await service.archive('user-001', 'ac-001');

      final snap = await fakeFirestore
          .collection('users')
          .doc('user-001')
          .collection('artwork_confirmations')
          .doc('ac-001')
          .get();

      expect(snap.data()?['status'], 'archived');
    });

    test('documents for different users are isolated', () async {
      final user1 = makeConfirmation(uid: 'user-001', id: 'ac-001');
      final user2 = makeConfirmation(uid: 'user-002', id: 'ac-001');

      await service.create(user1);
      await service.create(user2);

      await service.archive('user-001', 'ac-001');

      final snap2 = await fakeFirestore
          .collection('users')
          .doc('user-002')
          .collection('artwork_confirmations')
          .doc('ac-001')
          .get();

      // user-002's doc must remain 'confirmed' — archive of user-001 is isolated
      expect(snap2.data()?['status'], 'confirmed');
    });
  });
}
