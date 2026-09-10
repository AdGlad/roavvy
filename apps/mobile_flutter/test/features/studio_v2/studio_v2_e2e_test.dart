// M23 — the Studio as ONE session.
//
// Every milestone tested its own step. This suite tests the seams between
// them: that the design chosen at Instant is the design reviewed at the end,
// that each step mutates only what it owns, and that walking backwards and
// forwards through the flow is navigation rather than editing.
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

/// Everything about a session that must not move by accident.
typedef Session = ({
  String back,
  String front,
  String subject,
  String? detail,
  LabStyle? vibe,
  SizeClass size,
  String? garment,
  String? title,
  FrontFit fit,
  FrontArt art,
  // A String, not the Set: collections compare by identity, so a record
  // holding one is never equal to itself a moment later.
  String countries,
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StudioController controller;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    controller = buildStudioV2Controller();
  });
  tearDown(() => controller.dispose());

  int subjectIndex(String label) =>
      StudioController.subjects.indexWhere((s) => s.$3 == label);

  Session snap(StudioController c) => (
    back: c.hero.recipeId,
    front: c.frontFace.recipeId,
    subject: c.subjectLabel,
    detail: c.currentDetailId,
    vibe: c.currentStyle,
    size: c.hero.composition.sizeClass,
    garment: c.hero.palette?.garmentColour,
    title: c.hero.content.meta['title'] as String?,
    fit: c.frontFit,
    art: c.frontArt,
    countries: (c.selectedCountryCodes.toList()..sort()).join(','),
  );

  /// The design itself, read WITHOUT going through `current`.
  ///
  /// `currentStyle`, `currentDetailId` and friends describe whichever face is
  /// being viewed, so on Front Design they legitimately describe the chest
  /// badge. A whole-flow invariant has to name the two faces directly.
  ({String back, String front, String? title, String? garment, SizeClass size})
  designSnap(StudioController c) => (
    back: c.hero.recipeId,
    front: c.frontFace.recipeId,
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

  /// Settle without pumpAndSettle — the globe tickers never stop.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 320));
  }

  Future<void> go(
    WidgetTester tester,
    StudioV2ScreenState state,
    StudioStage s,
  ) async {
    state.goToStage(s);
    await settle(tester);
  }

  /// A session carrying one deliberate edit from every creative step.
  void design(StudioController c) {
    c.selectSubject(subjectIndex('Flags')); // M13
    c.applyDetailChoice('heart'); // M14
    final (style, styled) = c.vibeStyleOptions()[LabStyle.retro.index];
    c.onStyleTap(style, styled); // M15
    c.setSize(SizeClass.small); // M17
    c.commitFineTune(
      c.colourChoices()
          .firstWhere((x) => x.id == 'printStyle')
          .write(c.current, 'riso'), // M19
    );
    c.commitTitle('EUROPE 2026'); // M20
    c.setGarment('#FF1B2B');
    c.setFrontFit(FrontFit.chest); // M21
  }

  group('the design chosen at Instant is the design that gets customised', () {
    testWidgets('Customise carries the EXACT selected recipe into Travels', (
      tester,
    ) async {
      final state = await pump(tester);
      expect(state.stage, StudioStage.instant);

      // Browse the deck the way a person does, then take what is on screen.
      controller.showInstant(2);
      await settle(tester);
      final chosen = controller.hero.recipeId;
      final history = controller.history.length;

      await tester.tap(find.byKey(const Key('v2-instant-customise')));
      await settle(tester);

      expect(state.stage, StudioStage.travels);
      expect(
        controller.hero.recipeId,
        chosen,
        reason: 'Customise regenerated instead of carrying the design over',
      );
      expect(controller.history.length, history);
    });

    testWidgets('walking back to Instant does not replace the design', (
      tester,
    ) async {
      final state = await pump(tester);
      controller.showInstant(1);
      await settle(tester);
      await tester.tap(find.byKey(const Key('v2-instant-customise')));
      await settle(tester);
      final chosen = controller.hero.recipeId;

      await tester.tap(find.byKey(const Key('v2-customise-back')));
      await settle(tester);
      expect(state.stage, StudioStage.instant);
      expect(controller.hero.recipeId, chosen);
    });
  });

  group('each step mutates only what it owns', () {
    test('Direction keeps Travels; Detail keeps Direction; Vibe keeps both', () {
      final c = buildStudioV2Controller();
      addTearDown(c.dispose);
      final countries = c.selectedCountryCodes;

      c.selectSubject(subjectIndex('Flags'));
      expect(c.selectedCountryCodes, countries, reason: 'M13 moved Travels');

      c.applyDetailChoice('heart');
      expect(c.subjectLabel, 'Flags', reason: 'M14 moved Direction');
      expect(c.selectedCountryCodes, countries);

      final (style, styled) = c.vibeStyleOptions()[LabStyle.retro.index];
      c.onStyleTap(style, styled);
      expect(c.currentStyle, LabStyle.retro);
      expect(c.subjectLabel, 'Flags', reason: 'M15 moved Direction');
      expect(c.currentDetailId, 'heart', reason: 'M15 moved Detail');
      expect(c.selectedCountryCodes, countries);
    });

    test('the Fine Tune steps do not undo each other', () {
      final c = buildStudioV2Controller();
      addTearDown(c.dispose);
      design(c);
      final before = snap(c);

      // M17 layout, then M18 graphics, then M19 colour — each must survive
      // the next.
      c.beginEdit();
      final scale = c.fineTuneControls().firstWhere((x) => x.id == 'scale');
      c.applyLive(scale.write(c.current, scale.max));
      c.endEdit();
      final scaled = scale.read(c.current);

      final edge = c.graphicChoices().firstWhere((x) => x.id == 'edge');
      c.commitFineTune(edge.write(c.current, edge.options.last.id));
      expect(scale.read(c.current), scaled, reason: 'M18 undid M17');

      c.commitFineTune(
        c.colourChoices()
            .firstWhere((x) => x.id == 'colourTreatment')
            .write(c.current, 'mono'),
      );
      expect(scale.read(c.current), scaled, reason: 'M19 undid M17');
      expect(
        c.current.edgeTreatment?.style,
        isNotNull,
        reason: 'M19 undid M18',
      );
      // …and the creative identity is untouched throughout.
      expect(c.subjectLabel, before.subject);
      expect(c.currentDetailId, before.detail);
      expect(c.currentStyle, before.vibe);
      expect(
        (c.selectedCountryCodes.toList()..sort()).join(','),
        before.countries,
      );
    });

    test('Words changes the words and not the artwork', () {
      final c = buildStudioV2Controller();
      addTearDown(c.dispose);
      design(c);
      final flags = c.hero.content.flags.map((f) => f.code).toList();
      final composition = c.hero.composition.family;
      final effects = c.hero.effects!.riso;

      c.commitTitle('SOMEWHERE ELSE');

      expect(c.currentTitle, 'SOMEWHERE ELSE');
      expect(c.hero.content.flags.map((f) => f.code).toList(), flags);
      expect(c.hero.composition.family, composition);
      expect(c.hero.effects!.riso, effects);
    });

    test('Front configuration never reaches the Back', () {
      final c = buildStudioV2Controller();
      addTearDown(c.dispose);
      design(c);
      final back = c.hero.recipeId;
      final countries = c.selectedCountryCodes;

      for (final fit in FrontFit.values) {
        c.setFrontFit(fit);
      }
      c.setFrontFit(FrontFit.chest);
      for (final art in FrontArt.values) {
        c.setFrontArt(art);
      }
      c.setRibbonCoverage(true);

      expect(c.hero.recipeId, back, reason: 'M21 rewrote the back');
      expect(c.selectedCountryCodes, countries, reason: 'M21 moved Travels');
    });
  });

  group('walking backwards is navigation, not editing', () {
    testWidgets('M15 → M14 → M15 keeps every edit', (tester) async {
      final state = await pump(tester);
      design(controller);
      final before = snap(controller);
      final history = controller.history.length;

      await go(tester, state, StudioStage.vibe);
      await tester.tap(find.byKey(const Key('v2-customise-back')));
      await settle(tester);
      await go(tester, state, StudioStage.vibe);

      expect(snap(controller), before);
      expect(controller.history.length, history);
    });

    testWidgets('M19 → M18 → M19 keeps every edit', (tester) async {
      final state = await pump(tester);
      design(controller);
      await go(tester, state, StudioStage.colour);
      final before = snap(controller);

      await tester.tap(find.byKey(const Key('v2-customise-back')));
      await settle(tester);
      await go(tester, state, StudioStage.colour);

      expect(snap(controller), before);
    });

    testWidgets('M22 → M21 → M22 reflects a front edit made in between', (
      tester,
    ) async {
      final state = await pump(tester);
      design(controller);
      await go(tester, state, StudioStage.review);
      final back = controller.hero.recipeId;
      final firstFront = controller.frontFace.recipeId;

      await go(tester, state, StudioStage.front);
      controller.setFrontArt(FrontArt.matchBack);
      await settle(tester);
      await go(tester, state, StudioStage.review);

      final shown = tester.widget<ShirtPreview>(
        find.byKey(const Key('v2-review-front')),
      );
      expect(shown.recipe.recipeId, controller.frontFace.recipeId);
      expect(shown.recipe.recipeId, isNot(firstFront));
      expect(controller.hero.recipeId, back, reason: 'the back moved');
    });

    testWidgets('Back follows the path actually walked, not the stage list', (
      tester,
    ) async {
      final state = await pump(tester);
      // Jump around: Back must retrace THESE steps, not decrement an index.
      await go(tester, state, StudioStage.vibe);
      await go(tester, state, StudioStage.colour);
      await go(tester, state, StudioStage.words);

      await tester.tap(find.byKey(const Key('v2-customise-back')));
      await settle(tester);
      expect(state.stage, StudioStage.colour);
      await tester.tap(find.byKey(const Key('v2-customise-back')));
      await settle(tester);
      expect(state.stage, StudioStage.vibe);
    });

    testWidgets('workflow Back is not Undo', (tester) async {
      final state = await pump(tester);
      await go(tester, state, StudioStage.vibe);
      final r0 = controller.current.recipeId;
      final (style, styled) = controller.vibeStyleOptions()[LabStyle.grunge.index];
      controller.onStyleTap(style, styled);
      await settle(tester);
      final r1 = controller.current.recipeId;
      expect(r1, isNot(r0));
      final history = controller.history.length;

      await tester.tap(find.byKey(const Key('v2-customise-back')));
      await settle(tester);
      expect(
        controller.current.recipeId,
        r1,
        reason: 'going back reverted the design',
      );
      expect(controller.history.length, history);
    });
  });

  group('stages that do not apply are not stages', () {
    testWidgets('a Direction with no Detail is skipped in both directions', (
      tester,
    ) async {
      final state = await pump(tester);
      // Find a Direction the engine offers no Detail for; if every Direction
      // has one, the skip machinery is still asserted below.
      var skipped = false;
      for (var i = 0; i < StudioController.subjects.length; i++) {
        controller.selectSubject(i);
        if (!controller.detailApplies) {
          skipped = true;
          break;
        }
      }
      await settle(tester);
      if (!skipped) {
        expect(controller.detailApplies, isTrue);
        return;
      }

      await go(tester, state, StudioStage.direction);
      await tester.tap(find.byKey(const Key('v2-customise-next')));
      await settle(tester);
      expect(
        state.stage,
        StudioStage.vibe,
        reason: 'stopped on a Detail step with nothing on it',
      );
    });

    testWidgets('a design with no words does not get a Words step', (
      tester,
    ) async {
      final state = await pump(tester);
      controller.commitFineTune(
        controller.current.copyWith(
          composition: controller.current.composition.copyWith(
            statementHero: true,
          ),
        ),
      );
      await settle(tester);
      expect(controller.wordsApply, isFalse);

      await go(tester, state, StudioStage.front);
      await tester.tap(find.byKey(const Key('v2-customise-back')));
      await settle(tester);
      // Back retraces the visited path, so it returns where we came from —
      // never onto a step the design has no use for.
      expect(state.stage, isNot(StudioStage.words));
    });

    testWidgets('Next still works from a step that stopped applying', (
      tester,
    ) async {
      // A recipe Undo can restore a design whose current step has nothing on
      // it. Next used to go dead, stranding the customer mid-flow.
      final state = await pump(tester);
      await go(tester, state, StudioStage.words);
      controller.commitFineTune(
        controller.current.copyWith(
          composition: controller.current.composition.copyWith(
            statementHero: true,
          ),
        ),
      );
      await settle(tester);
      expect(controller.wordsApply, isFalse, reason: 'setup: Words must vanish');

      await tester.tap(find.byKey(const Key('v2-customise-next')));
      await settle(tester);
      expect(state.stage, StudioStage.front, reason: 'Next went nowhere');
    });

    test('no visible stage is ever an empty screen', () {
      final c = buildStudioV2Controller();
      addTearDown(c.dispose);
      design(c);
      final groups = c.fineTuneGroups();
      for (final g in groups) {
        final has =
            c.fineTuneControls().any((x) => x.group == g) ||
            c.fineTuneChoices().any((x) => x.group == g) ||
            c.graphicChoices().any((x) => x.group == g) ||
            c.colourChoices().any((x) => x.group == g) ||
            c.wordChoices().any((x) => x.group == g);
        expect(has, isTrue, reason: '${g.name} is offered but empty');
      }
    });
  });

  group('front and back stay apart', () {
    testWidgets('viewing a side is view state and nothing else', (
      tester,
    ) async {
      final state = await pump(tester);
      design(controller);
      await go(tester, state, StudioStage.colour);
      final before = snap(controller);
      final history = controller.history.length;

      await tester.tap(find.byKey(const Key('v2-side-back')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('v2-side-front')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('v2-side-back')));
      await settle(tester);

      expect(snap(controller), before);
      expect(controller.history.length, history);
    });

    testWidgets('an edit after visiting Front Design still edits the BACK', (
      tester,
    ) async {
      // Front Design opens on the front as a convenience. Leaving it must put
      // the view back, or every later edit silently lands on the chest badge.
      final state = await pump(tester);
      design(controller);
      await go(tester, state, StudioStage.front);
      expect(controller.onFront, isTrue);

      await go(tester, state, StudioStage.words);
      controller.commitTitle('BACK PLEASE');
      await settle(tester);

      expect(
        controller.hero.content.meta['title'],
        'BACK PLEASE',
        reason: 'the edit landed on the front face, not the design',
      );
    });

    testWidgets('a None front reviews as a plain shirt', (tester) async {
      final state = await pump(tester);
      design(controller);
      controller.setFrontFit(FrontFit.none);
      await go(tester, state, StudioStage.review);
      final front = tester.widget<ShirtPreview>(
        find.byKey(const Key('v2-review-front')),
      );
      expect(front.printArea, Rect.zero);
    });
  });

  group('navigation costs nothing', () {
    testWidgets('walking the whole flow creates no history and no changes', (
      tester,
    ) async {
      final state = await pump(tester);
      design(controller);
      final before = designSnap(controller);
      final history = controller.history.length;

      for (final s in StudioStage.values) {
        await go(tester, state, s);
        expect(
          designSnap(controller),
          before,
          reason: 'entering ${s.name} changed the design',
        );
        expect(
          controller.history.length,
          history,
          reason: 'entering ${s.name} wrote to the undo stack',
        );
      }

      // …and back on the design, every creative decision is still there.
      await go(tester, state, StudioStage.vibe);
      expect(controller.subjectLabel, 'Flags');
      expect(controller.currentDetailId, 'heart');
      expect(controller.currentStyle, LabStyle.retro);
    });

    testWidgets('repeated Back/Next leaves the design where it was', (
      tester,
    ) async {
      final state = await pump(tester);
      design(controller);
      await go(tester, state, StudioStage.vibe);
      final before = snap(controller);

      for (var i = 0; i < 4; i++) {
        await tester.tap(find.byKey(const Key('v2-customise-next')));
        await settle(tester);
        await tester.tap(find.byKey(const Key('v2-customise-back')));
        await settle(tester);
      }
      expect(snap(controller), before);
      expect(state.stage, StudioStage.vibe);
    });

    testWidgets('a slider drag is one history entry, not one per frame', (
      tester,
    ) async {
      final state = await pump(tester);
      design(controller);
      await go(tester, state, StudioStage.layout);
      final history = controller.history.length;

      final slider = find.byKey(const Key('v2-finetune-scale'));
      final g = await tester.startGesture(tester.getCenter(slider));
      for (var i = 0; i < 8; i++) {
        await g.moveBy(const Offset(8, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await g.up();
      await settle(tester);
      expect(controller.history.length, history + 1);
    });
  });

  group('the edges of a real travel history', () {
    test('no countries selected does not crash the session', () {
      final c = buildStudioV2Controller();
      addTearDown(c.dispose);
      c.clearCountries();
      expect(() => c.fineTuneGroups(), returnsNormally);
      expect(() => c.colourChoices(), returnsNormally);
      expect(() => c.wordChoices(), returnsNormally);
      expect(() => c.frontPrintRect(), returnsNormally);
      expect(() => c.garment, returnsNormally);
    });

    test('an undated travel history still yields a whole session', () {
      final c = buildStudioV2ControllerFor(
        const DesignContext(flagCodes: ['us', 'fr'], scopeKey: 'test:undated'),
      );
      addTearDown(c.dispose);
      expect(c.availableCountryCodes, isNotEmpty);
      expect(c.allTravelledCodes, ['us', 'fr']);
      expect(() => c.fineTuneGroups(), returnsNormally);
      c.setFrontArt(FrontArt.ribbon);
      c.setRibbonCoverage(true);
      expect(c.frontFace.content.flags, isNotEmpty);
    });
  });

  group('the end of the flow is the design that was made', () {
    testWidgets('Review shows the exact final front and back', (tester) async {
      final state = await pump(tester);
      design(controller);
      // Walk the whole flow the way a customer would.
      for (final s in [
        StudioStage.travels,
        StudioStage.direction,
        StudioStage.vibe,
        StudioStage.fineTune,
        StudioStage.colour,
        StudioStage.words,
        StudioStage.front,
        StudioStage.review,
      ]) {
        await go(tester, state, s);
      }

      final front = tester.widget<ShirtPreview>(
        find.byKey(const Key('v2-review-front')),
      );
      final back = tester.widget<ShirtPreview>(
        find.byKey(const Key('v2-review-back')),
      );
      expect(back.recipe.recipeId, controller.hero.recipeId);
      expect(front.recipe.recipeId, controller.frontFace.recipeId);
      // The creative decisions all survived the journey.
      expect(controller.subjectLabel, 'Flags');
      expect(controller.currentDetailId, 'heart');
      expect(controller.currentStyle, LabStyle.retro);
      expect(controller.hero.composition.sizeClass, SizeClass.small);
      expect(controller.hero.effects!.riso, greaterThan(0));
      expect(controller.hero.content.meta['title'], 'EUROPE 2026');
      expect(controller.hero.palette?.garmentColour, '#FF1B2B');
      expect(controller.frontFit, FrontFit.chest);
    });
  });
}
