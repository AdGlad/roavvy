// M14 — Direction Detail: how the chosen Direction is expressed. Contextual by
// construction, and skipped where the engine has nothing to offer.
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
import 'package:mobile_flutter/features/studio_v2/widgets/detail_workspace.dart';
import 'package:mobile_flutter/features/studio_v2/widgets/shirt_preview.dart';
import 'package:region_lookup/region_lookup.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StudioController controller;
  setUp(() {
    // Choosing a Detail can teach the preference model, which persists.
    SharedPreferences.setMockInitialValues({});
    controller = buildStudioV2Controller();
  });
  tearDown(() => controller.dispose());

  /// Subject indices, by the label the Direction step shows.
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

  Future<StudioV2ScreenState> pumpDetail(WidgetTester tester) async {
    final state = await pump(tester);
    state.goToStage(StudioStage.detail);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    return state;
  }

  group('the options depend on the Direction', () {
    test('each Direction gets its own set, or none', () {
      final c = buildStudioV2Controller();
      addTearDown(c.dispose);
      final byDirection = <String, List<String>>{};
      for (final s in StudioController.subjects) {
        c.selectSubject(subject(s.$3));
        byDirection[s.$3] = [for (final d in c.detailChoices) d.id];
      }

      // Backed by real engine capability, not one universal list.
      expect(byDirection['Flags'], [
        'grid',
        'circle',
        'map',
        'heart',
        'animals',
        'plants',
        'landmarks',
      ]);
      expect(byDirection['Passport'], ['passportPage', 'passportStampOutline']);
      expect(byDirection['Route'], ['journeys', 'timeline']);
      expect(byDirection['Milestones'], ['badge', 'achievements', 'stats']);

      // World IS the word-cloud family and Words IS the single typographic
      // subject — neither has a sibling to choose between.
      expect(byDirection['World'], isEmpty);
      expect(byDirection['Words'], isEmpty);

      // No two Directions share a set.
      final nonEmpty = byDirection.values
          .where((v) => v.isNotEmpty)
          .map((v) => v.join());
      expect(nonEmpty.toSet().length, nonEmpty.length);
    });

    test('every Flags option maps to a clip the engine can draw', () {
      final c = buildStudioV2Controller();
      addTearDown(c.dispose);
      for (final d in c.detailChoices) {
        c.applyDetailChoice(d.id);
        expect(
          StudioDetail.values.map((v) => v.name),
          contains(d.id),
          reason: '${d.id} is not a StudioDetail',
        );
      }
    });

    test('a made-up option is ignored, not guessed at', () {
      final c = buildStudioV2Controller();
      addTearDown(c.dispose);
      final before = c.current.recipeId;
      c.applyDetailChoice('polaroid');
      expect(c.current.recipeId, before);
    });
  });

  group('the screen', () {
    testWidgets('it asks in the words of the Direction, with no shirt', (
      tester,
    ) async {
      await pumpDetail(tester);
      expect(find.text('What style of flags?'), findsOneWidget);
      expect(
        find.text('Choose how the country flags are used in your design.'),
        findsOneWidget,
      );
      expect(find.text('Direction Detail'), findsOneWidget);
      expect(find.byType(ShirtPreview), findsNothing);
      expect(find.byKey(const Key('v2-side-front')), findsNothing);
    });

    testWidgets('the question changes with the Direction', (tester) async {
      controller.selectSubject(subject('Passport'));
      await pumpDetail(tester);
      expect(find.text('How should the stamps sit?'), findsOneWidget);
      expect(find.text('What style of flags?'), findsNothing);
    });

    testWidgets('two columns, and the current option is already chosen', (
      tester,
    ) async {
      await pumpDetail(tester);
      final first = tester.getRect(find.byKey(const Key('v2-detail-grid')));
      final second = tester.getRect(find.byKey(const Key('v2-detail-circle')));
      final third = tester.getRect(find.byKey(const Key('v2-detail-map')));
      expect(second.left, greaterThan(first.left));
      expect(second.top, closeTo(first.top, 1));
      expect(third.top, greaterThan(first.top));

      final card = tester.widget<Semantics>(
        find
            .descendant(
              of: find.byKey(Key('v2-detail-${controller.currentDetailId}')),
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(card.properties.selected, isTrue);
    });

    testWidgets('nothing overflows a phone', (tester) async {
      await pumpDetail(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('just looking changes nothing', (tester) async {
      final state = await pump(tester);
      final recipe = controller.current.recipeId;
      final history = controller.history.length;
      state.goToStage(StudioStage.detail);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(controller.current.recipeId, recipe);
      expect(controller.history.length, history);
    });
  });

  group('choosing a Detail', () {
    testWidgets('it changes the design and shows as selected', (tester) async {
      await pumpDetail(tester);
      final before = controller.current.recipeId;
      await tester.tap(find.byKey(const Key('v2-detail-heart')));
      await tester.pump();
      expect(controller.currentDetailId, 'heart');
      expect(controller.current.recipeId, isNot(before));
    });

    test('the travels, Direction, garment and title all survive', () {
      final c = buildStudioV2Controller();
      addTearDown(c.dispose);
      c.setGarment('#FF1B2B');
      c.setSide(false);
      c.commitTitle('EUROPE 2026');
      final codes = c.selectedCountryCodes;
      final lo = c.yearLo, hi = c.yearHi;

      c.applyDetailChoice('circle');

      expect(c.subjectLabel, 'Flags', reason: 'still the same Direction');
      expect(c.selectedCountryCodes, codes);
      expect(c.yearLo, lo);
      expect(c.yearHi, hi);
      expect(c.current.palette?.garmentColour, '#FF1B2B');
      expect(c.currentTitle, 'EUROPE 2026');
    });

    test('a family choice actually sticks', () {
      // Route pins the journeys family; choosing Timeline has to override it.
      final c = buildStudioV2Controller();
      addTearDown(c.dispose);
      c.selectSubject(subject('Route'));
      c.applyDetailChoice('timeline');
      expect(c.currentDetailId, 'timeline');
      expect(c.current.composition.family, DesignFamily.timeline);
    });

    test('a Detail belongs to the Direction that offered it', () {
      final c = buildStudioV2Controller();
      addTearDown(c.dispose);
      c.selectSubject(subject('Route'));
      c.applyDetailChoice('timeline');
      c.selectSubject(subject('Milestones'));
      expect(
        c.detailChoices.map((d) => d.id),
        isNot(contains('timeline')),
        reason: 'the old Direction\'s options must not follow you',
      );
    });
  });

  group('navigation', () {
    testWidgets('Back returns to Direction, Next goes on to Vibe', (
      tester,
    ) async {
      final state = await pump(tester);
      state.goToStage(StudioStage.direction);
      await tester.pump();
      await tester.tap(find.byKey(const Key('v2-customise-next')));
      await tester.pump();
      expect(state.stage, StudioStage.detail);
      final recipe = controller.current.recipeId;

      await tester.tap(find.byKey(const Key('v2-customise-back')));
      await tester.pump();
      expect(state.stage, StudioStage.direction);
      expect(controller.current.recipeId, recipe);

      state.goToStage(StudioStage.detail);
      await tester.pump();
      await tester.tap(find.byKey(const Key('v2-customise-next')));
      await tester.pump();
      expect(state.stage, StudioStage.vibe);
    });

    testWidgets('a Direction with no Detail steps straight past it', (
      tester,
    ) async {
      final state = await pump(tester);
      state.goToStage(StudioStage.direction);
      await tester.pump();
      await tester.tap(find.byKey(const Key('v2-direction-world')));
      await tester.pump();
      expect(controller.detailApplies, isFalse);

      await tester.tap(find.byKey(const Key('v2-customise-next')));
      await tester.pump();
      expect(
        state.stage,
        StudioStage.vibe,
        reason: 'an empty step is not a step',
      );
    });

    testWidgets('changing Direction changes what Detail offers', (
      tester,
    ) async {
      final state = await pump(tester);
      state.goToStage(StudioStage.direction);
      await tester.pump();
      await tester.tap(find.byKey(const Key('v2-direction-milestones')));
      await tester.pump();

      state.goToStage(StudioStage.detail);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('v2-detail-badge')), findsOneWidget);
      expect(find.byKey(const Key('v2-detail-grid')), findsNothing);
    });
  });

  group('control ownership', () {
    testWidgets('no tuning dials here — this picks a subtype', (tester) async {
      await pumpDetail(tester);
      expect(find.byType(Slider), findsNothing);
      expect(find.byType(Switch), findsNothing);
      for (final word in ['Scatter', 'Rotation', 'Size', 'Effects']) {
        expect(find.textContaining(word), findsNothing);
      }
    });

    test('the workspace asks the controller, it does not decide', () {
      // Every option the screen can show comes from the controller's
      // capability map, so the UI cannot offer something unsupported.
      final c = buildStudioV2Controller();
      addTearDown(c.dispose);
      expect(DetailWorkspace.questionFor('Flags').$1, isNotEmpty);
      expect(c.detailChoices, isNotEmpty);
    });
  });
}
