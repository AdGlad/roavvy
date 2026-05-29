import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';

import 'package:country_lookup/country_lookup.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_models/shared_models.dart';

import '../data/achievement_repository.dart';
import '../data/heritage_repository.dart';
import '../data/level_up_repository.dart';
import '../data/milestone_repository.dart';
import '../data/db/roavvy_database.dart';
import '../data/region_repository.dart';
import '../data/trip_repository.dart';
import '../data/visit_repository.dart';
import '../data/xp_repository.dart';
import '../features/memory/memory_anniversary_photo.dart';
import '../features/memory/memory_pulse_service.dart';
import '../features/scan/hero_image_repository.dart';
import '../features/xp/xp_event.dart';
import '../features/xp/xp_notifier.dart';
import 'notification_service.dart';
import '../features/cards/landmark_image_service.dart';
import '../features/legal/terms_service.dart';
import '../data/daily_challenge_repository.dart';
import '../features/challenge/daily_challenge_service.dart';
import '../features/challenge/daily_challenge_notifier.dart';
import '../features/challenge/daily_challenge_stats.dart';

/// True when Image Playground (Apple Intelligence) is available on this device.
/// Cached for the lifetime of the app; `false` on all non-iOS 18.1+ devices.
final imagePlaygroundAvailableProvider = FutureProvider<bool>(
  (_) => LandmarkImageService.isAvailable(),
);

/// True when the user has accepted the current T&C version.
final termsAcceptedProvider = FutureProvider<bool>(
  (_) => TermsService.hasAcceptedCurrent(),
);

final authStateProvider = StreamProvider<User?>(
  (ref) => FirebaseAuth.instance.authStateChanges(),
);

final currentUidProvider = Provider<String?>(
  (ref) => ref.watch(authStateProvider).value?.uid,
);

/// Overridden in [ProviderScope] at startup with the loaded asset bytes.
final geodataBytesProvider = Provider<Uint8List>(
  (_) => throw UnimplementedError('geodataBytesProvider not overridden'),
);

/// Overridden in [ProviderScope] at startup with the loaded region asset bytes.
final regionGeodataBytesProvider = Provider<Uint8List>(
  (_) => throw UnimplementedError('regionGeodataBytesProvider not overridden'),
);

/// Overridden in [ProviderScope] at startup with the opened DB instance.
final roavvyDatabaseProvider = Provider<RoavvyDatabase>(
  (_) => throw UnimplementedError('roavvyDatabaseProvider not overridden'),
);

final visitRepositoryProvider = Provider<VisitRepository>(
  (ref) => VisitRepository(ref.watch(roavvyDatabaseProvider)),
);

final tripRepositoryProvider = Provider<TripRepository>(
  (ref) => TripRepository(ref.watch(roavvyDatabaseProvider)),
);

final achievementRepositoryProvider = Provider<AchievementRepository>(
  (ref) => AchievementRepository(ref.watch(roavvyDatabaseProvider)),
);

final heritageRepositoryProvider = Provider<HeritageRepository>(
  (ref) => HeritageRepository(ref.watch(roavvyDatabaseProvider)),
);

/// All visited UNESCO World Heritage Sites for the current user.
///
/// Invalidated after each scan so the map layer and achievement screen refresh.
final visitedHeritageProvider = FutureProvider<List<VisitedHeritageSite>>(
  (ref) => ref.watch(heritageRepositoryProvider).loadAll(),
);

/// Set of unlocked achievement IDs for the current user (M110).
/// Used by [ReplayTimelineBuilder] to filter which achievements appear in replay.
final unlockedAchievementIdsProvider = FutureProvider<Set<String>>(
  (ref) async {
    final ids = await ref.watch(achievementRepositoryProvider).loadAll();
    return ids.toSet();
  },
);

final regionRepositoryProvider = Provider<RegionRepository>(
  (ref) => RegionRepository(ref.watch(roavvyDatabaseProvider)),
);

/// Calls [loadPolygons()] once; requires [initCountryLookup] to have run first.
final polygonsProvider = Provider<List<CountryPolygon>>((ref) {
  ref.watch(geodataBytesProvider); // establishes dependency, ensures init ordering
  return loadPolygons();
});

