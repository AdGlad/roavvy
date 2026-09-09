// M18 — Graphics: the element-level controls this design can use, and the
// clear line between them and M17's composition controls.
import 'dart:typed_data';

import 'package:country_lookup/country_lookup.dart';
import 'package:design_forge/design_forge.dart';
import 'package:design_studio/design_studio.dart';
import 'package:flutter/material.dart' hide Orientation;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/providers.dart';
import 'package:mobile_flutter/features/studio_v2/studio_v2_app.dart';
import 'package:mobile_flutter/features/studio_v2/studio_v2_screen.dart';
import 'package:mobile_flutter/features/studio_v2/studio_v2_stage.dart';
import 'package:mobile_flutter/features/studio_v2/widgets/shirt_preview.dart';
import 'package:region_lookup/region_lookup.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StudioController controller;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    controller = buildStudioV2Controller();
  });
  tearDown(() => controller.dispose());

  Future<StudioV2ScreenState> pump(WidgetTester tester) async {
    late Uint8List countries, regions;
    await tester.runAsync(() async {
      countries =
          (await rootBundle.load(
            'assets/geodata/ne_countries.bin',
          )).buffer.asUint8List();
      regions =
          (await rootBundle.load(
            'assets/geodata/ne_admin1.bin',
          )).buffer.asUint8List();
    });
    initCountryLookup(countries);
    initRegionLookup(regions);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey<StudioV2ScreenState>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          geodataBytesProvider.overrideWithValue(countries),
          regionGeodataBytesProvider.overrideWithValue(regions),
        ],
        child: MaterialApp(
          home: StudioV2Screen(key: key, controller: controller),
        ),
      ),
    );
    await tester.pump();
    return key.currentState!;
  }

  Future<StudioV2ScreenState> pumpGraphics(WidgetTester tester) async {
    final state = await pump(tester);
    state.goToStage(StudioStage.graphics);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    return state;
  }

  group('the capabilities are real', () {
    test('no invented adjustment sliders', () {
      // The storyboard shows Opacity, Contrast and Saturation. None of the
      // three exists on the recipe, so none is offered.
      final c = buildStudioV2Controller();
      addTearDown(c.dispose);
      final ids = {
        for (final x in c.fineTuneControls()) x.id,
        for (final x in c.fineTuneChoices()) x.id,
        for (final x in c.graphicChoices()) x.id,
      };
      for (final invented in ['opacity', 'contrast', 'saturation']) {
        expect(ids, isNot(contains(invented)));
      }
    });

    test('every edge option is a real TearStyle, plus Clean', () {
      final c = buildStudioV2Controller();
      addTearDown(c.dispose);
      final edge = c.graphicChoices().firstWhere((x) => x.id == 'edge');
      final names = TearStyle.values.map((v) => v.name).toSet();
      for (final o in edge.options) {
        expect(
          o.id == 'none' || names.contains(o.id),
          isTrue,
          reason: '${o.id} is not a TearStyle',
        );
      }
    });

    test('Clean really removes the tearing', () {
      // DesignRecipe.copyWith reads `edgeTreatment ?? this.edgeTreatment`, so
      // passing null KEEPS the current edge. A Clean option written that way
      // would look like it turned tearing off and do nothing.
      final c = buildStudioV2Controller();
      addTearDown(c.dispose);
      final edge = c.graphicChoices().firstWhere((x) => x.id == 'edge');

      c.commitFineTune(edge.write(c.current, 'deepRips'));
      expect(c.current.edgeTreatment!.edgeDamage, greaterThan(0));

      c.commitFineTune(edge.write(c.current, 'none'));
      expect(c.current.edgeTreatment?.edgeDamage ?? 0, 0);
      expect(edge.read(c.current), 'none');
    });

    test('corner rounding is offered only for shapes that honour it', () {
      // Applicability read from the shape catalogue's own metadata, not from
      // a list of shape names kept in the UI.
      final c = buildStudioV2Controller();
      addTearDown(c.dispose);
      for (final detail in ['heart', 'circle']) {
        c.applyDetailChoice(detail);
        final honours =
            clipShapeMetaById(c.current.clip?.shapeId ?? '')?.cornerRadius ??
            false;
        expect(
          c.fineTuneControls().map((x) => x.id).contains('clipCorner'),
          honours,
          reason: '$detail: offered=${!honours}',
        );
      }
    });

    test('the damage sliders appear only once there is damage to shape', () {
      final c = buildStudioV2Controller();
      addTearDown(c.dispose);
      final edge = c.graphicChoices().firstWhere((x) => x.id == 'edge');

      c.commitFineTune(edge.write(c.current, 'none'));
      expect(
        c.fineTuneControls().map((x) => x.id),
        isNot(contains('edgeFray')),
      );

      c.commitFineTune(edge.write(c.current, 'frayed'));
      expect(c.fineTuneControls().map((x) => x.id), contains('edgeFray'));
    });

    test('the silhouette pick appears only when the clip IS a silhouette', () {
      final c = buildStudioV2Controller();
      addTearDown(c.dispose);
      c.applyDetailChoice('heart');
      expect(
        c.graphicChoices().map((x) => x.id),
        isNot(contains('silhouette')),
      );

      c.applyDetailChoice('animals');
      final ids = c.graphicChoices().map((x) => x.id);
      if (c.silhouetteOptions().isNotEmpty) {
        expect(ids, contains('silhouette'));
      }
    });
  });

  group('ownership between M17 and M18', () {
    test('composition controls stay in Layout, element ones in Graphics', () {
      final c = buildStudioV2Controller();
      addTearDown(c.dispose);
      c.applyDetailChoice('circle');

      FineTuneGroup groupOf(String id) =>
          [
            ...c.fineTuneControls(),
            ...c.fineTuneChoices().map(
              (x) => FineTuneControl(
                id: x.id,
                label: x.label,
                group: x.group,
                read: (_) => 0,
                write: (r, _) => r,
              ),
            ),
            ...c.graphicChoices().map(
              (x) => FineTuneControl(
                id: x.id,
                label: x.label,
                group: x.group,
                read: (_) => 0,
                write: (r, _) => r,
              ),
            ),
          ].firstWhere((x) => x.id == id).group;

      // Whole-composition: how the elements are laid out and how big the
      // artwork is.
      expect(groupOf('fill'), FineTuneGroup.layout);
      expect(groupOf('scale'), FineTuneGroup.layout);
      expect(groupOf('copies'), FineTuneGroup.layout);
      // Element-level: the shape itself and its edge.
      expect(groupOf('clipScale'), FineTuneGroup.graphics);
      expect(groupOf('clipRotation'), FineTuneGroup.graphics);
      expect(groupOf('edge'), FineTuneGroup.graphics);
    });

    test('nothing is offered in two groups at once', () {
      final c = buildStudioV2Controller();
      addTearDown(c.dispose);
      final all = [
        for (final x in c.fineTuneControls()) x.id,
        for (final x in c.fineTuneChoices()) x.id,
        for (final x in c.graphicChoices()) x.id,
      ];
      expect(all.toSet().length, all.length);
    });
  });

  group('the screen', () {
    testWidgets('it shows Graphics only, over a live shirt', (tester) async {
      controller.applyDetailChoice('heart');
      await pumpGraphics(tester);
      expect(find.text('Graphics'), findsOneWidget);
      expect(find.byKey(const Key('v2-garment-preview')), findsOneWidget);
      expect(find.byKey(const Key('v2-side-front')), findsOneWidget);
      expect(
        find.byKey(const Key('v2-finetune-group-graphics')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('v2-finetune-group-layout')), findsNothing);
      expect(find.byKey(const Key('v2-finetune-group-colour')), findsNothing);
    });

    testWidgets('edge style is chosen by name', (tester) async {
      await pumpGraphics(tester);
      expect(find.byKey(const Key('v2-finetune-choice-edge')), findsOneWidget);
      expect(find.byKey(const Key('v2-finetune-edge-none')), findsOneWidget);
    });

    testWidgets('nothing overflows a phone', (tester) async {
      controller.applyDetailChoice('heart');
      await pumpGraphics(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('just looking changes nothing', (tester) async {
      final state = await pump(tester);
      final recipe = controller.current.recipeId;
      final history = controller.history.length;
      state.goToStage(StudioStage.graphics);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(controller.current.recipeId, recipe);
      expect(controller.history.length, history);
    });
  });

  group('editing', () {
    testWidgets('choosing an edge changes the shirt, in one undo step', (
      tester,
    ) async {
      await pumpGraphics(tester);
      final before = controller.current.recipeId;
      final history = controller.history.length;

      await tester.tap(find.byKey(const Key('v2-finetune-edge-ragged')));
      await tester.pump();

      expect(controller.current.edgeTreatment?.style, TearStyle.ragged);
      expect(controller.current.recipeId, isNot(before));
      expect(controller.history.length, history + 1);

      final shirt = tester.widget<ShirtPreview>(
        find.byKey(const Key('v2-garment-preview')),
      );
      expect(shirt.recipe.recipeId, controller.current.recipeId);
    });

    testWidgets('a damage drag is one undo step, not one per frame', (
      tester,
    ) async {
      final edge = controller.graphicChoices().firstWhere(
        (x) => x.id == 'edge',
      );
      controller.commitFineTune(edge.write(controller.current, 'frayed'));
      await pumpGraphics(tester);
      final history = controller.history.length;

      final slider = find.byKey(const Key('v2-finetune-edgeFray'));
      final g = await tester.startGesture(tester.getCenter(slider));
      for (var i = 0; i < 8; i++) {
        await g.moveBy(const Offset(-10, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await g.up();
      await tester.pump();
      expect(controller.history.length, history + 1);
    });

    test('a graphic change leaves M17 and everything earlier alone', () {
      final c = buildStudioV2Controller();
      addTearDown(c.dispose);
      c.applyDetailChoice('heart');
      c.setGarment('#FF1B2B');
      c.setSide(false);
      c.commitTitle('EUROPE 2026');
      final (style, styled) = c.vibeStyleOptions()[LabStyle.retro.index];
      c.onStyleTap(style, styled);
      final fill = c.fineTuneChoices().single;
      c.commitFineTune(fill.write(c.current, 'radial'));
      c.setSize(SizeClass.large);
      final codes = c.selectedCountryCodes;
      final grain = c.fineTuneControls().firstWhere((x) => x.id == 'grain');
      final grainBefore = grain.read(c.current);

      final edge = c.graphicChoices().firstWhere((x) => x.id == 'edge');
      c.commitFineTune(edge.write(c.current, 'battleWorn'));

      expect(c.selectedCountryCodes, codes);
      expect(c.subjectLabel, 'Flags');
      expect(c.currentDetailId, 'heart');
      expect(c.currentStyle, LabStyle.retro);
      // M17's composition settings survive.
      expect(c.current.composition.fillAlgorithm, FillAlgorithm.radial);
      expect(c.current.composition.sizeClass, SizeClass.large);
      expect(c.current.palette?.garmentColour, '#FF1B2B');
      expect(c.currentTitle, 'EUROPE 2026');
      expect(grain.read(c.current), grainBefore, reason: 'colour untouched');
    });
  });

  group('reset', () {
    test('it leaves the earlier choices and the garment alone', () {
      final c = buildStudioV2Controller();
      addTearDown(c.dispose);
      c.applyDetailChoice('heart');
      c.setGarment('#FF1B2B');
      final codes = c.selectedCountryCodes;

      final edge = c.graphicChoices().firstWhere((x) => x.id == 'edge');
      c.commitFineTune(edge.write(c.current, 'heavyEdgeDamage'));

      c.resetFineTune();

      expect(c.selectedCountryCodes, codes);
      expect(c.currentDetailId, 'heart');
      expect(c.subjectLabel, 'Flags');
      expect(c.current.palette?.garmentColour, '#FF1B2B');
    });
  });

  group('navigation', () {
    testWidgets('Layout leads here, Back returns with edits kept', (
      tester,
    ) async {
      final state = await pump(tester);
      state.goToStage(StudioStage.layout);
      await tester.pump();
      await tester.tap(find.byKey(const Key('v2-customise-next')));
      await tester.pump();
      expect(state.stage, StudioStage.graphics);

      await tester.tap(find.byKey(const Key('v2-finetune-edge-ragged')));
      await tester.pump();
      final edited = controller.current.recipeId;

      await tester.tap(find.byKey(const Key('v2-customise-back')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(state.stage, StudioStage.layout);
      expect(controller.current.recipeId, edited);
    });

    testWidgets('a step whose group is empty is not in the flow', (
      tester,
    ) async {
      // The skip is structural: the visible steps ask each group whether any
      // of its controls apply, so a group that empties drops out of Next.
      final state = await pump(tester);
      state.goToStage(StudioStage.graphics);
      await tester.pump();
      expect(
        controller.fineTuneGroups(),
        contains(FineTuneGroup.graphics),
        reason: 'the edge is always cuttable, so Graphics always applies',
      );
      await tester.tap(find.byKey(const Key('v2-customise-next')));
      await tester.pump();
      expect(state.stage, isNot(StudioStage.graphics));
    });
  });
}
