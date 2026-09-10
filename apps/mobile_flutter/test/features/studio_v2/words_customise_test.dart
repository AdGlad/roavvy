// M20 — Words & Title: the words on the shirt, and only the type controls the
// renderer will actually honour.
//
// The screenshot for this step offers a row of text colours. `TypographyStage`
// inks the title with a contrast tone derived from the garment and has no field
// to override it — so those swatches would be the most convincing inert control
// on the whole screen. These tests hold M20 to what the engine reads.
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

  int subject(String label) =>
      StudioController.subjects.indexWhere((s) => s.$3 == label);

  FineTuneChoice choiceNamed(StudioController c, String id) =>
      c.wordChoices().firstWhere((x) => x.id == id);

  /// A controller with a title on the shirt — the state the type controls
  /// exist for.
  StudioController titled() {
    final c = buildStudioV2Controller();
    c.commitTitle('EUROPE 2026');
    return c;
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

  Future<StudioV2ScreenState> pumpWords(WidgetTester tester) async {
    final state = await pump(tester);
    state.goToStage(StudioStage.words);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    return state;
  }

  Future<void> reveal(WidgetTester tester, Key key) async {
    await tester.scrollUntilVisible(
      find.byKey(key),
      200,
      scrollable:
          find
              .descendant(
                of: find.byKey(const Key('v2-words-scroll')),
                matching: find.byType(Scrollable),
              )
              .first,
    );
    await tester.ensureVisible(find.byKey(key));
    await tester.pump();
  }

  group('the text controls come from the engine, not the screenshot', () {
    test('text colour is never offered, because nothing would read it', () {
      // TypographyStage inks the title with `_legibleInk(background)` — derived
      // from the garment, with no recipe field to override. Same for size and
      // rotation: the size is fitted to the band, and there is no rotation.
      final c = titled();
      addTearDown(c.dispose);
      final ids = c.wordChoices().map((x) => x.id).toList();
      expect(ids, ['titleFont', 'textPlacement', 'textCase']);
      for (final banned in ['textColour', 'textSize', 'textScale', 'rotation']) {
        expect(ids, isNot(contains(banned)));
      }
    });

    test('the fonts offered are the fonts the generator can produce', () {
      // A picker with its own font table would drift from the generator and
      // start offering faces no generated design ever uses.
      final c = titled();
      addTearDown(c.dispose);
      expect(
        choiceNamed(c, 'titleFont').options.map((o) => o.id).toList(),
        LabShowcaseGenerator.titleFonts,
      );
      for (final o in choiceNamed(c, 'titleFont').options) {
        expect(o.sample, isNotNull, reason: 'a face has to be seen to be picked');
        expect(o.fontFamily, o.id);
      }
    });

    test('every option moves a field the renderer reads', () {
      final c = titled();
      addTearDown(c.dispose);
      for (final choice in c.wordChoices()) {
        final current = choice.read(c.current);
        for (final o in choice.options) {
          if (o.id == current) continue;
          final next = choice.write(c.current, o.id);
          expect(
            next.recipeId,
            isNot(c.current.recipeId),
            reason: '${choice.id}/${o.id} does nothing to this design',
          );
          expect(choice.read(next), o.id);
        }
      }
    });

    test('a title-less design is offered no type treatments', () {
      // With meta['title'] empty the stage returns before it reads the face,
      // the placement or the case — so all three would be inert. A generated
      // design ARRIVES with a title, so this is the state after Clear.
      expect(controller.currentTitle, isNotEmpty);
      controller.commitTitle('');
      expect(controller.currentTitle, isEmpty);
      expect(controller.wordChoices(), isEmpty);
      expect(controller.fineTuneGroups(), isNot(contains(FineTuneGroup.words)));

      controller.commitTitle('EUROPE 2026');
      expect(controller.wordChoices(), hasLength(3));
      expect(controller.fineTuneGroups(), contains(FineTuneGroup.words));
    });

    test('a design that draws its own words is not given a title step', () {
      // A statementHero composition draws the traveller's COUNT as the artwork
      // and TypographyStage never reads meta['title'] for it.
      final c = titled();
      addTearDown(c.dispose);
      expect(c.wordsApply, isTrue);

      c.commitFineTune(
        c.current.copyWith(
          composition: c.current.composition.copyWith(statementHero: true),
        ),
      );
      expect(c.wordsApply, isFalse);
      expect(
        c.wordChoices(),
        isEmpty,
        reason: 'text controls on a design that ignores text',
      );
    });

    test('choosing a face or a case un-hides the title it would set', () {
      // Picking "Classic" on a hidden title must not look like it did nothing.
      final c = titled();
      addTearDown(c.dispose);
      c.commitFineTune(
        choiceNamed(c, 'textPlacement').write(c.current, 'none'),
      );
      expect(c.current.typography!.placement, TextPlacement.none);

      final next = choiceNamed(c, 'titleFont').write(c.current, 'Georgia');
      expect(next.typography!.placement, isNot(TextPlacement.none));
      expect(next.typography!.titleStyle, 'Georgia');
    });
  });

  group('editing the words', () {
    test('a title edit touches the title and nothing else', () {
      final c = buildStudioV2Controller();
      addTearDown(c.dispose);
      c.selectSubject(subject('Flags'));
      c.applyDetailChoice('heart');
      c.setGarment('#FF1B2B');
      c.setSize(SizeClass.small);
      final (style, styled) = c.vibeStyleOptions()[LabStyle.retro.index];
      c.onStyleTap(style, styled);
      c.commitFineTune(
        c.colourChoices()
            .firstWhere((x) => x.id == 'printStyle')
            .write(c.current, 'riso'),
      );
      final codes = c.selectedCountryCodes;
      final before = c.current;

      c.commitTitle('EUROPE 2026');

      expect(c.currentTitle, 'EUROPE 2026');
      expect(c.selectedCountryCodes, codes);
      expect(c.subjectLabel, 'Flags');
      expect(c.currentDetailId, 'heart');
      expect(c.currentStyle, LabStyle.retro);
      expect(c.current.palette?.garmentColour, '#FF1B2B');
      expect(c.current.composition.sizeClass, before.composition.sizeClass);
      expect(c.current.clip?.scale, before.clip?.scale);
      expect(c.current.effects!.riso, greaterThan(0), reason: 'M19 print');
      expect(
        c.current.content.flags,
        before.content.flags,
        reason: 'editing words re-rolled the artwork',
      );
    });

    test('removing the title leaves the design standing', () {
      final c = titled();
      addTearDown(c.dispose);
      final flags = c.current.content.flags;
      c.commitTitle('');
      expect(c.currentTitle, isEmpty);
      expect(c.current.content.flags, flags);
    });

    testWidgets('typing updates the shirt but costs ONE undo step', (
      tester,
    ) async {
      await pumpWords(tester);
      final history = controller.history.length;

      await tester.enterText(find.byKey(const Key('v2-title-field')), 'EUR');
      await tester.pump();
      expect(controller.currentTitle, 'EUR');
      final shirt = tester.widget<ShirtPreview>(
        find.byKey(const Key('v2-garment-preview')),
      );
      expect(shirt.recipe.recipeId, controller.current.recipeId);

      await tester.enterText(
        find.byKey(const Key('v2-title-field')),
        'EUROPE 2026',
      );
      await tester.pump();
      expect(controller.currentTitle, 'EUROPE 2026');

      // Still mid-edit: the whole visit to the field is one step, and it lands
      // when the field is done.
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(
        controller.history.length,
        history + 1,
        reason: 'typing must not flood the undo stack',
      );
    });

    testWidgets('the field stops at the length the renderer can set', (
      tester,
    ) async {
      await pumpWords(tester);
      await tester.enterText(
        find.byKey(const Key('v2-title-field')),
        'A' * 80,
      );
      await tester.pump();
      expect(
        controller.currentTitle.length,
        StudioController.maxTitleLength,
      );
      expect(find.text('30/30'), findsOneWidget);
    });

    testWidgets('a suggestion applies to the title only', (tester) async {
      await pumpWords(tester);
      final before = controller.current.content.flags;
      await tester.tap(find.byKey(const Key('v2-title-suggest')));
      await tester.pump();
      expect(controller.titleIdeas, isNotEmpty);

      await tester.tap(find.byKey(const Key('v2-title-idea-0')));
      await tester.pump();
      expect(controller.currentTitle, controller.titleIdeas.first);
      expect(controller.current.content.flags, before);
    });
  });

  group('reset', () {
    test('it resets the type treatment and nothing else', () {
      final c = titled();
      addTearDown(c.dispose);
      c.applyDetailChoice('heart');
      c.setGarment('#FF1B2B');
      c.setSize(SizeClass.small);
      c.commitFineTune(
        c.colourChoices()
            .firstWhere((x) => x.id == 'printStyle')
            .write(c.current, 'riso'),
      );
      final size = c.current.composition.sizeClass;
      final clipScale = c.current.clip?.scale;

      c.commitFineTune(choiceNamed(c, 'textCase').write(c.current, 'lower'));
      expect(c.current.typography!.textCase, TextCase.lower);

      c.resetFineTune(only: FineTuneGroup.words);

      expect(c.current.typography!.textCase, isNot(TextCase.lower));
      // The words themselves are what the wearer wrote — reset treats type,
      // not text.
      expect(c.currentTitle, 'EUROPE 2026');
      // …and every other group is untouched.
      expect(c.current.effects!.riso, greaterThan(0), reason: 'M19 print');
      expect(c.current.composition.sizeClass, size, reason: 'M17 composition');
      expect(c.current.clip?.scale, clipScale, reason: 'M18 graphics');
      expect(c.current.palette?.garmentColour, '#FF1B2B');
      expect(c.currentDetailId, 'heart');
    });

    test('a scoped reset does not reach into another group', () {
      // Before M20 the Reset button was global: resetting Colour also undid the
      // Layout and Graphics work done two steps earlier.
      final c = titled();
      addTearDown(c.dispose);
      c.setSize(SizeClass.small);
      c.commitFineTune(choiceNamed(c, 'textCase').write(c.current, 'lower'));

      c.resetFineTune(only: FineTuneGroup.colour);

      expect(c.current.composition.sizeClass, SizeClass.small);
      expect(c.current.typography!.textCase, TextCase.lower);
    });
  });

  group('the screen', () {
    testWidgets('it is step 9, with the shirt and the current title', (
      tester,
    ) async {
      controller.commitTitle('EUROPE 2026');
      await pumpWords(tester);
      expect(find.text('Words & Title'), findsOneWidget);
      expect(find.text('9'), findsOneWidget);
      expect(find.byKey(const Key('v2-garment-preview')), findsOneWidget);
      expect(find.byType(ShirtPreview), findsOneWidget);
      expect(find.byKey(const Key('v2-side-front')), findsOneWidget);

      final field = tester.widget<TextField>(
        find.byKey(const Key('v2-title-field')),
      );
      expect(field.controller!.text, 'EUROPE 2026');
      expect(find.text('11/30'), findsOneWidget);
    });

    testWidgets('the type controls appear only once there is a title', (
      tester,
    ) async {
      // A generated design arrives titled, so clear it to reach the state
      // where there is nothing for the type controls to treat.
      controller.commitTitle('');
      await pumpWords(tester);
      expect(find.byKey(const Key('v2-finetune-choice-titleFont')), findsNothing);

      await tester.enterText(
        find.byKey(const Key('v2-title-field')),
        'EUROPE 2026',
      );
      await tester.pump();
      await reveal(tester, const Key('v2-finetune-choice-titleFont'));
      expect(
        find.byKey(const Key('v2-finetune-choice-titleFont')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('v2-finetune-choice-textPlacement')),
        findsOneWidget,
      );
    });

    testWidgets('picking a face changes the design on the shirt', (
      tester,
    ) async {
      controller.commitTitle('EUROPE 2026');
      await pumpWords(tester);
      final before = controller.current.recipeId;
      await reveal(tester, const Key('v2-finetune-titleFont-Georgia'));
      await tester.tap(find.byKey(const Key('v2-finetune-titleFont-Georgia')));
      await tester.pump();

      expect(controller.current.typography!.titleStyle, 'Georgia');
      expect(controller.current.recipeId, isNot(before));
      final shirt = tester.widget<ShirtPreview>(
        find.byKey(const Key('v2-garment-preview')),
      );
      expect(shirt.recipe.recipeId, controller.current.recipeId);
    });

    testWidgets('the clear button removes the title', (tester) async {
      controller.commitTitle('EUROPE 2026');
      await pumpWords(tester);
      await tester.tap(find.byKey(const Key('v2-title-remove')));
      await tester.pump();
      expect(controller.currentTitle, isEmpty);
    });

    testWidgets('nothing overflows a phone', (tester) async {
      controller.commitTitle('EUROPE 2026');
      await pumpWords(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('just looking changes nothing', (tester) async {
      final state = await pump(tester);
      final recipe = controller.current.recipeId;
      final history = controller.history.length;
      state.goToStage(StudioStage.words);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(controller.current.recipeId, recipe);
      expect(controller.history.length, history);
    });
  });

  group('navigation', () {
    testWidgets('the previous step leads here, and Back returns intact', (
      tester,
    ) async {
      final state = await pump(tester);
      // Focus — the M4-era composition tray that M17 largely supersedes —
      // still sits between Colour and Words, so the contextual path runs
      // through it. Retiring Focus is a product decision, not M20's to take.
      state.goToStage(StudioStage.colour);
      await tester.pump();
      final recipe = controller.current.recipeId;

      await tester.tap(find.byKey(const Key('v2-customise-next')));
      await tester.pump();
      expect(state.stage, StudioStage.focus);
      // Focus still wears the older wizard footer rather than the Customise
      // header, which is another reason it reads as a leftover here.
      await tester.tap(find.byKey(const Key('v2-next')));
      await tester.pump();
      expect(state.stage, StudioStage.words);
      expect(controller.current.recipeId, recipe, reason: 'stage ≠ design');

      await tester.tap(find.byKey(const Key('v2-customise-back')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(state.stage, StudioStage.focus);
      expect(controller.current.recipeId, recipe);
    });

    testWidgets('Next leads on to Front Design (M21)', (tester) async {
      final state = await pumpWords(tester);
      await tester.tap(find.byKey(const Key('v2-customise-next')));
      await tester.pump();
      expect(state.stage, StudioStage.front);
    });

    test('a design that ignores text skips the step entirely', () {
      final c = titled();
      addTearDown(c.dispose);
      c.commitFineTune(
        c.current.copyWith(
          composition: c.current.composition.copyWith(statementHero: true),
        ),
      );
      expect(c.wordsApply, isFalse);
    });
  });
}
