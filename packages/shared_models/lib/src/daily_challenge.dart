/// A single typed clue in the Daily Heritage Challenge.
///
/// [type] is one of: `geography`, `category`, `historical`, `location`, `direct`.
/// Backwards-compatible: old Firestore documents emit plain strings; those are
/// parsed as `ChallengeClue(type: 'general', text: value)`.
class ChallengeClue {
  const ChallengeClue({required this.type, required this.text});

  final String type;
  final String text;

  factory ChallengeClue.fromJson(Object json) {
    if (json is String) {
      return ChallengeClue(type: 'general', text: json);
    }
    final m = json as Map<String, dynamic>;
    return ChallengeClue(
      type: m['type'] as String? ?? 'general',
      text: m['text'] as String,
    );
  }
}

/// The server-side document fetched from Firestore for a given UTC date.
///
/// Clues are ordered from hardest (index 0, shown first) to easiest (index 4).
class DailyChallenge {
  const DailyChallenge({
    required this.siteId,
    required this.clues,
    this.difficulty = 'medium',
  });

  /// UNESCO `id_no` matching [WorldHeritageSite.siteId] in the bundled dataset.
  final String siteId;

  /// Five progressive typed clues. Always length 5.
  final List<ChallengeClue> clues;

  /// Difficulty tier: `'easy'`, `'medium'`, or `'hard'`.
  final String difficulty;
}

/// Local progress state for a single day's Daily Heritage Challenge.
///
/// Persisted to the [DailyChallengeProgressTable] in Drift. Never synced to
/// Firestore — this is private per-device state (ADR-002).
class DailyChallengeProgress {
  const DailyChallengeProgress({
    required this.date,
    required this.siteId,
    required this.cluesRevealed,
    required this.guesses,
    required this.solved,
    this.solvedAtClue,
    this.failed = false,
  });

  /// UTC date string in `YYYY-MM-DD` format. Primary key in local DB.
  final String date;

  /// The [WorldHeritageSite.siteId] for this day's challenge.
  final String siteId;

  /// Number of clues revealed so far (1–5). Starts at 1 (first clue auto-shown).
  final int cluesRevealed;

  /// Wrong guesses submitted by the user. Does not include the correct answer.
  final List<String> guesses;

  /// True once the user has correctly identified the site.
  final bool solved;

  /// Which clue was showing when the user solved it (1–5). Null until solved.
  final int? solvedAtClue;

  /// True when the user exhausted all 5 guesses without solving.
  final bool failed;

  DailyChallengeProgress copyWith({
    int? cluesRevealed,
    List<String>? guesses,
    bool? solved,
    int? solvedAtClue,
    bool? failed,
  }) {
    return DailyChallengeProgress(
      date: date,
      siteId: siteId,
      cluesRevealed: cluesRevealed ?? this.cluesRevealed,
      guesses: guesses ?? this.guesses,
      solved: solved ?? this.solved,
      solvedAtClue: solvedAtClue ?? this.solvedAtClue,
      failed: failed ?? this.failed,
    );
  }
}
