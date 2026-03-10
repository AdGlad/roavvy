import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/visits/review_screen.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Helper to pump ReviewScreen inside a MaterialApp.
Future<void> pumpReview(
  WidgetTester tester,
  List<CountryVisit> visits,
) async {
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(
    MaterialApp(
      home: ReviewScreen(initialVisits: visits),
    ),
  );
}

CountryVisit autoVisit(String code) => CountryVisit(
      countryCode: code,
      source: VisitSource.auto,
      updatedAt: DateTime.utc(2025, 1, 1),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('ReviewScreen — rendering', () {
    testWidgets('shows all active visits', (tester) async {
      await pumpReview(tester, [autoVisit('GB'), autoVisit('JP'), autoVisit('US')]);
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

      // Tap the remove icon for GB.
      final removeIcon = find.byIcon(Icons.remove_circle_outline).first;
      await tester.tap(removeIcon);
      await tester.pump();

      // GB should now appear in the Removed section header.
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

      // DE should now appear (uppercased).
      expect(find.text('DE'), findsOneWidget);
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

    testWidgets('tapping Save pops the screen', (tester) async {
      // Wrap in a Navigator so pop() has somewhere to go.
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ReviewScreen(initialVisits: [autoVisit('GB')]),
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

      // After pop, we should be back on the original screen.
      expect(find.text('Review countries'), findsNothing);
      expect(find.text('Open'), findsOneWidget);
    });
  });
}
