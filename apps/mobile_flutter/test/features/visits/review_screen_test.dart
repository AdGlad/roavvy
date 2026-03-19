import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/data/achievement_repository.dart';
import 'package:mobile_flutter/data/db/roavvy_database.dart';
import 'package:mobile_flutter/data/visit_repository.dart';
import 'package:mobile_flutter/features/visits/review_screen.dart';
import 'package:shared_models/shared_models.dart';

RoavvyDatabase _makeDb() => RoavvyDatabase(NativeDatabase.memory());

VisitRepository _makeRepo() => VisitRepository(_makeDb());

Future<void> pumpReview(
  WidgetTester tester,
  List<EffectiveVisitedCountry> visits, {
  VisitRepository? repository,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: ReviewScreen(
        initialVisits: visits,
        repository: repository ?? _makeRepo(),
      ),
    ),
  );
}

EffectiveVisitedCountry autoVisit(String code) => EffectiveVisitedCountry(
      countryCode: code,
      hasPhotoEvidence: true,
      photoCount: 1,
    );

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  group('ReviewScreen — rendering', () {
    testWidgets('shows all active visits', (tester) async {
      await pumpReview(
        tester,
        [autoVisit('GB'), autoVisit('JP'), autoVisit('US')],
      );
      expect(find.text('GB'), findsOneWidget);
      expect(find.text('JP'), findsOneWidget);
      expect(find.text('US'), findsOneWidget);
    });

    testWidgets('shows empty state when no visits', (tester) async {
      await pumpReview(tester, []);
      expect(find.text('No countries yet. Tap + to add one.'), findsOneWidget);
    });

    testWidgets('shows section header with count', (tester) async {
      await pumpReview(tester, [autoVisit('GB'), autoVisit('JP')]);
      expect(find.text('2 countries visited'), findsOneWidget);
    });

    testWidgets('shows singular header for one country', (tester) async {
      await pumpReview(tester, [autoVisit('GB')]);
      expect(find.text('1 country visited'), findsOneWidget);
    });
  });

  group('ReviewScreen — remove', () {
    testWidgets('tapping remove icon moves country to Removed section', (tester) async {
      await pumpReview(tester, [autoVisit('GB'), autoVisit('JP')]);

      final removeIcon = find.byIcon(Icons.remove_circle_outline).first;
      await tester.tap(removeIcon);
      await tester.pump();

      expect(
        find.text('Removed (will not re-appear after scan)'),
        findsOneWidget,
      );
    });

    testWidgets('removed country shows Undo button', (tester) async {
      await pumpReview(tester, [autoVisit('GB')]);
      await tester.tap(find.byIcon(Icons.remove_circle_outline));
      await tester.pump();
      expect(find.text('Undo'), findsOneWidget);
    });

    testWidgets('undo restores country to active section', (tester) async {
      await pumpReview(tester, [autoVisit('GB')]);
      await tester.tap(find.byIcon(Icons.remove_circle_outline));
      await tester.pump();
      await tester.tap(find.text('Undo'));
      await tester.pump();

      expect(find.text('1 country visited'), findsOneWidget);
      expect(find.text('Undo'), findsNothing);
    });
  });

  group('ReviewScreen — add country', () {
    testWidgets('FAB is present', (tester) async {
      await pumpReview(tester, []);
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('tapping FAB opens add dialog', (tester) async {
      await pumpReview(tester, []);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(find.text('Add country'), findsOneWidget);
    });

    testWidgets('entering invalid code shows error', (tester) async {
      await pumpReview(tester, []);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'X');
      await tester.tap(find.text('Add'));
      await tester.pump();

      expect(
        find.text('Enter a 2-letter ISO country code (e.g. GB, JP, US)'),
        findsOneWidget,
      );
    });

    testWidgets('entering valid code adds country to list', (tester) async {
      await pumpReview(tester, []);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'de');
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(find.textContaining('DE'), findsWidgets);
    });

    testWidgets('Cancel closes dialog without adding', (tester) async {
      await pumpReview(tester, []);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('No countries yet. Tap + to add one.'), findsOneWidget);
    });
  });

  group('ReviewScreen — save', () {
    testWidgets('Save button is in app bar', (tester) async {
      await pumpReview(tester, [autoVisit('GB')]);
      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('tapping Save writes removal to repository', (tester) async {
      final repo = _makeRepo();
      final now = DateTime.utc(2025, 1, 1);
      await repo.saveInferred(
        InferredCountryVisit(
          countryCode: 'GB',
          inferredAt: now,
          photoCount: 1,
        ),
      );

      await pumpReview(tester, [autoVisit('GB')], repository: repo);
      await tester.tap(find.byIcon(Icons.remove_circle_outline));
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(await repo.loadRemoved(), hasLength(1));
      expect((await repo.loadRemoved()).first.countryCode, 'GB');
    });

    testWidgets('tapping Save pops the screen', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ReviewScreen(
                    initialVisits: [autoVisit('GB')],
                    repository: _makeRepo(),
                  ),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Review countries'), findsOneWidget);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Review countries'), findsNothing);
      expect(find.text('Open'), findsOneWidget);
    });
  });

  group('ReviewScreen — achievement SnackBar', () {
    // Push ReviewScreen onto a route so that when it pops, the parent Scaffold
    // is still alive and the ScaffoldMessenger can render the SnackBar.
    Future<void> pumpReviewPushed(
      WidgetTester tester,
      List<EffectiveVisitedCountry> visits, {
      required VisitRepository visitRepo,
      required AchievementRepository achievementRepo,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => ReviewScreen(
                      initialVisits: visits,
                      repository: visitRepo,
                      achievementRepo: achievementRepo,
                    ),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
    }

    testWidgets('shows SnackBar with achievement title on new unlock',
        (tester) async {
      final db = _makeDb();
      final visitRepo = VisitRepository(db);
      final achievementRepo = AchievementRepository(db);

      await visitRepo.saveInferred(InferredCountryVisit(
        countryCode: 'GB',
        inferredAt: DateTime.utc(2025, 1, 1),
        photoCount: 3,
      ));

      await pumpReviewPushed(
        tester,
        [autoVisit('GB')],
        visitRepo: visitRepo,
        achievementRepo: achievementRepo,
      );

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('🏆 First Stamp'), findsOneWidget);
    });

    testWidgets('no SnackBar when achievement already unlocked', (tester) async {
      final db = _makeDb();
      final visitRepo = VisitRepository(db);
      final achievementRepo = AchievementRepository(db);

      await visitRepo.saveInferred(InferredCountryVisit(
        countryCode: 'GB',
        inferredAt: DateTime.utc(2025, 1, 1),
        photoCount: 1,
      ));

      // Pre-unlock countries_1 and mark clean.
      await achievementRepo.upsertAll({'countries_1'}, DateTime.utc(2025));
      await achievementRepo.markClean('countries_1', DateTime.utc(2025));

      await pumpReviewPushed(
        tester,
        [autoVisit('GB')],
        visitRepo: visitRepo,
        achievementRepo: achievementRepo,
      );

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('🏆 First Stamp'), findsNothing);
    });
  });

  group('ReviewScreen — achievement evaluation at save', () {
    testWidgets('saving with achievementRepo unlocks countries_1', (tester) async {
      final db = _makeDb();
      final visitRepo = VisitRepository(db);
      final achievementRepo = AchievementRepository(db);

      // Pre-populate an inferred visit so loadEffective returns one country.
      await visitRepo.saveInferred(InferredCountryVisit(
        countryCode: 'GB',
        inferredAt: DateTime.utc(2025, 1, 1),
        photoCount: 3,
      ));

      await tester.pumpWidget(
        MaterialApp(
          home: ReviewScreen(
            initialVisits: [autoVisit('GB')],
            repository: visitRepo,
            achievementRepo: achievementRepo,
          ),
        ),
      );

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(await achievementRepo.loadAll(), contains('countries_1'));
    });

    testWidgets('saving without achievementRepo does not throw', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ReviewScreen(
            initialVisits: [autoVisit('GB')],
            repository: _makeRepo(),
            // No achievementRepo — achievement evaluation is skipped.
          ),
        ),
      );

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      // Simply verifies no exception is thrown.
    });

    testWidgets('already-unlocked achievement is not re-stored as dirty', (tester) async {
      final db = _makeDb();
      final visitRepo = VisitRepository(db);
      final achievementRepo = AchievementRepository(db);

      await visitRepo.saveInferred(InferredCountryVisit(
        countryCode: 'GB',
        inferredAt: DateTime.utc(2025, 1, 1),
        photoCount: 1,
      ));

      // Pre-unlock countries_1 and mark it clean.
      await achievementRepo.upsertAll({'countries_1'}, DateTime.utc(2025));
      await achievementRepo.markClean('countries_1', DateTime.utc(2025));
      expect(await achievementRepo.loadDirty(), isEmpty);

      await tester.pumpWidget(
        MaterialApp(
          home: ReviewScreen(
            initialVisits: [autoVisit('GB')],
            repository: visitRepo,
            achievementRepo: achievementRepo,
          ),
        ),
      );

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // No new achievements → dirty list stays empty.
      expect(await achievementRepo.loadDirty(), isEmpty);
    });
  });
}
