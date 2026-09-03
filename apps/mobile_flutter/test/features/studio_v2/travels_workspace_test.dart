import 'package:design_forge/design_forge.dart';
import 'package:design_studio/design_studio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/studio_v2/studio_v2_app.dart';
import 'package:mobile_flutter/features/studio_v2/studio_v2_screen.dart';
import 'package:mobile_flutter/features/studio_v2/studio_v2_stage.dart';

/// M2 — the Choose-Your-Travels workspace. The List selector and the shared
/// [StudioController] selection are exercised here (the Map tab reuses the live
/// Roavvy globe, which needs the full provider graph, so it is verified in the
/// dev app rather than in this headless widget test). Map/List synchronisation is
/// proven by showing the List reflects a controller-level (Map-path) toggle.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  List<Trip> tripsFixture() => [
    Trip(
      countryCode: 'us',
      startedOn: DateTime(2020, 6, 1),
      endedOn: DateTime(2020, 6, 8),
    ),
    Trip(
      countryCode: 'fr',
      startedOn: DateTime(2021, 3, 1),
      endedOn: DateTime(2021, 3, 9),
    ),
    Trip(
      countryCode: 'jp',
      startedOn: DateTime(2021, 8, 1),
      endedOn: DateTime(2021, 8, 5),
    ),
  ];

  StudioController datedController() => buildStudioV2ControllerFor(
    DesignContext.fromTrips(tripsFixture(), scopeKey: 'test:dated'),
  );

  StudioController flatController() => buildStudioV2ControllerFor(
    const DesignContext(flagCodes: ['us', 'fr', 'jp'], scopeKey: 'test:flat'),
  );

  Future<StudioV2ScreenState> pumpTravels(
    WidgetTester tester,
    StudioController c,
  ) async {
    tester.view.physicalSize = const Size(1600, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey<StudioV2ScreenState>();
    await tester.pumpWidget(
      MaterialApp(home: StudioV2Screen(key: key, controller: c)),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('v2-stage-travels')));
    await tester.pump();
    return key.currentState!;
  }

  testWidgets('live shirt stays visible; Countries list selects/deselects', (
    tester,
  ) async {
    final c = datedController();
    addTearDown(c.dispose);
    await pumpTravels(tester, c);

    // The hero shirt is still on screen while choosing travels.
    expect(find.byKey(const Key('v2-garment-preview')), findsOneWidget);
    // All three countries listed and selected by default.
    expect(find.byKey(const Key('v2-travels-country-us')), findsOneWidget);
    expect(c.selectedCountryCodes, {'us', 'fr', 'jp'});

    // Deselect France via the List → shared selection updates.
    await tester.tap(find.byKey(const Key('v2-travels-country-fr')));
    await tester.pump();
    expect(c.isSelected('fr'), isFalse);
    expect(c.context.flagCodes, ['us', 'jp']);
    expect(find.byKey(const Key('v2-garment-preview')), findsOneWidget);

    // Re-select it.
    await tester.tap(find.byKey(const Key('v2-travels-country-fr')));
    await tester.pump();
    expect(c.isSelected('fr'), isTrue);
  });

  testWidgets('Select All / Clear drive the shared selection', (tester) async {
    final c = datedController();
    addTearDown(c.dispose);
    await pumpTravels(tester, c);

    await tester.tap(find.byKey(const Key('v2-travels-clear')));
    await tester.pump();
    expect(c.selectedCountryCodes, isEmpty);

    await tester.tap(find.byKey(const Key('v2-travels-select-all')));
    await tester.pump();
    expect(c.selectedCountryCodes, {'us', 'fr', 'jp'});
  });

  testWidgets('Trips source + year range show for dated history', (
    tester,
  ) async {
    final c = datedController();
    addTearDown(c.dispose);
    await pumpTravels(tester, c);

    expect(find.byKey(const Key('v2-travels-source-trips')), findsOneWidget);
    expect(find.byKey(const Key('v2-travels-year')), findsOneWidget);

    await tester.tap(find.byKey(const Key('v2-travels-source-trips')));
    await tester.pump();
    expect(c.sourceTrips, isTrue);
    // Trips mode repeats a country per visit → us appears once, fr once, jp once
    // here (one visit each), still 3.
    expect(c.context.flagCodes.length, 3);
  });

  testWidgets('Trips + year controls hide when there is no dated history', (
    tester,
  ) async {
    final c = flatController();
    addTearDown(c.dispose);
    await pumpTravels(tester, c);

    expect(find.byKey(const Key('v2-travels-source-trips')), findsNothing);
    expect(find.byKey(const Key('v2-travels-year')), findsNothing);
    // But the List still selects.
    await tester.tap(find.byKey(const Key('v2-travels-country-us')));
    await tester.pump();
    expect(c.isSelected('us'), isFalse);
  });

  testWidgets('a Map-path toggle is reflected in the List (shared state)', (
    tester,
  ) async {
    final c = datedController();
    addTearDown(c.dispose);
    await pumpTravels(tester, c);

    // Simulate the Map's onCountryTap writing the SAME selection the List reads.
    c.toggleCountry('us');
    await tester.pump();
    expect(c.isSelected('us'), isFalse);
    // The List row now renders the deselected state (unchecked icon present).
    final tile = tester.widget<ListTile>(
      find.byKey(const Key('v2-travels-country-us')),
    );
    expect((tile.trailing as Icon).icon, Icons.circle_outlined);
  });

  testWidgets(
    'travel change keeps garment; navigate away/back keeps selection',
    (tester) async {
      final c = datedController();
      addTearDown(c.dispose);
      final state = await pumpTravels(tester, c);

      // Set a garment colour, then change travels — garment must survive.
      await tester.tap(find.byKey(const Key('v2-garment-Olive')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('v2-travels-country-fr')));
      await tester.pump();
      expect(c.isSelected('fr'), isFalse);
      expect(c.current.palette?.garmentColour, '#6B7350');

      // Navigate away (Instant) and back to Travels — selection is preserved.
      await tester.tap(find.byKey(const Key('v2-stage-instant')));
      await tester.pump();
      expect(state.stage, StudioStage.instant);
      await tester.tap(find.byKey(const Key('v2-stage-travels')));
      await tester.pump();
      expect(c.isSelected('fr'), isFalse); // still deselected
      final tile = tester.widget<ListTile>(
        find.byKey(const Key('v2-travels-country-fr')),
      );
      expect((tile.trailing as Icon).icon, Icons.circle_outlined);
    },
  );
}
