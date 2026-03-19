import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/providers.dart';
import 'package:mobile_flutter/data/achievement_repository.dart';
import 'package:mobile_flutter/data/db/roavvy_database.dart';
import 'package:mobile_flutter/data/visit_repository.dart';
import 'package:mobile_flutter/features/map/stats_strip.dart';
import 'package:shared_models/shared_models.dart';

RoavvyDatabase _makeDb() => RoavvyDatabase(NativeDatabase.memory());

VisitRepository _makeRepo() => VisitRepository(_makeDb());

Widget _pumpStrip(
  VisitRepository repo, {
  AchievementRepository? achievementRepo,
}) {
  final db = _makeDb();
  return ProviderScope(
    overrides: [
      visitRepositoryProvider.overrideWithValue(repo),
      achievementRepositoryProvider.overrideWithValue(
        achievementRepo ?? AchievementRepository(db),
      ),
      polygonsProvider.overrideWithValue(const []),
    ],
    child: const MaterialApp(
      home: Scaffold(body: StatsStrip()),
    ),
  );
}

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  group('StatsStrip', () {
    testWidgets('shows 0 countries and — dates when repository is empty',
        (tester) async {
      await tester.pumpWidget(_pumpStrip(_makeRepo()));
      await tester.pumpAndSettle();

      expect(find.text('0'), findsOneWidget);
      expect(find.text('Countries'), findsOneWidget);
      expect(find.text('—'), findsWidgets);
    });

    testWidgets('shows country count when visits are present', (tester) async {
      final repo = _makeRepo();
      await repo.saveAdded(
        UserAddedCountry(countryCode: 'GB', addedAt: DateTime.utc(2022)),
      );
      await repo.saveAdded(
        UserAddedCountry(countryCode: 'JP', addedAt: DateTime.utc(2023)),
      );

      await tester.pumpWidget(_pumpStrip(repo));
      await tester.pumpAndSettle();

      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('shows year range from inferred visits', (tester) async {
      final repo = _makeRepo();
      await repo.saveInferred(
        InferredCountryVisit(
          inferredAt: DateTime.utc(2024),
          countryCode: 'FR',
          firstSeen: DateTime.utc(2019, 6),
          lastSeen: DateTime.utc(2024, 3),
          photoCount: 10,
        ),
      );

      await tester.pumpWidget(_pumpStrip(repo));
      await tester.pumpAndSettle();

      expect(find.text('2019'), findsOneWidget);
      expect(find.text('2024'), findsOneWidget);
    });

    testWidgets('renders nothing (SizedBox.shrink) while loading',
        (tester) async {
      await tester.pumpWidget(_pumpStrip(_makeRepo()));
      // Do not pumpAndSettle — captures the loading state
      expect(find.text('Countries'), findsNothing);
    });

    testWidgets('shows achievement count when achievements are unlocked',
        (tester) async {
      final db = _makeDb();
      final achievementRepo = AchievementRepository(db);
      await achievementRepo.upsertAll(
        {'countries_1', 'countries_5'},
        DateTime.utc(2025),
      );

      await tester.pumpWidget(_pumpStrip(_makeRepo(), achievementRepo: achievementRepo));
      await tester.pumpAndSettle();

      expect(find.text('🏆 2'), findsOneWidget);
      expect(find.text('Achievements'), findsOneWidget);
    });
  });
}
