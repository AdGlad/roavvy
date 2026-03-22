import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/map/discovery_overlay.dart';

void main() {
  group('DiscoveryOverlay', () {
    testWidgets('renders country name and XP amount', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DiscoveryOverlay(isoCode: 'GB', xpEarned: 50),
        ),
      );
      await tester.pump(); // post-frame haptic callback

      expect(find.textContaining('United Kingdom'), findsOneWidget);
      expect(find.text('+50 XP'), findsOneWidget);
    });

    testWidgets('renders flag emoji for country code', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DiscoveryOverlay(isoCode: 'JP', xpEarned: 50),
        ),
      );
      await tester.pump();

      expect(find.textContaining('Japan'), findsOneWidget);
    });

    testWidgets('shows Explore your map CTA', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DiscoveryOverlay(isoCode: 'GB', xpEarned: 50),
        ),
      );
      await tester.pump();

      expect(find.text('Explore your map'), findsOneWidget);
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
        const MaterialApp(
          home: DiscoveryOverlay(isoCode: 'GB', xpEarned: 50),
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

    testWidgets('CTA triggers popUntil back to home route', (tester) async {
      // Build: Home screen with a button that pushes DiscoveryOverlay.
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(ctx).push(
                  MaterialPageRoute<void>(
                    settings: const RouteSettings(
                      name: DiscoveryOverlay.routeName,
                    ),
                    builder: (_) => const DiscoveryOverlay(
                      isoCode: 'DE',
                      xpEarned: 50,
                    ),
                  ),
                ),
                child: const Text('Go'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Germany'), findsOneWidget);

      await tester.tap(find.text('Explore your map'));
      await tester.pumpAndSettle();

      // popUntil('/') lands back on Home
      expect(find.text('Go'), findsOneWidget);
      expect(find.textContaining('Germany'), findsNothing);
    });
  });
}
