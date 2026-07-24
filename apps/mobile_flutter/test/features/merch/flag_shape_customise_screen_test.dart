// FlagShapeCustomiseScreen — default row count.
//
// A single-country design repeats its one flag into a full mosaic, so it
// should default to the densest packing (10 rows, the slider's max) rather
// than the sparse 3 rows used for a handful of distinct flags. The "Rows"
// label/value builds synchronously regardless of the async shirt-mockup
// artwork render, so a single pump (no pumpAndSettle) is enough to observe
// it without needing native asset loading to succeed in the test harness.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/merch/flag_shape_customise_screen.dart';

Widget _wrap(List<String> codes) {
  return MaterialApp(
    home: FlagShapeCustomiseScreen(
      codes: codes,
      allCodes: codes,
      trips: const [],
    ),
  );
}

void main() {
  group('FlagShapeCustomiseScreen — default row count', () {
    testWidgets('defaults to 10 rows for a single country', (tester) async {
      await tester.pumpWidget(_wrap(const ['JP']));
      await tester.pump();

      expect(find.text('10'), findsOneWidget);
    });

    testWidgets('defaults to 3 rows for a small set of countries', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const ['JP', 'FR', 'GB']));
      await tester.pump();

      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('defaults to 1 row for a large set of countries', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const ['JP', 'FR', 'GB', 'US', 'CA', 'DE', 'IT', 'ES', 'PT']),
      );
      await tester.pump();

      expect(find.text('1'), findsOneWidget);
    });
  });
}
