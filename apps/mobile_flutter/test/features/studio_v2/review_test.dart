import 'package:design_forge/design_forge.dart';
import 'package:design_studio/design_studio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/studio_v2/commerce/garment_cart_request.dart';
import 'package:mobile_flutter/features/studio_v2/studio_v2_app.dart';
import 'package:mobile_flutter/features/studio_v2/studio_v2_screen.dart';
import 'package:mobile_flutter/features/studio_v2/studio_v2_stage.dart';

/// M8 — Review + Save + Add to Cart. Exercises the purchase-oriented final step
/// over the shared [StudioController]/GarmentDesign session: it replaces the
/// placeholder, switches Front/Back, summarises the real design, saves the whole
/// two-face garment, and hands a neutral [GarmentCartRequest] to the injected
/// cart callback — all while preserving M0–M7 state.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  List<Trip> tripsFixture() => [
        Trip(countryCode: 'us', startedOn: DateTime(2020, 6, 1), endedOn: DateTime(2020, 6, 8)),
        Trip(countryCode: 'fr', startedOn: DateTime(2021, 3, 1), endedOn: DateTime(2021, 3, 9)),
        Trip(countryCode: 'jp', startedOn: DateTime(2021, 8, 1), endedOn: DateTime(2021, 8, 5)),
      ];

  StudioController controller() => buildStudioV2ControllerFor(
      DesignContext.fromTrips(tripsFixture(), scopeKey: 'test:m8'));

  Future<StudioV2ScreenState> pumpAt(
    WidgetTester tester,
    StudioController c,
    StudioStage stage, {
    AddToCartCallback? onAddToCart,
  }) async {
    tester.view.physicalSize = const Size(1600, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey<StudioV2ScreenState>();
    await tester.pumpWidget(MaterialApp(
        home: StudioV2Screen(
            key: key, controller: c, onAddToCart: onAddToCart)));
    await tester.pump();
    await tester.tap(find.byKey(Key('v2-stage-${stage.name}')));
    await tester.pump();
    return key.currentState!;
  }

  testWidgets('Review replaces the placeholder and switches Front/Back',
      (tester) async {
    final c = controller();
    addTearDown(c.dispose);
    await pumpAt(tester, c, StudioStage.review);

    expect(find.text('Controls for this step arrive in a later milestone.'),
        findsNothing);
    expect(find.byKey(const Key('v2-review-save')), findsOneWidget);
    expect(find.byKey(const Key('v2-review-addtocart')), findsOneWidget);

    // Front/Back review switch drives the shared face state.
    expect(c.onFront, isFalse);
    await tester.tap(find.byKey(const Key('v2-review-side-front')));
    await tester.pump();
    expect(c.onFront, isTrue);
    await tester.tap(find.byKey(const Key('v2-review-side-back')));
    await tester.pump();
    expect(c.onFront, isFalse);
  });

  testWidgets('summary reflects the actual design (colour + direction)',
      (tester) async {
    final c = controller();
    addTearDown(c.dispose);
    c.setGarment('#F5F5F5'); // White
    await pumpAt(tester, c, StudioStage.review);

    // The garment colour + subject (Direction) appear in the spec chips.
    expect(find.text('White'), findsWidgets);
    expect(find.text(c.subjectLabel), findsWidgets);
  });

  testWidgets('Save design persists the whole two-face garment (idempotent)',
      (tester) async {
    final c = controller();
    addTearDown(c.dispose);
    await pumpAt(tester, c, StudioStage.review);

    final lib = c.library!;
    expect(lib.library.garments, isEmpty);
    await tester.tap(find.byKey(const Key('v2-review-save')));
    await tester.pump();
    expect(lib.library.garments.length, 1);
    // Re-saving does not create duplicates.
    await tester.tap(find.byKey(const Key('v2-review-save')));
    await tester.pump();
    expect(lib.library.garments.length, 1);
    expect(lib.library.garments.first.garment!.garmentId, c.garment.garmentId);
  });

  testWidgets('Add to cart hands a well-formed request to the host callback',
      (tester) async {
    final c = controller();
    addTearDown(c.dispose);
    c.setGarment('#1F2B33'); // Black
    // A chest front → placement maps to left_chest; the hero prints on the back.
    c.setFrontFit(FrontFit.chest);

    GarmentCartRequest? captured;
    await pumpAt(tester, c, StudioStage.review, onAddToCart: (ctx, req) async {
      captured = req;
    });

    await tester.tap(find.byKey(const Key('v2-review-addtocart')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(captured, isNotNull);
    expect(captured!.garmentColourName, 'Black');
    expect(captured!.frontPosition, 'left_chest');
    expect(captured!.backPosition, 'center'); // main artwork on the back
    expect(captured!.selectedCountryCodes, c.selectedCountryCodes.toList());
    expect(captured!.garment.back!.recipeId, c.hero.recipeId);
    expect(captured!.garment.front!.recipeId, c.frontFace.recipeId);
    expect(captured!.trips.length, 3);
    // M9: the real V2 front face is carried as a deferred render, so the true
    // front artwork (not the V1 ribbon) becomes the front print.
    expect(captured!.renderFrontArtwork, isNotNull);
  });

  testWidgets('Front None hands no front render → blank front print (M9)',
      (tester) async {
    final c = controller();
    addTearDown(c.dispose);
    c.setFrontFit(FrontFit.none);

    GarmentCartRequest? captured;
    await pumpAt(tester, c, StudioStage.review, onAddToCart: (ctx, req) async {
      captured = req;
    });
    await tester.tap(find.byKey(const Key('v2-review-addtocart')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(captured, isNotNull);
    expect(captured!.frontPosition, 'none');
    expect(captured!.renderFrontArtwork, isNull); // no front print
  });

  testWidgets('Add to cart with no host wired is a graceful no-op (snackbar)',
      (tester) async {
    final c = controller();
    addTearDown(c.dispose);
    await pumpAt(tester, c, StudioStage.review); // onAddToCart == null

    await tester.tap(find.byKey(const Key('v2-review-addtocart')));
    await tester.pump();
    expect(find.text('Cart is not available in this build'), findsOneWidget);
  });

  testWidgets('Back to edit preserves the whole design state (M0–M7)',
      (tester) async {
    final c = controller();
    addTearDown(c.dispose);

    // Establish earlier-stage state: a Detail shape + a front config + a lock.
    await pumpAt(tester, c, StudioStage.detail);
    await tester.tap(find.byKey(const Key('v2-detail-heart')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('v2-stage-front')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('v2-front-fit-chest')));
    await tester.pump();
    c.toggleLock(DesignAxis.vibe);
    final codes = c.selectedCountryCodes;
    final heroId = c.hero.recipeId;

    // Enter Review, then walk workflow Back — no design state is lost.
    await tester.tap(find.byKey(const Key('v2-stage-review')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('v2-workflow-back')));
    await tester.pump();

    expect(c.hero.recipeId, heroId);
    expect(c.hero.clip?.shapeId, ClipShape.heart.id);
    expect(c.frontFit, FrontFit.chest);
    expect(c.locked.contains(DesignAxis.vibe), isTrue);
    expect(c.selectedCountryCodes, codes);
  });
}
