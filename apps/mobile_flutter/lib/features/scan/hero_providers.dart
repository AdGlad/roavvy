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
/// Used by future trip card / journal screens to display the hero image.
/// Emits updated state reactively when background analysis completes.
final heroForTripProvider =
    StreamProvider.family<HeroImage?, String>((ref, tripId) {
  final repo = ref.watch(heroImageRepositoryProvider);
  return repo.watchHeroForTrip(tripId);
});
