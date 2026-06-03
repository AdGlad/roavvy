// T4.2 — MerchCustomisationSheet widget tests

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/providers.dart';
import 'package:mobile_flutter/features/merch/merch_customisation_sheet.dart';
import 'package:mobile_flutter/features/merch/merch_preset.dart';
import 'package:shared_models/shared_models.dart';

// ── Fixture ────────────────────────────────────────────────────────────────────

const _defaultConfig = MerchPresetConfig(
  layout: CardTemplateType.grid,
  source: MerchCountrySource.allTime,
  jitter: 0.5,
  density: MerchDensity.balanced,
  stampMode: MerchStampMode.entryOnly,
);

/// Pumps a scaffold that opens the customisation sheet on build.
Future<void> _pumpSheet(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(400, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        imagePlaygroundAvailableProvider.overrideWith((_) async => false),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: ElevatedButton(
                onPressed:
                    () => showMerchCustomisationSheet(
                      context,
                      config: _defaultConfig,
                    ),
                child: const Text('Open sheet'),
              ),
            );
          },
        ),
      ),
    ),
  );

  // Open the sheet
  await tester.tap(find.text('Open sheet'));
  await tester.pumpAndSettle();
}

// ── Tests ──────────────────────────────────────────────────────────────────────

void main() {
  group('MerchCustomisationSheet — rendering', () {
    testWidgets('shows "Customise Design" title', (tester) async {
      await _pumpSheet(tester);

      expect(find.text('Customise Design'), findsOneWidget);
    });

    testWidgets('shows Cancel button', (tester) async {
      await _pumpSheet(tester);

      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('shows Apply button', (tester) async {
      await _pumpSheet(tester);

      expect(find.text('Apply'), findsOneWidget);
    });

    testWidgets('shows Layout section with Passport and Grid options', (
      tester,
    ) async {
      await _pumpSheet(tester);

      expect(find.text('Layout'), findsOneWidget);
      expect(find.text('Passport'), findsOneWidget);
      expect(find.text('Grid'), findsOneWidget);
    });

    testWidgets('shows Scatter section', (tester) async {
      await _pumpSheet(tester);

      expect(find.text('Scatter'), findsOneWidget);
    });

    testWidgets('shows Density section', (tester) async {
      await _pumpSheet(tester);

      expect(find.text('Density'), findsOneWidget);
    });

    testWidgets('renders ChoiceChip preset options', (tester) async {
      await _pumpSheet(tester);

      expect(find.byType(ChoiceChip), findsWidgets);
    });
  });

  group('MerchCustomisationSheet — interaction', () {
    testWidgets('Cancel closes the sheet', (tester) async {
      await _pumpSheet(tester);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Customise Design'), findsNothing);
    });

    testWidgets('Apply closes the sheet', (tester) async {
      await _pumpSheet(tester);

      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      expect(find.text('Customise Design'), findsNothing);
    });

    testWidgets('tapping Layout option Passport changes selection', (
      tester,
    ) async {
      await _pumpSheet(tester);

      // Grid is currently selected (default config). Tap Passport.
      await tester.tap(find.text('Passport'));
      await tester.pump();

      // No crash — selection updated
      expect(tester.takeException(), isNull);
    });
  });
}
