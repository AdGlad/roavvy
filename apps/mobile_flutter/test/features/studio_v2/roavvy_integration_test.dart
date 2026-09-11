// M25 — the seam between Roavvy and the Studio.
//
// Everything here is about ONE direction of travel: the app's records go in,
// a design comes out, and nothing the customer does to a shirt reaches back.
import 'dart:io';
import 'dart:typed_data';

import 'package:country_lookup/country_lookup.dart';
import 'package:design_studio/design_studio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/providers.dart';
import 'package:mobile_flutter/features/studio_v2/host/travel_context.dart';
import 'package:mobile_flutter/features/studio_v2/studio_v2_app.dart';
import 'package:mobile_flutter/features/studio_v2/studio_v2_screen.dart';
import 'package:mobile_flutter/features/studio_v2/studio_v2_stage.dart';
import 'package:region_lookup/region_lookup.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A traveller as Roavvy actually records one: trips found by the scan.
List<TripRecord> roavvyTrips() => [
  TripRecord(
    id: 't1',
    countryCode: 'PT',
    startedOn: DateTime(2019, 5, 2),
    endedOn: DateTime(2019, 5, 14),
    photoCount: 96,
    isManual: false,
  ),
  TripRecord(
    id: 't2',
    countryCode: 'MA',
    startedOn: DateTime(2022, 9, 8),
    endedOn: DateTime(2022, 9, 20),
    photoCount: 130,
    isManual: false,
  ),
  TripRecord(
    id: 't3',
    countryCode: 'PT',
    startedOn: DateTime(2024, 3, 1),
    endedOn: DateTime(2024, 3, 6),
    photoCount: 41,
    isManual: false,
  ),
];

List<EffectiveVisitedCountry> roavvyVisits({bool dated = true}) => [
  EffectiveVisitedCountry(
    countryCode: 'PT',
    hasPhotoEvidence: true,
    firstSeen: dated ? DateTime(2019, 5, 2) : null,
    lastSeen: dated ? DateTime(2024, 3, 6) : null,
    photoCount: 137,
  ),
  EffectiveVisitedCountry(
    countryCode: 'MA',
    hasPhotoEvidence: true,
    firstSeen: dated ? DateTime(2022, 9, 8) : null,
    lastSeen: dated ? DateTime(2022, 9, 20) : null,
    photoCount: 130,
  ),
];

