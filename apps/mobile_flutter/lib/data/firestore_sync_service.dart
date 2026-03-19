import 'package:cloud_firestore/cloud_firestore.dart';

import 'achievement_repository.dart';
import 'trip_repository.dart';
import 'visit_repository.dart';

/// Contract for pushing dirty local records to the cloud.
///
/// The real implementation ([FirestoreSyncService]) writes to Cloud Firestore.
/// [NoOpSyncService] is a stub used in widget tests to prevent real network
/// calls (ADR-030).
abstract class SyncService {
  Future<void> flushDirty(
    String uid,
    VisitRepository repo, {
    AchievementRepository? achievementRepo,
    TripRepository? tripRepo,
  });
}

/// Pushes all [isDirty] = 1 rows from the three Drift tables to the three
/// Firestore subcollections under `users/{uid}` (ADR-029).
///
/// On a successful Firestore write, the corresponding Drift row is marked
/// clean ([isDirty] = 0, [syncedAt] set to now). Failures are silent —
/// [isDirty] remains 1 and the row will be retried on the next call.
///
/// Firestore schema (ADR-029):
///   users/{uid}/inferred_visits/{countryCode} → {inferredAt, photoCount, firstSeen?, lastSeen?, syncedAt}
///   users/{uid}/user_added/{countryCode}      → {addedAt, syncedAt}
///   users/{uid}/user_removed/{countryCode}    → {removedAt, syncedAt}
///
/// Privacy (ADR-002): no GPS coordinates, no photo filenames, no PHAsset
/// identifiers appear in any document written here.
class FirestoreSyncService implements SyncService {
  FirestoreSyncService([FirebaseFirestore? firestore])
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Future<void> flushDirty(
    String uid,
    VisitRepository repo, {
    AchievementRepository? achievementRepo,
    TripRepository? tripRepo,
  }) async {
    final now = DateTime.now().toUtc();
    final userDoc = _firestore.collection('users').doc(uid);

    final dirtyInferred = await repo.loadDirtyInferred();
    for (final v in dirtyInferred) {
      try {
        await userDoc
            .collection('inferred_visits')
            .doc(v.countryCode)
            .set({
          'inferredAt': v.inferredAt.toIso8601String(),
          'photoCount': v.photoCount,
          if (v.firstSeen != null) 'firstSeen': v.firstSeen!.toIso8601String(),
          if (v.lastSeen != null) 'lastSeen': v.lastSeen!.toIso8601String(),
          'syncedAt': now.toIso8601String(),
        });
        await repo.markInferredClean(v.countryCode, now);
      } catch (_) {
        // Silent failure — isDirty remains 1; retry on next call.
      }
    }

    final dirtyAdded = await repo.loadDirtyAdded();
    for (final v in dirtyAdded) {
      try {
        await userDoc
            .collection('user_added')
            .doc(v.countryCode)
            .set({
          'addedAt': v.addedAt.toIso8601String(),
          'syncedAt': now.toIso8601String(),
        });
        await repo.markAddedClean(v.countryCode, now);
      } catch (_) {
        // Silent failure — isDirty remains 1; retry on next call.
      }
    }

    final dirtyRemoved = await repo.loadDirtyRemoved();
    for (final v in dirtyRemoved) {
      try {
        await userDoc
            .collection('user_removed')
            .doc(v.countryCode)
            .set({
          'removedAt': v.removedAt.toIso8601String(),
          'syncedAt': now.toIso8601String(),
        });
        await repo.markRemovedClean(v.countryCode, now);
      } catch (_) {
        // Silent failure — isDirty remains 1; retry on next call.
      }
    }

    if (achievementRepo != null) {
      final dirtyAchievements = await achievementRepo.loadDirty();
      for (final row in dirtyAchievements) {
        try {
          await userDoc
              .collection('unlocked_achievements')
              .doc(row.achievementId)
              .set({
            'unlockedAt': row.unlockedAt.toUtc().toIso8601String(),
            'syncedAt': now.toIso8601String(),
          });
          await achievementRepo.markClean(row.achievementId, now);
        } catch (_) {
          // Silent failure — isDirty remains 1; retry on next call.
        }
      }
    }

    if (tripRepo != null) {
      final dirtyTrips = await tripRepo.loadDirty();
      for (final t in dirtyTrips) {
        try {
          await userDoc.collection('trips').doc(t.id).set({
            'countryCode': t.countryCode,
            'startedOn': t.startedOn.toUtc().toIso8601String(),
            'endedOn': t.endedOn.toUtc().toIso8601String(),
            'photoCount': t.photoCount,
            'isManual': t.isManual,
            'syncedAt': now.toIso8601String(),
          });
          await tripRepo.markClean(t.id, now);
        } catch (_) {
          // Silent failure — isDirty remains 1; retry on next call.
        }
      }
    }
  }
}

/// No-op stub used in widget tests. Prevents any real Firestore calls.
class NoOpSyncService implements SyncService {
  const NoOpSyncService();

  @override
  Future<void> flushDirty(
    String uid,
    VisitRepository repo, {
    AchievementRepository? achievementRepo,
    TripRepository? tripRepo,
  }) async {}
}
