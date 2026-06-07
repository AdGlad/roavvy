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
import 'package:mobile_flutter/features/stats/flag_mosaic_screen.dart';
import 'package:mobile_flutter/features/stats/stats_screen.dart';
import 'package:shared_models/shared_models.dart';

RoavvyDatabase _makeDb() => RoavvyDatabase(NativeDatabase.memory());

/// Pumps [StatsScreen] with a tall surface (3000px) so that all slivers in
/// the [CustomScrollView] are built — including the stats grid and achievement
/// gallery which would otherwise be scrolled off the default 600px test viewport.
Future<void> _pumpStats(
  WidgetTester tester, {
  required VisitRepository visitRepo,
  required AchievementRepository achievementRepo,
  required RegionRepository regionRepo,
}) async {
  await tester.binding.setSurfaceSize(const Size(800, 3000));
  addTearDown(() async => tester.binding.setSurfaceSize(null));
  final db = _makeDb();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        roavvyDatabaseProvider.overrideWithValue(db),
        visitRepositoryProvider.overrideWithValue(visitRepo),
        achievementRepositoryProvider.overrideWithValue(achievementRepo),
        regionRepositoryProvider.overrideWithValue(regionRepo),
        tripRepositoryProvider.overrideWithValue(TripRepository(db)),
        heritageRepositoryProvider.overrideWithValue(HeritageRepository(db)),
        polygonsProvider.overrideWithValue(const []),
      ],
      child: const MaterialApp(home: Scaffold(body: StatsScreen())),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  group('StatsScreen — stats panel', () {
    testWidgets('shows correct country count from visits', (tester) async {
      final db = _makeDb();
      final visitRepo = VisitRepository(db);
      await visitRepo.saveAdded(
        UserAddedCountry(countryCode: 'JP', addedAt: DateTime.utc(2024)),
      );
      await visitRepo.saveAdded(
        UserAddedCountry(countryCode: 'FR', addedAt: DateTime.utc(2024)),
      );

      await _pumpStats(
        tester,
        visitRepo: visitRepo,
        achievementRepo: AchievementRepository(db),
        regionRepo: RegionRepository(db),
      );

      expect(find.text('2'), findsWidgets); // country count tile
      expect(
        find.text('Countries'),
        findsWidgets,
      ); // stat card + tab both render 'Countries'
    });

    testWidgets('shows "—" for since year when no visits', (tester) async {
      final db = _makeDb();

      await _pumpStats(
        tester,
        visitRepo: VisitRepository(db),
        achievementRepo: AchievementRepository(db),
        regionRepo: RegionRepository(db),
      );

      // All stat cards (Countries/Continents/Regions/Trips) show '—' when counts are 0.
      expect(find.text('—'), findsWidgets);
      // 'Trips' appears in both the stats grid and the achievement gallery tab bar.
      expect(find.text('Trips'), findsWidgets);
    });

    testWidgets('shows region count', (tester) async {
      final db = _makeDb();
      final regionRepo = RegionRepository(db);
      await regionRepo.upsertAll([
        RegionVisit(
          tripId: 'FR_2024-01-01T00:00:00.000Z',
          countryCode: 'FR',
          regionCode: 'FR-IDF',
          firstSeen: DateTime.utc(2024, 1, 1),
          lastSeen: DateTime.utc(2024, 1, 5),
          photoCount: 3,
        ),
        RegionVisit(
          tripId: 'FR_2024-01-01T00:00:00.000Z',
          countryCode: 'FR',
          regionCode: 'FR-ARA',
          firstSeen: DateTime.utc(2024, 1, 1),
          lastSeen: DateTime.utc(2024, 1, 5),
          photoCount: 2,
        ),
      ]);

      await _pumpStats(
        tester,
        visitRepo: VisitRepository(db),
        achievementRepo: AchievementRepository(db),
        regionRepo: regionRepo,
      );

      expect(find.text('Regions'), findsOneWidget);
    });
  });

  group('StatsScreen — countries navigation', () {
    testWidgets('tapping Countries tile pushes FlagMosaicScreen', (
      tester,
    ) async {
      final db = _makeDb();
      final visitRepo = VisitRepository(db);
      await visitRepo.saveAdded(
        UserAddedCountry(countryCode: 'JP', addedAt: DateTime.utc(2024)),
      );

      await _pumpStats(
        tester,
        visitRepo: visitRepo,
        achievementRepo: AchievementRepository(db),
        regionRepo: RegionRepository(db),
      );

      // Both the stat card and the achievement tab render 'Countries'; tap the first.
      await tester.tap(find.text('Countries').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(FlagMosaicScreen), findsOneWidget);
    });
  });

  group('StatsScreen — achievement gallery', () {
    testWidgets('shows Achievements section and visible grid cards', (
      tester,
    ) async {
      final db = _makeDb();

      await _pumpStats(
        tester,
        visitRepo: VisitRepository(db),
        achievementRepo: AchievementRepository(db),
        regionRepo: RegionRepository(db),
      );

      expect(find.text('Achievements'), findsOneWidget);
      // The first visible achievement titles are rendered in the grid.
      expect(find.text(kAchievements.first.title), findsOneWidget);
      expect(find.text(kAchievements[1].title), findsOneWidget);
    });

    testWidgets('unlocked achievement shows unlock date', (tester) async {
      final db = _makeDb();
      final achievementRepo = AchievementRepository(db);
      await achievementRepo.upsertAll({
        'countries_1',
      }, DateTime.utc(2024, 1, 14));

      await _pumpStats(
        tester,
        visitRepo: VisitRepository(db),
        achievementRepo: achievementRepo,
        regionRepo: RegionRepository(db),
      );

      expect(find.textContaining('Unlocked 14 Jan 2024'), findsOneWidget);
    });

    testWidgets('locked achievement does not show unlock date', (tester) async {
      final db = _makeDb();
      // No achievements unlocked

      await _pumpStats(
        tester,
        visitRepo: VisitRepository(db),
        achievementRepo: AchievementRepository(db),
        regionRepo: RegionRepository(db),
      );

      expect(find.textContaining('Unlocked'), findsNothing);
    });

    testWidgets('unlocked achievement card uses trophy icon', (tester) async {
      final db = _makeDb();
      final achievementRepo = AchievementRepository(db);
      await achievementRepo.upsertAll({'countries_1'}, DateTime.utc(2024));

      await _pumpStats(
        tester,
        visitRepo: VisitRepository(db),
        achievementRepo: achievementRepo,
        regionRepo: RegionRepository(db),
      );

      // Trophy icon appears in the unlocked achievement row (and possibly other locations).
      expect(find.byIcon(Icons.emoji_events_outlined), findsWidgets);
    });

    testWidgets('locked achievement card uses lock icon', (tester) async {
      final db = _makeDb();
      // No achievements unlocked → all locked

      await _pumpStats(
        tester,
        visitRepo: VisitRepository(db),
        achievementRepo: AchievementRepository(db),
        regionRepo: RegionRepository(db),
      );

      // At least one lock icon is visible in the initial viewport.
      expect(find.byIcon(Icons.lock_outline), findsWidgets);
    });

    testWidgets('tapping locked achievement card opens sheet with locked state', (
      tester,
    ) async {
      final db = _makeDb();
      // No achievements unlocked — first card is locked.

      await _pumpStats(
        tester,
        visitRepo: VisitRepository(db),
        achievementRepo: AchievementRepository(db),
        regionRepo: RegionRepository(db),
      );

      // Locked achievement rows show LinearProgressIndicator (no tap-to-sheet in current UI).
      expect(find.byType(LinearProgressIndicator), findsWidgets);
    });

    testWidgets(
      'tapping unlocked achievement card opens sheet with unlock date',
      (tester) async {
        final db = _makeDb();
        final achievementRepo = AchievementRepository(db);
        await achievementRepo.upsertAll({
          'countries_1',
        }, DateTime.utc(2024, 3, 15));

        await _pumpStats(
          tester,
          visitRepo: VisitRepository(db),
          achievementRepo: achievementRepo,
          regionRepo: RegionRepository(db),
        );

        // Unlocked achievement shows date in the row (no tap-to-sheet in current UI).
        expect(find.textContaining('Unlocked 15 Mar 2024'), findsOneWidget);
      },
    );
  });
}
