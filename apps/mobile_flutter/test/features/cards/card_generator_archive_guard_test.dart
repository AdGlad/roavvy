// M54-G2 — Archive guard unit tests
//
// The archive-on-re-confirm guard lives in `CardGeneratorScreen._navigateToPrint`.
// Getting the widget into the re-confirmation state requires completing two full
// ArtworkConfirmationScreen flows with Firestore writes, which is impractical
// as a widget test.  Instead, these tests verify the invariant at the
// ArtworkConfirmationService level — which is what the guard calls — to confirm
// the archival mechanism works correctly for each scenario.

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/cards/artwork_confirmation_service.dart';
import 'package:shared_models/shared_models.dart';

ArtworkConfirmation _makeConfirmation({
  String uid = 'user-001',
  String id = 'ac-001',
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
      imageHash: 'a' * 64,
      renderSchemaVersion: 'v1',
      confirmedAt: DateTime.utc(2026, 4, 1),
      status: ArtworkConfirmationStatus.confirmed,
    );

void main() {
  group('M54-G2 — archive guard: first-time confirmation (no archive)', () {
    test('no Firestore doc is archived when this is the first confirmation',
        () async {
      // The guard condition is: priorId != null && priorId != newId.
      // When priorId is null (first-time confirmation), the condition is false
      // and archive() is never invoked.  Verify that no 'archived' document
      // appears in Firestore after a first-time confirmation (only a
      // 'confirmed' document should exist).
      final fakeFs = FakeFirebaseFirestore();
      final service = ArtworkConfirmationService(fakeFs);

      // Simulate first-time confirmation — creates one document, status=confirmed.
      await service.create(_makeConfirmation(id: 'ac-first'));

      // No archive call was made (guard: priorId == null).
      final confirmations = await fakeFs
          .collection('users')
          .doc('user-001')
          .collection('artwork_confirmations')
          .get();

      // Exactly one document; its status must be 'confirmed', not 'archived'.
      expect(confirmations.docs, hasLength(1));
      expect(confirmations.docs.first.data()['status'], 'confirmed',
          reason: 'First-time confirmation must not be archived');
    });
  });

  group('M54-G2 — archive guard: re-confirmation (archive called)', () {
    test('archive() called on prior ID marks it as archived', () async {
      // This mirrors what happens in CardGeneratorScreen when the user
      // re-confirms with changed params: archive(uid, priorId) is called.
      final fakeFs = FakeFirebaseFirestore();
      final service = ArtworkConfirmationService(fakeFs);

      // Create the prior confirmation (simulates first confirm).
      await service.create(_makeConfirmation(id: 'ac-prior'));

      // User re-confirms → guard calls archive on the prior ID.
      await service.archive('user-001', 'ac-prior');

      final snap = await fakeFs
          .collection('users')
          .doc('user-001')
          .collection('artwork_confirmations')
          .doc('ac-prior')
          .get();

      expect(snap.data()?['status'], 'archived',
          reason: 'Prior confirmation must be marked archived on re-confirm');
    });
  });
}