/// Distinct region count across all trips, for the Stats screen (ADR-052).
final regionCountProvider = FutureProvider<int>(
  (ref) => ref.watch(regionRepositoryProvider).countUnique(),
);

final effectiveVisitsProvider = FutureProvider<List<EffectiveVisitedCountry>>(
  (ref) => ref.watch(visitRepositoryProvider).loadEffective(),
);

/// Returns `true` when the user should see the main shell instead of onboarding.
///
/// True when [hasSeenOnboardingAt] is set in the DB, OR when the user already
/// has visits (returning user / reinstall with Firestore data). ADR-053.
final onboardingCompleteProvider = FutureProvider<bool>((ref) async {
  final db = ref.watch(roavvyDatabaseProvider);
  if (await db.hasSeenOnboarding()) return true;
  final visits = await ref.watch(effectiveVisitsProvider.future);
  return visits.isNotEmpty;
});

final xpRepositoryProvider = Provider<XpRepository>(
  (ref) => XpRepository(ref.watch(roavvyDatabaseProvider)),
);

final xpNotifierProvider = StateNotifierProvider<XpNotifier, XpState>(
  (ref) => XpNotifier(ref.watch(xpRepositoryProvider)),
);

final milestoneRepositoryProvider = Provider<MilestoneRepository>(
  (_) => MilestoneRepository(),
);

final levelUpRepositoryProvider = Provider<LevelUpRepository>(
  (_) => LevelUpRepository(),
);

/// All trips from local SQLite, for [JournalScreen]. (ADR-081)
///
/// Invalidated after [VisitRepository.clearAll] and after scan save so the
/// journal updates without requiring a sign-out.
final tripListProvider = FutureProvider<List<TripRecord>>(
  (ref) => ref.watch(tripRepositoryProvider).loadAll(),
);

/// ISO code → trip count, derived in-memory from [TripRepository.loadAll].
/// Used by [CountryPolygonLayer] for depth colouring (ADR-066).
final countryTripCountsProvider = FutureProvider<Map<String, int>>((ref) async {
  final trips = await ref.watch(tripRepositoryProvider).loadAll();
  final counts = <String, int>{};
  for (final trip in trips) {
    counts[trip.countryCode] = (counts[trip.countryCode] ?? 0) + 1;
  }
  return counts;
});

/// Total number of logged trips. Used by the achievement engine (M97, ADR-148).
final tripCountProvider = FutureProvider<int>(
  (ref) async => (await ref.watch(tripListProvider.future)).length,
);

/// Number of distinct continents visited, derived from [effectiveVisitsProvider]
/// and [kCountryContinent] (M97, ADR-148).
final continentCountProvider = FutureProvider<int>((ref) async {
  final visits = await ref.watch(effectiveVisitsProvider.future);
  return visits
      .map((v) => kCountryContinent[v.countryCode])
      .whereType<String>()
      .toSet()
      .length;
});

/// Number of distinct countries first seen in the current calendar year.
/// Used by the achievement engine (M97, ADR-148).
final thisYearCountryCountProvider = FutureProvider<int>((ref) async {
  final visits = await ref.watch(effectiveVisitsProvider.future);
  final year = DateTime.now().year;
  return visits.where((v) => v.firstSeen?.year == year).length;
});

/// Year filter for the timeline scrubber. null = show all time. (ADR-076)
final yearFilterProvider = StateProvider<int?>((ref) => null);

/// Whether the globe map is active. true = globe (default). (ADR-116)
final globeModeProvider = StateProvider<bool>((ref) => true);

/// When true the globe idles without auto-spinning so the user can inspect
/// heritage sites. Manual drag and snap animations still work normally.
final globeRotationPausedProvider = StateProvider<bool>((ref) => false);

/// Whether heritage site dots are shown on the main map globe (M129).
final heritageDotsEnabledProvider = StateProvider<bool>((ref) => true);

/// Target (lat, lng) in degrees to animate the globe to. Set from outside
/// (e.g. country flag strip); the globe resets this to null after arriving.
/// No-op when [globeModeProvider] is false. (M86)
final globeTargetProvider = StateProvider<(double, double)?>((_) => null);

