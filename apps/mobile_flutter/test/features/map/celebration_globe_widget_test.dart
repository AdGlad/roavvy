// M69 — CelebrationGlobeWidget smoke tests (ADR-123)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/providers.dart';
import 'package:mobile_flutter/features/map/celebration_globe_widget.dart';
import 'package:mobile_flutter/features/map/country_visual_state.dart';

Widget _pump(String isoCode) {
  return ProviderScope(
    overrides: [
      polygonsProvider.overrideWithValue(const []),
      countryVisualStatesProvider.overrideWithValue(const {}),
      countryTripCountsProvider.overrideWith((_) async => const <String, int>{}),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: CelebrationGlobeWidget(isoCode: isoCode),
      ),
    ),
  );
}

void main() {
  group('CelebrationGlobeWidget', () {
    testWidgets('renders without error for known isoCode (JP)', (tester) async {
      await tester.pumpWidget(_pump('JP'));
      await tester.pump(); // post-frame init

      expect(find.byType(CelebrationGlobeWidget), findsOneWidget);
    });

    testWidgets('renders without error for unknown isoCode (no centroid)',
        (tester) async {
      await tester.pumpWidget(_pump('XX')); // not in kCountryCentroids
      await tester.pump();

      expect(find.byType(CelebrationGlobeWidget), findsOneWidget);
    });
  });
}
