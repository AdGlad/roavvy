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
/// at the user's local midnight. If today's document does not yet exist, the
/// `getDailyChallenge` Cloud Function is called to generate it on-demand.
class DailyChallengeService {
  const DailyChallengeService();

  /// Reads `daily_challenge/{YYYY-MM-DD}` for today (local time).
  ///
  /// If the document is missing (function hasn't run for this local date yet),
  /// triggers the Cloud Function to generate it, then re-reads.
  ///
  /// Throws [DailyChallengeUnavailable] on unrecoverable network errors.
  Future<DailyChallenge> fetchToday() async {
    final date = todayLocal();
    try {
      var doc = await FirebaseFirestore.instance
          .collection('daily_challenge')
          .doc(date)
          .get();

      // Document missing — ask the Cloud Function to generate it.
      if (!doc.exists || doc.data() == null) {
        await FirebaseFunctions.instance
            .httpsCallable('getDailyChallenge')
            .call({'date': date});
        doc = await FirebaseFirestore.instance
            .collection('daily_challenge')
            .doc(date)
            .get();
      }

      if (!doc.exists || doc.data() == null) {
        throw const DailyChallengeUnavailable();
      }
      final data = doc.data()!;
      final rawClues = data['clues'] as List<dynamic>;
      return DailyChallenge(
        siteId: data['siteId'] as String,
        clues: rawClues
            .map<ChallengeClue>((e) => ChallengeClue.fromJson(e as Object))
            .toList(),
        difficulty: data['difficulty'] as String? ?? 'medium',
      );
    } on FirebaseException {
      throw const DailyChallengeUnavailable();
    } on FirebaseFunctionsException {
      throw const DailyChallengeUnavailable();
    }
  }

    /// Fire-and-forget prefetch: asks the Cloud Function to generate today's
  /// challenge document in the background so it exists before the user opens
  /// the screen. Swallows all errors — this is best-effort only.
  void prefetch() {
    final date = todayLocal();
    FirebaseFunctions.instance
        .httpsCallable('getDailyChallenge')
        .call({'date': date})
        .ignore();
  }

  /// Calls the Cloud Function to force-generate (or re-fetch) today's
  /// challenge, then returns it. Used by the refresh button.
  Future<DailyChallenge> forceRefresh() async {
    final date = todayLocal();
    try {
      await FirebaseFunctions.instance
          .httpsCallable('getDailyChallenge')
          .call({'date': date});
      return fetchToday();
    } on FirebaseFunctionsException {
      throw const DailyChallengeUnavailable();
    }
  }
}

/// Thrown when today's challenge document is missing or unreachable.
class DailyChallengeUnavailable implements Exception {
  const DailyChallengeUnavailable();

  @override
  String toString() => 'DailyChallengeUnavailable';
}
