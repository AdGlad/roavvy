import 'package:design_forge/design_forge.dart';
import 'package:design_studio/design_studio.dart';
import 'package:flutter/material.dart' hide Orientation;
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/studio_v2/studio_v2_app.dart';
import 'package:mobile_flutter/features/studio_v2/studio_v2_screen.dart';
import 'package:mobile_flutter/features/studio_v2/studio_v2_stage.dart';

/// M1 — the V2 shell. Verifies the permanent hierarchy + guarantees: the shirt
/// stays visible across stages, Tier-1 controls drive the live design, workflow
/// navigation never mutates the recipe, and workflow-Back is independent of the
/// shared recipe undo/redo.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StudioController controller;

  setUp(() {
    controller = buildStudioV2Controller();
  });

  tearDown(() => controller.dispose());

  Future<StudioV2ScreenState> pump(
      WidgetTester tester, GlobalKey<StudioV2ScreenState> key) async {
    // Wide viewport so the horizontal Tier-1 bar + stage strip are all on-screen
    // (so taps land without per-control scrolling).
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: StudioV2Screen(key: key, controller: controller),
    ));
    await tester.pump(); // don't settle — the preview spinner never settles
    return key.currentState!;
  }

  testWidgets('renders a real design + the shirt stays visible across stages',
      (tester) async {
    final key = GlobalKey<StudioV2ScreenState>();
    final state = await pump(tester, key);

    // A real DesignRecipe exists and the preview hero is present.
    expect(controller.current, isNotNull);
    expect(find.byKey(const Key('v2-garment-preview')), findsOneWidget);

    // Switching through every stage never removes the live shirt.
    for (final s in StudioStage.values) {
      await tester.tap(find.byKey(Key('v2-stage-${s.name}')));
      await tester.pump();
      expect(state.stage, s);
      expect(find.byKey(const Key('v2-garment-preview')), findsOneWidget);
    }
  });

  testWidgets('Tier-1 controls drive the live design', (tester) async {
    final key = GlobalKey<StudioV2ScreenState>();
    await pump(tester, key);

    // Garment colour.
    await tester.tap(find.byKey(const Key('v2-garment-Olive')));
    await tester.pump();
    expect(controller.current.palette?.garmentColour, '#6B7350');

    // Orientation.
    await tester.tap(find.byKey(const Key('v2-aspect-landscape')));
    await tester.pump();
    expect(controller.current.composition.orientation, Orientation.landscape);

    // Artwork size S/M/L (never XS–XXL).
    await tester.tap(find.byKey(const Key('v2-size-large')));
    await tester.pump();
    expect(controller.current.composition.sizeClass, SizeClass.large);
  });

  testWidgets('Front/Back switches the visible face without losing state',
      (tester) async {
    final key = GlobalKey<StudioV2ScreenState>();
    await pump(tester, key);
    final backId = controller.current.recipeId;

    await tester.tap(find.byKey(const Key('v2-side-front')));
    await tester.pump();
    expect(controller.onFront, isTrue);
    expect(controller.current.recipeId, isNot(backId));

    await tester.tap(find.byKey(const Key('v2-side-back')));
    await tester.pump();
    expect(controller.onFront, isFalse);
    expect(controller.current.recipeId, backId); // back state preserved
  });

  testWidgets('workflow navigation does not mutate the recipe', (tester) async {
    final key = GlobalKey<StudioV2ScreenState>();
    final state = await pump(tester, key);
    final id0 = controller.current.recipeId;

    await tester.tap(find.byKey(const Key('v2-next')));
    await tester.pump();
    expect(state.stage, StudioStage.travels);
    expect(controller.current.recipeId, id0); // stage change ≠ recipe change
  });

  testWidgets('workflow Back is independent of recipe Undo', (tester) async {
    final key = GlobalKey<StudioV2ScreenState>();
    final state = await pump(tester, key);
    final r0 = controller.current.recipeId;

    // Navigate forward (workflow history grows; recipe untouched).
    await tester.tap(find.byKey(const Key('v2-stage-vibe')));
    await tester.pump();
    expect(state.stage, StudioStage.vibe);
    expect(controller.current.recipeId, r0);

    // A committed recipe change (via the shared controller) grows recipe undo.
    controller.onChipTap(DesignAxis.focus);
    await tester.pump();
    final r1 = controller.current.recipeId;
    expect(r1, isNot(r0));
    expect(controller.history.length, 1);

    // Workflow Back pops the STAGE only — the recipe is not reverted.
    await tester.tap(find.byKey(const Key('v2-workflow-back')));
    await tester.pump();
    expect(state.stage, StudioStage.instant);
    expect(controller.current.recipeId, r1);
    expect(controller.history.length, 1);

    // Recipe Undo reverts the DESIGN only — the stage is unaffected.
    await tester.tap(find.byKey(const Key('v2-recipe-undo')));
    await tester.pump();
    expect(controller.current.recipeId, r0);
    expect(state.stage, StudioStage.instant);
  });
}
