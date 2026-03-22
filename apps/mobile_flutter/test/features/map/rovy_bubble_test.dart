import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/map/rovy_bubble.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _pumpBubble() {
  return const ProviderScope(
    child: MaterialApp(
      home: Scaffold(
        body: Center(child: RovyBubble()),
      ),
    ),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('RovyBubble', () {
    testWidgets('hidden when rovyMessageProvider is null', (tester) async {
      await tester.pumpWidget(_pumpBubble());
      await tester.pumpAndSettle();
      // No text visible — bubble is hidden.
      expect(find.byType(SizedBox), findsWidgets);
      expect(find.textContaining('Just'), findsNothing);
    });

    testWidgets('shows message text when provider has a value', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            rovyMessageProvider.overrideWith(
              (_) => const RovyMessage(
                text: 'Just 1 more country!',
                trigger: RovyTrigger.regionOneAway,
              ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: Center(child: RovyBubble())),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Just 1 more country!'), findsOneWidget);
    });

    testWidgets('shows "R" avatar when message is visible', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            rovyMessageProvider.overrideWith(
              (_) => const RovyMessage(
                text: 'Hello!',
                trigger: RovyTrigger.newCountry,
              ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: Center(child: RovyBubble())),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('R'), findsOneWidget);
    });

    testWidgets('message dismisses on tap', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            rovyMessageProvider.overrideWith(
              (_) => const RovyMessage(
                text: 'Dismiss me',
                trigger: RovyTrigger.caughtUp,
              ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: Center(child: RovyBubble())),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Dismiss me'), findsOneWidget);

      // Tap the bubble to dismiss immediately.
      await tester.tap(find.text('Dismiss me'));
      await tester.pumpAndSettle();
      expect(find.text('Dismiss me'), findsNothing);
    });

    testWidgets('message appears when provider is updated programmatically',
        (tester) async {
      // Pump with no override; set state via ref after build.
      late WidgetRef capturedRef;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  capturedRef = ref;
                  return const RovyBubble();
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      // Initially hidden.
      expect(find.text('Show me'), findsNothing);

      // Post a message — bubble should appear.
      capturedRef.read(rovyMessageProvider.notifier).state = const RovyMessage(
        text: 'Show me',
        trigger: RovyTrigger.newCountry,
      );
      await tester.pumpAndSettle();
      expect(find.text('Show me'), findsOneWidget);
    });
  });
}
