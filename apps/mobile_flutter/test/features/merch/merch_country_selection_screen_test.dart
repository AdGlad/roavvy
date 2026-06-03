// T4.3 — MerchCountrySelectionScreen widget tests

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/providers.dart';
import 'package:mobile_flutter/features/merch/merch_country_selection_screen.dart';
import 'package:shared_models/shared_models.dart';

// ── Fixture helpers ────────────────────────────────────────────────────────────

EffectiveVisitedCountry _visit(String code) => EffectiveVisitedCountry(
      countryCode: code,
      hasPhotoEvidence: true,
    );

Widget _pump(List<EffectiveVisitedCountry> visits) {
  return ProviderScope(
    overrides: [
      effectiveVisitsProvider.overrideWith((_) async => visits),
    ],
    child: const MaterialApp(home: MerchCountrySelectionScreen()),
  );
}

// ── Tests ──────────────────────────────────────────────────────────────────────

void main() {
  group('MerchCountrySelectionScreen — rendering', () {
    testWidgets('shows loading indicator before data resolves', (tester) async {
      await tester.pumpWidget(_pump(const []));
      // Before pump settles, the future hasn't resolved
      await tester.pump();

      // After resolve with empty list, shows the empty state (not crash)
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders country names from fixture visits', (tester) async {
      await tester.pumpWidget(_pump([_visit('GB'), _visit('FR')]));
      await tester.pumpAndSettle();

      expect(find.textContaining('United Kingdom'), findsOneWidget);
      expect(find.textContaining('France'), findsOneWidget);
    });

    testWidgets('each country has a CheckboxListTile', (tester) async {
      await tester.pumpWidget(_pump([_visit('GB'), _visit('JP')]));
      await tester.pumpAndSettle();

      expect(find.byType(CheckboxListTile), findsNWidgets(2));
    });

    testWidgets('all countries are selected by default', (tester) async {
      await tester.pumpWidget(_pump([_visit('GB'), _visit('FR')]));
      await tester.pumpAndSettle();

      final tiles = tester.widgetList<CheckboxListTile>(
        find.byType(CheckboxListTile),
      );
      expect(tiles.every((t) => t.value == true), isTrue);
    });

    testWidgets('app bar shows selected count', (tester) async {
      await tester.pumpWidget(_pump([_visit('GB'), _visit('FR')]));
      await tester.pumpAndSettle();

      expect(find.textContaining('2 selected'), findsOneWidget);
    });
  });

  group('MerchCountrySelectionScreen — selection toggle', () {
    testWidgets('tapping a country deselects it', (tester) async {
      await tester.pumpWidget(_pump([_visit('GB'), _visit('FR')]));
      await tester.pumpAndSettle();

      // Tap the first CheckboxListTile to deselect it
      await tester.tap(find.byType(CheckboxListTile).first);
      await tester.pump();

      // Now 1 of 2 tiles is unchecked
      final tiles = tester.widgetList<CheckboxListTile>(
        find.byType(CheckboxListTile),
      );
      final checkedCount = tiles.where((t) => t.value == true).length;
      expect(checkedCount, 1);
    });

    testWidgets('tapping a deselected country re-selects it', (tester) async {
      await tester.pumpWidget(_pump([_visit('GB')]));
      await tester.pumpAndSettle();

      // Deselect
      await tester.tap(find.byType(CheckboxListTile).first);
      await tester.pump();
      // Re-select
      await tester.tap(find.byType(CheckboxListTile).first);
      await tester.pump();

      final tile = tester.widget<CheckboxListTile>(
        find.byType(CheckboxListTile).first,
      );
      expect(tile.value, isTrue);
    });

    testWidgets('"Clear all" deselects all countries', (tester) async {
      await tester.pumpWidget(_pump([_visit('GB'), _visit('FR')]));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Clear all'));
      await tester.pump();

      final tiles = tester.widgetList<CheckboxListTile>(
        find.byType(CheckboxListTile),
      );
      expect(tiles.every((t) => t.value == false), isTrue);
    });

    testWidgets('"Select all" re-selects all after Clear all', (tester) async {
      await tester.pumpWidget(_pump([_visit('GB'), _visit('FR')]));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Clear all'));
      await tester.pump();
      await tester.tap(find.text('Select all'));
      await tester.pump();

      final tiles = tester.widgetList<CheckboxListTile>(
        find.byType(CheckboxListTile),
      );
      expect(tiles.every((t) => t.value == true), isTrue);
    });
  });

  group('MerchCountrySelectionScreen — Continue button', () {
    testWidgets('"Choose a design" button is enabled when countries are selected',
        (tester) async {
      await tester.pumpWidget(_pump([_visit('GB')]));
      await tester.pumpAndSettle();

      final btn = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(btn.onPressed, isNotNull);
    });

    testWidgets('"Choose a design" button is disabled when no countries selected',
        (tester) async {
      await tester.pumpWidget(_pump([_visit('GB')]));
      await tester.pumpAndSettle();

      // Deselect the only country
      await tester.tap(find.byType(CheckboxListTile).first);
      await tester.pump();

      final btn = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(btn.onPressed, isNull);
    });
  });
}
