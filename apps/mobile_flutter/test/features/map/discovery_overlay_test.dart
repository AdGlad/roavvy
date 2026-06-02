import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:mobile_flutter/core/providers.dart';
import 'package:mobile_flutter/features/map/country_visual_state.dart';
import 'package:mobile_flutter/features/map/discovery_overlay.dart';

/// Wraps [child] in a [ProviderScope] with minimal overrides so that
/// [DiscoveryOverlay] (and its embedded [CelebrationGlobeWidget]) can render
/// without real repositories or polygon assets (ADR-123).
Widget _wrap(Widget child) {
  return ProviderScope(
    overrides: [
      polygonsProvider.overrideWithValue(const []),
      countryVisualStatesProvider.overrideWithValue(const {}),
      countryTripCountsProvider.overrideWith((_) async => const <String, int>{}),
    ],
    child: MaterialApp(home: child),
  );
}

void main() {
  group('DiscoveryOverlay', () {
    testWidgets('renders country name and XP amount', (tester) async {
      await tester.pumpWidget(
        _wrap(DiscoveryOverlay(
          isoCode: 'GB',
          xpEarned: 50,
          onDone: () {},
        )),
      );
      await tester.pump(); // post-frame haptic callback

      expect(find.textContaining('United Kingdom'), findsOneWidget);
      expect(find.text('+50 XP'), findsOneWidget);

      // Drain the 2200ms confetti-delay timer so no pending timers remain.
      await tester.pump(const Duration(milliseconds: 2200));
    });

    testWidgets('renders flag emoji for country code', (tester) async {
      await tester.pumpWidget(
        _wrap(DiscoveryOverlay(
          isoCode: 'JP',
          xpEarned: 50,
          onDone: () {},
        )),
      );
      await tester.pump();

      expect(find.textContaining('Japan'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 2200));
    });

    testWidgets('shows Explore your map CTA for single overlay', (tester) async {
      await tester.pumpWidget(
        _wrap(DiscoveryOverlay(
          isoCode: 'GB',
          xpEarned: 50,
          onDone: () {},
        )),
      );
      await tester.pump();

      expect(find.text('Explore your map'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 2200));
    });

    testWidgets('shows Next arrow and Skip all for multi-country sequence',
        (tester) async {
      await tester.pumpWidget(
        _wrap(DiscoveryOverlay(
          isoCode: 'GB',
          xpEarned: 50,
          currentIndex: 0,
          totalCount: 3,
          onDone: () {},
          onSkipAll: () {},
        )),
      );
      await tester.pump();

      expect(find.text('Next →'), findsOneWidget);
      expect(find.text('Skip all'), findsOneWidget);
      expect(find.text('Country 1 of 3'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 2200));
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
        _wrap(DiscoveryOverlay(
          isoCode: 'GB',
          xpEarned: 50,
          onDone: () {},
        )),
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

      await tester.pump(const Duration(milliseconds: 2200));
    });

    testWidgets('primary CTA calls onDone on last overlay', (tester) async {
      bool doneCalled = false;
      await tester.pumpWidget(
        _wrap(DiscoveryOverlay(
          isoCode: 'DE',
          xpEarned: 50,
          currentIndex: 0,
          totalCount: 1,
          onDone: () => doneCalled = true,
        )),
      );
      await tester.pump();

      await tester.tap(find.text('Explore your map'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(doneCalled, isTrue);

      await tester.pump(const Duration(milliseconds: 2200));
    });
  });

  group('DiscoveryOverlay — M56 enhancements', () {
    testWidgets('shows first-visited date when provided', (tester) async {
      await tester.pumpWidget(
        _wrap(DiscoveryOverlay(
          isoCode: 'GB',
          xpEarned: 50,
          firstVisited: DateTime(2019, 3, 15),
          onDone: () {},
        )),
      );
      await tester.pump();

      final expected =
          'First visited: ${DateFormat('MMMM y').format(DateTime(2019, 3, 15))}';
      expect(find.text(expected), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 2200));
    });

    testWidgets('omits first-visited line when firstVisited is null',
        (tester) async {
      await tester.pumpWidget(
        _wrap(DiscoveryOverlay(
          isoCode: 'GB',
          xpEarned: 50,
          onDone: () {},
          // firstVisited intentionally omitted (defaults to null)
        )),
      );
      await tester.pump();

      expect(find.textContaining('First visited'), findsNothing);

      await tester.pump(const Duration(milliseconds: 2200));
    });

    testWidgets('shows Skip all for non-final overlay in sequence',
        (tester) async {
      await tester.pumpWidget(
        _wrap(DiscoveryOverlay(
          isoCode: 'FR',
          xpEarned: 30,
          currentIndex: 0,
          totalCount: 3,
          onDone: () {},
          onSkipAll: () {},
        )),
      );
      await tester.pump();

      expect(find.text('Skip all'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 2200));
    });

    testWidgets('no Skip all on final overlay in sequence', (tester) async {
      await tester.pumpWidget(
        _wrap(DiscoveryOverlay(
          isoCode: 'DE',
          xpEarned: 30,
          currentIndex: 2,
          totalCount: 3,
          onDone: () {},
          // onSkipAll is null — no skip button expected
        )),
      );
      await tester.pump();

      expect(find.text('Skip all'), findsNothing);

      await tester.pump(const Duration(milliseconds: 2200));
    });
  });
}
