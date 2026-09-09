// M17 — Layout & Composition: the arrangement controls that this design can
// actually use, and none that it cannot.
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

  Future<StudioV2ScreenState> pumpLayout(WidgetTester tester) async {
    final state = await pump(tester);
    state.goToStage(StudioStage.layout);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    return state;
  }

  group('the capabilities are the engine\'s, not a guess', () {
    test('every offered control is one the renderer actually reads', () {
      // The rule this milestone exists to enforce. composition.jitter,
      // density, rowCount and placement are set by the generator but never
      // consulted by the renderer, so a slider bound to any of them would
      // change the recipe id and not a single pixel.
      final c = buildStudioV2Controller();
      addTearDown(c.dispose);
      const inert = {'jitter', 'density', 'rowCount', 'placement'};
      final offered = {
        for (final x in c.fineTuneControls()) x.id,
        for (final x in c.fineTuneChoices()) x.id,
      };
      expect(offered.intersection(inert), isEmpty);
    });

    test('arrangement is offered only where the renderer consults it', () {
      // The composition stage picks the fill algorithm on the many-instance
      // path; one or two flags are drawn by code that ignores it.
      final many = buildStudioV2Controller();
      addTearDown(many.dispose);
      expect(many.fineTuneChoices().map((x) => x.id), contains('fill'));

      final few = buildStudioV2Controller();
      addTearDown(few.dispose);
      few.setSelectedCountries(few.availableCountryCodes.take(2));
      expect(
        few.fineTuneChoices(),
        isEmpty,
        reason: 'two flags never reach the algorithm',
      );
    });

    test('every arrangement option is a real FillAlgorithm', () {
      final c = buildStudioV2Controller();
      addTearDown(c.dispose);
      final names = FillAlgorithm.values.map((v) => v.name).toSet();
      for (final o in c.fineTuneChoices().single.options) {
        expect(names, contains(o.id), reason: '${o.id} is invented');
      }
    });

    test('Scale is offered for every design', () {
      final c = buildStudioV2Controller();
      addTearDown(c.dispose);
      for (var i = 0; i < StudioController.subjects.length; i++) {
        c.selectSubject(i);
        expect(
          c.fineTuneControls().map((x) => x.id),
          contains('scale'),
          reason: 'the renderer reads sizeClass whatever the subject is',
        );
      }
    });

    test('a two-flag design loses Repeats and Arrangement but keeps Scale', () {
      final c = buildStudioV2Controller();
      addTearDown(c.dispose);
      c.setSelectedCountries(c.availableCountryCodes.take(1));
      final ids = c.fineTuneControls().map((x) => x.id);
      expect(ids, contains('scale'));
      expect(ids, isNot(contains('copies')));
    });
  });

  group('the screen', () {
    testWidgets('it shows the layout group only, over a live shirt', (
      tester,
    ) async {
      await pumpLayout(tester);
      expect(find.text('Layout & Composition'), findsOneWidget);
      expect(find.byKey(const Key('v2-garment-preview')), findsOneWidget);
      expect(find.byKey(const Key('v2-side-front')), findsOneWidget);
      expect(find.byKey(const Key('v2-finetune-group-layout')), findsOneWidget);
      expect(
        find.byKey(const Key('v2-finetune-group-colour')),
        findsNothing,
        reason: 'Colour is M19, not this step',
      );
    });

    testWidgets('arrangement is chosen by name, not by dragging a number', (
      tester,
    ) async {
      await pumpLayout(tester);
      expect(find.byKey(const Key('v2-finetune-choice-fill')), findsOneWidget);
      expect(find.byKey(const Key('v2-finetune-fill-grid')), findsOneWidget);
    });

    testWidgets('sliders show a readable value', (tester) async {
      await pumpLayout(tester);
      expect(find.byKey(const Key('v2-finetune-scale')), findsOneWidget);
      expect(find.text('Size of the artwork.'), findsOneWidget);
    });

    testWidgets('nothing overflows a phone', (tester) async {
      await pumpLayout(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('just looking changes nothing', (tester) async {
      final state = await pump(tester);
      final recipe = controller.current.recipeId;
      final history = controller.history.length;
      state.goToStage(StudioStage.layout);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(controller.current.recipeId, recipe);
      expect(controller.history.length, history);
    });
  });

  group('editing', () {
    testWidgets('choosing an arrangement changes the shirt', (tester) async {
      await pumpLayout(tester);
      final before = controller.current.recipeId;
      await tester.tap(find.byKey(const Key('v2-finetune-fill-radial')));
      await tester.pump();
      expect(
        controller.current.composition.fillAlgorithm,
        FillAlgorithm.radial,
      );
      expect(controller.current.recipeId, isNot(before));

      final shirt = tester.widget<ShirtPreview>(
        find.byKey(const Key('v2-garment-preview')),
      );
      expect(shirt.recipe.recipeId, controller.current.recipeId);
    });

    testWidgets('one tap is one undo step', (tester) async {
      await pumpLayout(tester);
      final history = controller.history.length;
      await tester.tap(find.byKey(const Key('v2-finetune-fill-mosaic')));
      await tester.pump();
      expect(controller.history.length, history + 1);
    });

    testWidgets('a slider drag is one undo step, not one per frame', (
      tester,
    ) async {
      // Start from the smallest so a drag to the right genuinely moves it.
      controller.setSize(SizeClass.small);
      await pumpLayout(tester);
      final history = controller.history.length;
      final slider = find.byKey(const Key('v2-finetune-scale'));
      final g = await tester.startGesture(tester.getCenter(slider));
      for (var i = 0; i < 8; i++) {
        await g.moveBy(const Offset(10, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await g.up();
      await tester.pump();
      expect(controller.history.length, history + 1);
    });

    test('a layout change leaves every earlier choice alone', () {
      final c = buildStudioV2Controller();
      addTearDown(c.dispose);
      c.applyDetailChoice('heart');
      c.setGarment('#FF1B2B');
      c.setSide(false);
      c.commitTitle('EUROPE 2026');
      final (style, styled) = c.vibeStyleOptions()[LabStyle.retro.index];
      c.onStyleTap(style, styled);
      final codes = c.selectedCountryCodes;
      final grain = c.fineTuneControls().firstWhere((x) => x.id == 'grain');
      final grainBefore = grain.read(c.current);

      final fill = c.fineTuneChoices().single;
      c.commitFineTune(fill.write(c.current, 'voronoi'));

      expect(c.selectedCountryCodes, codes);
      expect(c.subjectLabel, 'Flags');
      expect(c.currentDetailId, 'heart');
      expect(c.currentStyle, LabStyle.retro);
      expect(c.current.palette?.garmentColour, '#FF1B2B');
      expect(c.currentTitle, 'EUROPE 2026');
      expect(grain.read(c.current), grainBefore, reason: 'colour untouched');
    });
  });

  group('reset', () {
    test('it restores layout and leaves the rest of the design alone', () {
      final c = buildStudioV2Controller();
      addTearDown(c.dispose);
      c.applyDetailChoice('heart');
      c.setGarment('#FF1B2B');
      final codes = c.selectedCountryCodes;

      final fill = c.fineTuneChoices().single;
      c.commitFineTune(fill.write(c.current, 'tornRegion'));
      expect(c.current.composition.fillAlgorithm, FillAlgorithm.tornRegion);

      c.resetFineTune();

      expect(
        c.current.composition.fillAlgorithm,
        isNot(FillAlgorithm.tornRegion),
      );
      expect(c.selectedCountryCodes, codes);
      expect(c.currentDetailId, 'heart');
      expect(c.current.palette?.garmentColour, '#FF1B2B');
    });
  });

  group('navigation', () {
    testWidgets('Fine Tune leads here, and Back returns with edits kept', (
      tester,
    ) async {
      final state = await pump(tester);
      state.goToStage(StudioStage.fineTune);
      await tester.pump();
      await tester.tap(find.byKey(const Key('v2-customise-next')));
      await tester.pump();
      expect(state.stage, StudioStage.layout);

      await tester.tap(find.byKey(const Key('v2-finetune-fill-mosaic')));
      await tester.pump();
      final edited = controller.current.recipeId;

      await tester.tap(find.byKey(const Key('v2-customise-back')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(state.stage, StudioStage.fineTune);
      expect(controller.current.recipeId, edited);
    });

    testWidgets('Next leads on towards the graphic controls (M18)', (
      tester,
    ) async {
      final state = await pumpLayout(tester);
      await tester.tap(find.byKey(const Key('v2-customise-next')));
      await tester.pump();
      expect(state.stage, isNot(StudioStage.layout));
    });
  });
}
