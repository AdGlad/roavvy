// M21 — Front Design: an optional front beside a FINISHED back.
//
// The one thing this step must never do is disturb the design the customer
// just spent nine steps on. Most of what follows is that promise, stated in
// as many ways as there are routes to breaking it.
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

  /// A back design carrying an edit from every step M17–M20, so that anything
  /// M21 disturbs shows up by name.
  StudioController finishedBack() {
    final c = buildStudioV2Controller();
    c.selectSubject(subject('Flags'));
    c.applyDetailChoice('heart');
    c.setGarment('#FF1B2B');
    c.setSize(SizeClass.small); // M17
    final (style, styled) = c.vibeStyleOptions()[LabStyle.retro.index];
    c.onStyleTap(style, styled);
    c.commitFineTune(
      c.colourChoices()
          .firstWhere((x) => x.id == 'printStyle')
          .write(c.current, 'riso'), // M19
    );
    c.commitTitle('EUROPE 2026'); // M20
    return c;
  }

  /// Everything about the back that must survive this step.
  ({String id, String? title, String? garment, SizeClass size}) backOf(
    StudioController c,
  ) => (
    id: c.hero.recipeId,
    title: c.hero.content.meta['title'] as String?,
    garment: c.hero.palette?.garmentColour,
    size: c.hero.composition.sizeClass,
  );

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

  /// The controls sheet is short; bring a control into view before touching it.
  Future<void> reveal(WidgetTester tester, Key key) async {
    await tester.scrollUntilVisible(
      find.byKey(key),
      160,
      scrollable:
          find
              .descendant(
                of: find.byKey(const Key('v2-front-scroll')),
                matching: find.byType(Scrollable),
              )
              .first,
    );
    await tester.ensureVisible(find.byKey(key));
    await tester.pump();
  }

  Future<StudioV2ScreenState> pumpFront(WidgetTester tester) async {
    final state = await pump(tester);
    state.goToStage(StudioStage.front);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    return state;
  }

  group('the back is finished, and stays finished', () {
    test('no front choice touches the back design', () {
      final c = finishedBack();
      addTearDown(c.dispose);
      final before = backOf(c);

      for (final fit in FrontFit.values) {
        c.setFrontFit(fit);
        expect(backOf(c), before, reason: 'fit ${fit.name} moved the back');
      }
      c.setFrontFit(FrontFit.chest);
      for (final right in [true, false]) {
        c.setChestSide(right);
        expect(backOf(c), before, reason: 'chest side moved the back');
      }
      for (final art in FrontArt.values) {
        c.setFrontArt(art);
        expect(backOf(c), before, reason: 'art ${art.name} moved the back');
      }
      c.setFrontArt(FrontArt.ribbon);
      for (final all in [true, false]) {
        c.setRibbonCoverage(all);
        expect(backOf(c), before, reason: 'ribbon coverage moved the back');
      }
    });

    test('the back keeps every M17–M20 edit through the front step', () {
      final c = finishedBack();
      addTearDown(c.dispose);
      c.setFrontFit(FrontFit.full);
      c.setFrontArt(FrontArt.complement);

      expect(c.hero.composition.sizeClass, SizeClass.small, reason: 'M17');
      expect(c.hero.clip, isNotNull, reason: 'M18');
      expect(c.hero.effects!.riso, greaterThan(0), reason: 'M19');
      expect(c.hero.content.meta['title'], 'EUROPE 2026', reason: 'M20');
      expect(c.hero.palette?.garmentColour, '#FF1B2B');
      expect(c.currentDetailId, 'heart');
      expect(c.currentStyle, LabStyle.retro);
    });

    test('a wider ribbon does not widen the design', () {
      // "All travelled" is a FRONT ribbon setting. It must not reach back into
      // the countries this design is of.
      final c = finishedBack();
      addTearDown(c.dispose);
      c.setSelectedCountries([c.availableCountryCodes.first]);
      final selected = c.selectedCountryCodes;
      final back = backOf(c);

      c.setFrontArt(FrontArt.ribbon);
      c.setRibbonCoverage(true);

      expect(c.selectedCountryCodes, selected, reason: 'M12 selection moved');
      expect(backOf(c), back, reason: 'the back followed the ribbon');
      expect(
        c.frontFace.content.flags.length,
        greaterThan(c.hero.content.flags.length),
        reason: 'All travelled showed no more countries than Selected',
      );
    });
  });

  group('the front modes', () {
    test('None prints nothing, and leaves the back alone', () {
      final c = finishedBack();
      addTearDown(c.dispose);
      final back = backOf(c);
      c.setFrontFit(FrontFit.none);
      expect(c.frontPrintRect(), Rect.zero);
      expect(backOf(c), back);
    });

    test('Full and Chest print somewhere, and Chest moves with the side', () {
      final c = finishedBack();
      addTearDown(c.dispose);
      c.setFrontFit(FrontFit.full);
      expect(c.frontPrintRect().isEmpty, isFalse);

      c.setFrontFit(FrontFit.chest);
      c.setChestSide(false);
      final left = c.frontPrintRect();
      c.setChestSide(true);
      expect(c.frontPrintRect(), isNot(left));
      expect(
        c.frontPrintRect().width,
        closeTo(left.width, 1e-9),
        reason: 'same badge size',
      );
    });

    test('the diagram is drawn from the rect the printer is given', () {
      final c = finishedBack();
      addTearDown(c.dispose);
      c.setFrontFit(FrontFit.chest);
      for (final fit in FrontFit.values) {
        c.setFrontFit(fit);
        expect(c.frontPrintRectFor(fit), c.frontPrintRect());
      }
    });

    test('each artwork choice produces a different front', () {
      final c = finishedBack();
      addTearDown(c.dispose);
      final seen = <String>{};
      for (final art in FrontArt.values) {
        c.setFrontArt(art);
        seen.add(c.frontFace.recipeId);
      }
      expect(seen, hasLength(FrontArt.values.length));

      // Match back is exactly the back — that is what the name promises.
      c.setFrontArt(FrontArt.matchBack);
      expect(c.frontFace.recipeId, c.hero.recipeId);
    });

    test('the ribbon front drops the back title rather than reprinting it', () {
      final c = finishedBack();
      addTearDown(c.dispose);
      c.setFrontArt(FrontArt.ribbon);
      expect(c.hero.content.meta['title'], 'EUROPE 2026');
      expect(c.frontFace.content.meta['title'], isNull);
    });
  });

  group('the front survives a trip back through the flow', () {
    test('changing travels no longer discards the chosen front artwork', () {
      // The front was rebuilt as a ribbon wherever the back changed, so going
      // back to Travels and toggling one country silently threw away a
      // Match-back or Complement front.
      final c = finishedBack();
      addTearDown(c.dispose);
      c.setFrontArt(FrontArt.matchBack);

      c.setSelectedCountries(c.availableCountryCodes.take(3).toList());

      expect(c.frontArt, FrontArt.matchBack);
      expect(
        c.frontFace.recipeId,
        c.hero.recipeId,
        reason: 'the front stopped matching the back it is meant to match',
      );
    });

    test('a complement follows the back without becoming a new design', () {
      final c = finishedBack();
      addTearDown(c.dispose);
      c.setFrontArt(FrontArt.complement);
      final first = c.frontFace.recipeId;

      // Same back, rebuilt: the complement must be stable.
      c.setChestSide(true);
      expect(c.frontFace.recipeId, first);
      expect(c.frontArt, FrontArt.complement);
    });
  });

  group('reset', () {
    test('it resets the front only', () {
      final c = finishedBack();
      addTearDown(c.dispose);
      final back = backOf(c);
      c.setFrontFit(FrontFit.full);
      c.setChestSide(true);
      c.setFrontArt(FrontArt.matchBack);

      c.resetFront();

      expect(c.frontFit, FrontFit.chest);
      expect(c.chestRight, isFalse);
      expect(c.frontArt, FrontArt.ribbon);
      expect(c.ribbonAllCountries, isFalse);
      // …and the back is exactly as it was.
      expect(backOf(c), back);
      expect(c.hero.effects!.riso, greaterThan(0));
      expect(c.currentDetailId, 'heart');
    });
  });

  group('the screen', () {
    testWidgets('it is step 10, and it opens on the front', (tester) async {
      await pumpFront(tester);
      expect(find.text('Front Design'), findsOneWidget);
      expect(find.text('10'), findsOneWidget);
      expect(controller.onFront, isTrue);
      final shirt = tester.widget<ShirtPreview>(
        find.byKey(const Key('v2-garment-preview')),
      );
      expect(shirt.front, isTrue);
      expect(shirt.recipe.recipeId, controller.frontFace.recipeId);
    });

    testWidgets('viewing the back changes the view and nothing else', (
      tester,
    ) async {
      await pumpFront(tester);
      final back = backOf(controller);
      final front = controller.frontFace.recipeId;
      final history = controller.history.length;

      await tester.tap(find.byKey(const Key('v2-side-back')));
      await tester.pump();
      expect(controller.onFront, isFalse);
      await tester.tap(find.byKey(const Key('v2-side-front')));
      await tester.pump();

      expect(controller.onFront, isTrue);
      expect(controller.history.length, history, reason: 'looking is not an edit');
      expect(backOf(controller), back);
      expect(controller.frontFace.recipeId, front);
    });

    testWidgets('the controls appear only when they apply', (tester) async {
      await pumpFront(tester);
      controller.setFrontFit(FrontFit.none);
      await tester.pump();
      // Nothing prints, so there is nothing to place or to make it from.
      expect(find.byKey(const Key('v2-front-chest-left')), findsNothing);
      expect(find.byKey(const Key('v2-front-art-ribbon')), findsNothing);
      expect(find.byKey(const Key('v2-front-ribbon-all')), findsNothing);

      controller.setFrontFit(FrontFit.full);
      await tester.pump();
      // A full front has artwork but no chest side.
      expect(find.byKey(const Key('v2-front-chest-left')), findsNothing);
      await reveal(tester, const Key('v2-front-art-ribbon'));
      expect(find.byKey(const Key('v2-front-art-ribbon')), findsOneWidget);

      controller.setFrontFit(FrontFit.chest);
      await tester.pump();
      await reveal(tester, const Key('v2-front-chest-left'));
      expect(find.byKey(const Key('v2-front-chest-left')), findsOneWidget);
      await reveal(tester, const Key('v2-front-ribbon-all'));
      expect(find.byKey(const Key('v2-front-ribbon-all')), findsOneWidget);

      // Only a ribbon has a country list to widen.
      controller.setFrontArt(FrontArt.matchBack);
      await tester.pump();
      expect(find.byKey(const Key('v2-front-ribbon-all')), findsNothing);
    });

    testWidgets('choosing a front updates the front preview', (tester) async {
      await pumpFront(tester);
      final before = controller.frontFace.recipeId;
      await reveal(tester, const Key('v2-front-art-matchback'));
      await tester.tap(find.byKey(const Key('v2-front-art-matchback')));
      await tester.pump();

      expect(controller.frontFace.recipeId, isNot(before));
      final shirt = tester.widget<ShirtPreview>(
        find.byKey(const Key('v2-garment-preview')),
      );
      expect(shirt.recipe.recipeId, controller.frontFace.recipeId);
    });

    testWidgets('Reset front is on the screen and spares the back', (
      tester,
    ) async {
      await pumpFront(tester);
      final back = backOf(controller);
      controller.setFrontFit(FrontFit.full);
      await tester.pump();

      await reveal(tester, const Key('v2-front-reset'));
      await tester.tap(find.byKey(const Key('v2-front-reset')));
      await tester.pump();
      expect(controller.frontFit, FrontFit.chest);
      expect(backOf(controller), back);
    });

    testWidgets('nothing overflows a phone', (tester) async {
      await pumpFront(tester);
      expect(tester.takeException(), isNull);
      controller.setFrontFit(FrontFit.none);
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('just looking changes nothing', (tester) async {
      final state = await pump(tester);
      final back = backOf(controller);
      final history = controller.history.length;
      state.goToStage(StudioStage.front);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(backOf(controller), back);
      expect(controller.history.length, history);
    });
  });

  group('navigation', () {
    testWidgets('Words leads here, and Back returns the session intact', (
      tester,
    ) async {
      final state = await pump(tester);
      state.goToStage(StudioStage.words);
      await tester.pump();
      final back = backOf(controller);

      await tester.tap(find.byKey(const Key('v2-customise-next')));
      await tester.pump();
      expect(state.stage, StudioStage.front);

      await tester.tap(find.byKey(const Key('v2-customise-back')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(state.stage, StudioStage.words);
      expect(backOf(controller), back);
    });

    testWidgets('Next leads on towards Review & Buy', (tester) async {
      // Placement still sits between Front and Review — an earlier step that
      // the redesigned flow has not yet absorbed.
      final state = await pumpFront(tester);
      await tester.tap(find.byKey(const Key('v2-customise-next')));
      await tester.pump();
      expect(state.stage, StudioStage.placement);
    });

    test('both sides are available to Review', () {
      final c = finishedBack();
      addTearDown(c.dispose);
      c.setFrontFit(FrontFit.chest);
      c.setFrontArt(FrontArt.ribbon);
      expect(c.hero, isNotNull);
      expect(c.frontFace, isNotNull);
      expect(c.frontFace.recipeId, isNot(c.hero.recipeId));
    });
  });
}
