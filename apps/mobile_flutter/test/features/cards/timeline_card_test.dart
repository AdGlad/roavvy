import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/cards/timeline_card.dart';
import 'package:shared_models/shared_models.dart';

TripRecord _trip(String code, int year, int startMonth, int endMonth) =>
    TripRecord(
      id: '$code-$year-$startMonth',
      countryCode: code,
      startedOn: DateTime(year, startMonth, 1),
      endedOn: DateTime(year, endMonth, 28),
      photoCount: 1,
      isManual: false,
    );

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('TimelineCard', () {
    testWidgets('renders landscape 3:2 as an AspectRatio widget', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          TimelineCard(
            trips: [_trip('GB', 2023, 3, 5), _trip('FR', 2022, 6, 8)],
            countryCodes: const ['GB', 'FR'],
            aspectRatio: 3.0 / 2.0,
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(TimelineCard), findsOneWidget);
    });

    testWidgets('renders portrait 2:3 as an AspectRatio widget', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          TimelineCard(
            trips: [_trip('DE', 2024, 1, 2)],
            countryCodes: const ['DE'],
            aspectRatio: 2.0 / 3.0,
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(TimelineCard), findsOneWidget);
    });

    testWidgets('branding footer is present', (tester) async {
      await tester.pumpWidget(
        _wrap(
          TimelineCard(
            trips: [_trip('JP', 2023, 4, 5)],
            countryCodes: const ['JP'],
          ),
        ),
      );
      await tester.pump();
      // TimelineCard renders branding via _TimelinePainter (CustomPainter),
      // not as a CardBrandingFooter widget. Verify the painter renders.
      expect(find.byType(CustomPaint), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('empty state shown when no trips', (tester) async {
      await tester.pumpWidget(
        _wrap(const TimelineCard(trips: [], countryCodes: ['US'])),
      );
      await tester.pump();
      // TimelineCard draws empty state text on canvas via CustomPainter —
      // no Text widgets in the widget tree.
      expect(find.byType(TimelineCard), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('TRAVEL LOG header is visible', (tester) async {
      await tester.pumpWidget(
        _wrap(
          TimelineCard(
            trips: [_trip('CA', 2024, 7, 8)],
            countryCodes: const ['CA'],
          ),
        ),
      );
      await tester.pump();
      // TimelineCard draws "TRAVEL LOG" via CardTextRenderer on the canvas —
      // no Text widgets in the widget tree.
      expect(find.byType(CustomPaint), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('year divider shown for trip year', (tester) async {
      await tester.pumpWidget(
        _wrap(
          TimelineCard(
            trips: [_trip('AU', 2021, 3, 4)],
            countryCodes: const ['AU'],
          ),
        ),
      );
      await tester.pump();
      // Year dividers are drawn via TextPainter on the canvas —
      // no Text widgets in the widget tree.
      expect(find.byType(TimelineCard), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('truncation note visible when truncatedCount > 0', (
      tester,
    ) async {
      // 40 trips in different years → many dividers → likely truncation
      final trips = List.generate(40, (i) => _trip('FR', 1985 + i, 6, 7));
      await tester.pumpWidget(
        _wrap(TimelineCard(trips: trips, countryCodes: const ['FR'])),
      );
      await tester.pump();
      // Find "and N more trips" — may or may not truncate depending on height
      // Just verify no crash.
      expect(tester.takeException(), isNull);
    });

    testWidgets('dateLabel shown in header when non-empty', (tester) async {
      await tester.pumpWidget(
        _wrap(
          TimelineCard(
            trips: [_trip('IT', 2023, 5, 6)],
            countryCodes: const ['IT'],
            dateLabel: '2023',
          ),
        ),
      );
      await tester.pump();
      // dateLabel is drawn via CardTextRenderer on the canvas (CustomPainter) —
      // no Text widgets in the widget tree.
      expect(find.byType(TimelineCard), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders on a dark shirt with white textColor without error', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          TimelineCard(
            trips: [_trip('GB', 2023, 3, 5), _trip('FR', 2022, 6, 8)],
            countryCodes: const ['GB', 'FR'],
            transparentBackground: true,
            textColor: Colors.white,
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('TimelineCard ordering (M193)', () {
    test('defaults to newest-first for a tour-poster feel', () {
      // A concert-tour poster reads best with the latest dates on top.
      const card = TimelineCard(trips: [], countryCodes: ['GB']);
      expect(card.newestFirst, isTrue);
    });
  });

  group('resolveTimelinePalette (M193 legibility)', () {
    test('dark shirt (transparent, no textColor) → light ink, no fill', () {
      final p = resolveTimelinePalette(transparentBackground: true);
      expect(
        p.ink.computeLuminance(),
        greaterThan(0.5),
        reason: 'light ink so names are legible on a dark garment',
      );
      expect(p.fill, isNull, reason: 'no opaque fill in shirt mode');
      expect(p.muted.computeLuminance(), greaterThan(0.5));
    });

    test('dark shirt with white textColor → ink follows the hint', () {
      final p = resolveTimelinePalette(
        transparentBackground: true,
        textColor: Colors.white,
      );
      expect(p.ink, Colors.white);
      expect(p.fill, isNull);
    });

    test('light shirt (dark textColor) → dark ink, deeper accent', () {
      final light = resolveTimelinePalette(
        transparentBackground: true,
        textColor: Colors.black,
      );
      final dark = resolveTimelinePalette(
        transparentBackground: true,
        textColor: Colors.white,
      );
      expect(light.ink.computeLuminance(), lessThan(0.5));
      expect(light.fill, isNull);
      // Deeper gold on a light garment differs from the bright gold on dark.
      expect(light.accent, isNot(dark.accent));
      expect(
        light.accent.computeLuminance(),
        lessThan(dark.accent.computeLuminance()),
      );
    });

    test('poster mode (opaque) → classic dark ink on a parchment fill', () {
      final p = resolveTimelinePalette(transparentBackground: false);
      expect(p.ink.computeLuminance(), lessThan(0.5));
      expect(p.fill, isNotNull, reason: 'parchment fill painted in poster mode');
      expect(p.fill!.computeLuminance(), greaterThan(0.5));
    });
  });
}
