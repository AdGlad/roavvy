import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile_flutter/features/scan/level_up_sheet.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('LevelUpSheet', () {
    testWidgets('displays level label in headline', (tester) async {
      await tester.pumpWidget(_wrap(const LevelUpSheet(levelLabel: 'Explorer')));
      expect(find.text("You're now a Explorer!"), findsOneWidget);
    });

    testWidgets('displays subtext', (tester) async {
      await tester.pumpWidget(_wrap(const LevelUpSheet(levelLabel: 'Navigator')));
      expect(find.text('The world keeps opening up.'), findsOneWidget);
    });

    testWidgets('shows Later button', (tester) async {
      await tester.pumpWidget(_wrap(const LevelUpSheet(levelLabel: 'Voyager')));
      expect(find.text('Later'), findsOneWidget);
    });

    testWidgets('shows Create a travel card button', (tester) async {
      await tester.pumpWidget(_wrap(const LevelUpSheet(levelLabel: 'Globetrotter')));
      expect(find.text('Create a travel card'), findsOneWidget);
    });

    testWidgets('Later button pops the route', (tester) async {
      bool popped = false;
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (ctx) {
          return Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                await Navigator.of(ctx).push(MaterialPageRoute<void>(
                  builder: (_) => const LevelUpSheet(levelLabel: 'Pioneer'),
                ));
                popped = true;
              },
              child: const Text('open'),
            ),
          );
        }),
      ));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Later'), findsOneWidget);

      await tester.tap(find.text('Later'));
      await tester.pumpAndSettle();
      expect(popped, isTrue);
    });

    for (final entry in const {
      'Traveller': '🌱',
      'Explorer': '🧭',
      'Navigator': '🗺️',
      'Globetrotter': '✈️',
      'Pathfinder': '🌍',
      'Voyager': '⚓',
      'Pioneer': '🔭',
      'Legend': '🏆',
    }.entries) {
      testWidgets('shows emoji ${entry.value} for ${entry.key}', (tester) async {
        await tester.pumpWidget(_wrap(LevelUpSheet(levelLabel: entry.key)));
        expect(find.text(entry.value), findsOneWidget);
      });
    }

    testWidgets('unknown label falls back to ✈️ emoji', (tester) async {
      await tester.pumpWidget(_wrap(const LevelUpSheet(levelLabel: 'Unknown')));
      expect(find.text('✈️'), findsOneWidget);
    });
  });
}
