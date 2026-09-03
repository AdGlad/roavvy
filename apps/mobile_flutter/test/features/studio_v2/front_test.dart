import 'package:design_forge/design_forge.dart';
import 'package:design_studio/design_studio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/studio_v2/studio_v2_app.dart';
import 'package:mobile_flutter/features/studio_v2/studio_v2_screen.dart';
import 'package:mobile_flutter/features/studio_v2/studio_v2_stage.dart';

/// M6 — Front Design. Exercises the Front workspace over the shared
/// [StudioController]: placement (Full/Chest/None), chest side, front artwork
/// (Ribbon/Complement/Match back) and ribbon coverage. The back stays the hero;
/// front edits never reroll or mutate it, and the two real faces are switched by
/// the persistent Front/Back control — not by workflow navigation.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  List<Trip> tripsFixture() => [
    Trip(
      countryCode: 'us',
      startedOn: DateTime(2020, 6, 1),
      endedOn: DateTime(2020, 6, 8),
    ),
    Trip(
      countryCode: 'fr',
      startedOn: DateTime(2021, 3, 1),
      endedOn: DateTime(2021, 3, 9),
    ),
    Trip(
      countryCode: 'jp',
      startedOn: DateTime(2021, 8, 1),
      endedOn: DateTime(2021, 8, 5),
    ),
  ];

  StudioController controller() => buildStudioV2ControllerFor(
    DesignContext.fromTrips(tripsFixture(), scopeKey: 'test:m6'),
  );

  Future<StudioV2ScreenState> pumpAt(
    WidgetTester tester,
    StudioController c,
    StudioStage stage,
  ) async {
    tester.view.physicalSize = const Size(1600, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey<StudioV2ScreenState>();
    await tester.pumpWidget(
      MaterialApp(home: StudioV2Screen(key: key, controller: c)),
    );
    await tester.pump();
    await tester.tap(find.byKey(Key('v2-stage-${stage.name}')));
    await tester.pump();
    return key.currentState!;
  }

  testWidgets('Front placement: Full / Chest (Left·Right) / None, using real '
      'print geometry — and the back is never rerolled', (tester) async {
    final c = controller();
    addTearDown(c.dispose);
    await pumpAt(tester, c, StudioStage.front);

    expect(find.byKey(const Key('v2-front-mockup')), findsOneWidget);

    // Capture the hero (back) — no Front edit may touch it.
    final backId = c.hero.recipeId;

    await tester.tap(find.byKey(const Key('v2-front-fit-full')));
    await tester.pump();
    expect(c.frontFit, FrontFit.full);
    expect(c.frontPrintRect().isEmpty, isFalse);

    await tester.tap(find.byKey(const Key('v2-front-fit-none')));
    await tester.pump();
    expect(c.frontFit, FrontFit.none);
    expect(c.frontPrintRect(), Rect.zero); // blank front
    // Artwork options vanish when nothing prints.
    expect(find.byKey(const Key('v2-front-art-ribbon')), findsNothing);

    await tester.tap(find.byKey(const Key('v2-front-fit-chest')));
    await tester.pump();
    expect(c.frontFit, FrontFit.chest);

    // Chest exposes Left / Right, and left/right map to distinct geometry.
    await tester.tap(find.byKey(const Key('v2-front-chest-left')));
    await tester.pump();
    expect(c.chestRight, isFalse);
    final leftRect = c.frontPrintRect();
    await tester.tap(find.byKey(const Key('v2-front-chest-right')));
    await tester.pump();
    expect(c.chestRight, isTrue);
    expect(c.frontPrintRect(), isNot(leftRect));

    // The hero (back) recipe is byte-identical throughout.
    expect(c.hero.recipeId, backId);
  });

  testWidgets('Front artwork: Ribbon (Selected/All), Complement, Match back — '
      'derived from the back without mutating it', (tester) async {
    final c = controller();
    addTearDown(c.dispose);
    await pumpAt(tester, c, StudioStage.front);
    final backId = c.hero.recipeId;

    await tester.tap(find.byKey(const Key('v2-front-art-ribbon')));
    await tester.pump();
    expect(c.frontArt, FrontArt.ribbon);

    // Ribbon coverage: Selected travels vs All travelled.
    await tester.tap(find.byKey(const Key('v2-front-ribbon-all')));
    await tester.pump();
    expect(c.ribbonAllCountries, isTrue);
    await tester.tap(find.byKey(const Key('v2-front-ribbon-selected')));
    await tester.pump();
    expect(c.ribbonAllCountries, isFalse);

    await tester.tap(find.byKey(const Key('v2-front-art-complement')));
    await tester.pump();
    expect(c.frontArt, FrontArt.complement);
    // Coverage control only shows for Ribbon.
    expect(find.byKey(const Key('v2-front-ribbon-all')), findsNothing);

    await tester.tap(find.byKey(const Key('v2-front-art-matchback')));
    await tester.pump();
    expect(c.frontArt, FrontArt.matchBack);
    expect(c.frontFace.recipeId, c.hero.recipeId); // match back = same design

    // Every artwork change left the back untouched.
    expect(c.hero.recipeId, backId);
  });

  testWidgets('Front/Back toggle switches the real faces; front + back state '
      'both survive switching', (tester) async {
    final c = controller();
    addTearDown(c.dispose);
    await pumpAt(tester, c, StudioStage.front);

    // Configure a front (chest-right, complement) while on the back face.
    await tester.tap(find.byKey(const Key('v2-front-fit-chest')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('v2-front-chest-right')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('v2-front-art-complement')));
    await tester.pump();
    final backId = c.hero.recipeId;
    final frontId = c.frontFace.recipeId;

    // Persistent Front/Back control switches the visible face (no nav event).
    expect(c.onFront, isFalse);
    await tester.tap(find.byKey(const Key('v2-side-front')));
    await tester.pump();
    expect(c.onFront, isTrue);
    expect(c.current.recipeId, frontId); // shows the front face
    await tester.tap(find.byKey(const Key('v2-side-back')));
    await tester.pump();
    expect(c.onFront, isFalse);
    expect(c.current.recipeId, backId); // shows the back face

    // Both faces and the front configuration are preserved across the switch.
    expect(c.hero.recipeId, backId);
    expect(c.frontFace.recipeId, frontId);
    expect(c.frontFit, FrontFit.chest);
    expect(c.chestRight, isTrue);
    expect(c.frontArt, FrontArt.complement);
  });

  testWidgets('Garment colour affects BOTH faces without rerolling either; '
      'front config is live (no recipe-history churn)', (tester) async {
    final c = controller();
    addTearDown(c.dispose);
    await pumpAt(tester, c, StudioStage.front);

    // A real front design so both faces carry a palette.
    await tester.tap(find.byKey(const Key('v2-front-art-ribbon')));
    await tester.pump();

    final backLayout = c.hero.composition.orientation;
    final frontLayout = c.frontFace.composition.orientation;
    final histLen = c.history.length;

    await tester.tap(find.byKey(const Key('v2-garment-Navy')));
    await tester.pump();

    final g = c.hero.palette?.garmentColour;
    expect(g, isNotNull);
    expect(c.frontFace.palette?.garmentColour, g); // both faces share it
    // Neither face's layout was rerolled…
    expect(c.hero.composition.orientation, backLayout);
    expect(c.frontFace.composition.orientation, frontLayout);
    // …and front config never pushes recipe history.
    expect(c.history.length, histLen);
    expect(c.frontFit, isNotNull);
  });

  testWidgets('M0–M5 state (travel / detail / colour) survives Front edits', (
    tester,
  ) async {
    final c = controller();
    addTearDown(c.dispose);
    await pumpAt(tester, c, StudioStage.detail);

    await tester.tap(find.byKey(const Key('v2-detail-heart')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('v2-stage-colour')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('v2-colour-monochrome')));
    await tester.pump();

    await tester.tap(find.byKey(const Key('v2-stage-front')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('v2-front-fit-full')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('v2-front-art-complement')));
    await tester.pump();

    // The hero back keeps its Detail shape, Colour treatment and travels.
    expect(c.hero.clip?.shapeId, ClipShape.heart.id);
    expect(c.hero.palette?.strategy, ColourStrategy.monochrome);
    expect(c.selectedCountryCodes, {'us', 'fr', 'jp'});
  });
}
