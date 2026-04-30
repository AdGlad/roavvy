import 'dart:developer' as dev;

import 'hero_image.dart';

/// Scores and ranks a set of [HeroAnalysisResult] candidates for a single trip.
///
/// Scoring formula (M89 updated, ADR-134):
///
///   heroScore = visualImpact  × 0.40   (0–40)
///             + quality       × 0.30   (0–30)
///             + travelScene   × 0.20   (0–20)
///             + uniqueness    × 0.10   (0–10)
///
/// Each component produces 0–100; the weighted sum is 0–100.
///
/// The highest-scoring candidate is assigned rank=1 (the hero).
/// Up to 3 candidates are returned with ranks 1, 2, 3.
/// Tie-breaking: higher [HeroLabels.confidence] wins.
///
/// Debug output (dart:developer log, name 'HeroScore') explains why the
/// winning photo was chosen and lists the scores of rejected candidates.
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
      final vi = _visualImpact(c);
      final q = _quality(c);
      final ts = _travelScene(c);
      final u = _uniqueness(c, candidates);
      final total = vi * 0.40 + q * 0.30 + ts * 0.20 + u * 0.10;
      return _ScoredCandidate(
        result: c,
        score: total,
        visualImpact: vi,
        quality: q,
        travel: ts,
        uniqueness: u,
      );
    }).toList()
      ..sort((a, b) {
        final cmp = b.score.compareTo(a.score);
        if (cmp != 0) return cmp;
        return b.result.labels.confidence.compareTo(a.result.labels.confidence);
      });

    _debugLog(scored, tripId: tripId);

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

  // ---------------------------------------------------------------------------
  // Visual Impact Score (0–100)
  //
  // Rewards vibrant colours, centred composition, golden-hour / scenic mood,
  // landmark presence, and group photos in scenic context.
  // Penalises food-only shots, isolated selfies, and very low-confidence
  // (likely flat/plain) images. A "not share-worthy" flag halves the score.
  // ---------------------------------------------------------------------------

  double _visualImpact(HeroAnalysisResult c) {
    double score = 0;

    // Color richness (0–25): vibrant images score higher.
    score += c.colorRichnessScore * 25;

    // Composition — saliency centering (0–20): subject clearly in frame.
    score += c.saliencyCenterScore * 20;

    // Mood / lighting (up to 20): golden hour and sunsets are visually striking.
    final mood = c.labels.mood;
    if (mood.contains('golden_hour')) {
      score += 20;
    } else if (mood.contains('sunset')) {
      score += 16;
    } else if (mood.contains('sunrise')) {
      score += 14;
    } else if (mood.contains('night')) {
      score += 10;
    }

    // Landmark (15): recognisable place signals a memorable travel moment.
    if (c.labels.landmark != null) score += 15;

    // Scenic primary scene (up to 10).
    const _topScenes = {'mountain', 'beach', 'island', 'coast', 'snow', 'desert'};
    const _goodScenes = {'forest', 'countryside', 'lake'};
    if (_topScenes.contains(c.labels.primaryScene)) {
      score += 10;
    } else if (_goodScenes.contains(c.labels.primaryScene)) {
      score += 6;
    } else if (c.labels.primaryScene == 'city') {
      score += 3;
    }

    // Face + context boost (up to 8): group or people in a scenic setting.
    if (c.faceCount >= 2 && c.labels.primaryScene != null) {
      score += 8;
    } else if (c.faceCount >= 1 && c.labels.primaryScene != null) {
      score += 4;
    }

    // Anti-boring penalties.
    // Food shot with no scene context → not a travel hero.
    if (c.labels.activity.contains('food') && c.labels.primaryScene == null) {
      score -= 15;
    }
    // Selfie with no scenic / landmark context → portrait-only.
    if (c.labels.subjects.contains('selfie') &&
        c.labels.primaryScene == null &&
        c.labels.landmark == null) {
      score -= 10;
    }
    // Very low label confidence with no scene → likely flat/plain image.
    if (c.labels.confidence < 0.30 && c.labels.primaryScene == null) {
      score -= 8;
    }

    // Share-worthy gate: if not share-worthy, reduce score significantly.
    if (!_isShareWorthy(c)) score *= 0.6;

    return score.clamp(0, 100);
  }

  /// Returns false for images that are unlikely to represent a meaningful
  /// travel memory: food-only shots and portrait-only selfies with no scene.
  bool _isShareWorthy(HeroAnalysisResult c) {
    // Food with no travel scene and no people → a meal photo, not a memory.
    if (c.labels.activity.contains('food') &&
        c.labels.primaryScene == null &&
        c.labels.subjects.isEmpty) {
      return false;
    }
    // Selfie-only with no scene and no landmark → headshot, not a travel photo.
    if (c.labels.subjects.contains('selfie') &&
        c.labels.primaryScene == null &&
        c.labels.landmark == null) {
      return false;
    }
    return true;
  }

  // ---------------------------------------------------------------------------
  // Quality Score (0–100)
  //
  // Combines the Swift-computed dimension-based quality score with an
  // analysis-resolution adequacy check. Images analysed at very low
  // resolution receive no resolution bonus (quality is unverifiable).
  // ---------------------------------------------------------------------------

  double _quality(HeroAnalysisResult c) {
    // Swift quality score 0.0–1.0 (dimension-based): 0–60.
    double score = c.qualityScore * 60;

    // Analysis resolution adequacy: was the image large enough to assess well?
    // analysisResolution == 0 means an older result without this field.
    final res = c.analysisResolution;
    if (res >= 800) {
      score += 40;
    } else if (res >= 400) {
      score += 25;
    } else if (res >= 200) {
      score += 12;
    }
    // res < 200 or 0: no bonus — quality assessment unreliable.

    return score.clamp(0, 100);
  }

  // ---------------------------------------------------------------------------
  // Travel Scene Score (0–100)
  //
  // Rewards images that look like genuine travel moments: landmarks, scenic
  // outdoor scenes, active travel (hiking, skiing, boat), architecture in
  // context, and the presence of a secondary scene indicating a rich location.
  // ---------------------------------------------------------------------------

  double _travelScene(HeroAnalysisResult c) {
    double score = 0;

    // Landmark is the strongest travel signal.
    if (c.labels.landmark != null) score += 30;

    // Outdoor scenic scenes.
    const _topScenes = {'mountain', 'beach', 'island', 'coast', 'desert', 'snow'};
    const _goodScenes = {'forest', 'countryside', 'lake'};
    if (_topScenes.contains(c.labels.primaryScene)) {
      score += 25;
    } else if (_goodScenes.contains(c.labels.primaryScene)) {
      score += 15;
    } else if (c.labels.primaryScene == 'city') {
      score += 10;
    }

    // Active travel activities (first match only).
    const _activityScores = {
      'hiking': 20,
      'skiing': 18,
      'boat': 15,
      'roadtrip': 12,
    };
    for (final act in c.labels.activity) {
      final actScore = _activityScores[act];
      if (actScore != null) {
        score += actScore;
        break;
      }
    }

    // Architecture in a travel context (landmark or scene present).
    if (c.labels.subjects.contains('architecture') &&
        c.labels.primaryScene != null) {
      score += 10;
    }

    // Secondary scene: richer location description.
    if (c.labels.secondaryScene != null) score += 5;

    return score.clamp(0, 100);
  }

  // ---------------------------------------------------------------------------
  // Uniqueness Score (0–100)
  //
  // Rewards GPS-tagged photos, candidates from a different day than the other
  // candidates (scene diversity), early-trip photos (often arrival impressions),
  // and sole GPS-tagged candidates.
  // ---------------------------------------------------------------------------

  double _uniqueness(
    HeroAnalysisResult c,
    List<HeroAnalysisResult> all,
  ) {
    double score = 0;

    // GPS data: strong uniqueness signal.
    if (c.hasGps) score += 40;

    // Different calendar day from all other candidates.
    final cDay = _dayKey(c.capturedAt);
    final otherDays = all
        .where((a) => a.assetId != c.assetId)
        .map((a) => _dayKey(a.capturedAt))
        .toSet();
    if (!otherDays.contains(cDay)) score += 30;

    // Early in trip (first 25%): often the first impression of a destination.
    final times =
        all.map((a) => a.capturedAt.millisecondsSinceEpoch).toList()..sort();
    if (times.isNotEmpty) {
      final duration = times.last - times.first;
      if (duration > 0) {
        final elapsed = c.capturedAt.millisecondsSinceEpoch - times.first;
        if (elapsed / duration <= 0.25) score += 20;
      } else {
        // Single-photo trip — always award early-trip bonus.
        score += 20;
      }
    }

    // Sole GPS-tagged candidate: uniquely located.
    final othersWithGps = all.where((a) => a.assetId != c.assetId && a.hasGps);
    if (c.hasGps && othersWithGps.isEmpty) score += 10;

    return score.clamp(0, 100);
  }

  // ---------------------------------------------------------------------------
  // Debug logging
  // ---------------------------------------------------------------------------

  void _debugLog(List<_ScoredCandidate> scored, {required String tripId}) {
    if (scored.isEmpty) return;
    final winner = scored.first;
    final buf = StringBuffer()
      ..writeln('[HeroScore] Trip: $tripId — winner: ${winner.result.assetId}')
      ..writeln(
        '  Total: ${winner.score.toStringAsFixed(1)} | '
        'Visual: ${winner.visualImpact.toStringAsFixed(1)} | '
        'Quality: ${winner.quality.toStringAsFixed(1)} | '
        'Travel: ${winner.travel.toStringAsFixed(1)} | '
        'Uniqueness: ${winner.uniqueness.toStringAsFixed(1)}',
      )
      ..writeln(
        '  Labels: scene=${winner.result.labels.primaryScene} '
        'mood=${winner.result.labels.mood} '
        'subjects=${winner.result.labels.subjects} '
        'landmark=${winner.result.labels.landmark} '
        'activity=${winner.result.labels.activity}',
      )
      ..writeln(
        '  colorRichness=${winner.result.colorRichnessScore.toStringAsFixed(2)} '
        'saliency=${winner.result.saliencyCenterScore.toStringAsFixed(2)} '
        'faces=${winner.result.faceCount} '
        'resolution=${winner.result.analysisResolution}px '
        'qualityScore=${winner.result.qualityScore.toStringAsFixed(2)}',
      );

    if (scored.length > 1) {
      buf.writeln('  Rejected candidates:');
      for (final c in scored.skip(1)) {
        buf.writeln(
          '    ${c.result.assetId}: total=${c.score.toStringAsFixed(1)} '
          '(V=${c.visualImpact.toStringAsFixed(1)} '
          'Q=${c.quality.toStringAsFixed(1)} '
          'T=${c.travel.toStringAsFixed(1)} '
          'U=${c.uniqueness.toStringAsFixed(1)})',
        );
      }
    }

    if (winner.score < 60) {
      buf.writeln(
        '  ⚠ Best score ${winner.score.toStringAsFixed(1)} < 60 — '
        'manual hero selection recommended for trip $tripId',
      );
    }

    dev.log(buf.toString().trimRight(), name: 'HeroScore');
  }

  static String _dayKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';
}

class _ScoredCandidate {
  const _ScoredCandidate({
    required this.result,
    required this.score,
    required this.visualImpact,
    required this.quality,
    required this.travel,
    required this.uniqueness,
  });

  final HeroAnalysisResult result;
  final double score;
  final double visualImpact;
  final double quality;
  final double travel;
  final double uniqueness;
}
