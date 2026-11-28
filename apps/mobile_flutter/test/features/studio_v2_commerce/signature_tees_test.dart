import 'dart:io';
import 'dart:ui' as ui;

import 'package:design_forge/design_forge.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:design_forge_render/design_forge_render.dart';
import 'package:design_studio/design_studio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/commerce/commerce_flag.dart';
import 'package:mobile_flutter/core/providers.dart';
import 'package:mobile_flutter/data/achievement_repository.dart';
import 'package:mobile_flutter/data/db/roavvy_database.dart';
import 'package:mobile_flutter/data/heritage_repository.dart';
import 'package:mobile_flutter/data/region_repository.dart';
import 'package:mobile_flutter/data/trip_repository.dart';
import 'package:mobile_flutter/data/visit_repository.dart';
import 'package:mobile_flutter/features/commerce_entry/commerce_entry.dart';
import 'package:mobile_flutter/features/map/country_celebration_carousel.dart';
import 'package:mobile_flutter/features/map/country_profile_screen.dart';
import 'package:mobile_flutter/features/map/country_stats.dart';
import 'package:mobile_flutter/features/map/country_visual_state.dart';
import 'package:mobile_flutter/features/map/discovery_overlay.dart';
import 'package:mobile_flutter/features/merch/shopify_pricing_repository.dart';
import 'package:mobile_flutter/features/scan/hero_providers.dart';
import 'package:mobile_flutter/features/stats/stats_screen.dart';
import 'package:mobile_flutter/features/studio_v2/commerce/garment_cart_request.dart';
import 'package:mobile_flutter/features/studio_v2_commerce/studio_v2_cart_adapter.dart';
import 'package:mobile_flutter/features/studio_v2_commerce/studio_v2_cart_service.dart';
import 'package:mobile_flutter/features/studio_v2_commerce/signature_tees/my_tees_screen.dart';
import 'package:mobile_flutter/features/studio_v2_commerce/signature_tees/signature_tee_screen.dart';
import 'package:mobile_flutter/features/studio_v2_commerce/signature_tees/signature_tees.dart';
import 'package:mobile_flutter/features/travel_timeline/trip_detail_sheet.dart';
import 'package:shared_models/shared_models.dart';

/// M200 — signature tees in the app.
///
/// The real `torn_flag` and `passport_stamp` packs are read from the package
/// so the recipes under test are the ones that ship (passport_stamp is the
/// one that needs a dated trip). Nothing renders (the resolver refuses every
/// flag, so previews stay on their placeholder) and nothing reaches Firebase
/// or Shopify: every provider that would is overridden.
SignatureRecipe _load(String id) => SignaturePackCodec.decode(
  File(
    '../../packages/design_studio/assets/signature/$id.pack.json',
  ).readAsStringSync(),
);
final SignatureRecipe _pack = _load('torn_flag');
final SignatureRecipe _stamp = _load('passport_stamp');

