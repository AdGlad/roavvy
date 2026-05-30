import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:intl/intl.dart';
import 'package:shared_models/shared_models.dart';

/// Returns today's date as a `YYYY-MM-DD` string in the device's local timezone.
/// Using local time means the challenge resets at the user's local midnight,
/// matching the convention used by Wordle and similar daily games.
String todayLocal() => DateFormat('yyyy-MM-dd').format(DateTime.now());

/// Fetches the daily challenge document from Firestore.
///
/// Documents are keyed by local date (`YYYY-MM-DD`) so the challenge resets
/// at the user's local midnight.
///
/// Generation is handled entirely by [prefetch] / [forceRefresh]. [fetchToday]
/// only reads — if the document does not yet exist it throws immediately
/// rather than blocking on a slow Cloud Function call.
class DailyChallengeService {
  const DailyChallengeService();

  /// Reads `daily_challenge/{YYYY-MM-DD}` for today (local time).
  ///
  /// Returns immediately. Throws [DailyChallengeUnavailable] when the document
  /// is missing (generation still in progress) or on network errors.
  /// Callers should show a retry prompt; [prefetch] generates the doc in the
  /// background and the retry will succeed once it's written.
  Future<DailyChallenge> fetchToday() async {
    final date = todayLocal();
    try {
      final doc = await FirebaseFirestore.instance
          .collection('daily_challenge')
          .doc(date)
          .get()
          .timeout(const Duration(seconds: 15));

      if (!doc.exists || doc.data() == null) {
        throw const DailyChallengeUnavailable();
      }
      return _parse(doc.data()!);
    } on TimeoutException {
      throw const DailyChallengeUnavailable();
    } on FirebaseException {
      throw const DailyChallengeUnavailable();
    }
  }

  /// Fire-and-forget: asks the Cloud Function to generate today's document in
  /// the background. Called on every app start so the document is ready before
  /// the user opens the challenge screen. Swallows all errors.
  void prefetch() {
    FirebaseFunctions.instance
        .httpsCallable(
          'getDailyChallenge',
          options: HttpsCallableOptions(
            timeout: const Duration(seconds: 90),
          ),
        )
        .call({'date': todayLocal()})
        .ignore();
  }

  /// Calls the Cloud Function to force-regenerate today's challenge, then
  /// reads the result. Used by the manual refresh button.
  Future<DailyChallenge> forceRefresh() async {
    final date = todayLocal();
    try {
      await FirebaseFunctions.instance
          .httpsCallable(
            'getDailyChallenge',
            options: HttpsCallableOptions(
              timeout: const Duration(seconds: 90),
            ),
          )
          .call({'date': date});
      return fetchToday();
    } on FirebaseException {
      throw const DailyChallengeUnavailable();
    }
  }

  static DailyChallenge _parse(Map<String, dynamic> data) {
    final rawClues = data['clues'] as List<dynamic>;
    return DailyChallenge(
      siteId: data['siteId'] as String,
      clues: rawClues
          .map<ChallengeClue>((e) => ChallengeClue.fromJson(e as Object))
          .toList(),
      difficulty: data['difficulty'] as String? ?? 'medium',
    );
  }
}

/// Thrown when today's challenge document is missing or unreachable.
class DailyChallengeUnavailable implements Exception {
  const DailyChallengeUnavailable();

  @override
  String toString() => 'DailyChallengeUnavailable';
}
