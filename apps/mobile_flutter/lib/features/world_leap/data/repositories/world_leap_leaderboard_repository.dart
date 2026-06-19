// lib/features/world_leap/data/repositories/world_leap_leaderboard_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../world_leap_config.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

class LeaderboardEntry {
  final String userId;
  final String displayName;
  final int totalScore;
  final int countryCount;
  final DateTime completedAt;

  const LeaderboardEntry({
    required this.userId,
    required this.displayName,
    required this.totalScore,
    required this.countryCount,
    required this.completedAt,
  });

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'displayName': displayName,
        'totalScore': totalScore,
        'countryCount': countryCount,
        'completedAt': completedAt.toIso8601String(),
      };

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) =>
      LeaderboardEntry(
        userId: json['userId'] as String,
        displayName: json['displayName'] as String,
        totalScore: (json['totalScore'] as num).toInt(),
        countryCount: (json['countryCount'] as num).toInt(),
        completedAt: DateTime.parse(json['completedAt'] as String),
      );
}

// ── Repository ────────────────────────────────────────────────────────────────

class WorldLeapLeaderboardRepository {
  final FirebaseFirestore _firestore;

  WorldLeapLeaderboardRepository(FirebaseFirestore firestore)
      : _firestore = firestore;

  // ── Helpers ────────────────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(WorldLeapConfig.leaderboardCollection);

  String _docId(String date, String userId) => '${date}_$userId';

  Query<Map<String, dynamic>> _topQuery(String date, int limit) => _collection
      .where('date', isEqualTo: date)
      .orderBy('totalScore', descending: true)
      .limit(limit);

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Upserts this user's entry for [date].
  Future<void> upsertEntry(String date, LeaderboardEntry entry) async {
    await _collection
        .doc(_docId(date, entry.userId))
        .set({'date': date, ...entry.toJson()});
  }

  /// Returns the top [limit] entries for [date], ordered by totalScore descending.
  Future<List<LeaderboardEntry>> getTopEntries(
    String date, {
    int limit = 20,
  }) async {
    final snapshot = await _topQuery(date, limit).get();
    return snapshot.docs
        .map((doc) => LeaderboardEntry.fromJson(doc.data()))
        .toList();
  }

  /// Stream of the top [limit] entries (real-time).
  Stream<List<LeaderboardEntry>> watchTopEntries(
    String date, {
    int limit = 20,
  }) {
    return _topQuery(date, limit).snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => LeaderboardEntry.fromJson(doc.data()))
              .toList(),
        );
  }
}
