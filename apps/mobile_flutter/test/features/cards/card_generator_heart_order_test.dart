import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/providers.dart';
import 'package:mobile_flutter/features/cards/card_generator_screen.dart';
import 'package:shared_models/shared_models.dart';

// Minimal providers override for widget tests.
ProviderContainer _buildContainer({
  List<EffectiveVisitedCountry> visits = const [],
  List<TripRecord> trips = const [],
}) {
  return ProviderContainer(
    overrides: [
      effectiveVisitsProvider.overrideWith((ref) async => visits),
      tripListProvider.overrideWith((ref) async => trips),
    ],
  );
}

Widget _wrap(Widget child, ProviderContainer container) {
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
  group('CardGeneratorScreen heart-order picker', () {
    testWidgets('order picker is not visible when grid template selected',
        (tester) async {
      final container = _buildContainer(visits: _makeVisits(['GB', 'US']));
      await tester.pumpWidget(_wrap(const CardGeneratorScreen(), container));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Default template is grid — order picker should be absent.
      expect(find.text('Shuffle'), findsNothing);
      expect(find.text('By date'), findsNothing);
    });

    testWidgets('order picker appears when heart template selected',
        (tester) async {
      final container = _buildContainer(visits: _makeVisits(['GB', 'US']));
      await tester.pumpWidget(_wrap(const CardGeneratorScreen(), container));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Tap "Heart" template tile.
      await tester.tap(find.text('Heart'));
      await tester.pump();

      expect(find.text('Shuffle'), findsOneWidget);
      expect(find.text('By date'), findsOneWidget);
      expect(find.text('A→Z'), findsOneWidget);
      expect(find.text('By region'), findsOneWidget);
    });

    testWidgets('order picker disappears when switching back to grid',
        (tester) async {
      final container = _buildContainer(visits: _makeVisits(['GB', 'US']));
      await tester.pumpWidget(_wrap(const CardGeneratorScreen(), container));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Switch to heart.
      await tester.tap(find.text('Heart'));
      await tester.pump();
      expect(find.text('Shuffle'), findsOneWidget);

      // Switch back to grid.
      await tester.tap(find.text('Grid'));
      await tester.pump();
      expect(find.text('Shuffle'), findsNothing);
    });
  });
}
