import 'hero_image.dart';

/// Scores and ranks a set of [HeroAnalysisResult] candidates for a single trip.
///
/// Scoring formula (M89, ADR-134):
///   HeroScore = qualityScore (0–30) + labelScore (0–25) +
///               diversityScore (0–25) + metadataScore (0–20)
///
/// The highest-scoring candidate is assigned rank=1 (the hero).
/// Up to 3 candidates are returned with ranks 1, 2, 3.
/// Tie-breaking: higher [HeroLabels.confidence] wins.
class HeroScoringEngine {
  const HeroScoringEngine();

  /// Scores and ranks [candidates] for a single trip.
  ///
  /// Returns up to 3 [HeroImage] records ordered by rank (1, 2, 3).
  /// Returns an empty list when [candidates] is empty.
  List<HeroImage> rank({
    required String tripId,
    required String countryCode,
    required List<HeroAnalysisResult> candidates,
  }) {
    if (candidates.isEmpty) return const [];

    final scored = candidates.map((c) {
      final score = _computeScore(c, candidates);
      return _ScoredCandidate(result: c, score: score);
    }).toList()
      ..sort((a, b) {
        final cmp = b.score.compareTo(a.score);
        if (cmp != 0) return cmp;
        // Tie-break: higher label confidence wins.
        return b.result.labels.confidence.compareTo(a.result.labels.confidence);
      });

    final now = DateTime.now().toUtc();
    final heroes = <HeroImage>[];

    for (var i = 0; i < scored.length && i < 3; i++) {
      final c = scored[i].result;
      final rank = i + 1;
      final id = rank == 1 ? 'hero_$tripId' : 'hero_${tripId}_$rank';

      heroes.add(HeroImage(
        id: id,
        assetId: c.assetId,
        tripId: tripId,
        countryCode: countryCode,
        capturedAt: c.capturedAt,
        heroScore: scored[i].score,
        rank: rank,
        isUserSelected: false,
        primaryScene: c.labels.primaryScene,
        secondaryScene: c.labels.secondaryScene,
        activity: c.labels.activity,
        mood: c.labels.mood,
        subjects: c.labels.subjects,
        landmark: c.labels.landmark,
        labelConfidence: c.labels.confidence,
        qualityScore: c.qualityScore,
        thumbnailLocalPath: null,
        createdAt: now,
        updatedAt: now,
      ));
    }

    return heroes;
  }

  double _computeScore(
    HeroAnalysisResult candidate,
    List<HeroAnalysisResult> allCandidates,
  ) {
    return _qualityScore(candidate) +
        _labelScore(candidate) +
        _diversityScore(candidate, allCandidates) +
        _metadataScore(candidate);
  }

  // ---------------------------------------------------------------------------
  // Quality score (0–30)
  // ---------------------------------------------------------------------------

  double _qualityScore(HeroAnalysisResult c) {
    double score = 0;

    // Pixel dimension sub-score (0–15).
    final shorter = c.pixelWidth < c.pixelHeight ? c.pixelWidth : c.pixelHeight;
    if (shorter >= 2000) {
      score += 15;
    } else if (shorter >= 1080) {
      score += 10;
    }

    // Aperture/sharpness sub-score (0–15) — already normalised 0.0–1.0 by Swift.
    final q = c.qualityScore; // 0.0–1.0
    if (q >= 0.6) {
      score += 15;
    } else if (q >= 0.4) {
      score += 10;
    } else if (q >= 0.2) {
      score += 5;
    }

    return score;
  }

  // ---------------------------------------------------------------------------
  // Label score (0–25)
  // ---------------------------------------------------------------------------

  double _labelScore(HeroAnalysisResult c) {
    final labels = c.labels;
    double score = 0;

    if (labels.landmark != null) score += 12;
    if (labels.mood.contains('sunset') || labels.mood.contains('golden_hour')) {
      score += 10;
    }
    if (labels.subjects.contains('people') ||
        labels.subjects.contains('group')) {
      score += 7;
    }
    if (labels.primaryScene != null) score += 6;

    // Up to +5 for additional mood/activity labels.
    final extra = labels.mood.length + labels.activity.length;
    score += (extra * 2).clamp(0, 5).toDouble();

    return score.clamp(0, 25);
  }

  // ---------------------------------------------------------------------------
  // Diversity score (0–25) — relative to other candidates in the trip
  // ---------------------------------------------------------------------------

  double _diversityScore(
    HeroAnalysisResult c,
    List<HeroAnalysisResult> all,
  ) {
    if (all.isEmpty) return 0;

    double score = 0;

    // Sort candidates by time to determine trip duration.
    final times = all.map((a) => a.capturedAt.millisecondsSinceEpoch).toList()
      ..sort();
    final earliest = times.first;
    final latest = times.last;
    final duration = latest - earliest;

    // Photo is in the first 25% of trip: +10.
    if (duration > 0) {
      final elapsed = c.capturedAt.millisecondsSinceEpoch - earliest;
      if (elapsed / duration <= 0.25) score += 10;
    } else {
      // Single-photo trip — award first-25% bonus.
      score += 10;
    }

    // Photo is on a different day from all other candidates: +8.
    final cDay = _dayKey(c.capturedAt);
    final otherDays = all
        .where((a) => a.assetId != c.assetId)
        .map((a) => _dayKey(a.capturedAt))
        .toSet();
    if (otherDays.isEmpty || !otherDays.contains(cDay)) score += 8;

    // No other candidates within 5 km: +7.
    // GPS is not available to Dart-side (ADR-002), so we use a proxy:
    // award the bonus when this candidate has GPS and all others lack it,
    // or when this candidate is the only GPS-tagged one.
    final othersWithGps = all.where((a) => a.assetId != c.assetId && a.hasGps);
    if (c.hasGps && othersWithGps.isEmpty) score += 7;

    return score.clamp(0, 25);
  }

  // ---------------------------------------------------------------------------
  // Metadata score (0–20)
  // ---------------------------------------------------------------------------

  double _metadataScore(HeroAnalysisResult c) {
    double score = 0;
    if (c.hasGps) score += 15;
    // Uniqueness bonus (not a burst duplicate) is encoded by the candidate
    // selector before this engine is called, so we just add a fixed +5 for
    // the fact that the candidate made it through dedup.
    score += 5;
    return score;
  }

  static String _dayKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}

class _ScoredCandidate {
  const _ScoredCandidate({required this.result, required this.score});
  final HeroAnalysisResult result;
  final double score;
}
