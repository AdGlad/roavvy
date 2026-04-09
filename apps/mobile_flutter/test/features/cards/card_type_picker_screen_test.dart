// M62 — CardTypePickerScreen widget tests
//
// Covers: all four template labels shown, empty-state shown when no visits,
// loading state, and navigation to CardEditorScreen on tile tap.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/providers.dart';
import 'package:mobile_flutter/features/cards/card_type_picker_screen.dart';
import 'package:mobile_flutter/features/cards/card_editor_screen.dart';
import 'package:shared_models/shared_models.dart';

Widget _wrap(
  Widget child, {
  List<EffectiveVisitedCountry> visits = const [],
  List<TripRecord> trips = const [],
}) {
  final container = ProviderContainer(
    overrides: [
      effectiveVisitsProvider.overrideWith((ref) async => visits),
      tripListProvider.overrideWith((ref) async => trips),
    ],
  );
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(home: child),
  );
}

List<EffectiveVisitedCountry> _makeVisits(List<String> codes) => codes
    .map((c) => EffectiveVisitedCountry(
          countryCode: c,
          hasPhotoEvidence: true,
          firstSeen: DateTime(2020),
          lastSeen: DateTime(2023),
        ))
    .toList();

void main() {
  group('CardTypePickerScreen', () {
    testWidgets('shows first three card-type labels when visits exist',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const CardTypePickerScreen(),
          visits: _makeVisits(['GB', 'US', 'JP']),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // The horizontal carousel shows tiles lazily. The first 3 are visible
      // in the default test viewport (800px wide, tiles ~280px each).
      expect(find.text('Flag Grid'), findsOneWidget);
      expect(find.text('Heart'), findsOneWidget);
      expect(find.text('Passport'), findsOneWidget);
    });

    testWidgets('Timeline tile becomes visible after scrolling',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const CardTypePickerScreen(),
          visits: _makeVisits(['GB', 'US', 'JP']),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Scroll the carousel to reveal the Timeline tile.
      await tester.drag(
          find.byType(ListView), const Offset(-800, 0));
      await tester.pump();

      expect(find.text('Timeline'), findsOneWidget);
    });

    testWidgets('shows empty state when no visits', (tester) async {
      await tester.pumpWidget(_wrap(const CardTypePickerScreen()));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.text('Scan your photos to generate a card'),
        findsOneWidget,
      );
      expect(find.text('Flag Grid'), findsNothing);
    });

    testWidgets('shows "Choose a style" heading when visits exist',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const CardTypePickerScreen(),
          visits: _makeVisits(['GB']),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Choose a style'), findsOneWidget);
    });

    testWidgets('tapping Flag Grid tile pushes CardEditorScreen',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const CardTypePickerScreen(),
          visits: _makeVisits(['GB', 'US']),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.text('Flag Grid'));
      await tester.pumpAndSettle();

      expect(find.byType(CardEditorScreen), findsOneWidget);
    });

    testWidgets('tapping Heart tile pushes CardEditorScreen',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const CardTypePickerScreen(),
          visits: _makeVisits(['GB', 'US']),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.text('Heart'));
      await tester.pumpAndSettle();

      expect(find.byType(CardEditorScreen), findsOneWidget);
    });
  });
}
