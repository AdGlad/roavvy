// M62 — CardEditorScreen widget tests
//
// Covers: sort-order picker visibility per template, passport colour picker
// visibility, Entry/Exit toggle visibility, and orientation toggle.

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
  group('CardEditorScreen — sort order picker', () {
    testWidgets('sort picker is visible for grid template',
        (tester) async {
      final container =
          _buildContainer(visits: _makeVisits(['GB', 'US']));
      await tester.pumpWidget(_wrap(
        const CardEditorScreen(templateType: CardTemplateType.grid),
        container,
      ));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Shuffle'), findsOneWidget);
      expect(find.text('By Date'), findsOneWidget);
      expect(find.text('A \u2192 Z'), findsOneWidget);
      expect(find.text('By Region'), findsOneWidget);
    });

    testWidgets('sort picker is visible for heart template',
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
    });

    testWidgets('sort picker is hidden for passport template',
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

    testWidgets('sort picker is hidden for timeline template',
        (tester) async {
      final container =
          _buildContainer(visits: _makeVisits(['GB', 'US']));
      await tester.pumpWidget(_wrap(
        const CardEditorScreen(
            templateType: CardTemplateType.timeline),
        container,
      ));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Shuffle'), findsNothing);
    });
  });

  group('CardEditorScreen — passport controls', () {
    testWidgets('stamp colour picker is NOT shown in card editor (moved to merch screen, M64)',
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

      // Colour picker has moved to LocalMockupPreviewScreen (M64).
      expect(find.text('Multicolor'), findsNothing);
      expect(find.text('White'), findsNothing);
    });

    testWidgets('entry/exit toggle is visible for passport',
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

      expect(find.text('Entry + Exit'), findsOneWidget);
      expect(find.text('Entry only'), findsOneWidget);
    });

    testWidgets('entry/exit toggle is hidden for grid template',
        (tester) async {
      final container =
          _buildContainer(visits: _makeVisits(['GB', 'US']));
      await tester.pumpWidget(_wrap(
        const CardEditorScreen(templateType: CardTemplateType.grid),
        container,
      ));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Entry + Exit'), findsNothing);
      expect(find.text('Entry only'), findsNothing);
    });
  });

  group('CardEditorScreen — action buttons', () {
    testWidgets('Share and Print buttons are visible', (tester) async {
      final container =
          _buildContainer(visits: _makeVisits(['GB', 'US']));
      await tester.pumpWidget(_wrap(
        const CardEditorScreen(templateType: CardTemplateType.grid),
        container,
      ));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Share'), findsOneWidget);
      expect(find.text('Print'), findsOneWidget);
    });
  });

  group('CardEditorScreen — typography', () {
    testWidgets('no text decorations (underlines) on control text',
        (tester) async {
      final container =
          _buildContainer(visits: _makeVisits(['GB', 'US']));
      await tester.pumpWidget(_wrap(
        const CardEditorScreen(templateType: CardTemplateType.grid),
        container,
      ));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Verify that no RichText or Text widget has underline decoration.
      final richTexts = tester.widgetList<RichText>(find.byType(RichText));
      for (final rt in richTexts) {
        final style = rt.text.style;
        expect(
          style?.decoration,
          isNot(TextDecoration.underline),
          reason: 'No underlines allowed in card editor UI (ADR-119)',
        );
      }
    });
  });
}
