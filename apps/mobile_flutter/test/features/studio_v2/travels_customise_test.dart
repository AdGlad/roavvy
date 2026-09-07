// M12 — Customise starts at Travels: the design you chose, re-cut for the
// journeys you pick, in a frame that can hand the screen back to the shirt.
import 'dart:typed_data';

import 'package:country_lookup/country_lookup.dart';
import 'package:design_studio/design_studio.dart';
import 'package:flutter/material.dart' hide Orientation;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/providers.dart';
import 'package:mobile_flutter/features/map/country_visual_state.dart';
import 'package:mobile_flutter/features/map/globe_map_widget.dart';
import 'package:mobile_flutter/features/studio_v2/studio_v2_app.dart';
import 'package:mobile_flutter/features/studio_v2/studio_v2_screen.dart';
import 'package:mobile_flutter/features/studio_v2/studio_v2_stage.dart';
import 'package:mobile_flutter/features/studio_v2/widgets/shirt_preview.dart';
import 'package:mobile_flutter/features/studio_v2/widgets/studio_workspace_shell.dart';
import 'package:region_lookup/region_lookup.dart';

// The globe keeps tickers running for as long as it is on screen, so nothing
// here ever reaches a quiescent frame: every wait in this file is a timed pump,
// never pumpAndSettle, which would simply hang.

/// How much of the screen the control sheet occupies.
///
/// The DraggableScrollableSheet widget itself always fills the viewport — what
/// moves is its child, so measure the grab handle that rides the top of it.
/// Let the snap animation run out. One long pump jumps the clock in a single
/// frame, which the sheet's physics does not resolve the same way a real run
/// of frames does.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

