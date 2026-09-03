// Instant, on screen: swipe the deck, switch the shirt colour, and the three
// ways out — buy, configure, custom.
import 'dart:ui' as ui;

import 'package:design_forge/design_forge.dart';
import 'package:design_forge_render/design_forge_render.dart';
import 'package:design_studio/design_studio.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart' hide Orientation;
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/studio_v2/commerce/garment_cart_request.dart';
import 'package:mobile_flutter/features/studio_v2/widgets/instant_workspace.dart';
import 'package:mobile_flutter/features/studio_v2/widgets/shirt_preview.dart';

class _NoopResolver implements AssetResolver {
  @override
  Future<ui.Image> resolveFlag(
    String code, {
    required int width,
    required int height,
  }) => throw UnimplementedError();
  @override
  Future<ui.Image?> resolveClipMask(
    ClipShape shape,
    String? code, {
    required int width,
    required int height,
  }) async => null;
  @override
  Future<ui.Image?> resolvePassportCollage(
    List<PassportStampRef> stamps, {
    required int width,
    required int height,
    int seed = 0,
    double scatter = 0.5,
    double stampScale = 1.0,
    PassportInk ink = PassportInk.flag,
  }) async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StudioController controller;

  setUp(() {
    controller = StudioController(
      generator: LabShowcaseGenerator(
        silhouettesByShape: const {},
        countryNames: const {},
      ),
      service: RenderService(_NoopResolver()),
      designContext: const DesignContext(
        flagCodes: ['us', 'fr', 'jp', 'br'],
        scopeKey: 'test:instant',
      ),
      initialSeed: 4,
    );
  });

  tearDown(() => controller.dispose());

