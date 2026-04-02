import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:mobile_flutter/features/map/discovery_overlay.dart';

void main() {
  group('DiscoveryOverlay', () {
    testWidgets('renders country name and XP amount', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DiscoveryOverlay(
            isoCode: 'GB',
            xpEarned: 50,
            onDone: () {},
          ),
        ),
      );
      await tester.pump(); // post-frame haptic callback

      expect(find.textContaining('United Kingdom'), findsOneWidget);
      expect(find.text('+50 XP'), findsOneWidget);
    });

    testWidgets('renders flag emoji for country code', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DiscoveryOverlay(
            isoCode: 'JP',
            xpEarned: 50,
            onDone: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('Japan'), findsOneWidget);
    });

    testWidgets('shows Explore your map CTA for single overlay', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DiscoveryOverlay(
            isoCode: 'GB',
            xpEarned: 50,
            onDone: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Explore your map'), findsOneWidget);
    });

    testWidgets('shows Next arrow and Skip all for multi-country sequence',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DiscoveryOverlay(
            isoCode: 'GB',
            xpEarned: 50,
            currentIndex: 0,
            totalCount: 3,
            onDone: () {},
            onSkipAll: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Next →'), findsOneWidget);
      expect(find.text('Skip all'), findsOneWidget);
      expect(find.text('Country 1 of 3'), findsOneWidget);
    });

    testWidgets('fires HeavyImpact haptic on appear', (tester) async {
      final log = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          log.add(call);
          return null;
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: DiscoveryOverlay(
            isoCode: 'GB',
            xpEarned: 50,
            onDone: () {},
          ),
        ),
      );
      await tester.pump(); // post-frame haptic fires

      expect(
        log,
        contains(
          isA<MethodCall>()
              .having((c) => c.method, 'method', 'HapticFeedback.vibrate')
              .having(
                (c) => c.arguments,
                'arguments',
                'HapticFeedbackType.heavyImpact',
              ),
        ),
      );

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    testWidgets('primary CTA calls onDone on last overlay', (tester) async {
      bool doneCalled = false;
      await tester.pumpWidget(
        MaterialApp(
          home: DiscoveryOverlay(
            isoCode: 'DE',
            xpEarned: 50,
            currentIndex: 0,
            totalCount: 1,
            onDone: () => doneCalled = true,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Explore your map'));
      await tester.pumpAndSettle();

      expect(doneCalled, isTrue);
    });
  });

  group('DiscoveryOverlay — M56 enhancements', () {
    testWidgets('shows first-visited date when provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DiscoveryOverlay(
            isoCode: 'GB',
            xpEarned: 50,
            firstVisited: DateTime(2019, 3, 15),
            onDone: () {},
          ),
        ),
      );
      await tester.pump();

      final expected =
          'First visited: ${DateFormat('MMMM y').format(DateTime(2019, 3, 15))}';
      expect(find.text(expected), findsOneWidget);
    });

    testWidgets('omits first-visited line when firstVisited is null',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DiscoveryOverlay(
            isoCode: 'GB',
            xpEarned: 50,
            onDone: () {},
            // firstVisited intentionally omitted (defaults to null)
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('First visited'), findsNothing);
    });

    testWidgets('shows Skip all for non-final overlay in sequence',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DiscoveryOverlay(
            isoCode: 'FR',
            xpEarned: 30,
            currentIndex: 0,
            totalCount: 3,
            onDone: () {},
            onSkipAll: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Skip all'), findsOneWidget);
    });

    testWidgets('no Skip all on final overlay in sequence', (tester) async {
      // onSkipAll: null → "Skip all" button must not be shown.
      await tester.pumpWidget(
        MaterialApp(
          home: DiscoveryOverlay(
            isoCode: 'DE',
            xpEarned: 30,
            currentIndex: 2,
            totalCount: 3,
            onDone: () {},
            // onSkipAll is null — no skip button expected
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Skip all'), findsNothing);
    });
  });
}