double sheetFraction(WidgetTester tester) {
  final screen = tester.view.physicalSize.height / tester.view.devicePixelRatio;
  final handleTop =
      tester.getRect(find.byKey(const Key('v2-workspace-handle'))).top;
  return (screen - handleTop) / screen;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StudioController controller;
  setUp(() => controller = buildStudioV2Controller());
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
    // The globe asks the lookup engines for polygons and asserts without them —
    // the same bootstrap the app entrypoints do.
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

  Future<StudioV2ScreenState> pumpTravels(WidgetTester tester) async {
    final state = await pump(tester);
    state.goToStage(StudioStage.travels);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    return state;
  }

  group('Customise carries the design across', () {
    testWidgets('tapping Customise on Instant opens Travels on THAT design', (
      tester,
    ) async {
      final state = await pump(tester);
      // Browse to something other than the opening pick.
      await tester.tap(find.byKey(const Key('v2-instant-next')));
      await tester.pump(const Duration(milliseconds: 400));
      final chosen = controller.hero.recipeId;

      await tester.tap(find.byKey(const Key('v2-instant-customise')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(state.stage, StudioStage.travels);
      expect(
        controller.hero.recipeId,
        chosen,
        reason: 'Customise must not mint a new or default design',
      );
    });
  });

  group('a travel change edits the design rather than replacing it', () {
    test('the creative characteristics survive a country change', () {
      final c = buildStudioV2Controller();
      addTearDown(c.dispose);
      final before = c.hero;
      final codes = c.availableCountryCodes;
      expect(codes.length, greaterThan(2));

      c.toggleCountry(codes.first);
      final after = c.hero;

      // Travel-dependent: the flags on the shirt.
      expect(
        after.content.flags.length,
        isNot(before.content.flags.length),
        reason: 'removing a country should change what is printed',
      );
      // Everything creative: untouched.
      expect(after.composition.family, before.composition.family);
      expect(after.composition.sizeClass, before.composition.sizeClass);
      expect(after.composition.orientation, before.composition.orientation);
      expect(after.clip?.shapeId, before.clip?.shapeId);
      expect(after.palette?.garmentColour, before.palette?.garmentColour);
      expect(after.palette?.strategy, before.palette?.strategy);
      expect(after.palette?.accents, before.palette?.accents);
      expect(after.palette?.vintageGrade, before.palette?.vintageGrade);
      expect(after.effects, before.effects);
      expect(after.typography, before.typography);
      expect(after.edgeTreatment, before.edgeTreatment);
    });

    test('the title survives too', () {
      final c = buildStudioV2Controller();
      addTearDown(c.dispose);
      c.setSide(false);
      c.commitTitle('EUROPE 2026');
      c.toggleCountry(c.availableCountryCodes.first);
      expect(c.currentTitle, 'EUROPE 2026');
    });

    test('the shirt colour survives too', () {
      final c = buildStudioV2Controller();
      addTearDown(c.dispose);
      c.setGarment('#FF1B2B');
      c.toggleCountry(c.availableCountryCodes.first);
      expect(c.hero.palette?.garmentColour, '#FF1B2B');
      expect(c.frontFace.palette?.garmentColour, '#FF1B2B');
    });
  });

  group('one selection, two views onto it', () {
    test('Select all and Clear drive the shared set', () {
      final c = buildStudioV2Controller();
      addTearDown(c.dispose);
      c.clearCountries();
      expect(c.selectedCountryCodes, isEmpty);
      c.selectAllCountries();
      expect(c.selectedCountryCodes.length, c.availableCountryCodes.length);
    });

    test('toggling one country changes only that one', () {
      final c = buildStudioV2Controller();
      addTearDown(c.dispose);
      final cc = c.availableCountryCodes.first;
      expect(c.isSelected(cc), isTrue);
      c.toggleCountry(cc);
      expect(c.isSelected(cc), isFalse);
      expect(c.selectedCountryCodes.length, c.availableCountryCodes.length - 1);
      c.toggleCountry(cc);
      expect(c.isSelected(cc), isTrue);
    });

    testWidgets('the list reflects the selection the map writes', (
      tester,
    ) async {
      await pumpTravels(tester);
      final cc = controller.availableCountryCodes.first;
      final row = find.byKey(Key('v2-travels-country-$cc'));
      await tester.scrollUntilVisible(row, 120);

      // A map tap and a list tap are the same act on the same set.
      controller.toggleCountry(cc);
      await tester.pump();
      expect(controller.isSelected(cc), isFalse);

      await tester.tap(row);
      await tester.pump();
      expect(controller.isSelected(cc), isTrue);
    });

    testWidgets('Select all and Clear are wired to the shared set', (
      tester,
    ) async {
      await pumpTravels(tester);
      await tester.tap(find.byKey(const Key('v2-travels-clear')));
      await tester.pump();
      expect(controller.selectedCountryCodes, isEmpty);

      await tester.tap(find.byKey(const Key('v2-travels-select-all')));
      await tester.pump();
      expect(
        controller.selectedCountryCodes.length,
        controller.availableCountryCodes.length,
      );
    });
  });

  group('the shirt keeps up with the selection', () {
    testWidgets('toggling a country changes the shirt on screen', (
      tester,
    ) async {
      await pumpTravels(tester);
      ShirtPreview shirt() => tester.widget<ShirtPreview>(
        find.byKey(const Key('v2-garment-preview')),
      );
      final before = shirt().recipe;

      await tester.tap(
        find.byKey(
          Key('v2-travels-country-${controller.availableCountryCodes.first}'),
        ),
      );
      await tester.pump();

      final after = shirt().recipe;
      expect(
        after.recipeId,
        isNot(before.recipeId),
        reason: 'the preview must follow the selection, live',
      );
      expect(
        after.content.flags.length,
        isNot(before.content.flags.length),
        reason: 'and it must be the flags that changed',
      );
      // …still the same design, only re-cut.
      expect(after.composition.family, before.composition.family);
    });

    testWidgets('Clear then Select all returns the shirt to where it was', (
      tester,
    ) async {
      await pumpTravels(tester);
      ShirtPreview shirt() => tester.widget<ShirtPreview>(
        find.byKey(const Key('v2-garment-preview')),
      );
      final before = shirt().recipe.recipeId;

      await tester.tap(find.byKey(const Key('v2-travels-clear')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('v2-travels-select-all')));
      await tester.pump();
      expect(shirt().recipe.recipeId, before);
    });
  });

  group('the year range decides which travels count', () {
    test('narrowing the years narrows the countries on offer', () {
      final c = buildStudioV2Controller();
      addTearDown(c.dispose);
      final all = c.availableCountryCodes.length;
      expect(all, greaterThan(2), reason: 'the demo history should be dated');

      final span = c.span!;
      c.setYearRange(span.start!.year, span.start!.year + 1);
      expect(
        c.availableCountryCodes.length,
        lessThan(all),
        reason: 'a country visited outside the range is not on offer',
      );
    });

    test('widening again brings a country back, still selected', () {
      final c = buildStudioV2Controller();
      addTearDown(c.dispose);
      final span = c.span!;
      final everything = c.availableCountryCodes;
      c.setYearRange(span.start!.year, span.start!.year + 1);
      final narrowed = c.availableCountryCodes;
      final dropped = everything.firstWhere((cc) => !narrowed.contains(cc));

      c.setYearRange(span.start!.year, span.end!.year);
      expect(c.availableCountryCodes, everything);
      expect(
        c.isSelected(dropped),
        isTrue,
        reason: 'hiding a country by date must not deselect it',
      );
    });

    testWidgets('the slider is on screen when the history is dated', (
      tester,
    ) async {
      await pumpTravels(tester);
      expect(find.byKey(const Key('v2-travels-year')), findsOneWidget);
      expect(find.text('Year range'), findsOneWidget);
    });
  });

  group('the map shows THIS shirt, not the whole history', () {
    testWidgets('selected and deselected countries are coloured differently', (
      tester,
    ) async {
      // The globe normally colours from the user's entire visit history, which
      // on this screen answers the wrong question: what matters is which of
      // their countries are going on the shirt.
      await pumpTravels(tester);
      final scope = tester.element(find.byKey(const Key('v2-travels-map')));
      Map<String, CountryVisualState> states() => ProviderScope.containerOf(
        tester.element(find.byType(GlobeMapWidget)),
      ).read(countryVisualStatesProvider);

      final cc = controller.availableCountryCodes.first;
      expect(states()[cc.toUpperCase()], CountryVisualState.newlyDiscovered);

      controller.toggleCountry(cc);
      await tester.pump();
      expect(
        states()[cc.toUpperCase()],
        CountryVisualState.reviewed,
        reason: 'somewhere they have been, but not on this shirt',
      );
      expect(scope, isNotNull);
    });

    testWidgets('a country never visited is not offered at all', (
      tester,
    ) async {
      await pumpTravels(tester);
      final states = ProviderScope.containerOf(
        tester.element(find.byType(GlobeMapWidget)),
      ).read(countryVisualStatesProvider);
      expect(states.containsKey('AQ'), isFalse);
    });
  });

  group('the screen itself', () {
    testWidgets('it is one Countries screen — no Trips, no view switch', (
      tester,
    ) async {
      await pumpTravels(tester);
      expect(find.byKey(const Key('v2-travels-map')), findsOneWidget);
      expect(find.byKey(const Key('v2-travels-scroll')), findsOneWidget);
      // Removed in M12: the old conceptual options.
      expect(find.byKey(const Key('v2-travels-view-toggle')), findsNothing);
      expect(find.byKey(const Key('v2-travels-source-trips')), findsNothing);
      expect(
        find.byKey(const Key('v2-travels-source-countries')),
        findsNothing,
      );
      expect(find.text('Trips'), findsNothing);
    });

    testWidgets('it asks the question, and shows the compact shirt', (
      tester,
    ) async {
      await pumpTravels(tester);
      expect(
        find.text('Which travels should this shirt represent?'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('v2-garment-preview')), findsOneWidget);
      expect(find.byKey(const Key('v2-side-front')), findsOneWidget);
      expect(find.byKey(const Key('v2-side-back')), findsOneWidget);
    });

    testWidgets('controls are expanded by default', (tester) async {
      await pumpTravels(tester);
      expect(
        sheetFraction(tester),
        closeTo(StudioWorkspaceShell.expanded, 0.06),
        reason: 'the controls are why you are on this screen',
      );
    });

    testWidgets('no step overflows a phone at either size', (tester) async {
      for (final size in [const Size(390, 844), const Size(375, 667)]) {
        await pump(tester, size: size);
        expect(tester.takeException(), isNull);
      }
    });
  });

  group('dragging is free', () {
    testWidgets('the handle collapses the sheet and gives the shirt the '
        'screen, and back', (tester) async {
      await pumpTravels(tester);
      final handle = find.byKey(const Key('v2-workspace-handle'));

      await tester.tap(handle);
      await settle(tester);
      expect(
        sheetFraction(tester),
        closeTo(StudioWorkspaceShell.collapsed, 0.06),
        reason: 'the shirt should now have roughly 80% of the screen',
      );

      await tester.tap(handle);
      await settle(tester);
      expect(
        sheetFraction(tester),
        closeTo(StudioWorkspaceShell.expanded, 0.06),
      );
    });

    testWidgets('moving the sheet touches neither the design nor the '
        'selection', (tester) async {
      await pumpTravels(tester);
      final recipe = controller.hero.recipeId;
      final selection = controller.selectedCountryCodes;
      final history = controller.history.length;

      await tester.drag(
        find.byKey(const Key('v2-workspace-handle')),
        const Offset(0, 320),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.drag(
        find.byKey(const Key('v2-workspace-handle')),
        const Offset(0, -320),
      );
      await tester.pump(const Duration(milliseconds: 400));

      expect(controller.hero.recipeId, recipe);
      expect(controller.selectedCountryCodes, selection);
      expect(controller.history.length, history);
    });
  });

  group('navigation', () {
    testWidgets('Next goes to Direction (M13)', (tester) async {
      final state = await pumpTravels(tester);
      await tester.tap(find.byKey(const Key('v2-customise-next')));
      await tester.pump();
      expect(state.stage, StudioStage.direction);
    });

    testWidgets('Back returns to Instant with the design intact', (
      tester,
    ) async {
      final state = await pump(tester);
      await tester.tap(find.byKey(const Key('v2-instant-customise')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final chosen = controller.hero.recipeId;

      await tester.tap(find.byKey(const Key('v2-customise-back')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(state.stage, StudioStage.instant);
      expect(controller.hero.recipeId, chosen);
    });

    testWidgets('the wizard chrome is not exposed here', (tester) async {
      await pumpTravels(tester);
      expect(find.byKey(const Key('v2-open-steps')), findsNothing);
      expect(find.byKey(const Key('v2-recipe-undo')), findsNothing);
      expect(find.byKey(const Key('v2-next')), findsNothing);
      expect(find.textContaining('Step '), findsNothing);
    });
  });
}
