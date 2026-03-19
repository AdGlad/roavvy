import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/data/db/roavvy_database.dart';
import 'package:mobile_flutter/data/visit_repository.dart';
import 'package:mobile_flutter/features/sharing/share_token_service.dart';
import 'package:shared_models/shared_models.dart';

VisitRepository _makeRepo() =>
    VisitRepository(RoavvyDatabase(NativeDatabase.memory()));

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  // ── getOrCreateToken ──────────────────────────────────────────────────────

  group('getOrCreateToken', () {
    test('returns a non-empty string', () async {
      final repo = _makeRepo();
      final token = await const ShareTokenService().getOrCreateToken(repo);
      expect(token, isNotEmpty);
    });

    test('returns the same token on second call', () async {
      final repo = _makeRepo();
      const service = ShareTokenService();
      final first = await service.getOrCreateToken(repo);
      final second = await service.getOrCreateToken(repo);
      expect(first, second);
    });

    test('generated token is a valid UUID v4 format', () async {
      final repo = _makeRepo();
      final token = await const ShareTokenService().getOrCreateToken(repo);
      final uuidV4Pattern = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      );
      expect(uuidV4Pattern.hasMatch(token), isTrue);
    });
  });

  // ── publishVisits ─────────────────────────────────────────────────────────

  group('publishVisits', () {
    test('writes document to sharedTravelCards/{token}', () async {
      final firestore = FakeFirebaseFirestore();
      final service = _TestableShareTokenService(firestore);

      final visits = [
        EffectiveVisitedCountry(
          countryCode: 'GB',
          firstSeen: DateTime.utc(2024),
          lastSeen: DateTime.utc(2024),
          photoCount: 1,
          hasPhotoEvidence: true,
        ),
        EffectiveVisitedCountry(
          countryCode: 'JP',
          firstSeen: DateTime.utc(2023),
          lastSeen: DateTime.utc(2023),
          photoCount: 2,
          hasPhotoEvidence: true,
        ),
      ];

      await service.publishVisits('test-token', 'uid-123', visits);

      final doc = await firestore
          .collection('sharedTravelCards')
          .doc('test-token')
          .get();

      expect(doc.exists, isTrue);
      expect(doc.data()!['uid'], 'uid-123');
      expect(doc.data()!['countryCount'], 2);
      expect(doc.data()!['visitedCodes'], containsAll(['GB', 'JP']));
      expect(doc.data()!['createdAt'], isNotNull);
    });
  });

  // ── revokeFirestoreOnly ───────────────────────────────────────────────────

  group('revokeFirestoreOnly', () {
    test('deletes document from sharedTravelCards', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('sharedTravelCards').doc('test-token').set({
        'uid': 'uid-123',
        'visitedCodes': ['GB'],
        'countryCount': 1,
        'createdAt': 'now',
      });

      await ShareTokenService(firestore: firestore)
          .revokeFirestoreOnly('test-token', 'uid-123');

      final doc = await firestore
          .collection('sharedTravelCards')
          .doc('test-token')
          .get();
      expect(doc.exists, isFalse);
    });

    test('does NOT clear the local token in the repository', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _makeRepo();
      await repo.saveShareToken('test-token');
      await firestore.collection('sharedTravelCards').doc('test-token').set({
        'uid': 'uid-123',
        'visitedCodes': <String>[],
        'countryCount': 0,
        'createdAt': 'now',
      });

      await ShareTokenService(firestore: firestore)
          .revokeFirestoreOnly('test-token', 'uid-123');

      expect(await repo.getShareToken(), 'test-token');
    });
  });

  // ── revokeToken ───────────────────────────────────────────────────────────

  group('revokeToken', () {
    test('deletes Firestore document and clears local token', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _makeRepo();
      await repo.saveShareToken('test-token');
      await firestore.collection('sharedTravelCards').doc('test-token').set({
        'uid': 'uid-123',
        'visitedCodes': ['GB'],
        'countryCount': 1,
        'createdAt': 'now',
      });

      await ShareTokenService(firestore: firestore)
          .revokeToken('test-token', 'uid-123', repo);

      final doc = await firestore
          .collection('sharedTravelCards')
          .doc('test-token')
          .get();
      expect(doc.exists, isFalse);
      expect(await repo.getShareToken(), isNull);
    });
  });
}

/// Test subclass that injects a [FakeFirebaseFirestore] instance.
class _TestableShareTokenService extends ShareTokenService {
  _TestableShareTokenService(this._firestore);

  final FakeFirebaseFirestore _firestore;

  @override
  Future<void> publishVisits(
    String token,
    String uid,
    List<EffectiveVisitedCountry> visits,
  ) async {
    final codes = visits.map((v) => v.countryCode).toList();
    await _firestore.collection('sharedTravelCards').doc(token).set({
      'uid': uid,
      'visitedCodes': codes,
      'countryCount': codes.length,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    });
  }
}
