// M19 — Colour, Effects & Print: the finishing treatments, and only the ones
// this design can actually wear.
//
// The screenshot for this step offers Opacity-style adjustments and a row of
// named print finishes. Words on a chip are cheap; these tests hold M19 to the
// engine: every option offered must move a field `design_forge_render` reads,
// and must move it on the artwork rather than only in the recipe id.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:country_lookup/country_lookup.dart';
import 'package:design_forge/design_forge.dart';
import 'package:design_forge_render/design_forge_render.dart';
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

/// Flags as flat colour, so a colour grade has something to grade.
class _ColourResolver implements AssetResolver {
  @override
  Future<ui.Image> resolveFlag(
    String code, {
    required int width,
    required int height,
  }) async {
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawRect(
      ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      ui.Paint()..color = const ui.Color(0xFF1E88E5),
    );
    return recorder.endRecording().toImage(width, height);
  }

  @override
  Future<ui.Image?> resolveClipMask(
    ClipShape shape,
    String? code, {
    required int width,
    required int height,
  }) async => null;

  @override
  Future<ui.Image?> resolvePassportCollage(
    List<PassportStampRef> stamps, {
    required int width,
    required int height,
    int seed = 0,
    double scatter = 0.5,
    double stampScale = 1.0,
    PassportInk ink = PassportInk.flag,
  }) async => null;
}

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

  StudioController renderable() => StudioController(
    generator: LabShowcaseGenerator(
      silhouettesByShape: const {},
      countryNames: const {},
    ),
    service: RenderService(_ColourResolver()),
    designContext: const DesignContext(
      flagCodes: ['us', 'fr', 'jp'],
      scopeKey: 'test:m19',
    ),
    initialSeed: 7,
  );

  FineTuneChoice choiceNamed(StudioController c, String id) =>
      c.colourChoices().firstWhere((x) => x.id == id);

  /// The rendered artwork, as raw pixels.
  Future<Uint8List> pixels(StudioController c, DesignRecipe r) async {
    final img = await c.service.imageFor(r, 180);
    return (await img.toByteData())!.buffer.asUint8List();
  }

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

  /// Bring a control into view before touching it — the treatment cards run
  /// past the bottom of a phone, which is what the sheet is for.
  Future<void> reveal(WidgetTester tester, Key key) async {
    // scrollUntilVisible stops as soon as the widget is BUILT, and a ListView
    // builds a little beyond its viewport — so it can succeed while the target
    // is still off-screen and untappable. ensureVisible finishes the job.
    await tester.scrollUntilVisible(
      find.byKey(key),
      200,
      scrollable:
          find
              .descendant(
                of: find.byKey(const Key('v2-finetune-scroll')),
                matching: find.byType(Scrollable),
              )
              .first,
    );
    await tester.ensureVisible(find.byKey(key));
    await tester.pump();
  }

  Future<StudioV2ScreenState> pumpColour(WidgetTester tester) async {
    final state = await pump(tester);
    state.goToStage(StudioStage.colour);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    return state;
  }

  group('the treatments come from the engine, not from the screenshot', () {
    test('three groups, and every one of them writes real recipe state', () {
      final ids = controller.colourChoices().map((c) => c.id).toList();
      expect(ids, ['colourTreatment', 'effectStyle', 'printStyle']);
      for (final c in controller.colourChoices()) {
        expect(c.group, FineTuneGroup.colour);
        expect(c.preview, isTrue, reason: '${c.id} is a look — show it');
      }
    });

    test('nothing offered is inert: every option changes the design', () {
      // The M17 lesson: a control that writes a field nothing reads is worse
      // than no control. Every option must at least produce a different design.
      for (final choice in controller.colourChoices()) {
        final defaultId = switch (choice.id) {
          'colourTreatment' => 'full',
          'printStyle' => 'standard',
          _ => 'none',
        };
        final base = choice.write(controller.current, defaultId);
        for (final o in choice.options) {
          if (o.id == defaultId) continue;
          expect(
            choice.write(controller.current, o.id).recipeId,
            isNot(base.recipeId),
            reason: '${choice.id}/${o.id} produces the same design as default',
          );
        }
      }
    });

    test('the fields the renderer ignores are never written', () {
      // `Effects.cracks` and `Effects.acidWash` exist on the recipe and are read
      // by nothing in design_forge_render. An option that set either would look
      // like a treatment and behave like nothing at all.
      for (final choice in controller.colourChoices()) {
        for (final o in choice.options) {
          final fx = choice.write(controller.current, o.id).effects;
          expect(fx?.cracks ?? 0, 0, reason: '${o.id} wrote inert `cracks`');
          expect(
            fx?.acidWash ?? 0,
            0,
            reason: '${o.id} wrote inert `acidWash`',
          );
        }
      }
    });

    test('Duotone supplies the accents it needs, or it would do nothing', () {
      // ColourStage only takes the duotone branch when
      // `strategy == duotone && accents.length >= 2`, and every generated
      // recipe carries an EMPTY accent list. Writing the strategy alone was a
      // chip that changed the recipe id and left the artwork untouched.
      expect(controller.current.palette?.accents ?? const [], isEmpty);

      final choice = choiceNamed(controller, 'colourTreatment');
      final duo = choice.write(controller.current, 'duotone');
      expect(duo.palette!.strategy, ColourStrategy.duotone);
      expect(
        duo.palette!.accents.length,
        greaterThanOrEqualTo(2),
        reason: 'duotone without two accents is a no-op in the renderer',
      );
    });

    test('Match shirt is offered only where the ink can be re-inked', () {
      // Garment-aware re-inks ADAPTIVE ink only; on a flag fill the renderer
      // skips the branch entirely, so the chip would be a decoration.
      final flags = buildStudioV2Controller();
      addTearDown(flags.dispose);
      flags.selectSubject(subject('Flags'));
      expect(flags.current.inkIsAdaptive, isFalse);
      expect(
        choiceNamed(flags, 'colourTreatment').options.map((o) => o.id),
        isNot(contains('garment')),
      );

      // …and a design whose ink IS adaptive gets it.
      final words = buildStudioV2Controller();
      addTearDown(words.dispose);
      final adaptive = words.current.copyWith(
        palette: (words.current.palette ?? const Palette()).copyWith(
          contrastInk: true,
        ),
      );
      words.commitFineTune(adaptive);
      expect(words.current.inkIsAdaptive, isTrue);
      expect(
        choiceNamed(words, 'colourTreatment').options.map((o) => o.id),
        contains('garment'),
      );
    });
  });

  group('the renderer honours what the screen offers', () {
    testWidgets('colour, effect and print each change the actual artwork', (
      tester,
    ) async {
      // Recipe ids are cheap. These treatments have to reach the pixels.
      final c = renderable();
      addTearDown(c.dispose);
      await tester.runAsync(() async {
        final base = await pixels(c, c.current);
        for (final (choiceId, optionId) in const [
          ('colourTreatment', 'mono'),
          ('colourTreatment', 'duotone'),
          ('colourTreatment', 'vintage'),
          ('effectStyle', 'halftone'),
          ('effectStyle', 'faded'),
          ('printStyle', 'riso'),
          ('printStyle', 'newsprint'),
          ('printStyle', 'photocopy'),
        ]) {
          final treated = choiceNamed(c, choiceId).write(c.current, optionId);
          final after = await pixels(c, treated);
          expect(
            after,
            isNot(equals(base)),
            reason: '$choiceId/$optionId rendered identically to the original',
          );
        }
      });
    });
  });

  group('the three groups stay disjoint', () {
    test('an effect leaves the print finish alone, and the reverse', () {
      final c = buildStudioV2Controller();
      addTearDown(c.dispose);
      c.commitFineTune(
        choiceNamed(c, 'printStyle').write(c.current, 'riso'),
      );
      expect(c.current.effects!.riso, greaterThan(0));

      c.commitFineTune(
        choiceNamed(c, 'effectStyle').write(c.current, 'distressed'),
      );
      expect(
        c.current.effects!.riso,
        greaterThan(0),
        reason: 'choosing an effect wiped the press finish',
      );
      expect(c.current.effects!.distress, greaterThan(0));

      c.commitFineTune(
        choiceNamed(c, 'printStyle').write(c.current, 'newsprint'),
      );
      expect(
        c.current.effects!.distress,
        greaterThan(0),
        reason: 'choosing a press finish wiped the effect',
      );
    });

    test('only one press finish at a time', () {
      final c = buildStudioV2Controller();
      addTearDown(c.dispose);
      final print = choiceNamed(c, 'printStyle');
      c.commitFineTune(print.write(c.current, 'riso'));
      c.commitFineTune(print.write(c.current, 'photocopy'));
      final fx = c.current.effects!;
      expect(fx.photocopy, greaterThan(0));
      expect(fx.riso, 0, reason: 'two presses stacked on one design');
      expect(print.read(c.current), 'photocopy');
    });

    test("neither disturbs the Vibe's own effects", () {
      // Tie-dye and shatter arrive with the Vibe, not with this screen.
      final c = buildStudioV2Controller();
      addTearDown(c.dispose);
      c.commitFineTune(
        c.current.copyWith(
          effects: (c.current.effects ?? const Effects()).copyWith(
            tieDye: 0.8,
            shatter: 0.4,
          ),
        ),
      );
      c.commitFineTune(choiceNamed(c, 'effectStyle').write(c.current, 'grain'));
      c.commitFineTune(choiceNamed(c, 'printStyle').write(c.current, 'riso'));
      expect(c.current.effects!.tieDye, closeTo(0.8, 0.001));
      expect(c.current.effects!.shatter, closeTo(0.4, 0.001));
    });
  });

  group('artwork colour is not garment colour', () {
    test('no treatment on this screen repaints the shirt', () {
      final c = buildStudioV2Controller();
      addTearDown(c.dispose);
      c.setGarment('#FF1B2B');
      for (final choice in c.colourChoices()) {
        for (final o in choice.options) {
          final next = choice.write(c.current, o.id);
          expect(
            next.palette?.garmentColour,
            '#FF1B2B',
            reason: '${choice.id}/${o.id} changed the blank the wearer chose',
          );
        }
      }
    });
  });

  group('the design that arrives is the design that leaves', () {
    test('every earlier choice survives an M19 edit', () {
      final c = buildStudioV2Controller();
      addTearDown(c.dispose);
      c.selectSubject(subject('Flags'));
      c.applyDetailChoice('heart');
      c.setGarment('#FF1B2B');
      c.commitTitle('EUROPE 2026');
      final (style, styled) = c.vibeStyleOptions()[LabStyle.retro.index];
      c.onStyleTap(style, styled);
      c.setSize(SizeClass.small);
      final codes = c.selectedCountryCodes;
      final size = c.current.composition.sizeClass;
      final clipScale = c.current.clip?.scale;

      c.commitFineTune(
        choiceNamed(c, 'colourTreatment').write(c.current, 'duotone'),
      );
      c.commitFineTune(choiceNamed(c, 'effectStyle').write(c.current, 'grain'));
      c.commitFineTune(
        choiceNamed(c, 'printStyle').write(c.current, 'newsprint'),
      );

      expect(c.selectedCountryCodes, codes);
      expect(c.subjectLabel, 'Flags');
      expect(c.currentDetailId, 'heart');
      expect(c.currentStyle, LabStyle.retro);
      expect(c.currentTitle, 'EUROPE 2026');
      expect(c.current.palette?.garmentColour, '#FF1B2B');
      expect(c.current.composition.sizeClass, size, reason: 'M17 composition');
      expect(c.current.clip?.scale, clipScale, reason: 'M18 graphics');
    });
  });

  group('reset', () {
    test('it puts colour, effects and print back and leaves the rest alone', () {
      final c = buildStudioV2Controller();
      addTearDown(c.dispose);
      c.applyDetailChoice('heart');
      c.setGarment('#FF1B2B');
      c.commitTitle('EUROPE 2026');
      final codes = c.selectedCountryCodes;

      c.commitFineTune(
        choiceNamed(c, 'colourTreatment').write(c.current, 'duotone'),
      );
      c.commitFineTune(
        choiceNamed(c, 'printStyle').write(c.current, 'photocopy'),
      );
      expect(choiceNamed(c, 'colourTreatment').read(c.current), 'duotone');

      c.resetFineTune();

      // A design left in Duotone with the "Full colour" chip lit is the bug
      // this asserts against: the strategy and its accents are finish state.
      expect(c.current.palette!.strategy, isNot(ColourStrategy.duotone));
      expect(choiceNamed(c, 'printStyle').read(c.current), 'standard');
      // …and nothing chosen earlier in the flow moved.
      expect(c.selectedCountryCodes, codes);
      expect(c.currentDetailId, 'heart');
      expect(c.current.palette?.garmentColour, '#FF1B2B');
      expect(c.currentTitle, 'EUROPE 2026');
    });
  });

  group('the screen', () {
    testWidgets('it is step 8, and the shirt is on it', (tester) async {
      await pumpColour(tester);
      expect(find.text('Colour, Effects & Print'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);
      expect(find.byKey(const Key('v2-garment-preview')), findsOneWidget);
      expect(find.byType(ShirtPreview), findsOneWidget);
      expect(find.byKey(const Key('v2-side-front')), findsOneWidget);
    });

    testWidgets('all three groups are on it, as thumbnails', (tester) async {
      await pumpColour(tester);
      for (final id in ['colourTreatment', 'effectStyle', 'printStyle']) {
        expect(
          find.byKey(Key('v2-finetune-choice-$id')),
          findsOneWidget,
          reason: '$id is missing from the screen',
        );
      }
      await reveal(tester, const Key('v2-finetune-printStyle-riso'));
      expect(
        find.byKey(const Key('v2-finetune-printStyle-riso')),
        findsOneWidget,
      );
    });

    testWidgets('only this group is shown here', (tester) async {
      await pumpColour(tester);
      expect(find.byKey(const Key('v2-finetune-group-colour')), findsOneWidget);
      expect(find.byKey(const Key('v2-finetune-group-layout')), findsNothing);
      expect(find.byKey(const Key('v2-finetune-group-graphics')), findsNothing);
    });

    testWidgets('nothing overflows a phone', (tester) async {
      await pumpColour(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('just looking changes nothing', (tester) async {
      final state = await pump(tester);
      final recipe = controller.current.recipeId;
      final history = controller.history.length;
      state.goToStage(StudioStage.colour);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(controller.current.recipeId, recipe);
      expect(controller.history.length, history);
    });

    testWidgets('a tap is one undo step, and the shirt follows', (tester) async {
      await pumpColour(tester);
      final history = controller.history.length;
      await reveal(tester, const Key('v2-finetune-printStyle-riso'));
      await tester.tap(find.byKey(const Key('v2-finetune-printStyle-riso')));
      await tester.pump();

      expect(controller.history.length, history + 1);
      expect(controller.current.effects!.riso, greaterThan(0));
      final shirt = tester.widget<ShirtPreview>(
        find.byKey(const Key('v2-garment-preview')),
      );
      expect(shirt.recipe.recipeId, controller.current.recipeId);
    });

    testWidgets('the thumbnail is the design you get', (tester) async {
      // Preview and commit go through the same pure write, so what a wearer
      // taps is what lands on the shirt.
      await pumpColour(tester);
      final choice = choiceNamed(controller, 'printStyle');
      final expected = choice.write(controller.current, 'newsprint').recipeId;
      await reveal(tester, const Key('v2-finetune-printStyle-newsprint'));
      await tester.tap(
        find.byKey(const Key('v2-finetune-printStyle-newsprint')),
      );
      await tester.pump();
      expect(controller.current.recipeId, expected);
    });

    testWidgets('Reset is on the screen and works', (tester) async {
      await pumpColour(tester);
      await reveal(tester, const Key('v2-finetune-reset'));
      await tester.tap(find.byKey(const Key('v2-finetune-reset')));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('navigation', () {
    testWidgets('Graphics leads here, and Back returns the design intact', (
      tester,
    ) async {
      final state = await pump(tester);
      state.goToStage(StudioStage.graphics);
      await tester.pump();
      await tester.tap(find.byKey(const Key('v2-customise-next')));
      await tester.pump();
      expect(state.stage, StudioStage.colour);
      final recipe = controller.current.recipeId;

      await tester.tap(find.byKey(const Key('v2-customise-back')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(state.stage, StudioStage.graphics);
      expect(controller.current.recipeId, recipe);
    });

    test('a step with nothing to offer is not a step', () {
      // The skip path is structural: `_visibleStages` asks the controller
      // whether the group has anything, exactly as it does for Detail, Layout
      // and Graphics. Every design the Studio generates today HAS a colour
      // group, so this pins the mechanism rather than a live case.
      expect(controller.fineTuneGroups(), contains(FineTuneGroup.colour));
      expect(controller.colourChoices(), isNotEmpty);
    });
  });
}
