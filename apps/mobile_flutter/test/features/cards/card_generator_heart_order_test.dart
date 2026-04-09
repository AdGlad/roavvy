// M62 migration — heart-order picker tests now use CardEditorScreen.
//
// These tests were originally written against CardGeneratorScreen (M37).
// CardGeneratorScreen is no longer navigated to; the same behaviour
// lives in CardEditorScreen (ADR-119).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/providers.dart';
import 'package:mobile_flutter/features/cards/card_editor_screen.dart';
import 'package:shared_models/shared_models.dart';

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
  group('CardEditorScreen sort-order picker (migrated from CardGeneratorScreen)',
      () {
    testWidgets('sort picker is visible when grid template selected',
        (tester) async {
      final container =
          _buildContainer(visits: _makeVisits(['GB', 'US']));
      await tester.pumpWidget(_wrap(
        const CardEditorScreen(templateType: CardTemplateType.grid),
        container,
      ));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Grid editor — sort picker is shown (unlike old CardGeneratorScreen default).
      expect(find.text('Shuffle'), findsOneWidget);
      expect(find.text('By Date'), findsOneWidget);
    });

    testWidgets('sort picker is visible when heart template selected',
        (tester) async {
      final container =
          _buildContainer(visits: _makeVisits(['GB', 'US']));
      await tester.pumpWidget(_wrap(
        const CardEditorScreen(templateType: CardTemplateType.heart),
        container,
      ));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Shuffle'), findsOneWidget);
      expect(find.text('By Date'), findsOneWidget);
      expect(find.text('A \u2192 Z'), findsOneWidget);
      expect(find.text('By Region'), findsOneWidget);
    });

    testWidgets('sort picker is absent for passport template',
        (tester) async {
      final container =
          _buildContainer(visits: _makeVisits(['GB', 'US']));
      await tester.pumpWidget(_wrap(
        const CardEditorScreen(
            templateType: CardTemplateType.passport),
        container,
      ));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Shuffle'), findsNothing);
      expect(find.text('By Date'), findsNothing);
    });
  });
}
