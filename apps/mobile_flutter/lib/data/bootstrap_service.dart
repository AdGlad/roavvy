import 'package:shared_models/shared_models.dart';

import 'region_repository.dart';
import 'trip_repository.dart';
import 'visit_repository.dart';

/// Synthesises one [TripRecord] per country for users who upgraded from a
/// version before photo-date records were introduced (schema v6, ADR-048).
///
/// Conditions for bootstrap (all must be true):
/// 1. [VisitRepository.loadBootstrapCompletedAt] returns null — never run.
/// 2. [VisitRepository.loadPhotoDates] is empty — no per-photo data exists.
/// 3. [VisitRepository.loadInferred] is non-empty — visits exist to derive from.
///
/// When all conditions hold, one [TripRecord] is synthesised per country using
/// [InferredCountryVisit.firstSeen] as [TripRecord.startedOn] and
/// [InferredCountryVisit.lastSeen] as [TripRecord.endedOn]. Countries with a
/// null [firstSeen] are skipped (no date anchor available). The bootstrap
/// timestamp is then stored so this logic does not re-run on subsequent launches.
///
/// This is a pure coordination function: no UI, no side effects beyond the two
/// repositories, deterministic output for given inputs.
Future<void> bootstrapExistingUser(
  VisitRepository visitRepo,
  TripRepository tripRepo, {
  RegionRepository? regionRepo,
}) async {
  // Guard 1: already bootstrapped.
  if (await visitRepo.loadBootstrapCompletedAt() != null) return;

  // Guard 2: photo dates already exist — no bootstrap needed.
  final photoDates = await visitRepo.loadPhotoDates();
  if (photoDates.isNotEmpty) return;

  // Guard 3: nothing to bootstrap from.
  final inferred = await visitRepo.loadInferred();
  if (inferred.isEmpty) return;

  final now = DateTime.now().toUtc();
  final bootstrapTrips = inferred
      .where((v) => v.firstSeen != null)
      .map((v) => TripRecord(
            id: '${v.countryCode}_${v.firstSeen!.toUtc().toIso8601String()}',
            countryCode: v.countryCode,
            startedOn: v.firstSeen!.toUtc(),
            endedOn: (v.lastSeen ?? v.firstSeen!).toUtc(),
            photoCount: v.photoCount,
            isManual: false,
          ))
      .toList();

  await tripRepo.upsertAll(bootstrapTrips);

  // Infer region visits from photo date records.
  // In practice this produces an empty list on bootstrap (guard 2 ensures
  // no per-photo records exist yet), but is wired for completeness.
  if (regionRepo != null) {
    final photoDates = await visitRepo.loadPhotoDates();
    await regionRepo.upsertAll(inferRegionVisits(photoDates, bootstrapTrips));
  }

  await visitRepo.saveBootstrapCompletedAt(now);
}
