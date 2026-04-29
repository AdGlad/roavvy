import 'package:shared_models/shared_models.dart';

import 'hero_analysis_channel.dart';
import 'hero_candidate_selector.dart';
import 'hero_image_repository.dart';

/// Orchestrates the post-scan hero image analysis pipeline (M89, ADR-134).
///
/// Pipeline for each trip:
///   1. [HeroCandidateSelector] picks up to 5 assetId candidates (metadata only).
///   2. [HeroAnalysisChannel] calls Swift to fetch thumbnails + Vision labels.
///   3. [HeroScoringEngine] scores and ranks the results.
///   4. [HeroImageRepository] upserts the ranked heroes (honours isUserSelected).
///
/// This service is designed to be called fire-and-forget after the scan
/// summary screen is pushed. It does not modify scan state and is safe to run
/// in the background.
class HeroAnalysisService {
  HeroAnalysisService({
    required HeroImageRepository repository,
    HeroAnalysisChannel? channel,
    HeroCandidateSelector? selector,
    HeroScoringEngine? scoringEngine,
  })  : _repository = repository,
        _channel = channel ?? HeroAnalysisChannel(),
        _selector = selector ?? const HeroCandidateSelector(),
        _scoringEngine = scoringEngine ?? const HeroScoringEngine();

  final HeroImageRepository _repository;
  final HeroAnalysisChannel _channel;
  final HeroCandidateSelector _selector;
  final HeroScoringEngine _scoringEngine;

  /// Runs hero analysis for [trips] using [photoDateRecords] as the photo pool.
  ///
  /// Each trip is processed independently. Failures on individual trips are
  /// swallowed — they do not prevent analysis of subsequent trips.
  Future<void> runForTrips({
    required List<TripRecord> trips,
    required List<PhotoDateRecord> photoDateRecords,
  }) async {
    if (trips.isEmpty) return;

    // Group photo date records by inferred trip.
    final photosByTrip = _groupPhotosByTrip(trips, photoDateRecords);

    for (final trip in trips) {
      final photos = photosByTrip[trip.id] ?? const [];
      if (photos.isEmpty) continue;

      try {
        await _analyseTrip(trip, photos);
      } catch (_) {
        // Non-critical — continue to next trip.
      }
    }
  }

  Future<void> _analyseTrip(
    TripRecord trip,
    List<PhotoDateRecord> photos,
  ) async {
    // T3: Select up to 5 candidates via metadata only.
    final candidateAssetIds = _selector.select(photos);
    if (candidateAssetIds.isEmpty) return;

    // T6: Vision labelling via MethodChannel (Swift, background thread).
    final analysisResults = await _channel.analyseHeroCandidates(
      tripId: trip.id,
      assetIds: candidateAssetIds,
    );
    if (analysisResults.isEmpty) return;

    // T7: Score and rank candidates.
    final heroes = _scoringEngine.rank(
      tripId: trip.id,
      countryCode: trip.countryCode,
      candidates: analysisResults,
    );
    if (heroes.isEmpty) return;

    // T8: Persist (honours isUserSelected guard).
    await _repository.upsertHeroesForTrip(trip.id, heroes);
  }

  /// Groups [photoDateRecords] by the trip they belong to.
  ///
  /// A photo belongs to a trip if its [capturedAt] falls within the trip's
  /// [startedOn]..[endedOn] range and the countryCode matches.
  Map<String, List<PhotoDateRecord>> _groupPhotosByTrip(
    List<TripRecord> trips,
    List<PhotoDateRecord> photos,
  ) {
    final result = <String, List<PhotoDateRecord>>{};
    for (final trip in trips) {
      result[trip.id] = [];
    }

    for (final photo in photos) {
      if (photo.assetId == null) continue;

      // Find the first matching trip (trips are non-overlapping per ADR-058).
      for (final trip in trips) {
        if (trip.countryCode == photo.countryCode &&
            !photo.capturedAt.isBefore(trip.startedOn) &&
            !photo.capturedAt.isAfter(trip.endedOn)) {
          result[trip.id]?.add(photo);
          break;
        }
      }
    }

    return result;
  }
}
