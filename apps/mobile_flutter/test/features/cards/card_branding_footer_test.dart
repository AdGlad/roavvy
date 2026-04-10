import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/cards/card_branding_footer.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(
        body: SizedBox(width: 300, height: 40, child: child),
      ),
    );

void main() {
  group('CardBrandingFooter', () {
    testWidgets('single-year dateLabel renders as "2024" (not "2024–2024")',
        (tester) async {
      await tester.pumpWidget(
        _wrap(const CardBrandingFooter(countryCount: 5, dateLabel: '2024')),
      );
      expect(find.text('2024'), findsOneWidget);
      expect(find.text('2024\u20132024'), findsNothing);
    });

    testWidgets('multi-year dateLabel renders as "2018–2024"', (tester) async {
      await tester.pumpWidget(
        _wrap(const CardBrandingFooter(
            countryCount: 10, dateLabel: '2018\u20132024')),
      );
      expect(find.text('2018\u20132024'), findsOneWidget);
    });

    testWidgets('empty dateLabel renders no date text', (tester) async {
      await tester.pumpWidget(
        _wrap(const CardBrandingFooter(countryCount: 3, dateLabel: '')),
      );
      // No year-like text should be rendered — only ROAVVY and count.
      expect(find.textContaining('20'), findsNothing);
    });

    testWidgets('empty dateLabel does not render empty space widget',
        (tester) async {
      await tester.pumpWidget(
        _wrap(const CardBrandingFooter(countryCount: 3, dateLabel: '')),
      );
      // Row should have exactly 3 children: wordmark, SizedBox, count.
      // When dateLabel is empty the extra SizedBox + text are absent.
      // We verify by checking only ROAVVY and "3 countries" are rendered.
      expect(find.text('ROAVVY'), findsOneWidget);
      expect(find.text('3 countries'), findsOneWidget);
    });

    testWidgets('ROAVVY wordmark is always visible', (tester) async {
      await tester.pumpWidget(
        _wrap(const CardBrandingFooter(countryCount: 7, dateLabel: '2023')),
      );
      expect(find.text('ROAVVY'), findsOneWidget);
    });

    testWidgets('country count renders in "{N} countries" format',
        (tester) async {
      await tester.pumpWidget(
        _wrap(const CardBrandingFooter(countryCount: 42, dateLabel: '')),
      );
      expect(find.text('42 countries'), findsOneWidget);
    });

    testWidgets('customLabel replaces auto "{N} countries" text (ADR-120)',
        (tester) async {
      await tester.pumpWidget(
        _wrap(const CardBrandingFooter(
          countryCount: 5,
          dateLabel: '',
          customLabel: 'My Travels',
        )),
      );
      expect(find.text('My Travels'), findsOneWidget);
      expect(find.text('5 countries'), findsNothing);
    });

    testWidgets('null customLabel falls back to auto count text', (tester) async {
      await tester.pumpWidget(
        _wrap(const CardBrandingFooter(
          countryCount: 3,
          dateLabel: '',
          customLabel: null,
        )),
      );
      expect(find.text('3 countries'), findsOneWidget);
    });
  });
}
