import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:shared_models/shared_models.dart';

import 'db/roavvy_database.dart';

/// Mediates reads and writes to the [DailyChallengeProgressTable] Drift table.
///
/// Stores per-day challenge progress (clues revealed, guesses, solved state).
/// Never synced to Firestore — private per-device data (ADR-002, M133).
class DailyChallengeRepository {
  const DailyChallengeRepository(this._db);

  final RoavvyDatabase _db;

  // ── Reads ─────────────────────────────────────────────────────────────────

  /// Returns today's progress row, or null if the user has not started yet.
  Future<DailyChallengeProgress?> loadToday(String date) async {
    final rows =
        await (_db.select(_db.dailyChallengeProgressTable)
          ..where((t) => t.date.equals(date))).get();
    if (rows.isEmpty) return null;
    return _fromRow(rows.first);
  }

  // ── Writes ────────────────────────────────────────────────────────────────

  /// Deletes the progress row for [date], if any. Used for dev testing.
  Future<void> deleteProgress(String date) async {
    await (_db.delete(_db.dailyChallengeProgressTable)
      ..where((t) => t.date.equals(date))).go();
  }

  /// Inserts or replaces a progress row for [progress.date].
  Future<void> save(DailyChallengeProgress progress) async {
    await _db
        .into(_db.dailyChallengeProgressTable)
        .insertOnConflictUpdate(
          DailyChallengeProgressTableCompanion.insert(
            date: progress.date,
            siteId: progress.siteId,
            cluesRevealed: Value(progress.cluesRevealed),
            guesses: Value(jsonEncode(progress.guesses)),
            solved: Value(progress.solved ? 1 : 0),
            solvedAtClue:
                progress.solvedAtClue == null
                    ? const Value.absent()
                    : Value(progress.solvedAtClue!),
            failed: Value(progress.failed ? 1 : 0),
          ),
        );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static DailyChallengeProgress _fromRow(DailyChallengeProgressRow row) {
    final guesses = (jsonDecode(row.guesses) as List<dynamic>).cast<String>();
    return DailyChallengeProgress(
      date: row.date,
      siteId: row.siteId,
      cluesRevealed: row.cluesRevealed,
      guesses: guesses,
      solved: row.solved == 1,
      solvedAtClue: row.solvedAtClue,
      failed: row.failed == 1,
    );
  }
}
