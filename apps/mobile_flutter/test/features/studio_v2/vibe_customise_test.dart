// M15 — Vibe: the look and feel, over the same design.
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
import 'package:mobile_flutter/features/studio_v2/widgets/vibe_workspace.dart';
import 'package:region_lookup/region_lookup.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StudioController controller;
  setUp(() {
    // Choosing a vibe teaches the preference model, which persists.
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

  Future<StudioV2ScreenState> pumpVibe(WidgetTester tester) async {
    final state = await pump(tester);
    state.goToStage(StudioStage.vibe);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    return state;
  }

  group('the thirteen vibes', () {
    test('the product list IS the engine list', () {
      // No parallel Vibe model: the names, and their order, come from LabStyle.
      expect(
        [for (final s in LabStyle.values) s.label],
        [
          'Showcase',
          'Extreme',
          'Maximal',
          'Beachwear',
          'Surf',
          'Grunge',
          'Minimalist',
          'Streetwear',
          'Vintage',
          'Retro',
          'Outdoor',
          'Premium',
          'Typography',
        ],
      );
    });

    test('every vibe has a line of copy', () {
      for (final s in LabStyle.values) {
        expect(
          VibeWorkspace.blurbs[s],
          isNotNull,
          reason: '${s.label} has no subtitle',
        );
      }
    });

    test('each vibe yields a genuinely different design', () {
      final c = buildStudioV2Controller();
      addTearDown(c.dispose);
      final ids = [for (final (_, r) in c.vibeStyleOptions()) r.recipeId];
      expect(ids.length, 13);
      expect(
        ids.toSet().length,
        greaterThan(8),
        reason: 'vibes that render the same shirt are not choices',
      );
    });

    testWidgets('all thirteen are reachable by scrolling', (tester) async {
      await pumpVibe(tester);
      final scroll = find.byKey(const Key('v2-vibe-scroll'));
      for (final s in LabStyle.values) {
        await tester.scrollUntilVisible(
          find.byKey(Key('v2-vibe-${s.name}')),
          160,
          scrollable: find.descendant(
            of: scroll,
            matching: find.byType(Scrollable),
          ),
        );
        expect(find.byKey(Key('v2-vibe-${s.name}')), findsOneWidget);
      }
    });
  });

  group('the screen', () {
    testWidgets('it asks the question, with no hero shirt or face toggle', (
      tester,
    ) async {
      await pumpVibe(tester);
      expect(find.text('What style vibe do you prefer?'), findsOneWidget);
      expect(find.text('Vibe'), findsOneWidget);
      expect(find.byKey(const Key('v2-garment-preview')), findsNothing);
      expect(find.byKey(const Key('v2-side-front')), findsNothing);
      expect(find.byKey(const Key('v2-workspace-sheet')), findsNothing);
    });

    testWidgets('two columns', (tester) async {
      await pumpVibe(tester);
      final a = tester.getRect(find.byKey(const Key('v2-vibe-showcase')));
      final b = tester.getRect(find.byKey(const Key('v2-vibe-extreme')));
      final c = tester.getRect(find.byKey(const Key('v2-vibe-maximal')));
      expect(b.left, greaterThan(a.left));
      expect(b.top, closeTo(a.top, 1));
      expect(c.top, greaterThan(a.top));
      expect(c.left, closeTo(a.left, 1));
    });

    testWidgets('the current vibe is already selected', (tester) async {
      // Arrive with a known style so the assertion is about selection, not
      // about whatever the opening design happened to be.
      controller.onStyleTap(
        LabStyle.vintage,
        controller.vibeStyleOptions()[LabStyle.vintage.index].$2,
      );
      await pumpVibe(tester);
      // Vintage is the ninth of thirteen — below the fold on a phone.
      await tester.scrollUntilVisible(
        find.byKey(const Key('v2-vibe-vintage')),
        160,
        scrollable: find.descendant(
          of: find.byKey(const Key('v2-vibe-scroll')),
          matching: find.byType(Scrollable),
        ),
      );
      final card = tester.widget<Semantics>(
        find
            .descendant(
              of: find.byKey(const Key('v2-vibe-vintage')),
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(card.properties.selected, isTrue);
    });

    testWidgets('no lock or remix controls here', (tester) async {
      await pumpVibe(tester);
      expect(find.textContaining('Remix'), findsNothing);
      expect(find.textContaining('Lock'), findsNothing);
      expect(find.byType(Slider), findsNothing);
    });

    testWidgets('nothing overflows a phone', (tester) async {
      await pumpVibe(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('just looking changes nothing', (tester) async {
      final state = await pump(tester);
      final recipe = controller.current.recipeId;
      final history = controller.history.length;
      state.goToStage(StudioStage.vibe);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(controller.current.recipeId, recipe);
      expect(controller.history.length, history);
    });
  });

  group('choosing a vibe', () {
    testWidgets('it restyles the design and shows as selected', (tester) async {
      await pumpVibe(tester);
      final before = controller.current.recipeId;
      await tester.tap(find.byKey(const Key('v2-vibe-grunge')));
      await tester.pump();
      expect(controller.currentStyle, LabStyle.grunge);
      expect(controller.current.recipeId, isNot(before));
    });

    test('the subject, travels, garment and title all survive', () {
      final c = buildStudioV2Controller();
      addTearDown(c.dispose);
      c.selectSubject(subject('Passport'));
      c.setGarment('#FF1B2B');
      c.setSide(false);
      c.commitTitle('EUROPE 2026');
      final codes = c.selectedCountryCodes;
      final lo = c.yearLo, hi = c.yearHi;
      final family = c.current.composition.family;

      final (style, styled) = c.vibeStyleOptions()[LabStyle.premium.index];
      c.onStyleTap(style, styled);

      expect(c.currentStyle, LabStyle.premium);
      expect(c.subjectLabel, 'Passport', reason: 'the Direction is untouched');
      expect(c.current.composition.family, family);
      expect(c.selectedCountryCodes, codes);
      expect(c.yearLo, lo);
      expect(c.yearHi, hi);
      expect(c.current.palette?.garmentColour, '#FF1B2B');
      expect(c.currentTitle, 'EUROPE 2026');
    });

    test('the Direction Detail survives too', () {
      final c = buildStudioV2Controller();
      addTearDown(c.dispose);
      c.applyDetailChoice('heart');
      final shape = c.current.clip?.shapeId;

      final (style, styled) = c.vibeStyleOptions()[LabStyle.retro.index];
      c.onStyleTap(style, styled);
      expect(c.currentDetailId, 'heart');
      expect(c.current.clip?.shapeId, shape);
    });
  });

  group('navigation', () {
    testWidgets('Next goes on to Fine Tune (M16)', (tester) async {
      final state = await pumpVibe(tester);
      await tester.tap(find.byKey(const Key('v2-customise-next')));
      await tester.pump();
      expect(state.stage, StudioStage.fineTune);
    });

    testWidgets('Back returns to Detail when Detail was shown', (tester) async {
      final state = await pump(tester);
      state.goToStage(StudioStage.direction);
      await tester.pump();
      await tester.tap(find.byKey(const Key('v2-direction-flags')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('v2-customise-next')));
      await tester.pump();
      expect(state.stage, StudioStage.detail);
      await tester.tap(find.byKey(const Key('v2-customise-next')));
      await tester.pump();
      expect(state.stage, StudioStage.vibe);
      final recipe = controller.current.recipeId;

      await tester.tap(find.byKey(const Key('v2-customise-back')));
      await tester.pump();
      expect(state.stage, StudioStage.detail);
      expect(controller.current.recipeId, recipe);
    });

    testWidgets('Back returns to Direction when Detail was skipped', (
      tester,
    ) async {
      // World has no Detail, so the step never happened and Back must not
      // pretend it did.
      final state = await pump(tester);
      state.goToStage(StudioStage.direction);
      await tester.pump();
      await tester.tap(find.byKey(const Key('v2-direction-world')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('v2-customise-next')));
      await tester.pump();
      expect(state.stage, StudioStage.vibe);

      await tester.tap(find.byKey(const Key('v2-customise-back')));
      await tester.pump();
      expect(state.stage, StudioStage.direction);
    });
  });
}
