// The Instant deck INSIDE the real studio shell, at phone size.
//
// The workspace sits under a persistent hero and inside the shell's own
// scrolling and gesture handlers. A deck that swipes perfectly in isolation can
// still lose the gesture to a parent, and only a test that pumps the whole
// screen will see it.
import 'package:design_studio/design_studio.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/studio_v2/studio_v2_app.dart';
import 'package:mobile_flutter/features/studio_v2/studio_v2_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StudioController controller;

  setUp(() => controller = buildStudioV2Controller());
  tearDown(() => controller.dispose());

  Future<void> pumpPhone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844); // iPhone-ish
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(home: StudioV2Screen(controller: controller)),
    );
    await tester.pump(); // the preview spinner never settles
  }

  Future<void> swipe(WidgetTester tester, double dx) async {
    final deck = find.byKey(const Key('v2-instant-deck'));
    expect(deck, findsOneWidget, reason: 'Instant should be the opening step');
    final g = await tester.startGesture(
      tester.getCenter(deck),
      kind: PointerDeviceKind.touch,
    );
    for (var i = 0; i < 6; i++) {
      await g.moveBy(Offset(dx / 6, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets(
    'the studio opens on Instant with a design already on the shirt',
    (tester) async {
      await pumpPhone(tester);
      expect(find.byKey(const Key('v2-instant-deck')), findsOneWidget);
      expect(find.byKey(const Key('v2-garment-preview')), findsOneWidget);
      expect(controller.instantPicks, isNotEmpty);
    },
  );

  testWidgets('a finger swipe pages the deck inside the shell', (tester) async {
    await pumpPhone(tester);
    expect(controller.instantIndex, 0);
    await swipe(tester, -240);
    expect(
      controller.instantIndex,
      1,
      reason: 'the shell must not swallow the deck swipe',
    );
    await swipe(tester, 240);
    expect(controller.instantIndex, 0);
  });

  testWidgets('the opening screen paints without overflowing a phone', (
    tester,
  ) async {
    await pumpPhone(tester);
    expect(tester.takeException(), isNull);
  });
}
