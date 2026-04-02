import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/providers.dart';
import 'package:mobile_flutter/features/scan/scan_reveal_mini_map.dart';

Widget _pumpMap({
  required List<String> newCodes,
  VoidCallback? onDoubleTap,
}) {
  return ProviderScope(
    overrides: [
      // Return an empty polygon list so no real asset loading is needed.
      polygonsProvider.overrideWithValue(const []),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: ScanRevealMiniMap(
          newCodes: newCodes,
          onDoubleTap: onDoubleTap,
        ),
      ),
    ),
  );
}

void main() {
  group('ScanRevealMiniMap', () {
    testWidgets('renders without error with multiple new codes', (tester) async {
      await tester.pumpWidget(_pumpMap(newCodes: ['GB', 'JP']));
      // Post-frame callback starts the reveal timer; pump once to process it.
      await tester.pump();

      // The widget should be present in the tree with no crash.
      expect(find.byType(ScanRevealMiniMap), findsOneWidget);
    });

    testWidgets('invokes onDoubleTap callback when double-tapped',
        (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        _pumpMap(
          newCodes: ['GB', 'JP'],
          onDoubleTap: () => tapped = true,
        ),
      );
      await tester.pump();

      // Double-tap the ScanRevealMiniMap widget.
      await tester.tap(find.byType(ScanRevealMiniMap));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byType(ScanRevealMiniMap));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });
  });
}
