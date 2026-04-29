import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_models/shared_models.dart';

import '../../core/providers.dart';
import 'hero_image_repository.dart';

/// Provider for the [HeroImageRepository] (M89, ADR-134).
final heroImageRepositoryProvider = Provider<HeroImageRepository>(
  (ref) => HeroImageRepository(ref.watch(roavvyDatabaseProvider)),
);

/// Streams the rank-1 [HeroImage] for [tripId], or null if none exists.
///
/// Used by journal trip cards to display the hero image reactively.
/// Emits updated state when background analysis completes.
final heroForTripProvider =
    StreamProvider.family<HeroImage?, String>((ref, tripId) {
  final repo = ref.watch(heroImageRepositoryProvider);
  return repo.watchHeroForTrip(tripId);
});

/// Streams the single highest-scoring rank-1 hero for [countryCode].
///
/// Used by the country detail sheet cover image (M90, ADR-135).
final bestHeroForCountryProvider =
    StreamProvider.family<HeroImage?, String>((ref, countryCode) {
  final repo = ref.watch(heroImageRepositoryProvider);
  return repo.watchBestHeroForCountry(countryCode);
});

/// Returns the highest-scoring rank-1 hero across [tripIds].
///
/// One-shot Future used by the scan summary "best shot" section (M90).
/// Returns null when no heroes have been analysed for the given trips.
final bestHeroFromScanProvider =
    FutureProvider.family<HeroImage?, List<String>>((ref, tripIds) {
  final repo = ref.watch(heroImageRepositoryProvider);
  return repo.getBestHeroFromTrips(tripIds);
});
