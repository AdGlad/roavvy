import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile_flutter/features/cards/card_templates.dart';

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: SizedBox(width: 300, height: 200, child: child)));

void main() {
  group('GridFlagsCard', () {
    testWidgets('renders empty state with 0 countries', (tester) async {
      await tester.pumpWidget(_wrap(const GridFlagsCard(countryCodes: [])));
      expect(find.text('Scan your photos\nto fill your card'), findsOneWidget);
    });

    testWidgets('renders flags with 5 countries', (tester) async {
      await tester.pumpWidget(_wrap(
        const GridFlagsCard(countryCodes: ['FR', 'DE', 'JP', 'US', 'GB']),
      ));
      expect(find.text('5'), findsOneWidget);
      expect(find.text('countries visited'), findsOneWidget);
    });

    testWidgets('shows overflow indicator with 50+ countries', (tester) async {
      final codes = List.generate(50, (i) => String.fromCharCode(65 + i % 26) +
          String.fromCharCode(65 + (i + 1) % 26));
      await tester.pumpWidget(_wrap(GridFlagsCard(countryCodes: codes)));
      // Should not throw; overflow shown as +N
      expect(find.textContaining('+'), findsOneWidget);
    });
  });

  group('HeartFlagsCard', () {
    testWidgets('renders empty state with 0 countries', (tester) async {
      await tester.pumpWidget(_wrap(const HeartFlagsCard(countryCodes: [])));
      expect(find.text('Scan your photos\nto fill your card'), findsOneWidget);
    });

    testWidgets('renders flags with 5 countries', (tester) async {
      await tester.pumpWidget(_wrap(
        const HeartFlagsCard(countryCodes: ['FR', 'DE', 'JP', 'US', 'GB']),
      ));
      expect(find.text('5'), findsOneWidget);
      expect(find.text('countries visited'), findsOneWidget);
    });

    testWidgets('shows overflow indicator with 50+ countries', (tester) async {
      final codes = List.generate(50, (i) => String.fromCharCode(65 + i % 26) +
          String.fromCharCode(65 + (i + 1) % 26));
      await tester.pumpWidget(_wrap(HeartFlagsCard(countryCodes: codes)));
      expect(find.textContaining('+'), findsOneWidget);
    });
  });

  group('PassportStampsCard', () {
    testWidgets('renders empty state with 0 countries', (tester) async {
      await tester.pumpWidget(_wrap(const PassportStampsCard(countryCodes: [])));
      expect(find.text('Scan your photos\nto fill your passport'), findsOneWidget);
    });

    testWidgets('renders stamps with 5 countries', (tester) async {
      await tester.pumpWidget(_wrap(
        const PassportStampsCard(countryCodes: ['FR', 'DE', 'JP', 'US', 'GB']),
      ));
      // Shows ISO codes in stamp widgets
      expect(find.text('FR'), findsOneWidget);
      expect(find.text('DE'), findsOneWidget);
    });

    testWidgets('no overflow with 50+ countries', (tester) async {
      final codes = List.generate(50, (i) => String.fromCharCode(65 + i % 26) +
          String.fromCharCode(65 + (i + 1) % 26));
      await tester.pumpWidget(_wrap(PassportStampsCard(countryCodes: codes)));
      // Should render without throwing
      expect(find.byType(PassportStampsCard), findsOneWidget);
    });
  });
}
