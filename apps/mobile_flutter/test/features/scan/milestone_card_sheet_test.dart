import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile_flutter/features/scan/milestone_card_sheet.dart';

void main() {
  group('pendingMilestoneThreshold', () {
    test('returns null when no thresholds are crossed', () {
      expect(pendingMilestoneThreshold(3, {}), isNull);
    });

    test('returns 5 when count is 5 and none shown', () {
      expect(pendingMilestoneThreshold(5, {}), 5);
    });

    test('returns 10 when count is 10 and 5 already shown', () {
      expect(pendingMilestoneThreshold(10, {5}), 10);
    });

    test('returns highest crossed threshold (10) when jumping from 4 to 12', () {
      expect(pendingMilestoneThreshold(12, {}), 10);
    });

    test('returns null when all crossed thresholds already shown', () {
      expect(pendingMilestoneThreshold(10, {5, 10}), isNull);
    });

    test('returns 100 for count 100 with all lower thresholds shown', () {
      expect(pendingMilestoneThreshold(100, {5, 10, 25, 50}), 100);
    });
  });

  group('MilestoneCardSheet widget', () {
    Widget buildSheet(int threshold) {
      return MaterialApp(
        home: Scaffold(
          body: MilestoneCardSheet(threshold: threshold),
        ),
      );
    }

    testWidgets('renders correct badge and count for 10', (tester) async {
      await tester.pumpWidget(buildSheet(10));
      expect(find.text('🗺️'), findsOneWidget);
      expect(find.text("You've visited 10 countries!"), findsOneWidget);
      expect(find.text('A new milestone for your travel story.'), findsOneWidget);
    });

    testWidgets('renders correct badge for 100', (tester) async {
      await tester.pumpWidget(buildSheet(100));
      expect(find.text('🏆'), findsOneWidget);
      expect(find.text("You've visited 100 countries!"), findsOneWidget);
    });

    testWidgets('Continue button dismisses sheet', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showMilestoneCardSheet(context, 10),
            child: const Text('open'),
          ),
        ),
      ));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text("You've visited 10 countries!"), findsOneWidget);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Sheet dismissed — headline no longer visible.
      expect(find.text("You've visited 10 countries!"), findsNothing);
    });
  });
}
