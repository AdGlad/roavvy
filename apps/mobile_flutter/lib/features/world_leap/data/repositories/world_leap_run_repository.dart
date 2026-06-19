// lib/features/world_leap/data/repositories/world_leap_run_repository.dart

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/world_leap_run.dart';
import '../../world_leap_config.dart';

// ── Abstract interface ────────────────────────────────────────────────────────

abstract class IWorldLeapRunRepository {
  /// Load the run for [userId] on [date]. Returns null if none exists.
  Future<WorldLeapRun?> loadRun(String userId, String date);

  /// Persist [run] to both local cache and Firestore.
  Future<void> saveRun(WorldLeapRun run);

  /// Stream that emits whenever the run document changes in Firestore.
  /// Emits null if no document exists yet.
  Stream<WorldLeapRun?> watchRun(String userId, String date);

  /// Delete the local cached run (used for testing/reset, not game flow).
  Future<void> clearLocalRun();

  /// Delete the run from both local cache and Firestore (used for reset/testing).
  Future<void> deleteRun(String userId, String date);
}

// ── Concrete implementation ───────────────────────────────────────────────────

class WorldLeapRunRepository implements IWorldLeapRunRepository {
  final FirebaseFirestore _firestore;
  final SharedPreferences _prefs;

  WorldLeapRunRepository({
    required FirebaseFirestore firestore,
    required SharedPreferences prefs,
  })  : _firestore = firestore,
        _prefs = prefs;

  // ── Helpers ──────────────────────────────────────────────────────────────

  DocumentReference<Map<String, dynamic>> _doc(String userId, String date) =>
      _firestore
          .collection(WorldLeapConfig.runsCollection)
          .doc(WorldLeapRun.documentId(userId, date));

  // ── IWorldLeapRunRepository ───────────────────────────────────────────────

  @override
  Future<WorldLeapRun?> loadRun(String userId, String date) async {
    // 1. Try local cache first.
    final cached = _prefs.getString(WorldLeapConfig.localRunKey);
    if (cached != null) {
      try {
        final run = WorldLeapRun.fromJson(
            jsonDecode(cached) as Map<String, dynamic>);
        if (run.userId == userId && run.date == date) {
          return run;
        }
      } catch (_) {
        // Corrupt cache — fall through to Firestore.
      }
    }

    // 2. Fall back to Firestore.
    final snapshot = await _doc(userId, date).get();
    if (!snapshot.exists || snapshot.data() == null) return null;
    return WorldLeapRun.fromJson(snapshot.data()!);
  }

  @override
  Future<void> saveRun(WorldLeapRun run) async {
    // Write to local cache.
    await _prefs.setString(
        WorldLeapConfig.localRunKey, jsonEncode(run.toJson()));

    // Write to Firestore (merge so partial updates don't clobber fields).
    await _doc(run.userId, run.date).set(run.toJson());
  }

  @override
  Stream<WorldLeapRun?> watchRun(String userId, String date) {
    return _doc(userId, date).snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) return null;
      return WorldLeapRun.fromJson(snapshot.data()!);
    });
  }

  @override
  Future<void> clearLocalRun() async {
    await _prefs.remove(WorldLeapConfig.localRunKey);
  }

  @override
  Future<void> deleteRun(String userId, String date) async {
    await _prefs.remove(WorldLeapConfig.localRunKey);
    await _doc(userId, date).delete();
  }
}
