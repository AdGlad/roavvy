// MerchDesignEntryScreen widget tests — "All countries" filter chip toggle.
//
// Reached from the Shop tab's "Design a shirt" banner. Verifies tapping the
// "All countries" chip while it's already the active filter clears the
// selection instead of re-selecting everything (a fast way to start a
// manual/custom pick from empty).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/providers.dart';
import 'package:mobile_flutter/features/merch/merch_design_entry_screen.dart';
import 'package:shared_models/shared_models.dart';

// ── Fixture helpers ────────────────────────────────────────────────────────────

EffectiveVisitedCountry _visit(String code) =>
    EffectiveVisitedCountry(countryCode: code, hasPhotoEvidence: true);

Widget _pump(List<EffectiveVisitedCountry> visits) {
  return ProviderScope(
    overrides: [
      effectiveVisitsProvider.overrideWith((_) async => visits),
      tripListProvider.overrideWith((_) async => const []),
    ],
    child: const MaterialApp(home: MerchDesignEntryScreen()),
  );
}

// ── Tests ──────────────────────────────────────────────────────────────────────

void main() {
  group('MerchDesignEntryScreen — "All countries" toggle', () {
    testWidgets('all countries are selected by default', (tester) async {
      await tester.pumpWidget(_pump([_visit('GB'), _visit('FR')]));
      await tester.pumpAndSettle();

      final tiles = tester.widgetList<CheckboxListTile>(
        find.byType(CheckboxListTile),
      );
      expect(tiles.every((t) => t.value == true), isTrue);
      expect(find.text('2 countries in your collection'), findsOneWidget);
    });

    testWidgets(
      'tapping "All countries" while already active deselects everything',
      (tester) async {
        await tester.pumpWidget(_pump([_visit('GB'), _visit('FR')]));
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(FilterChip, 'All countries'));
        await tester.pump();

        final tiles = tester.widgetList<CheckboxListTile>(
          find.byType(CheckboxListTile),
        );
        expect(tiles.every((t) => t.value == false), isTrue);
      },
    );

    testWidgets(
      'tapping "All countries" again after that reselects everything',
      (tester) async {
        await tester.pumpWidget(_pump([_visit('GB'), _visit('FR')]));
        await tester.pumpAndSettle();

        // First tap: All -> deselect all (was already active by default).
        await tester.tap(find.widgetWithText(FilterChip, 'All countries'));
        await tester.pump();
        // Second tap: from custom/empty -> All -> select all again.
        await tester.tap(find.widgetWithText(FilterChip, 'All countries'));
        await tester.pump();

        final tiles = tester.widgetList<CheckboxListTile>(
          find.byType(CheckboxListTile),
        );
        expect(tiles.every((t) => t.value == true), isTrue);
      },
    );

    testWidgets(
      'deselecting all disables the "Design with" button',
      (tester) async {
        await tester.pumpWidget(_pump([_visit('GB'), _visit('FR')]));
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(FilterChip, 'All countries'));
        await tester.pump();

        final btn = tester.widget<FilledButton>(find.byType(FilledButton));
        expect(btn.onPressed, isNull);
      },
    );

    testWidgets(
      'manually deselecting one country switches away from "All countries" '
      'without clearing the rest',
      (tester) async {
        await tester.pumpWidget(_pump([_visit('GB'), _visit('FR')]));
        await tester.pumpAndSettle();

        await tester.tap(find.byType(CheckboxListTile).first);
        await tester.pump();

        final tiles = tester.widgetList<CheckboxListTile>(
          find.byType(CheckboxListTile),
        );
        expect(tiles.where((t) => t.value == true).length, 1);

        final allChip = tester.widget<FilterChip>(
          find.widgetWithText(FilterChip, 'All countries'),
        );
        expect(allChip.selected, isFalse);
      },
    );
  });
}
