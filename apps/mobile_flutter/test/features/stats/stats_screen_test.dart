import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/providers.dart';
import 'package:mobile_flutter/data/achievement_repository.dart';
import 'package:mobile_flutter/data/db/roavvy_database.dart';
import 'package:mobile_flutter/data/region_repository.dart';
import 'package:mobile_flutter/data/trip_repository.dart';
import 'package:mobile_flutter/data/visit_repository.dart';
import 'package:mobile_flutter/features/stats/countries_list_screen.dart';
import 'package:mobile_flutter/features/stats/stats_screen.dart';
import 'package:shared_models/shared_models.dart';

RoavvyDatabase _makeDb() => RoavvyDatabase(NativeDatabase.memory());

Widget _pumpStats({
  required VisitRepository visitRepo,
  required AchievementRepository achievementRepo,
  required RegionRepository regionRepo,
}) {
  final db = _makeDb();
  return ProviderScope(
    overrides: [
      visitRepositoryProvider.overrideWithValue(visitRepo),
      achievementRepositoryProvider.overrideWithValue(achievementRepo),
      regionRepositoryProvider.overrideWithValue(regionRepo),
      tripRepositoryProvider.overrideWithValue(TripRepository(db)),
      polygonsProvider.overrideWithValue(const []),
    ],
    child: const MaterialApp(home: StatsScreen()),
  );
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

      await tester.pumpWidget(_pumpStats(
        visitRepo: visitRepo,
        achievementRepo: AchievementRepository(db),
        regionRepo: RegionRepository(db),
      ));
      await tester.pumpAndSettle();

      expect(find.text('2'), findsWidgets); // country count tile
      expect(find.text('Countries'), findsOneWidget);
    });

    testWidgets('shows "—" for since year when no visits', (tester) async {
      final db = _makeDb();

      await tester.pumpWidget(_pumpStats(
        visitRepo: VisitRepository(db),
        achievementRepo: AchievementRepository(db),
        regionRepo: RegionRepository(db),
      ));
      await tester.pumpAndSettle();

      expect(find.text('—'), findsWidgets);
      expect(find.text('Since'), findsOneWidget);
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

      await tester.pumpWidget(_pumpStats(
        visitRepo: VisitRepository(db),
        achievementRepo: AchievementRepository(db),
        regionRepo: regionRepo,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Regions'), findsOneWidget);
    });
  });

  group('StatsScreen — countries navigation', () {
    testWidgets('tapping Countries tile pushes CountriesListScreen',
        (tester) async {
      final db = _makeDb();
      final visitRepo = VisitRepository(db);
      await visitRepo.saveAdded(
        UserAddedCountry(countryCode: 'JP', addedAt: DateTime.utc(2024)),
      );

      await tester.pumpWidget(_pumpStats(
        visitRepo: visitRepo,
        achievementRepo: AchievementRepository(db),
        regionRepo: RegionRepository(db),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Countries'));
      await tester.pumpAndSettle();

      expect(find.byType(CountriesListScreen), findsOneWidget);
      expect(find.text('1 country visited'), findsOneWidget);
      expect(find.text('Japan'), findsOneWidget);
    });
  });

  group('StatsScreen — achievement gallery', () {
    testWidgets('shows Achievements section and visible grid cards',
        (tester) async {
      final db = _makeDb();

      await tester.pumpWidget(_pumpStats(
        visitRepo: VisitRepository(db),
        achievementRepo: AchievementRepository(db),
        regionRepo: RegionRepository(db),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Achievements'), findsOneWidget);
      // The first visible achievement titles are rendered in the grid.
      expect(find.text(kAchievements.first.title), findsOneWidget);
      expect(find.text(kAchievements[1].title), findsOneWidget);
    });

    testWidgets('unlocked achievement shows unlock date', (tester) async {
      final db = _makeDb();
      final achievementRepo = AchievementRepository(db);
      await achievementRepo.upsertAll(
        {'countries_1'},
        DateTime.utc(2024, 1, 14),
      );

      await tester.pumpWidget(_pumpStats(
        visitRepo: VisitRepository(db),
        achievementRepo: achievementRepo,
        regionRepo: RegionRepository(db),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('Unlocked 14 Jan 2024'), findsOneWidget);
    });

    testWidgets('locked achievement does not show unlock date', (tester) async {
      final db = _makeDb();
      // No achievements unlocked

      await tester.pumpWidget(_pumpStats(
        visitRepo: VisitRepository(db),
        achievementRepo: AchievementRepository(db),
        regionRepo: RegionRepository(db),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('Unlocked'), findsNothing);
    });

    testWidgets('unlocked achievement card uses trophy icon', (tester) async {
      final db = _makeDb();
      final achievementRepo = AchievementRepository(db);
      await achievementRepo.upsertAll({'countries_1'}, DateTime.utc(2024));

      await tester.pumpWidget(_pumpStats(
        visitRepo: VisitRepository(db),
        achievementRepo: achievementRepo,
        regionRepo: RegionRepository(db),
      ));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.emoji_events_outlined), findsOneWidget);
    });

    testWidgets('locked achievement card uses lock icon', (tester) async {
      final db = _makeDb();
      // No achievements unlocked → all locked

      await tester.pumpWidget(_pumpStats(
        visitRepo: VisitRepository(db),
        achievementRepo: AchievementRepository(db),
        regionRepo: RegionRepository(db),
      ));
      await tester.pumpAndSettle();

      // At least one lock icon is visible in the initial viewport.
      expect(find.byIcon(Icons.lock_outline), findsWidgets);
    });

    testWidgets('tapping locked achievement card opens sheet with locked state',
        (tester) async {
      final db = _makeDb();
      // No achievements unlocked — first card is locked.

      await tester.pumpWidget(_pumpStats(
        visitRepo: VisitRepository(db),
        achievementRepo: AchievementRepository(db),
        regionRepo: RegionRepository(db),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text(kAchievements.first.title).first);
      await tester.pumpAndSettle();

      expect(find.text('Not yet unlocked'), findsOneWidget);
    });

    testWidgets('tapping unlocked achievement card opens sheet with unlock date',
        (tester) async {
      final db = _makeDb();
      final achievementRepo = AchievementRepository(db);
      await achievementRepo.upsertAll(
        {'countries_1'},
        DateTime.utc(2024, 3, 15),
      );

      await tester.pumpWidget(_pumpStats(
        visitRepo: VisitRepository(db),
        achievementRepo: achievementRepo,
        regionRepo: RegionRepository(db),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text(kAchievements.first.title).first);
      await tester.pumpAndSettle();

      // Sheet opens — "Share achievement" button confirms it's the unlock sheet.
      expect(find.text('Share achievement'), findsOneWidget);
    });
  });
}
