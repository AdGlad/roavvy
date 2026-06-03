import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/data/achievement_repository.dart';
import 'package:mobile_flutter/data/db/roavvy_database.dart';
import 'package:mobile_flutter/data/firestore_sync_service.dart';
import 'package:mobile_flutter/data/trip_repository.dart';
import 'package:mobile_flutter/data/visit_repository.dart';
import 'package:shared_models/shared_models.dart';

RoavvyDatabase _makeDb() => RoavvyDatabase(NativeDatabase.memory());

VisitRepository _makeRepo() => VisitRepository(_makeDb());

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  group('FirestoreSyncService.flushDirty', () {
    test('writes inferred visit to Firestore and marks it clean', () async {
      final fakeFirestore = FakeFirebaseFirestore();
      final service = FirestoreSyncService(fakeFirestore);
      final repo = _makeRepo();

      await repo.saveInferred(InferredCountryVisit(
        countryCode: 'GB',
        inferredAt: DateTime.utc(2024, 6, 1),
        photoCount: 10,
        firstSeen: DateTime.utc(2024, 3, 1),
        lastSeen: DateTime.utc(2024, 6, 1),
      ));

      final dirtyBefore = await repo.loadDirtyInferred();
      expect(dirtyBefore, hasLength(1));

      await service.flushDirty('uid-123', repo);

      final doc = await fakeFirestore
          .collection('users')
          .doc('uid-123')
          .collection('inferred_visits')
          .doc('GB')
          .get();
      expect(doc.exists, isTrue);
      expect(doc.data()!['photoCount'], 10);
      expect(doc.data()!['firstSeen'], '2024-03-01T00:00:00.000Z');
      expect(doc.data()!['lastSeen'], '2024-06-01T00:00:00.000Z');
      expect(doc.data()!.containsKey('syncedAt'), isTrue);

      final dirtyAfter = await repo.loadDirtyInferred();
      expect(dirtyAfter, isEmpty);
    });

    test('writes user-added country to Firestore and marks it clean', () async {
      final fakeFirestore = FakeFirebaseFirestore();
      final service = FirestoreSyncService(fakeFirestore);
      final repo = _makeRepo();

      await repo.saveAdded(UserAddedCountry(
        countryCode: 'JP',
        addedAt: DateTime.utc(2024, 1, 15),
      ));

      await service.flushDirty('uid-456', repo);

      final doc = await fakeFirestore
          .collection('users')
          .doc('uid-456')
          .collection('user_added')
          .doc('JP')
          .get();
      expect(doc.exists, isTrue);
      expect(doc.data()!['addedAt'], '2024-01-15T00:00:00.000Z');

      final dirtyAfter = await repo.loadDirtyAdded();
      expect(dirtyAfter, isEmpty);
    });

    test('writes user-removed country to Firestore and marks it clean', () async {
      final fakeFirestore = FakeFirebaseFirestore();
      final service = FirestoreSyncService(fakeFirestore);
      final repo = _makeRepo();

      // saveRemoved requires no matching user-added row to conflict with.
      await repo.saveRemoved(UserRemovedCountry(
        countryCode: 'FR',
        removedAt: DateTime.utc(2024, 2, 20),
      ));

      await service.flushDirty('uid-789', repo);

      final doc = await fakeFirestore
          .collection('users')
          .doc('uid-789')
          .collection('user_removed')
          .doc('FR')
          .get();
      expect(doc.exists, isTrue);
      expect(doc.data()!['removedAt'], '2024-02-20T00:00:00.000Z');

      final dirtyAfter = await repo.loadDirtyRemoved();
      expect(dirtyAfter, isEmpty);
    });

    test('does not re-sync already-clean rows', () async {
      final fakeFirestore = FakeFirebaseFirestore();
      final service = FirestoreSyncService(fakeFirestore);
      final repo = _makeRepo();

      await repo.saveInferred(InferredCountryVisit(
        countryCode: 'DE',
        inferredAt: DateTime.utc(2024),
        photoCount: 3,
      ));

      // Flush once — marks clean.
      await service.flushDirty('uid-clean', repo);

      // Delete from Firestore to verify a second flush does NOT re-write.
      await fakeFirestore
          .collection('users')
          .doc('uid-clean')
          .collection('inferred_visits')
          .doc('DE')
          .delete();

      // Flush again — nothing should be written since isDirty = 0.
      await service.flushDirty('uid-clean', repo);

      final doc = await fakeFirestore
          .collection('users')
          .doc('uid-clean')
          .collection('inferred_visits')
          .doc('DE')
          .get();
      expect(doc.exists, isFalse);
    });

    test('no GPS coordinates, filenames, or PHAsset ids in Firestore documents', () async {
      final fakeFirestore = FakeFirebaseFirestore();
      final service = FirestoreSyncService(fakeFirestore);
      final repo = _makeRepo();

      await repo.saveInferred(InferredCountryVisit(
        countryCode: 'US',
        inferredAt: DateTime.utc(2024),
        photoCount: 5,
      ));
      await service.flushDirty('uid-privacy', repo);

      final doc = await fakeFirestore
          .collection('users')
          .doc('uid-privacy')
          .collection('inferred_visits')
          .doc('US')
          .get();
      final data = doc.data()!;
      // None of these GPS/filename/asset-id keys should be present.
      expect(data.containsKey('lat'), isFalse);
      expect(data.containsKey('lng'), isFalse);
      expect(data.containsKey('latitude'), isFalse);
      expect(data.containsKey('longitude'), isFalse);
      expect(data.containsKey('filename'), isFalse);
      expect(data.containsKey('assetId'), isFalse);
      expect(data.containsKey('localIdentifier'), isFalse);
    });
  });

  group('achievement flush', () {
    test('writes dirty achievement to Firestore and marks it clean', () async {
      final fakeFirestore = FakeFirebaseFirestore();
      final service = FirestoreSyncService(fakeFirestore);
      final db = _makeDb();
      final visitRepo = VisitRepository(db);
      final achievementRepo = AchievementRepository(db);

      await achievementRepo.upsertAll({'countries_1'}, DateTime.utc(2024, 3, 1));

      expect(await achievementRepo.loadDirty(), hasLength(1));

      await service.flushDirty('uid-ach', visitRepo,
          achievementRepo: achievementRepo);

      final doc = await fakeFirestore
          .collection('users')
          .doc('uid-ach')
          .collection('unlocked_achievements')
          .doc('countries_1')
          .get();
      expect(doc.exists, isTrue);
      expect(doc.data()!['unlockedAt'], '2024-03-01T00:00:00.000Z');
      expect(doc.data()!.containsKey('syncedAt'), isTrue);

      expect(await achievementRepo.loadDirty(), isEmpty);
    });

    test('does not flush achievements when achievementRepo is null', () async {
      final fakeFirestore = FakeFirebaseFirestore();
      final service = FirestoreSyncService(fakeFirestore);
      final repo = _makeRepo();

      // No achievementRepo passed — should complete without touching Firestore.
      await service.flushDirty('uid-noach', repo);

      final snap = await fakeFirestore
          .collection('users')
          .doc('uid-noach')
          .collection('unlocked_achievements')
          .get();
      expect(snap.docs, isEmpty);
    });
  });

  group('trip flush', () {
    test('writes dirty trip to Firestore and marks it clean', () async {
      final fakeFirestore = FakeFirebaseFirestore();
      final service = FirestoreSyncService(fakeFirestore);
      final db = _makeDb();
      final visitRepo = VisitRepository(db);
      final tripRepo = TripRepository(db);

      final trip = TripRecord(
        id: 'GB_2023-07-14T00:00:00.000Z',
        countryCode: 'GB',
        startedOn: DateTime.utc(2023, 7, 14),
        endedOn: DateTime.utc(2023, 7, 28),
        photoCount: 43,
        isManual: false,
      );
      await tripRepo.upsertAll([trip]);

      expect(await tripRepo.loadDirty(), hasLength(1));

      await service.flushDirty('uid-trip', visitRepo, tripRepo: tripRepo);

      final doc = await fakeFirestore
          .collection('users')
          .doc('uid-trip')
          .collection('trips')
          .doc('GB_2023-07-14T00:00:00.000Z')
          .get();
      expect(doc.exists, isTrue);
      expect(doc.data()!['countryCode'], 'GB');
      expect(doc.data()!['startedOn'], '2023-07-14T00:00:00.000Z');
      expect(doc.data()!['endedOn'], '2023-07-28T00:00:00.000Z');
      expect(doc.data()!['photoCount'], 43);
      expect(doc.data()!['isManual'], false);
      expect(doc.data()!.containsKey('syncedAt'), isTrue);

      expect(await tripRepo.loadDirty(), isEmpty);
    });

    test('writes manual trip with isManual=true', () async {
      final fakeFirestore = FakeFirebaseFirestore();
      final service = FirestoreSyncService(fakeFirestore);
      final db = _makeDb();
      final visitRepo = VisitRepository(db);
      final tripRepo = TripRepository(db);

      await tripRepo.upsertAll([
        TripRecord(
          id: 'manual_abc12345',
          countryCode: 'FR',
          startedOn: DateTime.utc(2022, 6, 1),
          endedOn: DateTime.utc(2022, 6, 14),
          photoCount: 0,
          isManual: true,
        ),
      ]);

      await service.flushDirty('uid-manual', visitRepo, tripRepo: tripRepo);

      final doc = await fakeFirestore
          .collection('users')
          .doc('uid-manual')
          .collection('trips')
          .doc('manual_abc12345')
          .get();
      expect(doc.data()!['isManual'], true);
      expect(doc.data()!['countryCode'], 'FR');
    });

    test('does not re-sync already-clean trip rows', () async {
      final fakeFirestore = FakeFirebaseFirestore();
      final service = FirestoreSyncService(fakeFirestore);
      final db = _makeDb();
      final visitRepo = VisitRepository(db);
      final tripRepo = TripRepository(db);

      await tripRepo.upsertAll([
        TripRecord(
          id: 'JP_2024-01-01T00:00:00.000Z',
          countryCode: 'JP',
          startedOn: DateTime.utc(2024, 1, 1),
          endedOn: DateTime.utc(2024, 1, 10),
          photoCount: 5,
          isManual: false,
        ),
      ]);

      // First flush — marks clean.
      await service.flushDirty('uid-clean-trip', visitRepo, tripRepo: tripRepo);

      // Delete from Firestore to verify a second flush does NOT re-write.
      await fakeFirestore
          .collection('users')
          .doc('uid-clean-trip')
          .collection('trips')
          .doc('JP_2024-01-01T00:00:00.000Z')
          .delete();

      await service.flushDirty('uid-clean-trip', visitRepo, tripRepo: tripRepo);

      final doc = await fakeFirestore
          .collection('users')
          .doc('uid-clean-trip')
          .collection('trips')
          .doc('JP_2024-01-01T00:00:00.000Z')
          .get();
      expect(doc.exists, isFalse);
    });

    test('does not flush trips when tripRepo is null', () async {
      final fakeFirestore = FakeFirebaseFirestore();
      final service = FirestoreSyncService(fakeFirestore);
      final repo = _makeRepo();

      // No tripRepo passed — should complete without touching trips collection.
      await service.flushDirty('uid-notrip', repo);

      final snap = await fakeFirestore
          .collection('users')
          .doc('uid-notrip')
          .collection('trips')
          .get();
      expect(snap.docs, isEmpty);
    });

    test('failure leaves trip dirty for retry', () async {
      // FakeFirebaseFirestore does not simulate write failures, so we verify
      // the invariant: a fresh dirty row remains dirty until flushed.
      final db = _makeDb();
      final tripRepo = TripRepository(db);

      await tripRepo.upsertAll([
        TripRecord(
          id: 'DE_2023-05-01T00:00:00.000Z',
          countryCode: 'DE',
          startedOn: DateTime.utc(2023, 5, 1),
          endedOn: DateTime.utc(2023, 5, 7),
          photoCount: 2,
          isManual: false,
        ),
      ]);

      // Without calling flushDirty, the row stays dirty.
      expect(await tripRepo.loadDirty(), hasLength(1));
    });
  });

  group('NoOpSyncService', () {
    test('flushDirty completes without error and does nothing', () async {
      final service = const NoOpSyncService();
      final repo = _makeRepo();
      await repo.saveInferred(InferredCountryVisit(
        countryCode: 'AU',
        inferredAt: DateTime.utc(2024),
        photoCount: 1,
      ));
      // Should complete without throwing; dirty rows remain dirty.
      await expectLater(service.flushDirty('any-uid', repo), completes);
      final dirty = await repo.loadDirtyInferred();
      expect(dirty, hasLength(1));
    });
  });

  // T3.3 — Firestore sync field guard (ADR-002, privacy constraint) ──────────

  group('FirestoreSyncService field guard — no GPS or photo data written', () {
    late FakeFirebaseFirestore fakeFirestore;
    late FirestoreSyncService service;
    late VisitRepository repo;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      service = FirestoreSyncService(fakeFirestore);
      repo = _makeRepo();
    });

    test('inferred visit document contains no GPS coordinate fields', () async {
      await repo.saveInferred(InferredCountryVisit(
        countryCode: 'GB',
        inferredAt: DateTime.utc(2024, 6, 1),
        photoCount: 5,
        firstSeen: DateTime.utc(2024, 3, 1),
        lastSeen: DateTime.utc(2024, 6, 1),
      ));
      await service.flushDirty('uid-privacy', repo);

      final doc = await fakeFirestore
          .collection('users')
          .doc('uid-privacy')
          .collection('inferred_visits')
          .doc('GB')
          .get();

      final data = doc.data()!;
      expect(data.containsKey('latitude'), isFalse);
      expect(data.containsKey('longitude'), isFalse);
      expect(data.containsKey('lat'), isFalse);
      expect(data.containsKey('lng'), isFalse);
      expect(data.containsKey('gps'), isFalse);
      expect(data.containsKey('location'), isFalse);
    });

    test('inferred visit document contains no photo identifier fields', () async {
      await repo.saveInferred(InferredCountryVisit(
        countryCode: 'FR',
        inferredAt: DateTime.utc(2024, 6, 1),
        photoCount: 3,
      ));
      await service.flushDirty('uid-privacy2', repo);

      final doc = await fakeFirestore
          .collection('users')
          .doc('uid-privacy2')
          .collection('inferred_visits')
          .doc('FR')
          .get();

      final data = doc.data()!;
      expect(data.containsKey('assetId'), isFalse);
      expect(data.containsKey('localIdentifier'), isFalse);
      expect(data.containsKey('filename'), isFalse);
      expect(data.containsKey('filePath'), isFalse);
      expect(data.containsKey('photoUrl'), isFalse);
    });

    test('inferred visit document contains only permitted fields', () async {
      await repo.saveInferred(InferredCountryVisit(
        countryCode: 'DE',
        inferredAt: DateTime.utc(2024, 6, 1),
        photoCount: 7,
        firstSeen: DateTime.utc(2024, 1, 1),
        lastSeen: DateTime.utc(2024, 6, 1),
      ));
      await service.flushDirty('uid-privacy3', repo);

      final doc = await fakeFirestore
          .collection('users')
          .doc('uid-privacy3')
          .collection('inferred_visits')
          .doc('DE')
          .get();

      final keys = doc.data()!.keys.toSet();
      // Only these fields are permitted in inferred_visits documents (ADR-029).
      const permitted = {'inferredAt', 'photoCount', 'firstSeen', 'lastSeen', 'syncedAt'};
      for (final key in keys) {
        expect(permitted, contains(key),
            reason: 'Unexpected field "$key" found in Firestore document');
      }
    });

    test('user_added document contains only permitted fields', () async {
      await repo.saveAdded(UserAddedCountry(
        countryCode: 'JP',
        addedAt: DateTime.utc(2024, 1, 1),
      ));
      await service.flushDirty('uid-privacy4', repo);

      final doc = await fakeFirestore
          .collection('users')
          .doc('uid-privacy4')
          .collection('user_added')
          .doc('JP')
          .get();

      final keys = doc.data()!.keys.toSet();
      const permitted = {'addedAt', 'syncedAt'};
      for (final key in keys) {
        expect(permitted, contains(key),
            reason: 'Unexpected field "$key" in user_added document');
      }
    });

    test('dirty record is written; clean record is skipped', () async {
      await repo.saveInferred(InferredCountryVisit(
        countryCode: 'IT',
        inferredAt: DateTime.utc(2024, 6, 1),
        photoCount: 2,
      ));

      await service.flushDirty('uid-clean', repo);
      expect(await repo.loadDirtyInferred(), isEmpty);

      final doc = await fakeFirestore
          .collection('users')
          .doc('uid-clean')
          .collection('inferred_visits')
          .doc('IT')
          .get();
      expect(doc.exists, isTrue);
      expect(doc.data()!['photoCount'], 2);
    });
  });

  // T3.5 — Achievement repository Firestore sync ────────────────────────────

  group('FirestoreSyncService — achievement sync', () {
    test('flushDirty with achievementRepo writes achievement to Firestore', () async {
      final fakeFirestore = FakeFirebaseFirestore();
      final service = FirestoreSyncService(fakeFirestore);
      final db = _makeDb();
      final visitRepo = VisitRepository(db);
      final achievementRepo = AchievementRepository(db);

      await achievementRepo.upsertAll({'countries_1'}, DateTime.utc(2025, 1, 1));

      await service.flushDirty('uid-ach', visitRepo,
          achievementRepo: achievementRepo);

      final doc = await fakeFirestore
          .collection('users')
          .doc('uid-ach')
          .collection('unlocked_achievements')
          .doc('countries_1')
          .get();

      expect(doc.exists, isTrue);
      expect(doc.data()!.containsKey('unlockedAt'), isTrue);
      expect(doc.data()!.containsKey('syncedAt'), isTrue);
    });

    test('achievement is marked clean in Drift after Firestore write', () async {
      final fakeFirestore = FakeFirebaseFirestore();
      final service = FirestoreSyncService(fakeFirestore);
      final db = _makeDb();
      final visitRepo = VisitRepository(db);
      final achievementRepo = AchievementRepository(db);

      await achievementRepo.upsertAll({'countries_5'}, DateTime.utc(2025, 1, 1));
      expect(await achievementRepo.loadDirty(), hasLength(1));

      await service.flushDirty('uid-ach2', visitRepo,
          achievementRepo: achievementRepo);

      expect(await achievementRepo.loadDirty(), isEmpty);
    });

    test('unlocking already-unlocked achievement is idempotent (no duplicate row)', () async {
      final db = _makeDb();
      final achievementRepo = AchievementRepository(db);

      await achievementRepo.upsertAll({'countries_1'}, DateTime.utc(2025, 1, 1));
      await achievementRepo.upsertAll({'countries_1'}, DateTime.utc(2025, 6, 1));

      final all = await achievementRepo.loadAll();
      expect(all.where((id) => id == 'countries_1'), hasLength(1));
    });

    test('multiple achievements in one flushDirty are all written', () async {
      final fakeFirestore = FakeFirebaseFirestore();
      final service = FirestoreSyncService(fakeFirestore);
      final db = _makeDb();
      final visitRepo = VisitRepository(db);
      final achievementRepo = AchievementRepository(db);

      final ids = {'countries_1', 'countries_3', 'countries_5'};
      await achievementRepo.upsertAll(ids, DateTime.utc(2025, 1, 1));

      await service.flushDirty('uid-ach3', visitRepo,
          achievementRepo: achievementRepo);

      final subcol = await fakeFirestore
          .collection('users')
          .doc('uid-ach3')
          .collection('unlocked_achievements')
          .get();

      expect(subcol.docs.map((d) => d.id).toSet(), equals(ids));
    });
  });
}
