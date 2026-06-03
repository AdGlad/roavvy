// T5 — Integration test app runner
//
// Pumps RoavvyApp with test-appropriate provider overrides:
//   - in-memory Drift database (created fresh or pre-seeded by caller)
//   - real geodata assets (country + region polygons loaded once)
//   - mocked Firebase auth (anonymous user or signed out)
//   - empty WHS site list
//   - empty merch cart stream (avoids FirebaseFirestore.instance)
//
// Does NOT call main() — bypasses Firebase.initializeApp().

import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/app.dart';
import 'package:mobile_flutter/core/providers.dart';
import 'package:mobile_flutter/data/achievement_repository.dart';
import 'package:mobile_flutter/data/daily_challenge_repository.dart';
import 'package:mobile_flutter/data/db/roavvy_database.dart';
import 'package:mobile_flutter/data/heritage_repository.dart';
import 'package:mobile_flutter/data/region_repository.dart';
import 'package:mobile_flutter/data/trip_repository.dart';
import 'package:mobile_flutter/data/visit_repository.dart';
import 'package:mobile_flutter/data/xp_repository.dart';
import 'package:mobile_flutter/features/challenge/daily_challenge_stats.dart';
import 'package:mobile_flutter/features/merch/merch_cart_screen.dart'
    show merchCartProvider;

/// Loads real geodata bytes from bundled Flutter assets.
///
/// Call once in [setUpAll] and reuse the result across tests.
Future<(Uint8List country, Uint8List region)> loadGeodataBytes() async {
  final country = await rootBundle.load('assets/geodata/ne_countries.bin');
  final region = await rootBundle.load('assets/geodata/ne_admin1.bin');
  return (country.buffer.asUint8List(), region.buffer.asUint8List());
}

/// Creates a fresh in-memory database for use in a single test.
RoavvyDatabase freshDb() => RoavvyDatabase(NativeDatabase.memory());

/// Pumps the full app under test with deterministic, isolated dependencies.
///
/// Returns the in-memory database so tests can assert or inspect state.
///
/// [db] — optional pre-seeded database; a fresh one is created if null.
/// [uid] — non-null means a signed-in anonymous user; null means signed out.
/// [onboardingDone] — pre-marks onboarding as complete (skips onboarding flow).
Future<RoavvyDatabase> pumpTestApp(
  WidgetTester tester, {
  RoavvyDatabase? db,
  String? uid = 'test-user-001',
  bool onboardingDone = true,
  required Uint8List countryBytes,
  required Uint8List regionBytes,
}) async {
  final database = db ?? freshDb();

  if (onboardingDone) {
    await database.markOnboardingComplete();
  }

  final MockFirebaseAuth mockAuth;
  if (uid != null) {
    final user = MockUser(uid: uid, isAnonymous: true);
    mockAuth = MockFirebaseAuth(signedIn: true, mockUser: user);
  } else {
    mockAuth = MockFirebaseAuth(signedIn: false);
  }

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        roavvyDatabaseProvider.overrideWithValue(database),
        visitRepositoryProvider.overrideWithValue(VisitRepository(database)),
        tripRepositoryProvider.overrideWithValue(TripRepository(database)),
        achievementRepositoryProvider.overrideWithValue(
          AchievementRepository(database),
        ),
        heritageRepositoryProvider.overrideWithValue(
          HeritageRepository(database),
        ),
        regionRepositoryProvider.overrideWithValue(RegionRepository(database)),
        xpRepositoryProvider.overrideWithValue(XpRepository(database)),
        dailyChallengeRepositoryProvider.overrideWithValue(
          DailyChallengeRepository(database),
        ),
        challengeStatsServiceProvider.overrideWithValue(
          ChallengeStatsService(database),
        ),
        // Avoids FirebaseFirestore.instance in the watch function.
        merchCartProvider.overrideWith((_) => const Stream.empty()),
        geodataBytesProvider.overrideWithValue(countryBytes),
        regionGeodataBytesProvider.overrideWithValue(regionBytes),
        allWhsSitesProvider.overrideWith((_) async => const []),
        authStateProvider.overrideWith((_) => mockAuth.authStateChanges()),
        currentUidProvider.overrideWith(
          (ref) => ref.watch(authStateProvider).value?.uid,
        ),
      ],
      child: const RoavvyApp(),
    ),
  );

  return database;
}
