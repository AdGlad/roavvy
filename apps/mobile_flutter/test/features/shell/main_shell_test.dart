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
      visitRepositoryProvider.overrideWithValue(VisitRepository(db)),
      achievementRepositoryProvider.overrideWithValue(AchievementRepository(db)),
      tripRepositoryProvider.overrideWithValue(TripRepository(db)),
      regionRepositoryProvider.overrideWithValue(RegionRepository(db)),
      polygonsProvider.overrideWithValue(const []),
    ],
    child: const MaterialApp(home: MainShell()),
  );
}

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  group('MainShell — navigation', () {
    testWidgets('shows all 4 tab labels in NavigationBar', (tester) async {
      await tester.pumpWidget(_pumpShell());
      await tester.pumpAndSettle();

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('Map'), findsOneWidget);
      expect(find.text('Journal'), findsOneWidget);
      expect(find.text('Stats'), findsOneWidget);
      expect(find.text('Scan'), findsOneWidget);
    });

    testWidgets('Map tab is selected by default', (tester) async {
      await tester.pumpWidget(_pumpShell());
      await tester.pumpAndSettle();

      // ScanScreen content is offstage — not visible on Map tab
      expect(find.text('Grant Access'), findsNothing);
      expect(find.text('Scan my photo library'), findsNothing);
    });

    testWidgets('tapping Journal tab shows JournalScreen', (tester) async {
      await tester.pumpWidget(_pumpShell());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Journal'));
      await tester.pumpAndSettle();

      expect(find.text('Journal'), findsWidgets); // tab label + screen text
    });

    testWidgets('tapping Stats tab shows StatsScreen', (tester) async {
      await tester.pumpWidget(_pumpShell());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Stats'));
      await tester.pumpAndSettle();

      expect(find.text('Stats'), findsWidgets); // tab label + screen text
    });

    testWidgets('tapping Scan tab shows ScanScreen', (tester) async {
      await tester.pumpWidget(_pumpShell());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Scan'));
      await tester.pumpAndSettle();

      expect(find.text('Grant Access'), findsOneWidget);
      expect(find.text('Scan my photo library'), findsOneWidget);
    });

    testWidgets('tapping Map tab returns to MapScreen from Scan', (tester) async {
      await tester.pumpWidget(_pumpShell());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Scan'));
      await tester.pumpAndSettle();
      expect(find.text('Grant Access'), findsOneWidget);

      await tester.tap(find.text('Map'));
      await tester.pumpAndSettle();
      expect(find.text('Grant Access'), findsNothing);
    });
  });
}
