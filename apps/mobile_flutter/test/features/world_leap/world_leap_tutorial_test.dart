// Tutorial overlay for World Leap: shown automatically the first time the
// lobby is opened, persisted via SharedPreferences so it never auto-shows
// again, and re-openable at any time via the "How to Play" link.
//
// The illustration's AnimationController loops continuously (it only stops
// under reduce-motion), so these tests use explicit tester.pump() calls
// instead of pumpAndSettle, which would never settle while the dialog is up.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobile_flutter/features/world_leap/presentation/screens/world_leap_lobby_screen.dart';
import 'package:mobile_flutter/features/world_leap/presentation/widgets/world_leap_tutorial_overlay.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpLobby(WidgetTester tester) async {
    // setSurfaceSize only resizes the render surface, not the MediaQuery
    // reported to the widget tree — set the view's physicalSize directly so
    // the lobby actually picks Orientation.portrait.
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: WorldLeapLobbyScreen()));
    // Let the postFrameCallback's async hasSeenWorldLeapTutorial() resolve
    // and the dialog mount, without pumpAndSettle (would spin forever on the
    // looping illustration controller).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  group('World Leap lobby — tutorial auto-show', () {
    testWidgets(
      'shows the tutorial automatically on first visit',
      (tester) async {
        await pumpLobby(tester);

        expect(find.text('How to Play'), findsWidgets);
        expect(find.textContaining('Drag on the highlighted country'),
            findsOneWidget);
      },
    );

    testWidgets(
      'does not auto-show again once already seen',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          'world_leap_tutorial_seen': true,
        });

        await pumpLobby(tester);

        expect(find.textContaining('Drag on the highlighted country'),
            findsNothing);
        // The on-demand link is still present.
        expect(find.text('How to Play'), findsOneWidget);
      },
    );

    testWidgets(
      'the "How to Play" link reopens the tutorial on demand',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          'world_leap_tutorial_seen': true,
        });

        await pumpLobby(tester);

        await tester.tap(find.text('How to Play').first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.text('Got it'), findsOneWidget);
        expect(find.textContaining('Hit the highlighted target country'),
            findsOneWidget);

        await tester.tap(find.text('Got it'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Got it'), findsNothing);
      },
    );

    testWidgets(
      'step 2 copy reflects Beginner vs Classic mode',
      (tester) async {
        await pumpLobby(tester);

        // Default mode is Classic.
        expect(find.textContaining('letting go launches'), findsOneWidget);

        await tester.tap(find.text('Got it'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.text('Beginner'));
        await tester.pump();
        await tester.tap(find.text('How to Play').first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.textContaining('tap FIRE when ready'), findsOneWidget);
      },
    );
  });

  group('hasSeenWorldLeapTutorial / showWorldLeapTutorial', () {
    testWidgets('marks the tutorial as seen once opened', (tester) async {
      SharedPreferences.setMockInitialValues({});
      expect(await hasSeenWorldLeapTutorial(), isFalse);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () =>
                  showWorldLeapTutorial(context, beginnerMode: false),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(await hasSeenWorldLeapTutorial(), isTrue);

      // Dismiss so the looping controller's ticker doesn't trip the
      // pending-timer teardown check.
      await tester.tap(find.text('Got it'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    });
  });
}
