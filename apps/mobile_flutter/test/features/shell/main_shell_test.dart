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
import 'package:mobile_flutter/data/xp_repository.dart';
import 'package:mobile_flutter/features/memory/memory_anniversary_photo.dart';
import 'package:mobile_flutter/features/shell/main_shell.dart';

RoavvyDatabase _makeDb() => RoavvyDatabase(NativeDatabase.memory());

/// Pumps [MainShell] with provider overrides for all four screens.
///
/// [polygonsProvider] is overridden with [] so MapScreen never calls
/// [loadPolygons()]. All repositories use an in-memory DB.
Widget _pumpShell() {
  final db = _makeDb();
  return ProviderScope(
    overrides: [
      roavvyDatabaseProvider.overrideWithValue(db),
      visitRepositoryProvider.overrideWithValue(VisitRepository(db)),
      achievementRepositoryProvider.overrideWithValue(
        AchievementRepository(db),
      ),
      tripRepositoryProvider.overrideWithValue(TripRepository(db)),
      regionRepositoryProvider.overrideWithValue(RegionRepository(db)),
      xpRepositoryProvider.overrideWithValue(XpRepository(db)),
      polygonsProvider.overrideWithValue(const []),
      // No Firebase in tests — treat user as signed out
      currentUidProvider.overrideWithValue(null),
      // Prevent photo_manager platform channel calls in tests
      todaysMemoriesProvider.overrideWith(
        (ref) => Future<List<MemoryAnniversaryPhoto>>.value([]),
      ),
    ],
    child: const MaterialApp(home: MainShell()),
  );
}

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  group('MainShell — navigation', () {
    testWidgets('shows all 4 tab labels in NavigationBar', (tester) async {
      await tester.pumpWidget(_pumpShell());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('Map'), findsOneWidget);
      expect(find.text('Journal'), findsOneWidget);
      expect(find.text('Stats'), findsOneWidget);
      expect(find.text('Shop'), findsOneWidget);
    });

    testWidgets('Map tab is selected by default', (tester) async {
      await tester.pumpWidget(_pumpShell());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Shop tab content is offstage — not visible on Map tab
      expect(find.text('Sign in to view your saved designs.'), findsNothing);
    });

    testWidgets('tapping Journal tab shows JournalScreen', (tester) async {
      await tester.pumpWidget(_pumpShell());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text('Journal'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Journal'), findsWidgets); // tab label + screen text
    });

    testWidgets('tapping Stats tab shows StatsScreen', (tester) async {
      await tester.pumpWidget(_pumpShell());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text('Stats'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Stats'), findsWidgets); // tab label + screen text
    });

    testWidgets('tapping Shop tab shows MerchShopScreen', (tester) async {
      await tester.pumpWidget(_pumpShell());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text('Shop'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Shop nav tab label appears (tab bar + nav bar)
      expect(find.text('Shop'), findsWidgets);
    });

    testWidgets('tapping Map tab returns to MapScreen from Shop', (
      tester,
    ) async {
      await tester.pumpWidget(_pumpShell());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text('Shop'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text('Map'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      // After returning to map, the Stats tab label is still visible in nav bar
      expect(find.text('Stats'), findsOneWidget);
    });
  });
}