/// The earliest trip `startedOn` year across all trips; null if no trips exist.
/// Used to compute the scrubber range in [TimelineScrubberBar]. (ADR-076)
final earliestVisitYearProvider = FutureProvider<int?>((ref) async {
  final trips = await ref.watch(tripRepositoryProvider).loadAll();
  if (trips.isEmpty) return null;
  return trips.map((t) => t.startedOn.year).reduce(min);
});

/// Effective visits filtered by [yearFilterProvider].
///
/// When the filter is null, returns the same list as [effectiveVisitsProvider].
/// When set to year Y, retains only countries that have at least one trip with
/// `startedOn.year <= Y`, or (for manually-added countries with no trips)
/// `firstSeen != null && firstSeen.year <= Y`. (ADR-076)
final filteredEffectiveVisitsProvider =
    FutureProvider<List<EffectiveVisitedCountry>>((ref) async {
  final year = ref.watch(yearFilterProvider);
  final allVisits = await ref.watch(effectiveVisitsProvider.future);

  if (year == null) return allVisits;

  final trips = await ref.watch(tripRepositoryProvider).loadAll();

  // Build a set of country codes that have at least one trip on or before year.
  final codesWithQualifyingTrip = <String>{};
  for (final trip in trips) {
    if (trip.startedOn.year <= year) {
      codesWithQualifyingTrip.add(trip.countryCode);
    }
  }

  return allVisits.where((visit) {
    if (codesWithQualifyingTrip.contains(visit.countryCode)) return true;
    // No trips for this country — fall back to firstSeen (manually added).
    final firstSeen = visit.firstSeen;
    return firstSeen != null && firstSeen.year <= year;
  }).toList();
});

/// Last scan timestamp; null if the user has never scanned. (ADR-085)
final lastScanAtProvider = FutureProvider<DateTime?>(
  (ref) => ref.watch(visitRepositoryProvider).loadLastScanAt(),
);

/// Whether the user has dismissed the 30-day scan nudge banner this session.
/// Not persisted — resets to false on every app launch. (ADR-085)
final scanNudgeDismissedProvider = StateProvider<bool>((ref) => false);

// ── M91 Memory Pulse providers ────────────────────────────────────────────

/// Provides the [MemoryPulseService] instance (M91, M114, ADR-136).
final memoryPulseServiceProvider = Provider<MemoryPulseService>(
  (ref) {
    final db = ref.watch(roavvyDatabaseProvider);
    return MemoryPulseService(
      heroRepo: HeroImageRepository(db),
      notifications: NotificationService.instance,
      db: db,
    );
  },
);

/// Debug toggle: when true, [todaysMemoriesProvider] skips anniversary date
/// filtering and returns hero images instead (for manual testing).
final memoryPulseDebugOverrideProvider = StateProvider<bool>((ref) => false);

/// Today's memory pulse photos — one-shot per app session (M114, ADR-136).
///
/// Returns up to 3 [MemoryAnniversaryPhoto] records sourced directly from the
/// device photo library whose capture date matches today's month+day in a past
/// year. Returns empty list when none found or permission is denied.
///
/// Set [memoryPulseDebugOverrideProvider] to true to force-fire without the
/// anniversary date filter (shows hero images instead).
final todaysMemoriesProvider = FutureProvider<List<MemoryAnniversaryPhoto>>(
  (ref) async {
    if (ref.watch(memoryPulseDebugOverrideProvider)) {
      // In debug override mode, use the hero-image path so tester can see
      // cards without needing an actual anniversary date.
      final heroes = await HeroImageRepository(ref.watch(roavvyDatabaseProvider))
          .getHeroesForRank1();
      return heroes
          .take(3)
          .map((h) => MemoryAnniversaryPhoto(
                assetId: h.assetId,
                capturedAt: h.capturedAt,
                countryCode: h.countryCode,
                tripId: h.tripId,
              ))
          .toList();
    }
    return ref
        .watch(memoryPulseServiceProvider)
        .checkTodayFromPhotoLibrary(DateTime.now());
  },
);

/// Session-scoped set of assetIds dismissed by the user this session.
///
/// When the user taps Dismiss on a [MemoryPulseCard], their assetId is added
/// here so the card vanishes immediately without re-querying the library (ADR-136).
final memoriesDismissedProvider = StateProvider<Set<String>>((ref) => {});