class _NoRender implements AssetResolver {
  @override
  Future<ui.Image> resolveFlag(
    String code, {
    required int width,
    required int height,
  }) => Future.error(UnsupportedError('no rendering in widget tests'));
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

List<Override> _overrides({
  required bool commerce,
  bool pack = true,
  List<EffectiveVisitedCountry> visits = const [],
  List<TripRecord> trips = const [],
}) => [
  commerceBuildProvider.overrideWithValue(commerce),
  commerceRemoteSwitchProvider.overrideWithValue(true),
  signatureCatalogProvider.overrideWith(
    (ref) async => SignatureCatalog(pack ? [_pack, _stamp] : const []),
  ),
  signatureTeeRenderServiceProvider.overrideWithValue(
    RenderService(_NoRender()),
  ),
  shopifyPricingProvider.overrideWith(
    (ref) async => const MerchPrices(tshirtFromPrice: r'$39.00'),
  ),
  effectiveVisitsProvider.overrideWith((ref) async => visits),
  tripListProvider.overrideWith((ref) async => trips),
  // Celebration globe.
  polygonsProvider.overrideWithValue(const []),
  countryVisualStatesProvider.overrideWithValue(const {}),
  countryTripCountsProvider.overrideWith((_) async => const <String, int>{}),
];

Widget _app(List<Override> overrides, Widget home) =>
    ProviderScope(overrides: overrides, child: MaterialApp(home: home));

Future<void> _tall(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(430, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

EffectiveVisitedCountry _visit(String cc, [DateTime? first]) =>
    EffectiveVisitedCountry(
      countryCode: cc,
      hasPhotoEvidence: first != null,
      firstSeen: first,
      lastSeen: first,
    );

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  group('signature tees — model', () {
    test('a country gets the pack hero, lower-cased', () {
      final container = ProviderContainer(
        overrides: _overrides(commerce: true),
      );
      addTearDown(container.dispose);
      return container.read(signatureCatalogProvider.future).then((_) {
        final r =
            container
                .read(signatureTeeProvider((countryCode: 'FR', packId: null)))
                ?.recipe;
        expect(r, isNotNull);
        expect(r!.recipeId, SignatureResolver.hero(_pack, 'fr').recipeId);
        expect(r.content.flags.single.code, 'fr');
      });
    });

    test('no pack, no tee', () async {
      final container = ProviderContainer(
        overrides: _overrides(commerce: true, pack: false),
      );
      addTearDown(container.dispose);
      await container.read(signatureCatalogProvider.future);
      expect(
        container.read(signatureTeeProvider((countryCode: 'FR', packId: null))),
        isNull,
      );
      expect(container.read(signatureTeesProvider('FR')), isEmpty);
    });

    test('a trip-dated design needs a trip, and carries its dates', () {
      final trip = TripRecord(
        id: 'fr1',
        countryCode: 'FR',
        startedOn: DateTime(2019, 5, 1),
        endedOn: DateTime(2019, 5, 9),
        photoCount: 12,
        isManual: false,
      );
      expect(
        [
          for (final t in teesFor([_pack, _stamp], 'FR')) t.pack.id,
        ],
        ['torn_flag'],
      );
      final tees = teesFor([_pack, _stamp], 'FR', trip: trip);
      expect(
        [for (final t in tees) t.pack.id],
        ['torn_flag', 'passport_stamp'],
      );
      final stamp = tees.last.recipe;
      expect(
        stamp.recipeId,
        SignatureResolver.hero(
          _stamp,
          'fr',
          tokens: {'entry': '01 MAY 19', 'exit': '09 MAY 19'},
        ).recipeId,
      );
      expect(
        stamp.recipeId,
        isNot(SignatureResolver.hero(_stamp, 'fr').recipeId),
        reason: 'never the sample dates',
      );
    });

    test('the latest trip to the country fills the dates', () {
      TripRecord t(String cc, DateTime start) => TripRecord(
        id: '$cc$start',
        countryCode: cc,
        startedOn: start,
        endedOn: start.add(const Duration(days: 3)),
        photoCount: 1,
        isManual: false,
      );
      final trips = [
        t('FR', DateTime(2017, 2, 3)),
        t('fr', DateTime(2022, 11, 30)),
        t('JP', DateTime(2024, 1, 1)),
      ];
      expect(latestTrip(trips, 'FR')!.startedOn, DateTime(2022, 11, 30));
      expect(latestTrip(trips, 'IT'), isNull);
      expect(stampDate(DateTime(2022, 11, 30)), '30 NOV 22');
      expect(stampDate(DateTime(2005, 3, 4)), '04 MAR 05');
    });

    test('only a design whose ink follows the shirt takes its colour', () {
      final trip = TripRecord(
        id: 'fr1',
        countryCode: 'FR',
        startedOn: DateTime(2019, 5, 1),
        endedOn: DateTime(2019, 5, 9),
        photoCount: 1,
        isManual: false,
      );
      final tees = teesFor([_pack, _stamp], 'FR', trip: trip);
      final torn = tees.first, stamp = tees.last;
      expect(inkFollowsShirt(torn.recipe), isFalse);
      expect(teeRecipe(torn, '#000000'), same(torn.recipe));
      expect(inkFollowsShirt(stamp.recipe), isTrue);
      final onBlack = teeRecipe(stamp, '#000000');
      expect(onBlack.palette!.garmentColour, '#000000');
      expect(onBlack.recipeId, isNot(teeRecipe(stamp, '#FFFFFF').recipeId));
      // The cart prints that same shirt-specific design.
      final r = buildSignatureTeeCartRequest(
        service: RenderService(_NoRender()),
        tee: stamp,
        countryCode: 'FR',
        garment: ('#000000', 'Black'),
        trips: [trip],
      );
      expect(r.garment.back!.recipeId, onBlack.recipeId);
    });

    test('only orderable colours are offered', () {
      final names = [for (final g in teeGarments) g.$2];
      expect(names, isNot(contains('Orange')));
      expect(names, isNot(contains('Royal')));
      expect(names, containsAll(['Black', 'White', 'Navy', 'Red']));
      for (final n in names) {
        expect(StudioV2CartAdapter.v1ColourName(n), isNotNull, reason: n);
      }
    });

    test('My tees: newest first visit first, undated last by name', () {
      final order = orderTees([
        _visit('fr', DateTime(2018)),
        _visit('JP', DateTime(2024)),
        _visit('NZ'),
        _visit('BR', DateTime(2021)),
        _visit('AU'),
        _visit('FR', DateTime(2018)),
      ]);
      expect(order, ['JP', 'BR', 'FR', 'AU', 'NZ']);
    });

    test('the cart request carries the approved recipe untouched', () {
      final recipe = SignatureResolver.hero(_pack, 'fr');
      final r = buildSignatureTeeCartRequest(
        service: RenderService(_NoRender()),
        tee: (pack: _pack, recipe: recipe),
        countryCode: 'FR',
        garment: ('#0F1830', 'Navy'),
        trips: [
          TripRecord(
            id: 'fr1',
            countryCode: 'FR',
            startedOn: DateTime(2019, 5, 1),
            endedOn: DateTime(2019, 5, 9),
            photoCount: 12,
            isManual: false,
          ),
          TripRecord(
            id: 'jp1',
            countryCode: 'JP',
            startedOn: DateTime(2020, 5, 1),
            endedOn: DateTime(2020, 5, 9),
            photoCount: 3,
            isManual: false,
          ),
        ],
      );
      expect(r.session.hero.recipeId, recipe.recipeId);
      expect(r.garment.back!.recipeId, recipe.recipeId);
      expect(r.garmentColourName, 'Navy');
      expect(r.garmentColourHex, '#0F1830');
      expect(r.backPosition, 'center');
      expect(r.frontPosition, 'none');
      expect(r.renderFrontArtwork, isNull);
      expect(r.selectedCountryCodes, ['fr']);
      expect([for (final t in r.trips) t.countryCode], ['fr']);
      expect(r.aspectRatio, 4 / 5);
      expect(r.title, 'France · Torn Flag');
      expect(StudioV2CartAdapter.map(r).colourName, 'Blue');
    });
  });

  group('product page', () {
    testWidgets('offers only orderable colours; Add to cart sends the tee', (
      tester,
    ) async {
      await _tall(tester);
      final sent = <(GarmentCartRequest, StudioV2PurchaseOptions)>[];
      await tester.pumpWidget(
        _app(
          _overrides(commerce: true),
          SignatureTeeScreen(
            countryCode: 'jp',
            onAddToCart: (context, r, o) async => sent.add((r, o)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (final (_, name) in StudioController.garments) {
        final orderable = !StudioV2CartAdapter.unstockedColours.contains(name);
        expect(
          find.byKey(Key('tee-colour-$name')),
          orderable ? findsOneWidget : findsNothing,
          reason: name,
        );
      }
      expect(find.text(r'$39.00'), findsOneWidget);

      // No size yet: nothing can be added.
      expect(find.text('Choose a size'), findsOneWidget);
      await tester.tap(find.byKey(const Key('tee-add-to-cart')));
      await tester.pump();
      expect(sent, isEmpty);

      await tester.tap(find.byKey(const Key('tee-colour-White')));
      await tester.tap(find.byKey(const Key('tee-size-L')));
      await tester.pump();
      expect(find.text(r'Add to cart · $39.00'), findsOneWidget);
      await tester.tap(find.byKey(const Key('tee-add-to-cart')));
      await tester.pumpAndSettle();

      expect(sent, hasLength(1));
      final (r, o) = sent.single;
      expect(
        r.session.hero.recipeId,
        SignatureResolver.hero(_pack, 'jp').recipeId,
      );
      expect(r.garment.back!.recipeId, r.session.hero.recipeId);
      expect(r.garmentColourName, 'White');
      expect(r.backPosition, 'center');
      expect(r.renderFrontArtwork, isNull);
      expect(r.selectedCountryCodes, ['jp']);
      expect(o.size, 'L');
    });

    testWidgets('switching design sends that design to the cart', (
      tester,
    ) async {
      await _tall(tester);
      final trip = TripRecord(
        id: 'jp1',
        countryCode: 'JP',
        startedOn: DateTime(2024, 3, 12),
        endedOn: DateTime(2024, 3, 26),
        photoCount: 40,
        isManual: false,
      );
      final sent = <GarmentCartRequest>[];
      await tester.pumpWidget(
        _app(
          _overrides(commerce: true, trips: [trip]),
          SignatureTeeScreen(
            countryCode: 'JP',
            onAddToCart: (context, r, o) async => sent.add(r),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Torn Flag · Japan'), findsOneWidget);
      expect(find.byKey(const Key('tee-design-torn_flag')), findsOneWidget);
      await tester.tap(find.byKey(const Key('tee-design-passport_stamp')));
      await tester.pump();
      expect(find.text('Passport Stamp · Japan'), findsOneWidget);
      await tester.tap(find.byKey(const Key('tee-size-M')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('tee-add-to-cart')));
      await tester.pumpAndSettle();
      final stamp = (
        pack: _stamp,
        recipe: SignatureResolver.hero(_stamp, 'jp', tokens: tripTokens(trip)),
      );
      // Its ink follows the shirt (Black, the default colour).
      expect(
        sent.single.garment.back!.recipeId,
        teeRecipe(stamp, teeGarments.first.$1).recipeId,
      );
      expect(sent.single.title, 'Japan · Passport Stamp');
    });

    testWidgets('opens on the requested design', (tester) async {
      await _tall(tester);
      final trip = TripRecord(
        id: 'jp1',
        countryCode: 'JP',
        startedOn: DateTime(2024, 3, 12),
        endedOn: DateTime(2024, 3, 26),
        photoCount: 40,
        isManual: false,
      );
      await tester.pumpWidget(
        _app(
          _overrides(commerce: true, trips: [trip]),
          const SignatureTeeScreen(countryCode: 'JP', packId: 'passport_stamp'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Passport Stamp · Japan'), findsOneWidget);
    });

    testWidgets('a single design shows no design row', (tester) async {
      await _tall(tester);
      await tester.pumpWidget(
        _app(
          _overrides(commerce: true),
          const SignatureTeeScreen(countryCode: 'JP', packId: 'passport_stamp'),
        ),
      );
      await tester.pumpAndSettle();
      // No trip: the stamp isn't offered, so the default design shows.
      expect(find.text('Torn Flag · Japan'), findsOneWidget);
      expect(find.byKey(const Key('tee-designs')), findsNothing);
    });

    testWidgets('without the pack it says so instead of selling nothing', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          _overrides(commerce: true, pack: false),
          const SignatureTeeScreen(countryCode: 'JP'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text("This tee isn't available yet."), findsOneWidget);
      expect(find.byKey(const Key('tee-add-to-cart')), findsNothing);
    });
  });

  group('country page', () {
    CountryDetailState detail() => const CountryDetailState(
      trips: [],
      visitedRegionCodes: {},
      visitedSites: [],
      unvisitedSites: [],
      allSitesInCountry: [],
      photoAssetIds: [],
      stats: CountryStats(
        tripCount: 1,
        totalDays: 5,
        totalPhotos: 0,
        visitedRegions: 0,
        totalRegions: 0,
        visitedHeritageSites: 0,
        totalHeritageSites: 0,
      ),
      totalRegions: 0,
    );

    Future<void> pump(WidgetTester tester, {required bool commerce}) async {
      await _tall(tester);
      await tester.pumpWidget(
        _app([
          ..._overrides(commerce: commerce),
          countryDetailProvider('FR').overrideWith((ref) async => detail()),
          bestHeroForCountryProvider(
            'FR',
          ).overrideWith((ref) => Stream.value(null)),
        ], CountryProfileScreen(isoCode: 'FR', visit: _visit('FR'))),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows the tee when commerce is on, and opens it', (
      tester,
    ) async {
      await pump(tester, commerce: true);
      expect(find.text('Your France tees'), findsOneWidget);
      await tester.tap(find.byKey(const Key('signature-tee-card-open-FR')));
      await tester.pumpAndSettle();
      expect(find.byType(SignatureTeeScreen), findsOneWidget);
    });

    testWidgets('shows nothing when commerce is off', (tester) async {
      await pump(tester, commerce: false);
      expect(find.text('Your France tees'), findsNothing);
      expect(find.byKey(const Key('signature-tee-card-FR')), findsNothing);
    });
  });

  group('trip detail sheet', () {
    final trip = TripRecord(
      id: 'it1',
      countryCode: 'IT',
      startedOn: DateTime(2023, 4, 2),
      endedOn: DateTime(2023, 4, 9),
      photoCount: 20,
      isManual: false,
    );

    Future<void> pump(WidgetTester tester, {required bool commerce}) async {
      await _tall(tester);
      await tester.pumpWidget(
        _app(
          _overrides(commerce: commerce),
          Scaffold(
            body: Builder(
              builder:
                  (context) => TextButton(
                    onPressed:
                        () => showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          builder:
                              (_) => TripDetailSheet(
                                trip: trip,
                                isFirstVisit: false,
                              ),
                        ),
                    child: const Text('open'),
                  ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('shows the tee when commerce is on; tap closes and opens it', (
      tester,
    ) async {
      await pump(tester, commerce: true);
      expect(find.byKey(const Key('signature-tee-card-IT')), findsOneWidget);
      await tester.tap(find.byKey(const Key('signature-tee-card-open-IT')));
      await tester.pumpAndSettle();
      expect(find.byType(TripDetailSheet), findsNothing);
      expect(find.byType(SignatureTeeScreen), findsOneWidget);
    });

    testWidgets('shows nothing when commerce is off', (tester) async {
      await pump(tester, commerce: false);
      expect(find.byType(TripDetailSheet), findsOneWidget);
      expect(find.byKey(const Key('signature-tee-card-IT')), findsNothing);
      expect(find.text('Your Italy tees'), findsNothing);
    });
  });

  group('new-country celebration', () {
    Future<void> drain(WidgetTester tester) async {
      // Confetti / globe timers.
      await tester.pump(const Duration(seconds: 4));
    }

    testWidgets('single country: "Get this tee" when commerce is on', (
      tester,
    ) async {
      await _tall(tester);
      await tester.pumpWidget(
        _app(
          _overrides(commerce: true),
          DiscoveryOverlay(isoCode: 'PT', xpEarned: 50, onDone: () {}),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('Get this tee'), findsOneWidget);
      await tester.tap(find.byKey(const Key('celebration-get-tee')));
      await drain(tester);
      await tester.pumpAndSettle();
      expect(find.byType(SignatureTeeScreen), findsOneWidget);
    });

    testWidgets('single country: nothing when commerce is off', (tester) async {
      await _tall(tester);
      await tester.pumpWidget(
        _app(
          _overrides(commerce: false),
          DiscoveryOverlay(isoCode: 'PT', xpEarned: 50, onDone: () {}),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('Get this tee'), findsNothing);
      await drain(tester);
    });

    for (final commerce in [true, false]) {
      testWidgets('carousel: "Get this tee" only with commerce ($commerce)', (
        tester,
      ) async {
        await _tall(tester);
        await tester.pumpWidget(
          _app(
            _overrides(commerce: commerce),
            CountryCelebrationCarousel(
              codes: const ['PT', 'ES'],
              firstVisitedByCode: const {},
              onDone: () {},
            ),
          ),
        );
        await tester.pump();
        await tester.pump();
        expect(
          find.byKey(const Key('celebration-tee-PT')),
          commerce ? findsOneWidget : findsNothing,
        );
        expect(
          find.text('Get this tee'),
          commerce ? findsOneWidget : findsNothing,
        );
        await drain(tester);
      });
    }

    testWidgets('gives way on a screen too short for it', (tester) async {
      await tester.binding.setSurfaceSize(const Size(375, 620));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _app(
          _overrides(commerce: true),
          DiscoveryOverlay(isoCode: 'PT', xpEarned: 50, onDone: () {}),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('Get this tee'), findsNothing);
      expect(tester.takeException(), isNull);
      await drain(tester);
    });
  });

  group('My tees', () {
    final visits = [
      _visit('FR', DateTime(2018)),
      _visit('JP', DateTime(2024)),
      _visit('BR', DateTime(2021)),
    ];

    for (final commerce in [true, false]) {
      testWidgets('Stats card only with commerce ($commerce)', (tester) async {
        await tester.pumpWidget(
          _app(
            _overrides(commerce: commerce, visits: visits),
            Scaffold(body: CommerceEntry.myTeesCard()),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('my-tees-card')),
          commerce ? findsOneWidget : findsNothing,
        );
        if (commerce) expect(find.textContaining('all 3 countries'), findsOne);
      });
    }

    testWidgets('lists one tee per country, newest first; tap opens it', (
      tester,
    ) async {
      await _tall(tester);
      await tester.pumpWidget(
        _app(
          _overrides(commerce: true, visits: visits),
          Scaffold(body: CommerceEntry.myTeesCard()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('my-tees-card')));
      await tester.pumpAndSettle();
      expect(find.byType(MyTeesScreen), findsOneWidget);

      final tiles =
          tester
              .widgetList<Material>(
                find.byWidgetPredicate(
                  (w) =>
                      w is Material &&
                      w.key is ValueKey<String> &&
                      (w.key! as ValueKey<String>).value.startsWith('my-tee-'),
                ),
              )
              .map((m) => (m.key! as ValueKey<String>).value)
              .toList();
      expect(tiles, ['my-tee-JP', 'my-tee-BR', 'my-tee-FR']);

      await tester.tap(find.byKey(const Key('my-tee-BR')));
      await tester.pumpAndSettle();
      expect(find.byType(SignatureTeeScreen), findsOneWidget);
      expect(find.text('Brazil'), findsWidgets);
    });

    testWidgets('empty state when nothing is visited', (tester) async {
      await tester.pumpWidget(
        _app(_overrides(commerce: true), MyTeesScreen(onOpenTee: (_, __) {})),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Scan your photos'), findsOneWidget);
    });
  });

  testWidgets('tee openers push nothing when commerce is off', (tester) async {
    await tester.pumpWidget(
      _app(
        _overrides(commerce: false),
        Scaffold(
          body: Builder(
            builder:
                (context) => Column(
                  children: [
                    TextButton(
                      onPressed:
                          () => CommerceEntry.openSignatureTee(context, 'FR'),
                      child: const Text('tee'),
                    ),
                    TextButton(
                      onPressed: () => CommerceEntry.openMyTees(context),
                      child: const Text('tees'),
                    ),
                  ],
                ),
          ),
        ),
      ),
    );
    for (final label in ['tee', 'tees']) {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(find.byType(SignatureTeeScreen), findsNothing);
      expect(find.byType(MyTeesScreen), findsNothing);
    }
  });

  group('Stats screen', () {
    for (final commerce in [true, false]) {
      testWidgets('My tees card only with commerce ($commerce)', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(800, 4000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final db = RoavvyDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        await tester.pumpWidget(
          _app([
            ..._overrides(commerce: commerce, visits: [_visit('FR')]),
            roavvyDatabaseProvider.overrideWithValue(db),
            visitRepositoryProvider.overrideWithValue(VisitRepository(db)),
            achievementRepositoryProvider.overrideWithValue(
              AchievementRepository(db),
            ),
            regionRepositoryProvider.overrideWithValue(RegionRepository(db)),
            tripRepositoryProvider.overrideWithValue(TripRepository(db)),
            heritageRepositoryProvider.overrideWithValue(
              HeritageRepository(db),
            ),
          ], const Scaffold(body: StatsScreen())),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 2));
        expect(
          find.byKey(const Key('my-tees-card')),
          commerce ? findsOneWidget : findsNothing,
        );
      });
    }
  });
}
