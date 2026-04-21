// M55-C/D — LocalMockupPreviewScreen widget tests

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/providers.dart';
import 'package:mobile_flutter/data/db/roavvy_database.dart';
import 'package:mobile_flutter/features/merch/local_mockup_preview_screen.dart';
import 'package:mobile_flutter/features/merch/merch_variant_lookup.dart';
import 'package:shared_models/shared_models.dart';

RoavvyDatabase _makeDb() => RoavvyDatabase(NativeDatabase.memory());

// Minimal valid 1×1 RGB PNG — generated with Python's zlib + struct (69 bytes).
// Decodes successfully via ui.instantiateImageCodec in Flutter tests.
final _kFakeArtwork = Uint8List.fromList([
  137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 1,
  0, 0, 0, 1, 8, 2, 0, 0, 0, 144, 119, 83, 222, 0, 0, 0, 12, 73, 68, 65, 84,
  120, 156, 99, 72, 153, 118, 2, 0, 3, 36, 1, 195, 32, 85, 100, 163, 0, 0, 0,
  0, 73, 69, 78, 68, 174, 66, 96, 130,
]);

Widget _wrap(
  Widget child, {
  String? uid = 'test-uid',
}) {
  final db = _makeDb();
  return ProviderScope(
    overrides: [
      currentUidProvider.overrideWith((ref) => uid),
      roavvyDatabaseProvider.overrideWithValue(db),
    ],
    child: MaterialApp(home: child),
  );
}

LocalMockupPreviewScreen _makeScreen({
  CardTemplateType template = CardTemplateType.grid,
  double confirmedAspectRatio = 3.0 / 2.0,
  bool confirmedEntryOnly = false,
}) {
  return LocalMockupPreviewScreen(
    selectedCodes: const ['GB', 'FR'],
    allCodes: const ['GB', 'FR'],
    trips: const [],
    artworkImageBytes: _kFakeArtwork,
    artworkConfirmationId: 'ac-test-001',
    initialTemplate: template,
    confirmedAspectRatio: confirmedAspectRatio,
    confirmedEntryOnly: confirmedEntryOnly,
  );
}

void main() {
  group('M55-C — LocalMockupPreviewScreen initial render', () {
    testWidgets('shows AppBar with product name', (tester) async {
      await tester.pumpWidget(_wrap(_makeScreen()));
      // Absorb any image decode exception from fake PNG bytes.
      tester.takeException();
      await tester.pump();

      expect(find.text('Design your T-Shirt'), findsOneWidget);
    });

    testWidgets('shows "Approve this order" CTA when no template change',
        (tester) async {
      await tester.pumpWidget(_wrap(_makeScreen()));
      tester.takeException();
      await tester.pump();

      expect(find.text('Approve this order'), findsOneWidget);
    });

    testWidgets('shows "Edit card design" back button', (tester) async {
      await tester.pumpWidget(_wrap(_makeScreen()));
      tester.takeException();
      await tester.pump();

      expect(find.text('Edit card design'), findsOneWidget);
    });

    testWidgets('"Edit card design" pops (returns null) when tapped',
        (tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();
      final db = _makeDb();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUidProvider.overrideWith((ref) => 'test-uid'),
            roavvyDatabaseProvider.overrideWithValue(db),
          ],
          child: MaterialApp(
            navigatorKey: navigatorKey,
            home: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => _makeScreen()),
                  );
                },
                child: const Text('Go'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Go'));
      await tester.pump(); // start route transition
      await tester.pump(const Duration(milliseconds: 300)); // complete transition
      tester.takeException(); // absorb any image-decode errors

      expect(find.byType(LocalMockupPreviewScreen), findsOneWidget);

      await tester.tap(find.text('Edit card design'));
      await tester.pump(); // start pop
      await tester.pump(const Duration(milliseconds: 500)); // complete pop

      // Screen popped.
      expect(find.byType(LocalMockupPreviewScreen), findsNothing);
    });

    testWidgets('product picker shows T-Shirt and Poster options',
        (tester) async {
      await tester.pumpWidget(_wrap(_makeScreen()));
      tester.takeException();
      await tester.pump();
      
      await tester.tap(find.text('More'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('T-Shirt'), findsOneWidget);
      expect(find.text('Poster'), findsOneWidget);
    });

    testWidgets('card design picker shows all 4 templates', (tester) async {
      await tester.pumpWidget(_wrap(_makeScreen()));
      tester.takeException();
      await tester.pump();

      await tester.tap(find.text('More'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Grid'), findsOneWidget);
      expect(find.text('Heart'), findsOneWidget);
      expect(find.text('Passport'), findsOneWidget);
      expect(find.text('Timeline'), findsOneWidget);
    });
  });

  group('M55-C — inline re-confirmation banner', () {
    testWidgets('banner NOT shown on initial render', (tester) async {
      await tester.pumpWidget(_wrap(_makeScreen()));
      tester.takeException();
      await tester.pump();

      expect(
        find.text(
            'Design changed — please confirm this is correct before ordering'),
        findsNothing,
      );
    });
  });

  group('M65 — Printful dual-mockup: pre-generation paths unchanged', () {
    // These tests verify that the configuring-state local mockup path is
    // unaffected by the M65 changes. Ready-state (Printful URL) tests require
    // Firebase Function mocking and are covered by manual QA.

    testWidgets('unavailable banner NOT shown in configuring state',
        (tester) async {
      await tester.pumpWidget(_wrap(_makeScreen()));
      tester.takeException();
      await tester.pump();

      expect(find.text('Front mockup unavailable'), findsNothing);
      expect(find.text('Back mockup unavailable'), findsNothing);
    });

    testWidgets('unavailable banner NOT shown in configuring state — back face',
        (tester) async {
      await tester.pumpWidget(_wrap(_makeScreen()));
      tester.takeException();
      await tester.pump();

      // Simulate toggling to back face via placement toggle.
      // The toggle is inside the compact strip which renders for t-shirt.
      final backFinders = find.text('Back');
      if (backFinders.evaluate().isNotEmpty) {
        await tester.tap(backFinders.first);
        await tester.pump();
      }

      expect(find.text('Back mockup unavailable'), findsNothing);
    });

    testWidgets('Approve CTA still present in configuring state after M65',
        (tester) async {
      await tester.pumpWidget(_wrap(_makeScreen()));
      tester.takeException();
      await tester.pump();

      expect(find.text('Approve this order'), findsOneWidget);
    });
  });

  group('M55-D — null UID guard', () {
    testWidgets('shows SnackBar when UID is null on approve', (tester) async {
      await tester.pumpWidget(_wrap(_makeScreen(), uid: null));
      tester.takeException();
      await tester.pump();

      await tester.tap(find.text('Approve this order'));
      await tester.pump();

      expect(find.text('Please sign in to continue'), findsOneWidget);
    });

    testWidgets('CTA remains visible after null-UID rejection', (tester) async {
      await tester.pumpWidget(_wrap(_makeScreen(), uid: null));
      tester.takeException();
      await tester.pump();

      await tester.tap(find.text('Approve this order'));
      await tester.pump();

      // Screen stays open.
      expect(find.byType(LocalMockupPreviewScreen), findsOneWidget);
      // CTA is re-enabled (not in approving spinner state).
      expect(find.text('Approve this order'), findsOneWidget);
    });
  });
}
