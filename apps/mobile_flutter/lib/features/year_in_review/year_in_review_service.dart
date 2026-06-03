import 'package:shared_models/shared_models.dart';

import '../../data/trip_repository.dart';
import '../scan/hero_image_repository.dart';

/// Aggregated data for a single calendar year's travel summary (M94, ADR-139).
///
/// Pure value object — no Firestore, no side effects. Never stored or synced.
class YearInReviewData {
  const YearInReviewData({
    required this.year,
    required this.trips,
    required this.heroByTripId,
    required this.countryCount,
    required this.tripCount,
    required this.totalPhotos,
    this.topScene,
    this.topMood,
    this.topActivity,
    this.topCountry,
  });

  final int year;

  /// All trips that started in [year], sorted ascending by [TripRecord.startedOn].
  final List<TripRecord> trips;

  /// Rank-1 hero image per trip. Value is null when no hero exists for that trip.
  final Map<String, HeroImage?> heroByTripId;

  final int countryCount;
  final int tripCount;

  /// Sum of [TripRecord.photoCount] across all trips in [year].
  final int totalPhotos;

  /// Most frequent non-null [HeroImage.primaryScene] across all heroes.
  final String? topScene;

  /// Most frequent first mood label across all heroes.
  final String? topMood;

  /// Most frequent first activity label across all heroes.
  final String? topActivity;

  /// Country code with the most photos in [year].
  final String? topCountry;
}

/// Aggregates data from [TripRepository] and [HeroImageRepository] for a given year.
///
/// See ADR-139 for design rationale.
class YearInReviewService {
  const YearInReviewService({
    required TripRepository tripRepo,
    required HeroImageRepository heroRepo,
  }) : _tripRepo = tripRepo,
       _heroRepo = heroRepo;

  final TripRepository _tripRepo;
  final HeroImageRepository _heroRepo;

  /// Returns [YearInReviewData] for [year], or null if no trips started in [year].
  Future<YearInReviewData?> getDataForYear(int year) async {
    final allTrips = await _tripRepo.loadAll();
    final trips =
        allTrips.where((t) => t.startedOn.year == year).toList()
          ..sort((a, b) => a.startedOn.compareTo(b.startedOn));

    if (trips.isEmpty) return null;

    // Single query for all rank-1 heroes, then filter to relevant trips.
    final allHeroes = await _heroRepo.getHeroesForRank1();
    final tripIds = {for (final t in trips) t.id};
    final heroMap = <String, HeroImage?>{for (final t in trips) t.id: null};
    for (final hero in allHeroes) {
      if (tripIds.contains(hero.tripId)) {
        heroMap[hero.tripId] = hero;
      }
    }

    final heroes = heroMap.values.whereType<HeroImage>().toList();

    return YearInReviewData(
      year: year,
      trips: trips,
      heroByTripId: Map.unmodifiable(heroMap),
      countryCount: {for (final t in trips) t.countryCode}.length,
      tripCount: trips.length,
      totalPhotos: trips.fold(0, (sum, t) => sum + t.photoCount),
      topScene: _topLabel(
        heroes.map((h) => h.primaryScene).whereType<String>(),
      ),
      topMood: _topLabel(heroes.expand((h) => h.mood.take(1))),
      topActivity: _topLabel(heroes.expand((h) => h.activity.take(1))),
      topCountry: _topCountry(trips),
    );
  }

  static String? _topLabel(Iterable<String> labels) {
    final freq = <String, int>{};
    for (final label in labels) {
      freq[label] = (freq[label] ?? 0) + 1;
    }
    if (freq.isEmpty) return null;
    return freq.entries
        .reduce(
          (a, b) =>
              a.value > b.value ||
                      (a.value == b.value && a.key.compareTo(b.key) < 0)
                  ? a
                  : b,
        )
        .key;
  }

  static String? _topCountry(List<TripRecord> trips) {
    if (trips.isEmpty) return null;
    final photos = <String, int>{};
    for (final t in trips) {
      photos[t.countryCode] = (photos[t.countryCode] ?? 0) + t.photoCount;
    }
    return photos.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }
}
