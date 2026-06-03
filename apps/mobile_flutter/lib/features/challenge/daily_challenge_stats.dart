import 'package:drift/drift.dart' show Value, OrderingTerm;
import 'package:intl/intl.dart';

import '../../data/db/roavvy_database.dart';

// ── Aggregate model ───────────────────────────────────────────────────────────

/// Aggregated challenge statistics computed from the local [ChallengeStatsTable].
class ChallengeAggregate {
  const ChallengeAggregate({
    required this.totalPlayed,
    required this.totalSolved,
    required this.currentStreak,
    required this.bestStreak,
    required this.avgGuesses,
    required this.avgClues,
  });

  final int totalPlayed;
  final int totalSolved;

  /// Consecutive days the user solved the challenge ending today (or yesterday).
  final int currentStreak;

  final int bestStreak;

  /// Average wrong guesses on solved days.
  final double avgGuesses;

  /// Average clues used on solved days.
  final double avgClues;
}

// ── Service ───────────────────────────────────────────────────────────────────

/// Reads and writes per-day challenge stats from [ChallengeStatsTable].
///
/// Stats are recorded once per game session when the game ends (solve or fail).
/// Never synced to Firestore — private per-device data (ADR-002).
class ChallengeStatsService {
  const ChallengeStatsService(this._db);

  final RoavvyDatabase _db;

  // ── Writes ────────────────────────────────────────────────────────────────

  /// Records the result of one completed game session.
  ///
  /// Upserts — replaying a day overwrites the previous row.
  Future<void> record({
    required String date,
    required String siteId,
    required bool solved,
    required int guessesUsed,
    required int cluesUsed,
    int durationSecs = 0,
  }) async {
    await _db
        .into(_db.challengeStatsTable)
        .insertOnConflictUpdate(
          ChallengeStatsTableCompanion.insert(
            date: date,
            siteId: siteId,
            solved: Value(solved ? 1 : 0),
            guessesUsed: Value(guessesUsed),
            cluesUsed: Value(cluesUsed),
            durationSecs: Value(durationSecs),
          ),
        );
  }

  // ── Dev helpers ───────────────────────────────────────────────────────────

  /// Deletes the stats row for [date]. Used only in debug builds for testing.
  Future<void> deleteForDate(String date) async {
    await (_db.delete(_db.challengeStatsTable)
      ..where((t) => t.date.equals(date))).go();
  }

  // ── Reads ─────────────────────────────────────────────────────────────────

  /// Computes aggregate statistics from all stored rows.
  Future<ChallengeAggregate> loadAggregate() async {
    final rows =
        await (_db.select(_db.challengeStatsTable)
          ..orderBy([(t) => OrderingTerm.desc(t.date)])).get();

    if (rows.isEmpty) {
      return const ChallengeAggregate(
        totalPlayed: 0,
        totalSolved: 0,
        currentStreak: 0,
        bestStreak: 0,
        avgGuesses: 0,
        avgClues: 0,
      );
    }

    final totalPlayed = rows.length;
    final solvedRows = rows.where((r) => r.solved == 1).toList();
    final totalSolved = solvedRows.length;

    final avgGuesses =
        totalSolved > 0
            ? solvedRows.map((r) => r.guessesUsed).reduce((a, b) => a + b) /
                totalSolved
            : 0.0;
    final avgClues =
        totalSolved > 0
            ? solvedRows.map((r) => r.cluesUsed).reduce((a, b) => a + b) /
                totalSolved
            : 0.0;

    final currentStreak = _currentStreak(rows);
    final bestStreak = _bestStreak(rows);

    return ChallengeAggregate(
      totalPlayed: totalPlayed,
      totalSolved: totalSolved,
      currentStreak: currentStreak,
      bestStreak: bestStreak,
      avgGuesses: avgGuesses,
      avgClues: avgClues,
    );
  }

  /// Returns the most-recent 30 days of challenge history in descending order.
  Future<List<({String date, bool solved, int guessesUsed})>>
  last30Days() async {
    final rows =
        await (_db.select(_db.challengeStatsTable)
              ..orderBy([(t) => OrderingTerm.desc(t.date)])
              ..limit(30))
            .get();
    return rows
        .map(
          (r) => (
            date: r.date,
            solved: r.solved == 1,
            guessesUsed: r.guessesUsed,
          ),
        )
        .toList();
  }

  // ── Streak helpers ────────────────────────────────────────────────────────

  /// Current streak: consecutive days solved counting back from today/yesterday.
  int _currentStreak(List<ChallengeStatsRow> rows) {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now().toUtc());
    // rows are ordered DESC by date
    int streak = 0;
    DateTime? expected;

    for (final row in rows) {
      if (row.solved != 1) break;
      final rowDate = DateTime.parse(row.date).toUtc();

      if (expected == null) {
        // First row: accept today or yesterday.
        final todayDate = DateTime.parse(today).toUtc();
        final yesterday = todayDate.subtract(const Duration(days: 1));
        if (rowDate == todayDate || rowDate == yesterday) {
          streak++;
          expected = rowDate.subtract(const Duration(days: 1));
        } else {
          break;
        }
      } else {
        if (rowDate == expected) {
          streak++;
          expected = rowDate.subtract(const Duration(days: 1));
        } else {
          break;
        }
      }
    }
    return streak;
  }

  /// Best streak ever: longest consecutive solved run in the history.
  int _bestStreak(List<ChallengeStatsRow> rows) {
    // rows ordered DESC; reverse to ascending for scanning.
    final asc = rows.reversed.toList();
    int best = 0;
    int current = 0;
    DateTime? prev;

    for (final row in asc) {
      final rowDate = DateTime.parse(row.date).toUtc();
      if (row.solved == 1) {
        if (prev == null || rowDate.difference(prev).inDays == 1) {
          current++;
        } else {
          current = 1;
        }
        if (current > best) best = current;
        prev = rowDate;
      } else {
        current = 0;
        prev = null;
      }
    }
    return best;
  }
}
