import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart';

import 'db/roavvy_database.dart';
import 'visit_repository.dart';

/// Restores Firestore-backed travel data into the local Drift database after
/// a fresh install or reinstall (ADR-160).
///
/// Restore is pull-on-demand: triggered only when the local DB is completely
/// empty. It is NOT a continuous two-way sync — Drift remains the source of
/// truth for all reads; Firestore is secondary.
///
/// All restored rows are written with [isDirty] = 0 so [FirestoreSyncService]
/// does not immediately re-upload them.
class FirestoreRestoreService {
  FirestoreRestoreService({
    required RoavvyDatabase db,
    FirebaseFirestore? firestore,
  })  : _db = db,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final RoavvyDatabase _db;
  final FirebaseFirestore _firestore;

  /// Returns true when a restore is warranted:
  ///  - local inferred_visits table is empty, AND
  ///  - local photo_date_records table is empty
  ///
  /// Checking both ensures a genuine zero-country user (who has scanned but
  /// found nothing) does not trigger a restore on every launch.
  static Future<bool> shouldRestore(VisitRepository visitRepo) async {
    final inferred = await visitRepo.loadInferred();
    if (inferred.isNotEmpty) return false;
    final photoDates = await visitRepo.loadPhotoDates();
    return photoDates.isEmpty;
  }

  /// Pulls all 5 Firestore subcollections and writes them into local Drift
  /// tables with [isDirty] = 0.
  ///
  /// A 5-second timeout prevents a slow network from blocking app startup.
  /// Returns true if the restore completed within the timeout; false otherwise.
  Future<bool> restore(String uid) async {
    try {
      bool completed = false;
      await Future.any([
        _doRestore(uid).then((_) => completed = true),
        Future.delayed(const Duration(seconds: 5)),
      ]);
      return completed;
    } catch (_) {
      return false;
    }
  }

  Future<void> _doRestore(String uid) async {
    final userDoc = _firestore.collection('users').doc(uid);

    // 1. inferred_visits → InferredCountryVisits table
    final inferredSnap = await userDoc.collection('inferred_visits').get();
    if (inferredSnap.docs.isNotEmpty) {
      await _db.transaction(() async {
        for (final doc in inferredSnap.docs) {
          final data = doc.data();
          final inferredAt =
              DateTime.tryParse(data['inferredAt'] as String? ?? '')?.toUtc();
          if (inferredAt == null) continue;
          final firstSeen = data['firstSeen'] != null
              ? DateTime.tryParse(data['firstSeen'] as String)?.toUtc()
              : null;
          final lastSeen = data['lastSeen'] != null
              ? DateTime.tryParse(data['lastSeen'] as String)?.toUtc()
              : null;
          await _db.into(_db.inferredCountryVisits).insertOnConflictUpdate(
                InferredCountryVisitsCompanion(
                  countryCode: Value(doc.id),
                  inferredAt: Value(inferredAt),
                  photoCount: Value((data['photoCount'] as int?) ?? 0),
                  firstSeen: Value(firstSeen),
                  lastSeen: Value(lastSeen),
                  isDirty: const Value(0),
                ),
              );
        }
      });
    }

    // 2. user_added → UserAddedCountries table
    final addedSnap = await userDoc.collection('user_added').get();
    if (addedSnap.docs.isNotEmpty) {
      await _db.transaction(() async {
        for (final doc in addedSnap.docs) {
          final data = doc.data();
          final addedAt =
              DateTime.tryParse(data['addedAt'] as String? ?? '')?.toUtc();
          if (addedAt == null) continue;
          await _db.into(_db.userAddedCountries).insertOnConflictUpdate(
                UserAddedCountriesCompanion(
                  countryCode: Value(doc.id),
                  addedAt: Value(addedAt),
                  isDirty: const Value(0),
                ),
              );
        }
      });
    }

    // 3. user_removed → UserRemovedCountries table
    final removedSnap = await userDoc.collection('user_removed').get();
    if (removedSnap.docs.isNotEmpty) {
      await _db.transaction(() async {
        for (final doc in removedSnap.docs) {
          final data = doc.data();
          final removedAt =
              DateTime.tryParse(data['removedAt'] as String? ?? '')?.toUtc();
          if (removedAt == null) continue;
          await _db.into(_db.userRemovedCountries).insertOnConflictUpdate(
                UserRemovedCountriesCompanion(
                  countryCode: Value(doc.id),
                  removedAt: Value(removedAt),
                  isDirty: const Value(0),
                ),
              );
        }
      });
    }

    // 4. trips → Trips table
    final tripsSnap = await userDoc.collection('trips').get();
    if (tripsSnap.docs.isNotEmpty) {
      await _db.transaction(() async {
        for (final doc in tripsSnap.docs) {
          final data = doc.data();
          final countryCode = data['countryCode'] as String?;
          final startedOn =
              DateTime.tryParse(data['startedOn'] as String? ?? '')?.toUtc();
          final endedOn =
              DateTime.tryParse(data['endedOn'] as String? ?? '')?.toUtc();
          if (countryCode == null || startedOn == null || endedOn == null) {
            continue;
          }
          await _db.into(_db.trips).insertOnConflictUpdate(
                TripsCompanion(
                  id: Value(doc.id),
                  countryCode: Value(countryCode),
                  startedOn: Value(startedOn),
                  endedOn: Value(endedOn),
                  photoCount: Value((data['photoCount'] as int?) ?? 0),
                  isManual:
                      Value((data['isManual'] as bool? ?? false) ? 1 : 0),
                  isDirty: const Value(0),
                ),
              );
        }
      });
    }

    // 5. unlocked_achievements → UnlockedAchievements table
    final achievementsSnap =
        await userDoc.collection('unlocked_achievements').get();
    if (achievementsSnap.docs.isNotEmpty) {
      await _db.transaction(() async {
        for (final doc in achievementsSnap.docs) {
          final data = doc.data();
          final unlockedAt =
              DateTime.tryParse(data['unlockedAt'] as String? ?? '')?.toUtc();
          if (unlockedAt == null) continue;
          await _db.into(_db.unlockedAchievements).insertOnConflictUpdate(
                UnlockedAchievementsCompanion.insert(
                  achievementId: doc.id,
                  unlockedAt: unlockedAt,
                  isDirty: const Value(0),
                ),
              );
        }
      });
    }
  }
}
