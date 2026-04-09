import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/cards/front_ribbon_card.dart';

void main() {
  group('FrontRibbonCard', () {
    Widget wrap(Widget child) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: child,
            ),
          ),
        ),
      );
    }

    testWidgets('renders empty state for 0 countries', (tester) async {
      await tester.pumpWidget(wrap(const FrontRibbonCard(
        countryCodes: [],
        travelerLevel: 'Explorer',
      )));
      // It returns SizedBox.shrink()
      expect(
        find.descendant(
          of: find.byType(FrontRibbonCard),
          matching: find.byType(LayoutBuilder),
        ),
        findsNothing,
      );
    });

    testWidgets('renders correctly with flags', (tester) async {
      await tester.pumpWidget(wrap(const FrontRibbonCard(
        countryCodes: ['US', 'GB', 'FR', 'IT', 'DE', 'ES', 'NL', 'BE', 'PT'],
        travelerLevel: 'Explorer',
        textColor: Colors.black,
      )));

      expect(
        find.descendant(
          of: find.byType(FrontRibbonCard),
          matching: find.byType(CustomPaint),
        ),
        findsOneWidget,
      );
    });
  });
}