  Future<({int configure, int custom, List<GarmentCartRequest> carts})> pump(
    WidgetTester tester, {
    bool withCart = true,
  }) async {
    var configure = 0, custom = 0;
    final carts = <GarmentCartRequest>[];
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InstantWorkspace(
            controller: controller,
            onConfigure: () => configure++,
            onCustom: () => custom++,
            onAddToCart:
                withCart ? (context, req) async => carts.add(req) : null,
          ),
        ),
      ),
    );
    await tester.pump();
    return (configure: configure, custom: custom, carts: carts);
  }

  testWidgets('opens on a ready design with all three ways out', (
    tester,
  ) async {
    await pump(tester);
    expect(find.byKey(const Key('v2-instant-deck')), findsOneWidget);
    expect(find.byKey(const Key('v2-instant-buy')), findsOneWidget);
    expect(find.byKey(const Key('v2-instant-configure')), findsOneWidget);
    expect(find.byKey(const Key('v2-instant-custom')), findsOneWidget);
  });

  testWidgets('swiping the deck changes the design on the shirt', (
    tester,
  ) async {
    await pump(tester);
    expect(controller.instantIndex, 0);
    final before = controller.hero.recipeId;

    // Right-to-left: forward through the deck.
    await tester.fling(
      find.byKey(const Key('v2-instant-deck')),
      const Offset(-300, 0),
      1200,
    );
    await tester.pumpAndSettle();
    expect(controller.instantIndex, 1);
    expect(controller.hero.recipeId, isNot(before));

    // Left-to-right: back again.
    await tester.fling(
      find.byKey(const Key('v2-instant-deck')),
      const Offset(300, 0),
      1200,
    );
    await tester.pumpAndSettle();
    expect(controller.instantIndex, 0);
  });

  testWidgets('the shirt colour can be switched from the page', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('v2-instant-garment-Red')));
    await tester.pumpAndSettle();
    expect(controller.current.palette?.garmentColour, '#FF1B2B');
  });

  testWidgets('Buy hands the design straight to the cart', (tester) async {
    final r = await pump(tester);
    await tester.tap(find.byKey(const Key('v2-instant-buy')));
    await tester.pumpAndSettle();
    expect(r.carts, hasLength(1));
    // The same payload the careful path sends — both faces and the garment.
    final req = r.carts.single;
    expect(req.garmentColourHex, controller.hero.palette?.garmentColour);
    expect(req.renderBackArtwork, isNotNull);
  });

  testWidgets('Buy without a cart wired explains itself', (tester) async {
    final r = await pump(tester, withCart: false);
    await tester.tap(find.byKey(const Key('v2-instant-buy')));
    await tester.pump();
    expect(r.carts, isEmpty);
    expect(find.textContaining('not available'), findsOneWidget);
  });

  testWidgets('Configure keeps the design and hands off', (tester) async {
    await pump(tester);
    await tester.fling(
      find.byKey(const Key('v2-instant-deck')),
      const Offset(-300, 0),
      1200,
    );
    await tester.pumpAndSettle();
    final chosen = controller.hero.recipeId;

    await tester.tap(find.byKey(const Key('v2-instant-configure')));
    await tester.pumpAndSettle();
    expect(
      controller.hero.recipeId,
      chosen,
      reason: 'Configure edits this design; it must not roll a new one',
    );
  });

  testWidgets('the deck fits a narrow phone panel without overflowing', (
    tester,
  ) async {
    // The reported failure: a 310-wide panel gave the deck card 40px of height
    // and its stacked text needed 47, painting a striped overflow bar across
    // the first thing anyone sees.
    tester.view.physicalSize = const Size(310, 620);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InstantWorkspace(
            controller: controller,
            onConfigure: () {},
            onCustom: () {},
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('the arrows step the deck for anyone who cannot swipe', (
    tester,
  ) async {
    // A mouse cannot swipe comfortably even once the drag is accepted.
    await pump(tester);
    expect(controller.instantIndex, 0);

    await tester.tap(find.byKey(const Key('v2-instant-next')));
    await tester.pumpAndSettle();
    expect(controller.instantIndex, 1);

    await tester.tap(find.byKey(const Key('v2-instant-prev')));
    await tester.pumpAndSettle();
    expect(controller.instantIndex, 0);

    // …and back past the first, which wraps to the end.
    await tester.tap(find.byKey(const Key('v2-instant-prev')));
    await tester.pumpAndSettle();
    expect(controller.instantIndex, controller.instantPicks.length - 1);
  });

  testWidgets('the deck swipes with a finger, at phone size', (tester) async {
    // The touch path is the one that matters on a real phone, and it is a
    // different pointer kind from the mouse — proving one says nothing about
    // the other. Run it at phone dimensions, not the wide test viewport.
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InstantWorkspace(
            controller: controller,
            onConfigure: () {},
            onCustom: () {},
          ),
        ),
      ),
    );
    await tester.pump();
    expect(controller.instantIndex, 0);

    final deck = find.byKey(const Key('v2-instant-deck'));
    final touch = await tester.startGesture(
      tester.getCenter(deck),
      kind: PointerDeviceKind.touch,
    );
    for (var i = 0; i < 6; i++) {
      await touch.moveBy(const Offset(-45, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await touch.up();
    await tester.pumpAndSettle();
    expect(controller.instantIndex, 1, reason: 'a finger swipe must page');

    // …and back the other way.
    final back = await tester.startGesture(
      tester.getCenter(deck),
      kind: PointerDeviceKind.touch,
    );
    for (var i = 0; i < 6; i++) {
      await back.moveBy(const Offset(45, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await back.up();
    await tester.pumpAndSettle();
    expect(controller.instantIndex, 0);
  });

  testWidgets('the deck accepts a mouse drag, not just touch', (tester) async {
    // Flutter's desktop scroll behaviour omits the mouse, which left the deck
    // completely unswipeable on macOS.
    await pump(tester);
    final centre = tester.getCenter(find.byKey(const Key('v2-instant-deck')));
    final mouse = await tester.startGesture(
      centre,
      kind: PointerDeviceKind.mouse,
    );
    // Past the halfway point, so the page commits rather than springing back.
    for (var i = 0; i < 7; i++) {
      await mouse.moveBy(const Offset(-110, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await mouse.up();
    await tester.pumpAndSettle();
    expect(controller.instantIndex, 1);
  });

  testWidgets('the deck shows shirts, not just names', (tester) async {
    // The promise of the screen is swiping through ready-made shirts.
    await pump(tester);
    expect(find.byType(ShirtPreview), findsWidgets);
  });

  testWidgets('only the visible page renders a shirt, not all eight', (
    tester,
  ) async {
    // Eight garment renders on open would put the studio behind a spinner. The
    // PageView must stay lazy.
    await pump(tester);
    final shown =
        tester.widgetList<ShirtPreview>(find.byType(ShirtPreview)).length;
    expect(
      shown,
      lessThan(controller.instantPicks.length),
      reason: 'the deck should build around the current page, not all of it',
    );
  });

  testWidgets('Custom leaves the pick alone and hands off', (tester) async {
    await pump(tester);
    final before = controller.hero.recipeId;
    await tester.tap(find.byKey(const Key('v2-instant-custom')));
    await tester.pumpAndSettle();
    // The workspace itself changes nothing — the host navigates to Direction,
    // which is where a new design gets made.
    expect(controller.hero.recipeId, before);
  });
}
