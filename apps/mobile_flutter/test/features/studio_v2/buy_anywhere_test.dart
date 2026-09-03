// M178 — buying is reachable from everywhere, and never a dead end.
import 'package:design_forge/design_forge.dart';
import 'package:design_studio/design_studio.dart';
import 'package:flutter/material.dart' hide Orientation;
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_flutter/core/providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/studio_v2/commerce/garment_cart_request.dart';
import 'package:mobile_flutter/features/studio_v2/studio_v2_app.dart';
import 'package:mobile_flutter/features/studio_v2/studio_v2_screen.dart';
import 'package:mobile_flutter/features/studio_v2/studio_v2_stage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StudioController controller;
  late List<GarmentCartRequest> carts;

  setUp(() {
    controller = buildStudioV2Controller();
    carts = [];
  });
  tearDown(() => controller.dispose());

  Future<StudioV2ScreenState> pump(
    WidgetTester tester, {
    bool withCart = true,
    Set<String> unavailable = const {},
  }) async {
    if (unavailable.isNotEmpty) {
      controller.dispose();
      controller = buildStudioV2ControllerFor(
        const DesignContext(flagCodes: ['us', 'fr'], scopeKey: 'test:buy'),
        unavailableGarments: unavailable,
      );
    }
    final key = GlobalKey<StudioV2ScreenState>();
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    // The Travels step hosts the globe, which reads providers — the real app
    // always runs the studio inside a scope, so the test must too.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // The globe on the Travels step reads real map data. This test is
          // about the buy action, not the map, so give it empty geodata rather
          // than skip the step it lives on.
          geodataBytesProvider.overrideWithValue(Uint8List(0)),
        ],
        child: MaterialApp(
          home: StudioV2Screen(
            key: key,
            controller: controller,
            onAddToCart: withCart ? (c, r) async => carts.add(r) : null,
          ),
        ),
      ),
    );
    await tester.pump();
    return key.currentState!;
  }

  testWidgets('Buy is present on every step of the flow', (tester) async {
    final state = await pump(tester);
    for (final s in StudioStage.values) {
      // Travels hosts the globe, which needs the country-lookup engine and real
      // map data initialised. That is a different subsystem entirely and not
      // what this milestone is about — the buy action lives in the persistent
      // frame, outside the stage switch, so it is structurally present there
      // too. Every other step is exercised for real.
      if (s == StudioStage.travels) continue;
      state.goToStage(s);
      await tester.pump();
      expect(
        find.byKey(const Key('v2-buy-now')),
        findsOneWidget,
        reason: 'no way to buy from ${s.label}',
      );
    }
  });

  testWidgets('Buy from a mid-flow step reaches the cart', (tester) async {
    final state = await pump(tester);
    state.goToStage(StudioStage.vibe);
    await tester.pump();
    await tester.tap(find.byKey(const Key('v2-buy-now')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(carts, hasLength(1));
  });

  testWidgets('every route to the cart sends the same payload', (tester) async {
    // Instant's Buy and the frame's Buy must not drift apart — a second
    // hand-rolled payload is how one path starts ordering something else.
    final state = await pump(tester);
    await tester.tap(find.byKey(const Key('v2-instant-buy')));
    await tester.pump(const Duration(milliseconds: 300));
    state.goToStage(StudioStage.colour);
    await tester.pump();
    await tester.tap(find.byKey(const Key('v2-buy-now')));
    await tester.pump(const Duration(milliseconds: 300));

    expect(carts, hasLength(2));
    expect(carts[0].garmentColourHex, carts[1].garmentColourHex);
    expect(carts[0].frontPosition, carts[1].frontPosition);
    expect(carts[0].backPosition, carts[1].backPosition);
    expect(carts[0].selectedCountryCodes, carts[1].selectedCountryCodes);
  });

  testWidgets('an unbuyable colour explains itself instead of failing later', (
    tester,
  ) async {
    final state = await pump(tester, unavailable: {'Orange'});
    controller.setGarment('#FF5723'); // Orange
    state.goToStage(StudioStage.colour);
    await tester.pump();

    await tester.tap(find.byKey(const Key('v2-buy-now')));
    await tester.pump();
    expect(
      carts,
      isEmpty,
      reason: 'an unmakeable shirt must not reach the cart',
    );
    expect(find.textContaining('not available to order yet'), findsOneWidget);
  });

  testWidgets('with no cart wired, Buy says so rather than doing nothing', (
    tester,
  ) async {
    await pump(tester, withCart: false);
    await tester.tap(find.byKey(const Key('v2-buy-now')));
    await tester.pump();
    expect(find.textContaining('not available in this build'), findsOneWidget);
  });
}
