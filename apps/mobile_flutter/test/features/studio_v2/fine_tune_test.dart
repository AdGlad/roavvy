import 'package:design_forge/design_forge.dart';
import 'package:design_studio/design_studio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/studio_v2/studio_v2_app.dart';
import 'package:mobile_flutter/features/studio_v2/studio_v2_screen.dart';
import 'package:mobile_flutter/features/studio_v2/studio_v2_stage.dart';

/// M7 — Fine Tune. Exercises the progressive-disclosure refine workspace over the
/// shared [StudioController] refine API: contextual categories, layout / graphic /
/// text / colour / edges / effects / print controls, finish presets, per-category
/// reset, live vs. committed (undoable) semantics, lock preservation and M0–M6
/// state survival.
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
    DesignContext.fromTrips(tripsFixture(), scopeKey: 'test:m7'),
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

  Future<void> expand(WidgetTester tester, String cat) async {
    await tester.tap(find.byKey(Key('v2-ft-cat-$cat')));
    await tester.pump();
  }

  testWidgets('Fine Tune replaces the placeholder with contextual categories '
      '(flags: no Text; Graphic only once clipped)', (tester) async {
    final c = controller();
    addTearDown(c.dispose);
    await pumpAt(tester, c, StudioStage.fineTune);

    // Placeholder is gone…
    expect(
      find.text('Controls for this step arrive in a later milestone.'),
      findsNothing,
    );
    // …replaced by the contextual category set for a (default) Flags recipe.
    for (final cat in [
      'finish',
      'layout',
      'colour',
      'edges',
      'effects',
      'print',
    ]) {
      expect(find.byKey(Key('v2-ft-cat-$cat')), findsOneWidget, reason: cat);
    }
    // Flags is not typographic and (by default) not clipped.
    expect(find.byKey(const Key('v2-ft-cat-text')), findsNothing);
    expect(find.byKey(const Key('v2-ft-cat-graphic')), findsNothing);

    // Clipping the design (a Detail shape) makes Graphic contextual.
    c.setClip(Clip.shape(ClipShape.heart, scale: 0.8));
    await tester.pump();
    expect(find.byKey(const Key('v2-ft-cat-graphic')), findsOneWidget);
  });

  testWidgets('Typography subject swaps Layout out for Text', (tester) async {
    final c = controller();
    addTearDown(c.dispose);
    await pumpAt(tester, c, StudioStage.fineTune);

    // subjects[4] == Words (typography).
    c.selectSubject(4);
    await tester.pump();
    expect(find.byKey(const Key('v2-ft-cat-text')), findsOneWidget);
    expect(find.byKey(const Key('v2-ft-cat-layout')), findsNothing);

    await expand(tester, 'text');
    await tester.tap(find.byKey(const Key('v2-ft-case-upper')));
    await tester.pump();
    expect(c.typography.textCase, TextCase.upper);
  });

  testWidgets('Layout controls: fill algorithm, density, copies — live '
      '(no recipe-history churn)', (tester) async {
    final c = controller();
    addTearDown(c.dispose);
    await pumpAt(tester, c, StudioStage.fineTune);
    final histLen = c.history.length;

    await expand(tester, 'layout');
    await tester.tap(find.byKey(const Key('v2-ft-fill-voronoi')));
    await tester.pump();
    expect(c.current.composition.fillAlgorithm, FillAlgorithm.voronoi);

    await tester.tap(find.byKey(const Key('v2-ft-density-dense')));
    await tester.pump();
    expect(c.current.composition.density, Density.dense);

    await tester.tap(find.byKey(const Key('v2-ft-copies-inc')));
    await tester.pump();
    expect(c.current.composition.copiesPerCountry, 2);

    // All live edits: no undo entries pushed.
    expect(c.history.length, histLen);
  });

  testWidgets('Graphic controls edit the clip live', (tester) async {
    final c = controller();
    addTearDown(c.dispose);
    c.setClip(Clip.shape(ClipShape.heart, scale: 1.0));
    await pumpAt(tester, c, StudioStage.fineTune);

    await expand(tester, 'graphic');
    final before = c.current.recipeId;
    await tester.drag(
      find.byKey(const Key('v2-ft-clip-scale')),
      const Offset(-120, 0),
    );
    await tester.pump();
    expect(c.current.clip!.scale, lessThan(1.0)); // dragged smaller
    expect(c.current.recipeId, isNot(before)); // live preview updated

    await tester.tap(find.byKey(const Key('v2-ft-reset-graphic')));
    await tester.pump();
    expect(c.current.clip!.scale, 1.0);
    expect(c.current.clip!.rotationDeg, 0.0);
  });

  testWidgets('Colour treatment is undoable; vintage grade is a live knob', (
    tester,
  ) async {
    final c = controller();
    addTearDown(c.dispose);
    await pumpAt(tester, c, StudioStage.fineTune);

    await expand(tester, 'colour');
    final histLen = c.history.length;
    await tester.tap(find.byKey(const Key('v2-ft-colour-monochrome')));
    await tester.pump();
    expect(c.colourStrategy, ColourStrategy.monochrome);
    expect(c.history.length, histLen + 1); // committed → undoable

    c.undo();
    await tester.pump();
    expect(c.colourStrategy, isNot(ColourStrategy.monochrome));

    // Vintage grade slider is a live palette edit.
    await tester.drag(
      find.byKey(const Key('v2-ft-vintage')),
      const Offset(200, 0),
    );
    await tester.pump();
    expect(c.vintageGrade, greaterThan(0));
  });

  testWidgets('Edges: tear style + damage parameters', (tester) async {
    final c = controller();
    addTearDown(c.dispose);
    await pumpAt(tester, c, StudioStage.fineTune);

    await expand(tester, 'edges');
    await tester.tap(find.byKey(const Key('v2-ft-tear-frayed')));
    await tester.pump();
    expect(c.edges.style, TearStyle.frayed);

    await tester.drag(
      find.byKey(const Key('v2-ft-edge-damage')),
      const Offset(-300, 0),
    );
    await tester.pump();
    expect(c.edges.edgeDamage, lessThan(0.5)); // dragged down from default
  });

  testWidgets('Effects sliders + reset preserves the Print looks', (
    tester,
  ) async {
    final c = controller();
    addTearDown(c.dispose);
    await pumpAt(tester, c, StudioStage.fineTune);

    // Set a Print look first (a different Effects field group).
    await expand(tester, 'print');
    await tester.tap(find.byKey(const Key('v2-ft-print-riso')));
    await tester.pump();
    expect(c.fx.riso, greaterThan(0));
    await expand(tester, 'print'); // collapse

    await expand(tester, 'effects');
    await tester.drag(
      find.byKey(const Key('v2-ft-fx-distress')),
      const Offset(300, 0),
    );
    await tester.pump();
    expect(c.fx.distress, greaterThan(0));

    final reset = find.byKey(const Key('v2-ft-reset-effects'));
    await tester.ensureVisible(reset);
    await tester.pump();
    await tester.tap(reset);
    await tester.pump();
    expect(c.fx.distress, 0); // effect cleared…
    expect(c.fx.riso, greaterThan(0)); // …Print look preserved
  });

  testWidgets('Print looks are mutually distinct and clearable', (
    tester,
  ) async {
    final c = controller();
    addTearDown(c.dispose);
    await pumpAt(tester, c, StudioStage.fineTune);

    await expand(tester, 'print');
    await tester.tap(find.byKey(const Key('v2-ft-print-newsprint')));
    await tester.pump();
    expect(c.fx.newsprint, greaterThan(0));

    await tester.tap(find.byKey(const Key('v2-ft-print-photocopy')));
    await tester.pump();
    expect(c.fx.photocopy, greaterThan(0));
    expect(c.fx.newsprint, 0); // switching looks clears the previous one

    await tester.tap(find.byKey(const Key('v2-ft-print-none')));
    await tester.pump();
    expect(c.fx.photocopy, 0);
  });

  testWidgets('Finish presets apply effects + palette (undoable)', (
    tester,
  ) async {
    final c = controller();
    addTearDown(c.dispose);
    await pumpAt(tester, c, StudioStage.fineTune);

    await expand(tester, 'finish');
    final histLen = c.history.length;
    await tester.tap(find.byKey(const Key('v2-ft-finish-vintage')));
    await tester.pump();
    expect(c.fx.fade, greaterThan(0));
    expect(c.fx.grain, greaterThan(0));
    expect(c.history.length, histLen + 1); // committed → undoable
  });

  testWidgets('Locks are preserved and M0–M6 state survives Fine Tune edits', (
    tester,
  ) async {
    final c = controller();
    addTearDown(c.dispose);

    // Establish M0–M6 state: a Detail shape, a front config.
    await pumpAt(tester, c, StudioStage.detail);
    await tester.tap(find.byKey(const Key('v2-detail-heart')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('v2-stage-front')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('v2-front-fit-chest')));
    await tester.pump();

    // Lock the Vibe axis, then make Fine Tune edits.
    c.toggleLock(DesignAxis.vibe);
    final selected = c.selectedCountryCodes;
    await tester.tap(find.byKey(const Key('v2-stage-fineTune')));
    await tester.pump();
    await expand(tester, 'effects');
    await tester.drag(
      find.byKey(const Key('v2-ft-fx-grain')),
      const Offset(200, 0),
    );
    await tester.pump();

    // The lock is still held; unrelated axes are intact.
    expect(c.locked.contains(DesignAxis.vibe), isTrue);
    expect(c.hero.clip?.shapeId, ClipShape.heart.id);
    expect(c.frontFit, FrontFit.chest);
    expect(c.selectedCountryCodes, selected);
  });
}
