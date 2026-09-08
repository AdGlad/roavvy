// M13 — Direction: what the shirt is about. Six choices, drawn from the
// traveller's own countries, with no garment on screen.
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
import 'package:mobile_flutter/features/studio_v2/widgets/direction_workspace.dart';
import 'package:mobile_flutter/features/studio_v2/widgets/shirt_preview.dart';
import 'package:region_lookup/region_lookup.dart';
import 'package:shared_preferences/shared_preferences.dart';

// The Travels step's globe runs tickers for as long as it is mounted, so waits
// in this file are timed pumps rather than pumpAndSettle.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StudioController controller;
  setUp(() {
    // Choosing a vibe teaches the preference model, which persists through
    // shared_preferences. Without a backing store that write throws from
    // inside the plugin and lands on whichever test is running when it fails.
    SharedPreferences.setMockInitialValues({});
    controller = buildStudioV2Controller();
  });
  tearDown(() => controller.dispose());

  Future<StudioV2ScreenState> pump(
    WidgetTester tester, {
    Size size = const Size(390, 844),
  }) async {
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

    tester.view.physicalSize = size;
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

  Future<StudioV2ScreenState> pumpDirection(WidgetTester tester) async {
    final state = await pump(tester);
    state.goToStage(StudioStage.direction);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    return state;
  }

  group('getting here from Travels', () {
    testWidgets('Next from Travels opens Direction with the same design', (
      tester,
    ) async {
      final state = await pump(tester);
      state.goToStage(StudioStage.travels);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final recipe = controller.hero.recipeId;
      final codes = controller.selectedCountryCodes;

      await tester.tap(find.byKey(const Key('v2-customise-next')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(state.stage, StudioStage.direction);
      expect(controller.hero.recipeId, recipe, reason: 'no new design');
      expect(controller.selectedCountryCodes, codes);
    });

    testWidgets('Back returns to Travels with the session intact', (
      tester,
    ) async {
      final state = await pump(tester);
      state.goToStage(StudioStage.travels);
      await tester.pump();
      await tester.tap(find.byKey(const Key('v2-customise-next')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final recipe = controller.hero.recipeId;

      await tester.tap(find.byKey(const Key('v2-customise-back')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(state.stage, StudioStage.travels);
      expect(controller.hero.recipeId, recipe);
    });
  });

  group('the screen', () {
    testWidgets('six directions, asked as a question, with no shirt', (
      tester,
    ) async {
      await pumpDirection(tester);
      expect(find.text('What should lead the design?'), findsOneWidget);
      for (final (title, subtitle) in DirectionWorkspace.copy) {
        expect(find.text(title), findsOneWidget);
        expect(find.text(subtitle), findsOneWidget);
      }
      expect(DirectionWorkspace.copy, hasLength(6));

      // Direction redraws the artwork wholesale — a preview here would show
      // the design about to be replaced.
      expect(find.byType(ShirtPreview), findsNothing);
      expect(find.byKey(const Key('v2-garment-preview')), findsNothing);
      expect(find.byKey(const Key('v2-side-front')), findsNothing);
    });

    testWidgets('the labels match the engine subjects exactly', (tester) async {
      // One Direction model, not two.
      expect(
        [for (final s in StudioController.subjects) s.$3],
        [for (final (t, _) in DirectionWorkspace.copy) t],
      );
    });

    testWidgets('two columns', (tester) async {
      await pumpDirection(tester);
      final first = tester.getRect(find.byKey(const Key('v2-direction-flags')));
      final second = tester.getRect(
        find.byKey(const Key('v2-direction-passport')),
      );
      final third = tester.getRect(find.byKey(const Key('v2-direction-route')));
      expect(second.left, greaterThan(first.left));
      expect(second.top, closeTo(first.top, 1));
      expect(third.top, greaterThan(first.top), reason: 'wraps after two');
      expect(third.left, closeTo(first.left, 1));
    });

    testWidgets('the current direction is selected on arrival', (tester) async {
      await pumpDirection(tester);
      final card = tester.widget<Semantics>(
        find
            .descendant(
              of: find.byKey(
                Key('v2-direction-${controller.subjectLabel.toLowerCase()}'),
              ),
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(card.properties.selected, isTrue);
    });

    testWidgets('nothing overflows a phone', (tester) async {
      for (final size in [const Size(390, 844), const Size(375, 667)]) {
        await pumpDirection(tester);
        expect(tester.takeException(), isNull, reason: '$size');
      }
    });
  });

  group('choosing a direction', () {
    test('it changes the design', () {
      final c = buildStudioV2Controller();
      addTearDown(c.dispose);
      final before = c.current.recipeId;
      c.selectSubject(1);
      expect(c.current.recipeId, isNot(before));
      expect(c.subjectLabel, 'Passport');
    });

    test('the travels are untouched', () {
      final c = buildStudioV2Controller();
      addTearDown(c.dispose);
      final codes = c.selectedCountryCodes;
      final lo = c.yearLo, hi = c.yearHi;
      c.selectSubject(2);
      expect(c.selectedCountryCodes, codes);
      expect(c.yearLo, lo);
      expect(c.yearHi, hi);
    });

    test('the garment colour is untouched', () {
      final c = buildStudioV2Controller();
      addTearDown(c.dispose);
      c.setGarment('#FF1B2B');
      c.selectSubject(3);
      expect(c.current.palette?.garmentColour, '#FF1B2B');
    });

    test('the title they typed is untouched', () {
      // A bare regeneration used to throw this away.
      final c = buildStudioV2Controller();
      addTearDown(c.dispose);
      c.setSide(false);
      c.commitTitle('EUROPE 2026');
      c.selectSubject(4);
      expect(c.currentTitle, 'EUROPE 2026');
    });

    test('the vibe they picked is kept', () {
      final c = buildStudioV2Controller();
      addTearDown(c.dispose);
      final options = c.vibeStyleOptions();
      final (style, styled) = options[3];
      c.onStyleTap(style, styled);
      expect(c.currentStyle, style);

      c.selectSubject(1);
      expect(
        c.currentStyle,
        style,
        reason: 'changing the subject is not changing the style',
      );
    });

    testWidgets('tapping a card selects it and redraws the design', (
      tester,
    ) async {
      await pumpDirection(tester);
      final before = controller.current.recipeId;
      await tester.tap(find.byKey(const Key('v2-direction-words')));
      await tester.pump();
      expect(controller.subjectLabel, 'Words');
      expect(controller.current.recipeId, isNot(before));
    });

    testWidgets('just looking at the screen changes nothing', (tester) async {
      // Rendering six cards must not touch the design or the undo history.
      final state = await pump(tester);
      final recipe = controller.current.recipeId;
      final history = controller.history.length;
      state.goToStage(StudioStage.direction);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(controller.current.recipeId, recipe);
      expect(controller.history.length, history);
    });
  });

  group('the way on to Detail (M14)', () {
    testWidgets('Flags leads to Detail, which has shapes to offer', (
      tester,
    ) async {
      final state = await pumpDirection(tester);
      await tester.tap(find.byKey(const Key('v2-direction-flags')));
      await tester.pump();
      expect(controller.detailApplies, isTrue);

      await tester.tap(find.byKey(const Key('v2-customise-next')));
      await tester.pump();
      expect(state.stage, StudioStage.detail);
    });

    testWidgets('a direction with no detail skips the step', (tester) async {
      // World IS the word-cloud family — there is no sibling to choose
      // between, so the Detail step has nothing to ask. (Passport, Route and
      // Milestones all DO have choices; see the M14 tests.)
      final state = await pumpDirection(tester);
      await tester.tap(find.byKey(const Key('v2-direction-world')));
      await tester.pump();
      expect(controller.detailApplies, isFalse);

      await tester.tap(find.byKey(const Key('v2-customise-next')));
      await tester.pump();
      expect(
        state.stage,
        isNot(StudioStage.detail),
        reason: 'an empty step is not a step',
      );
    });
  });
}
