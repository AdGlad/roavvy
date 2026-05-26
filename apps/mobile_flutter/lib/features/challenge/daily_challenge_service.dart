import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:shared_models/shared_models.dart';

/// Fetches the daily challenge document from Firestore.
///
/// The document is written by the `scheduleDailyChallenge` Cloud Function
/// (M133, ADR-XXX) and is identical for all users on a given UTC date.
class DailyChallengeService {
  const DailyChallengeService();

  /// Reads `daily_challenge/{YYYY-MM-DD}` for today UTC.
  ///
  /// Throws [DailyChallengeUnavailable] when the document does not exist
  /// (function hasn't run yet) or when a network error occurs.
  Future<DailyChallenge> fetchToday() async {
    final date = DateFormat('yyyy-MM-dd').format(DateTime.now().toUtc());
    try {
      final doc = await FirebaseFirestore.instance
          .collection('daily_challenge')
          .doc(date)
          .get();
      if (!doc.exists || doc.data() == null) {
        throw const DailyChallengeUnavailable();
      }
      final data = doc.data()!;
      return DailyChallenge(
        siteId: data['siteId'] as String,
        clues: List<String>.from(data['clues'] as List),
      );
    } on FirebaseException {
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
