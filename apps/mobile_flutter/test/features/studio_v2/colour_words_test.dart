import 'package:design_forge/design_forge.dart';
import 'package:design_studio/design_studio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/studio_v2/studio_v2_app.dart';
import 'package:mobile_flutter/features/studio_v2/studio_v2_screen.dart';
import 'package:mobile_flutter/features/studio_v2/studio_v2_stage.dart';

/// M5 — Colour + Words. Exercises the two new lower-workspace stages over the
/// shared [StudioController]: the artwork COLOUR treatments (distinct from the
/// persistent shirt colour) and the WORDS title editor. The live shirt stays the
/// hero; every earlier axis (travel / Direction / Detail / Vibe / Focus) and the
/// Tier-1 controls persist across a Colour or Words change.
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
    DesignContext.fromTrips(tripsFixture(), scopeKey: 'test:m5'),
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

  testWidgets('Colour: treatments update the artwork ink live, preserve Detail/'
      'Tier-1, and the shirt colour stays independent', (tester) async {
    final c = controller();
    addTearDown(c.dispose);
    await pumpAt(tester, c, StudioStage.detail);

    // Pin a Detail (heart) + a garment; both must survive a treatment change.
    await tester.tap(find.byKey(const Key('v2-detail-heart')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('v2-garment-Olive')));
    await tester.pump();

    await tester.tap(find.byKey(const Key('v2-stage-colour')));
    await tester.pump();
    expect(find.byKey(const Key('v2-garment-preview')), findsOneWidget);

    // All five treatments are reachable.
    for (final slug in const [
      'flagcolours',
      'monochrome',
      'duotone',
      'matchshirt',
      'vintage',
    ]) {
      expect(
        find.byKey(Key('v2-colour-$slug')),
        findsOneWidget,
        reason: 'missing colour treatment $slug',
      );
    }

    final id0 = c.current.recipeId;
    await tester.tap(find.byKey(const Key('v2-colour-monochrome')));
    await tester.pump();
    expect(c.colourStrategy, ColourStrategy.monochrome); // treatment applied
    expect(c.current.recipeId, isNot(id0)); // live shirt updated
    expect(c.current.clip?.shapeId, ClipShape.heart.id); // Detail preserved
    expect(c.current.palette?.garmentColour, '#6B7350'); // garment preserved
    expect(c.selectedCountryCodes, {'us', 'fr', 'jp'}); // travel preserved

    // Shirt colour is a SEPARATE, persistent control: switching it keeps the
    // treatment's layout and does not roll a recipe-history step.
    final layout0 = c.current.composition.orientation;
    final histLen = c.history.length;
    await tester.tap(find.byKey(const Key('v2-garment-Navy')));
    await tester.pump();
    expect(c.current.palette?.garmentColour, '#22303A');
    expect(c.current.composition.orientation, layout0); // no layout reroll
    expect(c.history.length, histLen);

    // Colour change participates in recipe Undo.
    await tester.tap(find.byKey(const Key('v2-recipe-undo')));
    await tester.pump();
    expect(c.current.recipeId, id0);
  });

  testWidgets('Colour alternatives tray is deterministic and offers More', (
    tester,
  ) async {
    final c = controller();
    addTearDown(c.dispose);
    await pumpAt(tester, c, StudioStage.colour);
    await tester.pump(); // let the post-frame focusAxis populate the tray
    await tester.pump();

    expect(c.activeAxis, DesignAxis.colour);
    expect(c.alternatives, isNotEmpty);
    expect(find.byKey(const Key('v2-alt-0')), findsOneWidget);

    // "More" advances the deterministic seed stream → a fresh set.
    final firstSet = c.alternatives.map((r) => r.recipeId).toList();
    await tester.tap(find.byKey(const Key('v2-alt-more')));
    await tester.pump();
    expect(c.alternatives.map((r) => r.recipeId).toList(), isNot(firstSet));
  });

  testWidgets('Words: manual title edit, suggestions, and removal — undoable', (
    tester,
  ) async {
    final c = controller();
    addTearDown(c.dispose);
    await pumpAt(tester, c, StudioStage.words);
    await tester.pump(); // post-frame focusWords seeds suggestions
    await tester.pump();

    // Manual edit via the field commits (undoable).
    final id0 = c.current.recipeId;
    await tester.enterText(
      find.byKey(const Key('v2-title-field')),
      'Osaka Nights',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(c.currentTitle, 'Osaka Nights');
    expect(c.current.recipeId, isNot(id0));

    // Remove clears the title.
    await tester.tap(find.byKey(const Key('v2-title-remove')));
    await tester.pump();
    expect(c.currentTitle, isEmpty);

    // Undo brings the manual title back (recipe undo/redo).
    await tester.tap(find.byKey(const Key('v2-recipe-undo')));
    await tester.pump();
    expect(c.currentTitle, 'Osaka Nights');

    // Local suggestions work with no network; tapping one applies immediately.
    await tester.tap(find.byKey(const Key('v2-title-suggest')));
    await tester.pump();
    if (c.titleIdeas.isNotEmpty) {
      await tester.tap(find.byKey(const Key('v2-title-idea-0')));
      await tester.pump();
      expect(c.currentTitle, isNotEmpty);
    }
  });

  testWidgets('locks + Remix: locking Colour holds the palette while Remix '
      'rerolls the rest', (tester) async {
    final c = controller();
    addTearDown(c.dispose);
    await pumpAt(tester, c, StudioStage.colour);
    await tester.pump();

    await tester.tap(find.byKey(const Key('v2-colour-monochrome')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('v2-lock-colour')));
    await tester.pump();
    expect(c.locked, contains(DesignAxis.colour));

    final id0 = c.current.recipeId;
    await tester.tap(find.byKey(const Key('v2-remix')));
    await tester.pump();
    expect(c.current.recipeId, isNot(id0)); // unlocked axes evolved
    expect(c.colourStrategy, ColourStrategy.monochrome); // locked Colour held
  });
}