StudioContext liveContext() => StudioV2TravelContext.fromRoavvy(
  trips: roavvyTrips(),
  visits: roavvyVisits(),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Roavvy travel, as the Studio sees it', () {
    test('every trip the app recorded arrives, dates and all', () {
      final ctx = liveContext();

      expect(ctx.trips.length, 3, reason: 'two visits to Portugal stay two');
      expect(ctx.trips.first.countryCode, 'pt');
      expect(ctx.trips.first.startedOn, DateTime(2019, 5, 2));
      expect(ctx.trips.first.endedOn, DateTime(2019, 5, 14));
      expect(ctx.trips.first.photoCount, 96);
      expect(ctx.isDated, isTrue);
      expect(ctx.source, StudioTravelSource.live);
    });

    test('the countries are the real ones, and only the real ones', () {
      final ctx = liveContext();
      expect(ctx.countryCodes, ['pt', 'ma']);
      expect(ctx.hasTravel, isTrue);
    });

    test('the year range comes from the real dates', () {
      expect(liveContext().yearRange, (2019, 2024));
    });

    test('cloud-restored visits still date the history without trip rows', () {
      // A reinstall restores visits, not trips. Their first/last dates are
      // real travel information and are the difference between the Studio
      // offering a year range and not having one at all.
      final ctx = StudioV2TravelContext.fromRoavvy(
        trips: const [],
        visits: roavvyVisits(),
      );
      expect(ctx.isDated, isTrue);
      expect(ctx.countryCodes, ['pt', 'ma']);
      // The range is derived, never defaulted — and derived the way every
      // other reader of a travel history derives it: TravelHistory.span runs
      // from the earliest start to the end of the LAST-STARTING entry, which
      // for a promoted visit that spans years (Portugal, 2019→2024) is the
      // later Morocco visit. Engine semantics, shared with V1; not restated
      // here.
      expect(ctx.yearRange, (2019, 2022));
    });

    test('a country added by hand is never dropped for being undated', () {
      // Manual additions carry no dates. Deriving a dated history from the
      // ones that do would leave this country out of the design entirely, so
      // the whole history stays undated instead — and complete.
      final ctx = StudioV2TravelContext.fromRoavvy(
        trips: const [],
        visits: [
          ...roavvyVisits(),
          const EffectiveVisitedCountry(
            countryCode: 'IS',
            hasPhotoEvidence: false,
          ),
        ],
      );
      expect(ctx.isDated, isFalse);
      expect(ctx.countryCodes, ['pt', 'ma', 'is']);
    });

    test('no travel means no travel — nothing is invented', () {
      final ctx = StudioV2TravelContext.fromRoavvy(
        trips: const [],
        visits: const [],
      );
      expect(ctx.hasTravel, isFalse);
      expect(ctx.countryCodes, isEmpty);
      expect(ctx.trips, isEmpty);
    });
  });

  group('a session opened on real travel', () {
    test('Instant designs are made of the real countries', () {
      final ctx = liveContext();
      final c = openStudioSession(ctx);
      addTearDown(c.dispose);

      final flags = {for (final f in c.current.content.flags) f.code};
      expect(flags, isNotEmpty);
      expect(
        flags.difference({'pt', 'ma'}),
        isEmpty,
        reason: 'a design may only use countries this traveller has been to',
      );
      expect(
        flags.contains('us'),
        isFalse,
        reason: 'the demo fixtures must not reach a real session',
      );
    });

    test('the Travels step offers exactly the real travel', () {
      final c = openStudioSession(liveContext());
      addTearDown(c.dispose);

      expect(c.availableCountryCodes.toSet(), {'pt', 'ma'});
      expect(c.allTravelledCodes.toSet(), {'pt', 'ma'});
      expect((c.yearLo, c.yearHi), (2019, 2024));
      expect(c.hasTrips, isTrue);
    });

    test('a host-supplied opening selection is honoured', () {
      final c = openStudioSession(
        StudioV2TravelContext.fromRoavvy(
          trips: roavvyTrips(),
          visits: roavvyVisits(),
          initialSelection: const ['MA'],
        ),
      );
      addTearDown(c.dispose);
      expect(c.selectedCountryCodes, {'ma'});
    });

    test('browsing Instant stays deterministic on real data', () {
      final a = openStudioSession(liveContext());
      final b = openStudioSession(liveContext());
      addTearDown(a.dispose);
      addTearDown(b.dispose);
      expect(
        [for (final r in a.instantPicks) r.recipeId],
        [for (final r in b.instantPicks) r.recipeId],
      );
    });
  });

  group('the shirt is design state; the travel history is not', () {
    test('deselecting a country changes the design and nothing else', () {
      final trips = roavvyTrips();
      final visits = roavvyVisits();
      final ctx = StudioV2TravelContext.fromRoavvy(
        trips: trips,
        visits: visits,
      );
      final c = openStudioSession(ctx);
      addTearDown(c.dispose);

      c.setSelectedCountries(const ['pt']);

      expect(c.selectedCountryCodes, {'pt'});
      expect(c.context.flagCodes, ['pt'], reason: 'the DESIGN narrowed');
      // …while every canonical record is exactly as Roavvy handed it over.
      expect(trips.map((t) => t.countryCode).toList(), ['PT', 'MA', 'PT']);
      expect(visits.map((v) => v.countryCode).toList(), ['PT', 'MA']);
      expect(ctx.countryCodes, ['pt', 'ma']);
      expect(ctx.trips.length, 3);
      expect(
        c.allTravelledCodes.toSet(),
        {'pt', 'ma'},
        reason: 'what the traveller has done is unchanged by what they design',
      );
    });

    test('the Studio has no way to write travel back', () {
      // Structural, and the reason the test above can only ever pass: the only
      // travel the Studio holds is a StudioContext, whose every field is an
      // unmodifiable list of derived values.
      final ctx = liveContext();
      expect(() => ctx.countryCodes.add('fr'), throwsUnsupportedError);
      expect(() => ctx.trips.clear(), throwsUnsupportedError);
    });

    test('features/studio_v2 cannot reach the scan, the photos or the DB', () {
      final forbidden = {
        'features/scan': 'the scanner',
        'photo_scan_channel': 'the PhotoKit bridge',
        'data/db': 'the travel database',
        'data/repositories': 'the travel repositories',
      };
      final offenders = <String>[];
      for (final f in Directory('lib/features/studio_v2')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        for (final line in f.readAsStringSync().split('\n')) {
          final l = line.trimLeft();
          if (!l.startsWith('import')) continue;
          for (final entry in forbidden.entries) {
            if (l.contains(entry.key)) {
              offenders.add('${f.path}: ${entry.value} ($l)');
            }
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'Roavvy discovers travel; the Studio only ever receives '
            'it:\n${offenders.join('\n')}',
      );
    });
  });

  group('standalone and production are the same Studio', () {
    test('the fixtures go through the same boundary, marked as fixtures', () {
      expect(demoStudioContext.source, StudioTravelSource.fixture);
      expect(demoStudioContext.isDated, isTrue);
      expect(demoStudioContext.hasTravel, isTrue);
      expect(liveContext().source, StudioTravelSource.live);
    });

    test('the dev controller is an ordinary session over that context', () {
      final demo = buildStudioV2Controller();
      final direct = openStudioSession(demoStudioContext);
      addTearDown(demo.dispose);
      addTearDown(direct.dispose);
      expect(demo.current.recipeId, direct.current.recipeId);
      expect(demo.availableCountryCodes, direct.availableCountryCodes);
    });

    test('a design is scoped to its travel, so the two cannot collide', () {
      final live = openStudioSession(liveContext());
      addTearDown(live.dispose);
      final demo = buildStudioV2Controller();
      addTearDown(demo.dispose);
      expect(live.current.recipeId, isNot(demo.current.recipeId));
    });
  });

  group('opening and leaving the Studio from inside Roavvy', () {
    Future<void> pumpHost(
      WidgetTester tester, {
      required StudioContext studio,
    }) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Builder(
              builder:
                  (context) => Scaffold(
                    body: Center(
                      child: TextButton(
                        key: const Key('host-open-studio'),
                        onPressed:
                            () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder:
                                    (_) => StudioV2App(
                                      studioContext: studio,
                                      embedded: true,
                                    ),
                              ),
                            ),
                        child: const Text('Roavvy Shop'),
                      ),
                    ),
                  ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('host-open-studio')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('Roavvy opens the Studio on its own travel, and gets it back', (
      tester,
    ) async {
      await pumpHost(tester, studio: liveContext());

      // The Studio is up, on the real countries…
      expect(find.byKey(const Key('v2-instant-deck')), findsOneWidget);

      // …and the way out is there, because the host's navigator can pop.
      expect(find.byKey(const Key('v2-instant-exit')), findsOneWidget);
      await tester.tap(find.byKey(const Key('v2-instant-exit')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Roavvy Shop'), findsOneWidget);
      expect(find.byKey(const Key('v2-instant-deck')), findsNothing);
    });

    testWidgets('a traveller with nothing found is told so, not shown fiction', (
      tester,
    ) async {
      await pumpHost(tester, studio: StudioContext.empty);

      expect(find.byKey(const Key('v2-no-travel')), findsOneWidget);
      expect(find.byKey(const Key('v2-instant-deck')), findsNothing);
      await tester.tap(find.byKey(const Key('v2-no-travel-close')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Roavvy Shop'), findsOneWidget);
    });

    testWidgets('the live app path opens the session on Roavvy\'s own travel', (
      tester,
    ) async {
      // No injected context: this is the production wiring, provider to
      // shirt.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripListProvider.overrideWith((ref) async => roavvyTrips()),
            effectiveVisitsProvider.overrideWith((ref) async => roavvyVisits()),
          ],
          child: const MaterialApp(home: StudioV2App(embedded: true)),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final screen = tester.widget<StudioV2Screen>(
        find.byType(StudioV2Screen),
      );
      expect(screen.controller.allTravelledCodes.toSet(), {'pt', 'ma'});
      expect((screen.controller.yearLo, screen.controller.yearHi), (2019, 2024));
    });

    testWidgets('a travel read that failed is never reported as no travel', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripListProvider.overrideWith(
              (ref) async => throw StateError('database unavailable'),
            ),
            effectiveVisitsProvider.overrideWith(
              (ref) async => throw StateError('database unavailable'),
            ),
          ],
          child: const MaterialApp(home: StudioV2App(embedded: true)),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Travels unavailable'), findsOneWidget);
      expect(find.text('No travels yet'), findsNothing);
      expect(find.byKey(const Key('v2-instant-deck')), findsNothing);
    });

    testWidgets('rebuilding the host does not start a second session', (
      tester,
    ) async {
      // A session generates its opening designs; recreating one on a rebuild
      // would throw away whatever the customer had already chosen.
      final key = GlobalKey();
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: StudioV2App(
              key: key,
              studioContext: liveContext(),
              embedded: true,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      final first = tester.state(find.byKey(key));
      final shownFirst = find.byKey(const Key('v2-instant-deck'));
      expect(shownFirst, findsOneWidget);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: StudioV2App(
              key: key,
              studioContext: liveContext(),
              embedded: true,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(identical(tester.state(find.byKey(key)), first), isTrue);
    });
  });

  group('Instant → Customise', () {
    late Uint8List countries, regions;

    Future<StudioV2ScreenState> pumpStudio(
      WidgetTester tester,
      StudioController c,
    ) async {
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
          child: MaterialApp(home: StudioV2Screen(key: key, controller: c)),
        ),
      );
      await tester.pump();
      return key.currentState!;
    }

    testWidgets('the chosen design carries into Travels, unchanged', (
      tester,
    ) async {
      final c = openStudioSession(liveContext());
      addTearDown(c.dispose);
      final state = await pumpStudio(tester, c);

      final chosen = c.current.recipeId;
      await tester.tap(find.byKey(const Key('v2-instant-customise')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(state.stage, StudioStage.travels);
      expect(
        c.current.recipeId,
        chosen,
        reason: 'Customise edits THIS shirt; it does not make another one',
      );
    });

    testWidgets('Travels shows the real countries, not a demo set', (
      tester,
    ) async {
      final c = openStudioSession(liveContext());
      addTearDown(c.dispose);
      final state = await pumpStudio(tester, c);
      state.goToStage(StudioStage.travels);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byKey(const Key('v2-travels-country-pt')), findsOneWidget);
      expect(find.byKey(const Key('v2-travels-country-ma')), findsOneWidget);
      expect(find.byKey(const Key('v2-travels-country-us')), findsNothing);
    });
  });
}
