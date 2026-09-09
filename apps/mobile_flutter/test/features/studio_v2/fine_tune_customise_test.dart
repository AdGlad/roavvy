// M16 — Fine Tune: the dials that can actually move THIS design, and no others.
import 'dart:typed_data';

import 'package:country_lookup/country_lookup.dart';
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

  int subject(String label) =>
      StudioController.subjects.indexWhere((s) => s.$3 == label);

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

  Future<StudioV2ScreenState> pumpFineTune(WidgetTester tester) async {
    final state = await pump(tester);
    state.goToStage(StudioStage.fineTune);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    return state;
  }

  group('the controls come from the design, not from a table', () {
    test('a clipped design gets Graphics; an unclipped one does not', () {
      final c = buildStudioV2Controller();
      addTearDown(c.dispose);

      c.applyDetailChoice('grid'); // Grid is the ABSENCE of a clip
      expect(
        c.fineTuneGroups(),
        isNot(contains(FineTuneGroup.graphics)),
        reason: 'there is no clip to size or rotate',
      );
      expect(
        c.fineTuneControls().map((x) => x.id),
        isNot(contains('clipScale')),
      );

      c.applyDetailChoice('heart');
      expect(c.fineTuneGroups(), contains(FineTuneGroup.graphics));
      expect(c.fineTuneControls().map((x) => x.id), contains('clipScale'));
    });

    test('two different designs offer different controls', () {
      final a = buildStudioV2Controller();
      addTearDown(a.dispose);
      a.applyDetailChoice('grid');
      final b = buildStudioV2Controller();
      addTearDown(b.dispose);
      b.applyDetailChoice('circle');
      expect(
        a.fineTuneControls().map((x) => x.id).toSet(),
        isNot(b.fineTuneControls().map((x) => x.id).toSet()),
      );
    });

    test('a one-country design has nothing to arrange', () {
      final c = buildStudioV2Controller();
      addTearDown(c.dispose);
      c.setSelectedCountries([c.availableCountryCodes.first]);
      expect(
        c.fineTuneGroups(),
        isNot(contains(FineTuneGroup.layout)),
        reason: 'scatter and repeats need more than one thing',
      );
    });

    test('every control can actually change the recipe it is offered for', () {
      // The whole promise of the screen: nothing on it is inert.
      final c = buildStudioV2Controller();
      addTearDown(c.dispose);
      c.applyDetailChoice('heart');
      for (final control in c.fineTuneControls()) {
        final before = c.current;
        final v = control.read(before);
        final other =
            v > (control.min + control.max) / 2 ? control.min : control.max;
        final after = control.write(before, other);
        expect(
          after.recipeId,
          isNot(before.recipeId),
          reason: '${control.id} does nothing to this design',
        );
      }
    });

    test('every control belongs to a group that is offered', () {
      final c = buildStudioV2Controller();
      addTearDown(c.dispose);
      final groups = c.fineTuneGroups().toSet();
      for (final control in c.fineTuneControls()) {
        expect(groups, contains(control.group));
      }
    });
  });

  group('the screen', () {
    testWidgets('it keeps the shirt, because the dials change how it looks', (
      tester,
    ) async {
      await pumpFineTune(tester);
      expect(find.byKey(const Key('v2-garment-preview')), findsOneWidget);
      expect(find.byType(ShirtPreview), findsOneWidget);
      expect(find.byKey(const Key('v2-side-front')), findsOneWidget);
      expect(find.text('Fine Tune'), findsOneWidget);
    });

    testWidgets('only the groups with something in them are shown', (
      tester,
    ) async {
      controller.applyDetailChoice('grid');
      await pumpFineTune(tester);
      expect(
        find.byKey(const Key('v2-finetune-group-graphics')),
        findsNothing,
        reason: 'an empty panel is not a panel',
      );
      expect(find.byKey(const Key('v2-finetune-group-colour')), findsOneWidget);
    });

    testWidgets('a clip brings its controls with it', (tester) async {
      controller.applyDetailChoice('heart');
      await pumpFineTune(tester);
      expect(
        find.byKey(const Key('v2-finetune-group-graphics')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('v2-finetune-clipScale')), findsOneWidget);
    });

    testWidgets('nothing overflows a phone', (tester) async {
      await pumpFineTune(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('just looking changes nothing', (tester) async {
      final state = await pump(tester);
      final recipe = controller.current.recipeId;
      final history = controller.history.length;
      state.goToStage(StudioStage.fineTune);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(controller.current.recipeId, recipe);
      expect(controller.history.length, history);
    });
  });

  group('editing', () {
    testWidgets('dragging a slider changes the design on the shirt', (
      tester,
    ) async {
      await pumpFineTune(tester);
      final before = controller.current.recipeId;
      await tester.drag(
        find.byKey(const Key('v2-finetune-grain')),
        const Offset(60, 0),
      );
      await tester.pump();
      expect(controller.current.recipeId, isNot(before));

      final shirt = tester.widget<ShirtPreview>(
        find.byKey(const Key('v2-garment-preview')),
      );
      expect(shirt.recipe.recipeId, controller.current.recipeId);
    });

    testWidgets('a whole drag is ONE undo step, not one per frame', (
      tester,
    ) async {
      await pumpFineTune(tester);
      final history = controller.history.length;
      final slider = find.byKey(const Key('v2-finetune-grain'));

      // A real gesture: many frames of movement, then a release.
      final g = await tester.startGesture(tester.getCenter(slider));
      for (var i = 0; i < 8; i++) {
        await g.moveBy(const Offset(8, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await g.up();
      await tester.pump();

      expect(
        controller.history.length,
        history + 1,
        reason: 'a slider drag must not flood the undo stack',
      );
    });

    test('editing leaves every earlier choice alone', () {
      final c = buildStudioV2Controller();
      addTearDown(c.dispose);
      c.selectSubject(subject('Flags'));
      c.applyDetailChoice('heart');
      c.setGarment('#FF1B2B');
      c.setSide(false);
      c.commitTitle('EUROPE 2026');
      final (style, styled) = c.vibeStyleOptions()[LabStyle.retro.index];
      c.onStyleTap(style, styled);
      final codes = c.selectedCountryCodes;

      final grain = c.fineTuneControls().firstWhere((x) => x.id == 'grain');
      c.beginEdit();
      c.applyLive(grain.write(c.current, 0.8));
      c.endEdit();

      expect(c.selectedCountryCodes, codes);
      expect(c.subjectLabel, 'Flags');
      expect(c.currentDetailId, 'heart');
      expect(c.currentStyle, LabStyle.retro);
      expect(c.current.palette?.garmentColour, '#FF1B2B');
      expect(c.currentTitle, 'EUROPE 2026');
    });
  });

  group('reset', () {
    test('it puts the dials back and leaves the design alone', () {
      final c = buildStudioV2Controller();
      addTearDown(c.dispose);
      c.applyDetailChoice('heart');
      c.setGarment('#FF1B2B');
      c.setSide(false);
      c.commitTitle('EUROPE 2026');
      final codes = c.selectedCountryCodes;
      final detail = c.currentDetailId;

      final grain = c.fineTuneControls().firstWhere((x) => x.id == 'grain');
      c.beginEdit();
      c.applyLive(grain.write(c.current, 0.9));
      c.endEdit();
      expect(grain.read(c.current), closeTo(0.9, 0.001));

      c.resetFineTune();

      expect(grain.read(c.current), isNot(closeTo(0.9, 0.001)));
      // …and nothing chosen earlier in the flow moved.
      expect(c.selectedCountryCodes, codes);
      expect(c.currentDetailId, detail);
      expect(c.subjectLabel, 'Flags');
      expect(c.current.palette?.garmentColour, '#FF1B2B');
      expect(c.currentTitle, 'EUROPE 2026');
    });

    testWidgets('the button is on the screen and works', (tester) async {
      await pumpFineTune(tester);
      await tester.scrollUntilVisible(
        find.byKey(const Key('v2-finetune-reset')),
        200,
      );
      await tester.tap(find.byKey(const Key('v2-finetune-reset')));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('navigation', () {
    testWidgets('Vibe leads here, and Next leads on', (tester) async {
      final state = await pump(tester);
      state.goToStage(StudioStage.vibe);
      await tester.pump();
      await tester.tap(find.byKey(const Key('v2-customise-next')));
      await tester.pump();
      expect(state.stage, StudioStage.fineTune);
      final recipe = controller.current.recipeId;

      await tester.tap(find.byKey(const Key('v2-customise-back')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(state.stage, StudioStage.vibe);
      expect(controller.current.recipeId, recipe);
    });
  });
}
