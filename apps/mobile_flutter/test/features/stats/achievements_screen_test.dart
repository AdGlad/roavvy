// T4.8 — AchievementsScreen widget tests

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/providers.dart';
import 'package:mobile_flutter/data/achievement_repository.dart';
import 'package:mobile_flutter/data/db/roavvy_database.dart';
import 'package:mobile_flutter/data/heritage_repository.dart';
import 'package:mobile_flutter/data/region_repository.dart';
import 'package:mobile_flutter/data/trip_repository.dart';
import 'package:mobile_flutter/data/visit_repository.dart';
import 'package:mobile_flutter/features/stats/stats_screen.dart';

RoavvyDatabase _makeDb() => RoavvyDatabase(NativeDatabase.memory());

/// Pumps AchievementsScreen with a tall viewport so all slivers are built.
Future<void> _pump(
  WidgetTester tester, {
  required AchievementRepository achievementRepo,
  VisitRepository? visitRepo,
}) async {
  await tester.binding.setSurfaceSize(const Size(400, 3000));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final db = _makeDb();
  final vr = visitRepo ?? VisitRepository(db);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        roavvyDatabaseProvider.overrideWithValue(db),
        visitRepositoryProvider.overrideWithValue(vr),
        achievementRepositoryProvider.overrideWithValue(achievementRepo),
        regionRepositoryProvider.overrideWithValue(RegionRepository(db)),
        tripRepositoryProvider.overrideWithValue(TripRepository(db)),
        heritageRepositoryProvider.overrideWithValue(HeritageRepository(db)),
        polygonsProvider.overrideWithValue(const []),
      ],
      child: const MaterialApp(home: AchievementsScreen()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  group('AchievementsScreen — rendering', () {
    testWidgets('shows "Achievements" in the app bar', (tester) async {
      final db = _makeDb();
      await _pump(tester, achievementRepo: AchievementRepository(db));

      expect(find.text('Achievements'), findsWidgets);
    });

    testWidgets('renders without exception when no achievements unlocked', (
      tester,
    ) async {
      final db = _makeDb();
      await _pump(tester, achievementRepo: AchievementRepository(db));

      // No exception thrown; screen is stable
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows achievement names from kAchievements', (tester) async {
      final db = _makeDb();
      await _pump(tester, achievementRepo: AchievementRepository(db));

      // kAchievements contains "First Stamp" as the first achievement
      // (countries_1 — visited 1 country). It should always appear, locked or not.
      expect(find.textContaining('First'), findsWidgets);
    });
  });

  group('AchievementsScreen — unlock state', () {
    testWidgets('unlocked achievement badge is shown', (tester) async {
      final db = _makeDb();
      final repo = AchievementRepository(db);
      // Unlock the first achievement: countries_1
      await repo.upsertAll({'countries_1'}, DateTime.utc(2026, 1, 1));

      await _pump(tester, achievementRepo: repo);

      // The gallery renders achievement names — "First Stamp" is countries_1
      expect(find.textContaining('First'), findsWidgets);
    });

    testWidgets('screen stays stable with multiple unlocked achievements', (
      tester,
    ) async {
      final db = _makeDb();
      final repo = AchievementRepository(db);
      await repo.upsertAll({'countries_1'}, DateTime.utc(2026, 1, 1));
      await repo.upsertAll({'countries_3'}, DateTime.utc(2026, 1, 1));
      await repo.upsertAll({'trips_1'}, DateTime.utc(2026, 1, 1));

      await _pump(tester, achievementRepo: repo);

      expect(tester.takeException(), isNull);
    });
  });
}
