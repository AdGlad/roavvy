import 'dart:convert';

import 'package:design_forge/design_forge.dart';
import 'package:design_lab/flag_source.dart';
import 'package:design_lab/lab_generator.dart';
import 'package:design_lab/render_service.dart';
import 'package:design_lab/studio_canvas_screen.dart';
import 'package:flutter/material.dart' hide Orientation;
import 'package:flutter_test/flutter_test.dart';

/// Canonical view of the DIRECTION axis (the clip) for byte-identity checks.
String _clip(DesignRecipe r) => jsonEncode(r.clip?.toJson());

void main() {
  // The Lab reads flag SVGs straight from the repo checkout; locate() walks up
  // from cwd (apps/design_lab) to the repo root.
  final source = FlagSource.locate();

  // Build the same generator + render service main.dart wires up, plus a
  // sensible default single-country context so the hero is a reliable flag.
  late LabShowcaseGenerator generator;
  late RenderService service;
  const context = DesignContext(flagCodes: ['us'], scopeKey: 'lab:us');

  setUp(() {
    generator = LabShowcaseGenerator(
      silhouettesByShape: {
        for (final s in ClipShape.values) s: const <String>[],
      },
      countryNames: source?.countryNames() ?? const {},
    );
    service = RenderService(source!.resolver());
  });

  Future<StudioCanvasScreenState> pumpScreen(
    WidgetTester tester,
    GlobalKey<StudioCanvasScreenState> key,
  ) async {
    await tester.pumpWidget(MaterialApp(
      home: StudioCanvasScreen(
        key: key,
        generator: generator,
        service: service,
        designContext: context,
        initialSeed: 7,
      ),
    ));
    // A couple of pumps to let the async hero image resolve (don't settle — the
    // spinner animation never settles).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    return key.currentState!;
  }

  testWidgets('(a) screen builds and shows a hero', (tester) async {
    final key = GlobalKey<StudioCanvasScreenState>();
    final state = await pumpScreen(tester, key);

    expect(find.byType(StudioCanvasScreen), findsOneWidget);
    expect(find.byKey(const Key('studio-hero')), findsOneWidget);
    expect(state.currentRecipe, isNotNull);
    // All five decision-deck chips are present.
    for (final axis in DesignAxis.values) {
      expect(find.byKey(Key('studio-chip-${axis.key}')), findsOneWidget);
    }
  });

  testWidgets('(b) tapping a decision chip changes the current recipeId',
      (tester) async {
    final key = GlobalKey<StudioCanvasScreenState>();
    final state = await pumpScreen(tester, key);

    final before = state.currentRecipe.recipeId;
    await tester.tap(find.byKey(Key('studio-chip-${DesignAxis.vibe.key}')));
    await tester.pump();

    expect(state.currentRecipe.recipeId, isNot(before));
    // The touched axis drives the alternatives tray.
    expect(state.activeAxis, DesignAxis.vibe);
    expect(state.alternatives, isNotEmpty);
  });

  testWidgets('(c) locking an axis then Surprise-me leaves that axis unchanged',
      (tester) async {
    final key = GlobalKey<StudioCanvasScreenState>();
    final state = await pumpScreen(tester, key);

    final clipBefore = _clip(state.currentRecipe);

    // Lock DIRECTION (owns the clip) via its lock badge (the deletable icon on
    // the chip). Long-press works in-app too, but the badge is deterministic to
    // target in a widget test.
    await tester.tap(find.descendant(
      of: find.byKey(Key('studio-chip-${DesignAxis.direction.key}')),
      matching: find.byIcon(Icons.lock_open),
    ));
    await tester.pump();
    expect(state.lockedAxes, contains(DesignAxis.direction));

    // Surprise me re-rolls everything else.
    await tester.tap(find.byKey(const Key('studio-surprise')));
    await tester.pump();

    // The locked axis's field is byte-identical…
    expect(_clip(state.currentRecipe), clipBefore);
    // …while the overall design moved on.
    expect(state.historyLength, greaterThan(0));
  });

  testWidgets('(d) undo restores the previous recipeId', (tester) async {
    final key = GlobalKey<StudioCanvasScreenState>();
    final state = await pumpScreen(tester, key);

    final original = state.currentRecipe.recipeId;
    await tester.tap(find.byKey(Key('studio-chip-${DesignAxis.direction.key}')));
    await tester.pump();
    final afterReroll = state.currentRecipe.recipeId;
    expect(afterReroll, isNot(original));

    await tester.tap(find.byKey(const Key('studio-undo')));
    await tester.pump();

    expect(state.currentRecipe.recipeId, original);
    expect(state.historyLength, 0);
  });

  testWidgets('(e) Direction switches subject, not just re-rolls flags',
      (tester) async {
    final key = GlobalKey<StudioCanvasScreenState>();
    final state = await pumpScreen(tester, key);

    // Cycle the Direction chip through the whole subject set.
    final families = <DesignFamily>{state.currentRecipe.composition.family};
    for (var i = 0; i < 6; i++) {
      await tester
          .tap(find.byKey(Key('studio-chip-${DesignAxis.direction.key}')));
      await tester.pump();
      families.add(state.currentRecipe.composition.family);
    }
    // Route→journeys and World→wordCloud are distinct data families, so the
    // subject genuinely changes (a plain flag re-roll would never reach them).
    expect(families.length, greaterThan(1),
        reason: 'Direction must reach different subjects');
    expect(
        families.any((f) =>
            f == DesignFamily.journeys || f == DesignFamily.wordCloud),
        isTrue,
        reason: 'Route/World subjects must be reachable via Direction');
    // The Direction tray previews one hero per subject.
    expect(state.activeAxis, DesignAxis.direction);
    expect(state.alternatives.length, greaterThan(1));
  });

  testWidgets('(f) Detail sub-step swaps the clip on the Flags subject',
      (tester) async {
    final key = GlobalKey<StudioCanvasScreenState>();
    final state = await pumpScreen(tester, key);

    // Flags is the opening subject → the Detail sub-row is present.
    expect(find.byKey(const Key('studio-detail-heart')), findsOneWidget);

    await tester.tap(find.byKey(const Key('studio-detail-heart')));
    await tester.pump();
    expect(state.currentRecipe.clip?.shapeId, ClipShape.heart.id);

    // Grid clears the clip back to a plain flag ('none').
    await tester.tap(find.byKey(const Key('studio-detail-grid')));
    await tester.pump();
    expect(state.currentRecipe.clip?.shapeId, ClipShape.none.id);
  });

  testWidgets('(g) Adjust panel live-edits the recipe (fill algorithm)',
      (tester) async {
    final key = GlobalKey<StudioCanvasScreenState>();
    final state = await pumpScreen(tester, key);

    // Hidden until toggled.
    expect(find.byKey(const Key('studio-adjust-fill')), findsNothing);
    await tester.tap(find.byKey(const Key('studio-adjust-toggle')));
    await tester.pump();
    expect(find.byKey(const Key('studio-adjust-fill')), findsOneWidget);

    // Change the grid fill algorithm and confirm it lands on the recipe.
    await tester.tap(find.byKey(const Key('studio-adjust-fill')));
    await tester.pump();
    await tester.tap(find.text(FillAlgorithm.treemap.name).last);
    await tester.pump();
    expect(state.currentRecipe.composition.fillAlgorithm, FillAlgorithm.treemap);
  });

  testWidgets('(h) Tier-1 controls edit and survive a Vibe re-roll',
      (tester) async {
    final key = GlobalKey<StudioCanvasScreenState>();
    final state = await pumpScreen(tester, key);

    await tester.tap(find.byKey(const Key('studio-aspect-square')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('studio-size-large')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('studio-garment-White')));
    await tester.pump();
    expect(state.currentRecipe.composition.orientation, Orientation.square);
    expect(state.currentRecipe.composition.sizeClass, SizeClass.large);
    expect(state.currentRecipe.palette?.garmentColour, '#F5F5F5');

    // A Style change (Vibe re-roll) must NOT reset the fixed Tier-1 controls.
    await tester.tap(find.byKey(Key('studio-chip-${DesignAxis.vibe.key}')));
    await tester.pump();
    expect(state.currentRecipe.composition.orientation, Orientation.square,
        reason: 'aspect must survive a style change');
    expect(state.currentRecipe.composition.sizeClass, SizeClass.large,
        reason: 'size must survive a style change');
    expect(state.currentRecipe.palette?.garmentColour, '#F5F5F5',
        reason: 'garment colour must survive a style change');
  });

  testWidgets('(i) Back is a separate, independently-editable side',
      (tester) async {
    final key = GlobalKey<StudioCanvasScreenState>();
    final state = await pumpScreen(tester, key);
    final frontId = state.currentRecipe.recipeId;

    // Flip to the Back — it's a distinct (complementary) design. (The Format bar
    // scrolls horizontally, so reveal the control before tapping.)
    await tester.ensureVisible(find.byKey(const Key('studio-side-back')));
    await tester.tap(find.byKey(const Key('studio-side-back')));
    await tester.pump();
    expect(state.currentRecipe.recipeId, isNot(frontId));

    // Edit the Back only.
    await tester.ensureVisible(find.byKey(const Key('studio-garment-Olive')));
    await tester.tap(find.byKey(const Key('studio-garment-Olive')));
    await tester.pump();
    expect(state.currentRecipe.palette?.garmentColour, '#6B7350');

    // Returning to the Front leaves it byte-identical (the edit hit the back).
    await tester.ensureVisible(find.byKey(const Key('studio-side-front')));
    await tester.tap(find.byKey(const Key('studio-side-front')));
    await tester.pump();
    expect(state.currentRecipe.recipeId, frontId);
  });

  testWidgets('(j) a Finish preset applies a bundled effect', (tester) async {
    final key = GlobalKey<StudioCanvasScreenState>();
    final state = await pumpScreen(tester, key);
    await tester.tap(find.byKey(const Key('studio-adjust-toggle')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('studio-finish-Tie-dye')));
    await tester.tap(find.byKey(const Key('studio-finish-Tie-dye')));
    await tester.pump();
    expect(state.currentRecipe.effects?.tieDye, 0.9);
  });

  testWidgets('(k) custom text edits the word on the Words subject',
      (tester) async {
    final key = GlobalKey<StudioCanvasScreenState>();
    final state = await pumpScreen(tester, key);
    // Cycle Direction to the Words subject (index 4: Flags→Passport→Route→World→Words).
    for (var i = 0; i < 4; i++) {
      await tester
          .tap(find.byKey(Key('studio-chip-${DesignAxis.direction.key}')));
      await tester.pump();
    }
    await tester.tap(find.byKey(const Key('studio-adjust-toggle')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('studio-text-input')));
    await tester.enterText(find.byKey(const Key('studio-text-input')), 'WANDER');
    await tester.pump();
    expect(state.currentRecipe.clip?.shapeId, 'text');
    expect(state.currentRecipe.clip?.text, 'WANDER');
  });

  testWidgets('(l) silhouette picker lists all kinds for selected countries',
      (tester) async {
    final gen = LabShowcaseGenerator(
      silhouettesByShape: const {
        ClipShape.animalSilhouette: ['us_bald_eagle', 'us_bison'],
        ClipShape.plantSilhouette: ['us_redwood'],
        ClipShape.landmarkSilhouette: ['us_statue_of_liberty'],
      },
      countryNames: source?.countryNames() ?? const {},
    );
    final key = GlobalKey<StudioCanvasScreenState>();
    await tester.pumpWidget(MaterialApp(
      home: StudioCanvasScreen(
        key: key,
        generator: gen,
        service: service,
        designContext: context,
        initialSeed: 7,
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    final state = key.currentState!;

    // Pick the Animals detail, then open Adjust — the picker appears.
    await tester.tap(find.byKey(const Key('studio-detail-animals')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('studio-adjust-toggle')));
    await tester.pump();
    expect(find.byKey(const Key('studio-silhouette-pick')), findsOneWidget);

    // The full list (animal + plant + landmark) is offered; pick the landmark.
    await tester.ensureVisible(find.byKey(const Key('studio-silhouette-pick')));
    await tester.tap(find.byKey(const Key('studio-silhouette-pick')));
    await tester.pump();
    await tester.tap(find.text('US · Statue Of Liberty (landmark)').last);
    await tester.pump();
    expect(state.currentRecipe.clip?.shapeId, 'landmarkSilhouette');
    expect(state.currentRecipe.clip?.code, 'us_statue_of_liberty');
  });
}