// ─────────────────────────────────────────────────────────────────────────────

// ── M133 / M134 Daily Heritage Challenge ──────────────────────────────────────

final dailyChallengeRepositoryProvider = Provider<DailyChallengeRepository>(
  (ref) => DailyChallengeRepository(ref.watch(roavvyDatabaseProvider)),
);

final challengeStatsServiceProvider = Provider<ChallengeStatsService>(
  (ref) => ChallengeStatsService(ref.watch(roavvyDatabaseProvider)),
);

final challengeAggregateProvider = FutureProvider<ChallengeAggregate>(
  (ref) => ref.watch(challengeStatsServiceProvider).loadAggregate(),
);

/// Last 30 days of challenge history for the stats screen (M136).
final challengeLast30Provider =
    FutureProvider<List<({String date, bool solved, int guessesUsed})>>(
  (ref) => ref.watch(challengeStatsServiceProvider).last30Days(),
);

/// Fetches today's challenge from Firestore. Re-fetches only on invalidation.
final dailyChallengeProvider = FutureProvider<DailyChallenge>(
  (_) => const DailyChallengeService().fetchToday(),
);

/// Today's local progress (clues revealed, guesses, solved state).
/// Null when the user has not yet opened the challenge today.
final dailyChallengeProgressProvider =
    FutureProvider<DailyChallengeProgress?>((ref) {
  final today = DateFormat('yyyy-MM-dd').format(DateTime.now().toUtc());
  return ref.watch(dailyChallengeRepositoryProvider).loadToday(today);
});

/// Raw JSON string from bundled whs_sites.json. Loaded once per app lifetime.
final whsSitesJsonProvider = FutureProvider<String>(
  (_) => rootBundle.loadString('assets/geodata/whs_sites.json'),
);

/// All unique [WorldHeritageSite]s parsed from the bundled JSON. Cached.
final allWhsSitesProvider = FutureProvider<List<WorldHeritageSite>>((ref) async {
  final json = await ref.watch(whsSitesJsonProvider.future);
  return parseWhsSitesJson(json);
});

/// Composes the three async deps into a single [DailyChallengeState].
/// Used as initial state for [dailyChallengeNotifierProvider].
final _dailyChallengeInitProvider =
    FutureProvider.autoDispose<DailyChallengeState>((ref) async {
  final challenge = await ref.watch(dailyChallengeProvider.future);
  final sites = await ref.watch(allWhsSitesProvider.future);
  final progress = await ref.watch(dailyChallengeProgressProvider.future);
  return buildInitialChallengeState(
    challenge: challenge,
    savedProgress: progress,
    allSites: sites,
  );
});

/// Drives [DailyChallengeScreen]. Auto-disposed when the screen is popped.
final dailyChallengeNotifierProvider = StateNotifierProvider.autoDispose<
    DailyChallengeNotifier, AsyncValue<DailyChallengeState>>(
  (ref) {
    final init = ref.watch(_dailyChallengeInitProvider);
    final repo = ref.watch(dailyChallengeRepositoryProvider);
    final allSites = ref.watch(allWhsSitesProvider).valueOrNull ?? const [];
    final statsService = ref.watch(challengeStatsServiceProvider);
    final notifier = DailyChallengeNotifier(
      initial: init,
      repo: repo,
      allSites: allSites,
      statsService: statsService,
    );
    ref.listen(_dailyChallengeInitProvider, (_, next) => notifier.update(next));
    return notifier;
  },
);

// ─────────────────────────────────────────────────────────────────────────────

final travelSummaryProvider = FutureProvider<TravelSummary>((ref) async {
  final visits = await ref.watch(effectiveVisitsProvider.future);
  final achievementRepo = ref.watch(achievementRepositoryProvider);
  final achievementIds = await achievementRepo.loadAll();
  final base = TravelSummary.fromVisits(visits);
  return TravelSummary(
    visitedCodes: base.visitedCodes,
    computedAt: base.computedAt,
    earliestVisit: base.earliestVisit,
    latestVisit: base.latestVisit,
    achievementCount: achievementIds.length,
  );
});
