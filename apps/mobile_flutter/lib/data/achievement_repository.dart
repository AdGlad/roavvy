import 'package:drift/drift.dart';

import 'db/roavvy_database.dart';

/// Mediates all reads and writes to the [UnlockedAchievements] Drift table.
///
/// Achievements are never cleared by [VisitRepository.clearAll] — once
/// earned they persist across travel-history deletes (ADR-036).
///
/// The dirty-flag pattern (ADR-030) is used here identically to
/// [VisitRepository]: rows start with [isDirty] = 1 and [FirestoreSyncService]
/// marks them clean after a successful Firestore write.
class AchievementRepository {
  const AchievementRepository(this._db);

  final RoavvyDatabase _db;

  // ── Writes ───────────────────────────────────────────────────────────────

  /// Inserts rows for each ID in [ids] that is not already present.
  ///
  /// Already-unlocked IDs are silently skipped (idempotent). New rows get
  /// [isDirty] = 1. [unlockedAt] is used for all new rows in this call.
  Future<void> upsertAll(Set<String> ids, DateTime unlockedAt) async {
    if (ids.isEmpty) return;
    await _db.transaction(() async {
      for (final id in ids) {
        await _db.into(_db.unlockedAchievements).insertOnConflictUpdate(
          UnlockedAchievementsCompanion.insert(
            achievementId: id,
            unlockedAt: unlockedAt.toUtc(),
            isDirty: const Value(1),
          ),
        );
      }
    });
  }

  // ── Reads ────────────────────────────────────────────────────────────────

  /// Returns the achievement IDs of all unlocked achievements.
  Future<List<String>> loadAll() async {
    final rows = await _db.select(_db.unlockedAchievements).get();
    return rows.map((r) => r.achievementId).toList();
  }

  /// Returns all unlocked achievement rows, including the unlock timestamp.
  ///
  /// Used by the Stats screen to display unlock dates in the achievement
  /// gallery (ADR-052, Decision 3).
  Future<List<UnlockedAchievementRow>> loadAllRows() =>
      _db.select(_db.unlockedAchievements).get();

  /// Returns all rows with [isDirty] = 1 (pending Firestore sync).
  Future<List<UnlockedAchievementRow>> loadDirty() =>
      (_db.select(_db.unlockedAchievements)
            ..where((t) => t.isDirty.equals(1)))
          .get();

  // ── Mark clean (called by FirestoreSyncService after a successful write) ──

  /// Sets [isDirty] = 0 and records [syncedAt] for a single achievement row.
  Future<void> markClean(String id, DateTime syncedAt) =>
      (_db.update(_db.unlockedAchievements)
            ..where((t) => t.achievementId.equals(id)))
          .write(UnlockedAchievementsCompanion(
        isDirty: const Value(0),
        syncedAt: Value(syncedAt.toUtc()),
      ));
}
