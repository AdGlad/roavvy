import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../scan/hero_image_repository.dart';
import 'year_in_review_service.dart';

/// Returns [YearInReviewData] for the given year, or null if no trips exist
/// in that year. Cache key is the year integer (ADR-139).
final yearInReviewDataProvider = FutureProvider.family<YearInReviewData?, int>((
  ref,
  year,
) async {
  final service = YearInReviewService(
    tripRepo: ref.watch(tripRepositoryProvider),
    heroRepo: HeroImageRepository(ref.watch(roavvyDatabaseProvider)),
  );
  return service.getDataForYear(year);
});
