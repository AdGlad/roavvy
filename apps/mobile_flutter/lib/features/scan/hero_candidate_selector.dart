import 'package:shared_models/shared_models.dart';

/// Selects up to 25 hero image candidates for a single trip using photo
/// metadata only — no image loading, no ML at this stage (M89, ADR-134).
///
/// 25 candidates spread across the trip's timespan give the Vision pipeline
/// richer label coverage, improving [HeroScoringEngine] ranking quality.
/// Candidates are passed to the Swift [HeroImageAnalyzer] for Vision labelling
/// after the scan result screen is shown.
class HeroCandidateSelector {
  const HeroCandidateSelector();

  /// Selects up to [maxCandidates] candidate assetIds from [photos].
  ///
  /// [photos] must all belong to the same trip and must have non-null [assetId]
  /// values. Photos with null assetIds are silently skipped.
  ///
  /// Selection rules (applied in priority order per the M89 spec):
  /// 1. Photos are sorted by capturedAt ascending.
  /// 2. Photos without assetId are discarded.
  /// 3. Burst dedup: if two photos are within 60 seconds of each other, only
  ///    the first is kept.
  /// 4. GPS-tagged photos (those whose countryCode is non-empty — all records
  ///    in photo_date_records inherently have GPS since they required GPS for
  ///    country resolution) are preferred. When no GPS-tagged photos survive
  ///    dedup, a fallback set of the first [maxCandidates] photos is returned.
  /// 5. Temporal spacing: from the GPS-eligible pool, select candidates that
  ///    are at least 15 minutes apart from the previously selected candidate,
  ///    ensuring good coverage of the trip timespan.
  /// 6. Cap at [maxCandidates] (default 25).
  List<String> select(
    List<PhotoDateRecord> photos, {
    int maxCandidates = 25,
  }) {
    if (photos.isEmpty) return const [];

    // Keep only photos that have an assetId.
    final withAssetId =
        photos.where((p) => (p.assetId ?? '').isNotEmpty).toList()
          ..sort((a, b) => a.capturedAt.compareTo(b.capturedAt));

    if (withAssetId.isEmpty) return const [];

    // Burst dedup: remove photos within 60 s of the previous.
    final deduped = _burstDedup(withAssetId, windowSeconds: 60);

    // All photo_date_records have GPS (that's how their countryCode was
    // resolved), so there is no GPS-less fallback needed. However, to handle
    // edge cases (manual trip records, future schema variations), we still
    // apply temporal spacing on the full deduped set.
    if (deduped.isEmpty) {
      // Fallback: take first maxCandidates from withAssetId.
      return withAssetId
          .take(maxCandidates)
          .map((p) => p.assetId!)
          .toList();
    }

    // Temporal spacing: at least 15 minutes between selected candidates.
    // Reduced from 30 min so 25 candidates fit comfortably within a single
    // travel day while still avoiding near-duplicate shots.
    final spaced = _temporalSpacing(deduped, minGapMinutes: 15);

    if (spaced.isEmpty) {
      // Fallback: return first candidate from deduped.
      return [deduped.first.assetId!];
    }

    return spaced.take(maxCandidates).map((p) => p.assetId!).toList();
  }

  /// Removes photos within [windowSeconds] of the previous kept photo.
  List<PhotoDateRecord> _burstDedup(
    List<PhotoDateRecord> sorted, {
    required int windowSeconds,
  }) {
    final result = <PhotoDateRecord>[];
    DateTime? lastKept;

    for (final photo in sorted) {
      if (lastKept == null ||
          photo.capturedAt.difference(lastKept).inSeconds.abs() >
              windowSeconds) {
        result.add(photo);
        lastKept = photo.capturedAt;
      }
    }

    return result;
  }

  /// Returns a subset where consecutive candidates are at least
  /// [minGapMinutes] apart. Always includes the first photo.
  List<PhotoDateRecord> _temporalSpacing(
    List<PhotoDateRecord> sorted, {
    required int minGapMinutes,
  }) {
    if (sorted.isEmpty) return const [];

    final result = <PhotoDateRecord>[sorted.first];

    for (final photo in sorted.skip(1)) {
      final gap =
          photo.capturedAt.difference(result.last.capturedAt).inMinutes.abs();
      if (gap >= minGapMinutes) {
        result.add(photo);
      }
    }

    return result;
  }
}
