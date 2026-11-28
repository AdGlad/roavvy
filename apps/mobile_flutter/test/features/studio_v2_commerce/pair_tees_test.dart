import 'dart:io';
import 'dart:ui' as ui;

import 'package:design_forge/design_forge.dart';
import 'package:design_forge_render/design_forge_render.dart';
import 'package:design_studio/design_studio.dart'
    show RenderService, SignatureCatalog;
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/commerce/commerce_flag.dart';
import 'package:mobile_flutter/core/providers.dart';
import 'package:mobile_flutter/features/merch/shopify_pricing_repository.dart';
import 'package:mobile_flutter/features/studio_v2/commerce/garment_cart_request.dart';
import 'package:mobile_flutter/features/studio_v2_commerce/signature_tees/my_tees_screen.dart';
import 'package:mobile_flutter/features/studio_v2_commerce/signature_tees/pair_tees_screen.dart';
import 'package:mobile_flutter/features/studio_v2_commerce/signature_tees/signature_tee_screen.dart';
import 'package:mobile_flutter/features/studio_v2_commerce/signature_tees/signature_tees.dart';
import 'package:mobile_flutter/features/studio_v2_commerce/studio_v2_cart_service.dart';
import 'package:mobile_flutter/features/travel_timeline/trip_detail_sheet.dart';
import 'package:shared_models/shared_models.dart';

/// M213 — pair (two-country) tees in the app.
///
/// No two-country pack ships yet, so a test-only pair pack stands in; the
/// real one-country `torn_flag` pack rides alongside to prove the two kinds
/// never mix. Nothing renders and nothing reaches Firebase or Shopify.
final SignatureRecipe _single = SignaturePackCodec.decode(
  File(
    '../../packages/design_studio/assets/signature/torn_flag.pack.json',
  ).readAsStringSync(),
);

SignatureRecipe _pairPack() {
  // The torn-flag recipe with a second flag: enough for the resolver, and
  // nothing renders in these tests.
  final json = deepCopyJson(_single.base) as Map<String, Object?>;
  (json['content']! as Map<String, Object?>)['flags'] = [
    {'code': '{{countryA}}', 'weight': 1.0},
    {'code': '{{countryB}}', 'weight': 1.0},
  ];
  return SignatureRecipe(
    id: 'test_pair',
    title: 'Test Pair',
    version: 1,
    status: SignatureStatus.draft,
    base: json,
    countries: 2,
    samplePairs: const ['us+co'],
  );
}

final SignatureRecipe _pair = _pairPack();

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

EffectiveVisitedCountry _visit(String cc, [DateTime? first]) =>
    EffectiveVisitedCountry(
      countryCode: cc,
      hasPhotoEvidence: first != null,
      firstSeen: first,
      lastSeen: first,
    );

TripRecord _trip(
  String id,
  String cc,
  DateTime start,
  int days, {
  int photos = 10,
}) => TripRecord(
  id: id,
  countryCode: cc,
  startedOn: start,
  endedOn: start.add(Duration(days: days)),
  photoCount: photos,
  isManual: false,
);

/// FR → IT → CH in June 2024 is one journey; JP (three trips) and ES are
/// separate.
final _trips = [
  _trip('fr', 'FR', DateTime(2024, 6, 1), 4),
  _trip('it', 'IT', DateTime(2024, 6, 6), 4),
  _trip('ch', 'CH', DateTime(2024, 6, 11), 2),
  _trip('jp1', 'JP', DateTime(2022, 3, 1), 5),
  _trip('jp2', 'JP', DateTime(2023, 3, 1), 5),
  _trip('jp3', 'JP', DateTime(2025, 3, 1), 5),
  _trip('es', 'ES', DateTime(2021, 8, 1), 5, photos: 500),
];

final _visits = [
  _visit('FR', DateTime(2024, 6, 1)),
  _visit('IT', DateTime(2024, 6, 6)),
  _visit('CH', DateTime(2024, 6, 11)),
  _visit('JP', DateTime(2022, 3, 1)),
  _visit('ES', DateTime(2021, 8, 1)),
];

List<Override> _overrides({
  bool commerce = true,
  bool pairPack = true,
  List<EffectiveVisitedCountry>? visits,
  List<TripRecord>? trips,
}) => [
  commerceBuildProvider.overrideWithValue(commerce),
  commerceRemoteSwitchProvider.overrideWithValue(true),
  signatureCatalogProvider.overrideWith(
    (ref) async => SignatureCatalog([_single, if (pairPack) _pair]),
  ),
  signatureTeeRenderServiceProvider.overrideWithValue(
    RenderService(_NoRender()),
  ),
  shopifyPricingProvider.overrideWith(
    (ref) async => const MerchPrices(tshirtFromPrice: r'$39.00'),
  ),
  effectiveVisitsProvider.overrideWith((ref) async => visits ?? _visits),
  tripListProvider.overrideWith((ref) async => trips ?? _trips),
];

Widget _app(List<Override> overrides, Widget home) =>
    ProviderScope(overrides: overrides, child: MaterialApp(home: home));

Future<void> _tall(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(430, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

Future<void> _tapKey(WidgetTester tester, String key) async {
  final f = find.byKey(Key(key), skipOffstage: false);
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
}

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  group('pair tees — model', () {
    test('pair packs make pair tees only; single packs single tees only', () {
      final packs = [_single, _pair];
      expect(teesFor(packs, 'FR').map((t) => t.pack.id), ['torn_flag']);
      final pair = teesForPair(packs, teePair('gr', 'it'));
      expect(pair.map((t) => t.pack.id), ['test_pair']);
      expect(
        pair.single.recipe.recipeId,
        SignatureResolver.heroPair(_pair, 'gr', 'it').recipeId,
      );
      expect(pair.single.recipe.content.flags.map((f) => f.code), ['gr', 'it']);
    });

    test('order matters; a country cannot pair with itself', () {
      final packs = [_pair];
      final ab = teesForPair(packs, teePair('GR', 'IT')).single.recipe;
      final ba = teesForPair(packs, teePair('IT', 'GR')).single.recipe;
      expect(ab.recipeId, isNot(ba.recipeId));
      expect(teesForPair(packs, teePair('GR', 'GR')), isEmpty);
    });

    test('pairTitle uses country names in order', () {
      expect(pairTitle(teePair('gr', 'it')), 'Greece & Italy');
      expect(pairTitle(teePair('IT', 'GR')), 'Italy & Greece');
    });

    test('journeys chain trips a couple of days apart', () {
      expect(journeysFrom(_trips), [
        ['JP'],
        ['FR', 'IT', 'CH'],
        ['JP'],
        ['JP'],
        ['ES'],
      ]);
    });

    test('journeyPairFor: the trip with its neighbour, in travel order', () {
      TripRecord t(String id) => _trips.firstWhere((x) => x.id == id);
      expect(journeyPairFor(_trips, t('fr')), teePair('FR', 'IT'));
      expect(journeyPairFor(_trips, t('it')), teePair('FR', 'IT'));
      expect(journeyPairFor(_trips, t('ch')), teePair('IT', 'CH'));
      expect(journeyPairFor(_trips, t('jp2')), isNull);
    });

    test('suggestions: journeys first, then the two most visited', () {
      expect(pairSuggestions(trips: _trips, visits: _visits), [
        teePair('FR', 'IT'),
        teePair('IT', 'CH'),
        // JP has 3 trips; FR/IT/CH/ES have one each, ES has the most photos.
        teePair('JP', 'ES'),
      ]);
    });

    test('suggestions never repeat a pair in the other order', () {
      final trips = [
        _trip('a', 'FR', DateTime(2024, 1, 1), 2),
        _trip('b', 'IT', DateTime(2024, 1, 3), 2),
        _trip('c', 'FR', DateTime(2024, 1, 5), 2),
      ];
      expect(pairSuggestions(trips: trips, visits: const []), [
        teePair('FR', 'IT'),
      ]);
    });

    test('without trips, the two most recently discovered', () {
      expect(pairSuggestions(trips: const [], visits: _visits), [
        teePair('CH', 'IT'),
      ]);
    });

    test('availability needs a pair pack and two countries', () {
      bool available(List<Override> o) {
        final c = ProviderContainer(overrides: o);
        addTearDown(c.dispose);
        return c.read(pairTeesAvailableProvider);
      }

      Future<void> load(ProviderContainer c) async {
        await c.read(signatureCatalogProvider.future);
        await c.read(effectiveVisitsProvider.future);
      }

      Future<bool> check(List<Override> o) async {
        final c = ProviderContainer(overrides: o);
        addTearDown(c.dispose);
        await load(c);
        return c.read(pairTeesAvailableProvider);
      }

      // Before anything loads: not available.
      expect(available(_overrides()), isFalse);
      return Future.wait([
        check(_overrides()),
        check(_overrides(pairPack: false)),
        check(_overrides(visits: [_visit('FR')])),
      ]).then((r) => expect(r, [true, false, false]));
    });
  });

  group('pair chooser', () {
    testWidgets('pick two, swap, open', (tester) async {
      await _tall(tester);
      final opened = <TeePair>[];
      await tester.pumpWidget(
        _app(_overrides(), PairTeesScreen(onOpenPair: (_, p) => opened.add(p))),
      );
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('pair-open')))
            .onPressed,
        isNull,
      );
      await _tapKey(tester, 'pair-pick-JP');
      await _tapKey(tester, 'pair-pick-ES');
      await tester.pump();
      String picked() =>
          tester.widget<Text>(find.byKey(const Key('pair-picked'))).data!;
      expect(picked(), 'Japan & Spain');
      await _tapKey(tester, 'pair-swap');
      await tester.pump();
      expect(picked(), 'Spain & Japan');
      await _tapKey(tester, 'pair-open');
      await tester.pump();
      expect(opened, [teePair('ES', 'JP')]);

      // A third pick replaces the oldest.
      await _tapKey(tester, 'pair-pick-FR');
      await tester.pump();
      expect(picked(), 'Japan & France');
    });

    testWidgets('suggested pairs come from the journeys', (tester) async {
      await _tall(tester);
      final opened = <TeePair>[];
      await tester.pumpWidget(
        _app(_overrides(), PairTeesScreen(onOpenPair: (_, p) => opened.add(p))),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pair-suggestion-FR-IT')), findsOneWidget);
      expect(find.byKey(const Key('pair-suggestion-IT-CH')), findsOneWidget);
      await tester.tap(find.byKey(const Key('pair-suggestion-FR-IT')));
      await tester.pump();
      expect(opened, [teePair('FR', 'IT')]);
    });

    testWidgets('says so when there is only one country', (tester) async {
      await tester.pumpWidget(
        _app(
          _overrides(visits: [_visit('FR')], trips: const []),
          PairTeesScreen(onOpenPair: (_, __) {}),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('need two countries'), findsOneWidget);
    });
  });

  group('pair tee page', () {
    testWidgets('titled by the pair; swap reverses it; cart gets the pair', (
      tester,
    ) async {
      await _tall(tester);
      final sent = <(GarmentCartRequest, StudioV2PurchaseOptions)>[];
      await tester.pumpWidget(
        _app(
          _overrides(),
          SignatureTeeScreen(
            countryCode: 'gr',
            pairWith: 'it',
            onAddToCart: (context, r, o) async => sent.add((r, o)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Greece & Italy'), findsOneWidget); // app bar
      expect(find.text('Test Pair · Greece & Italy'), findsOneWidget);
      // Only the two-country design is offered: no design row.
      expect(find.byKey(const Key('tee-designs')), findsNothing);

      await _tapKey(tester, 'tee-pair-swap');
      await tester.pumpAndSettle();
      expect(find.text('Italy & Greece'), findsOneWidget);

      await _tapKey(tester, 'tee-size-M');
      await tester.pump();
      await _tapKey(tester, 'tee-add-to-cart');
      await tester.pumpAndSettle();

      expect(sent, hasLength(1));
      final (r, o) = sent.single;
      expect(
        r.session.hero.recipeId,
        SignatureResolver.heroPair(_pair, 'it', 'gr').recipeId,
      );
      expect(r.title, 'Italy & Greece · Test Pair');
      expect(r.selectedCountryCodes, ['it', 'gr']);
      expect(o.size, 'M');
    });

    testWidgets('a single-country page never offers a pair design', (
      tester,
    ) async {
      await _tall(tester);
      await tester.pumpWidget(
        _app(_overrides(), const SignatureTeeScreen(countryCode: 'fr')),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('tee-pair-swap')), findsNothing);
      expect(find.text('Torn Flag · France'), findsOneWidget);
    });
  });

  group('entry points', () {
    for (final (name, overrides, shown) in [
      ('pair pack + two countries', _overrides(), true),
      ('no pair pack', _overrides(pairPack: false), false),
      ('one country', _overrides(visits: [_visit('FR')]), false),
    ]) {
      testWidgets('My tees "Two countries" row: $name', (tester) async {
        await _tall(tester);
        var opened = 0;
        await tester.pumpWidget(
          _app(
            overrides,
            MyTeesScreen(onOpenTee: (_, __) {}, onOpenPairs: (_) => opened++),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('pair-tees-card')),
          shown ? findsOneWidget : findsNothing,
        );
        if (shown) {
          await tester.tap(find.byKey(const Key('pair-tees-card')));
          expect(opened, 1);
        }
      });
    }

    Future<void> openSheet(
      WidgetTester tester,
      TripRecord trip, {
      bool commerce = true,
    }) async {
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

    testWidgets('trip sheet: a multi-country journey offers its pair', (
      tester,
    ) async {
      await openSheet(tester, _trips[1]); // IT, after FR
      final card = find.byKey(
        const Key('trip-pair-tee-FR-IT'),
        skipOffstage: false,
      );
      expect(card, findsOneWidget);
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(find.byType(TripDetailSheet), findsNothing);
      expect(find.byType(SignatureTeeScreen), findsOneWidget);
      expect(find.text('France & Italy'), findsWidgets);
    });

    testWidgets('trip sheet: a one-country journey offers none', (
      tester,
    ) async {
      await openSheet(tester, _trips[3]); // JP alone
      expect(
        find.byWidgetPredicate(
          (w) =>
              w.key is ValueKey<String> &&
              (w.key! as ValueKey<String>).value.startsWith('trip-pair-tee-'),
          skipOffstage: false,
        ),
        findsNothing,
      );
    });

    testWidgets('trip sheet: nothing when commerce is off', (tester) async {
      await openSheet(tester, _trips[1], commerce: false);
      expect(
        find.byKey(const Key('trip-pair-tee-FR-IT'), skipOffstage: false),
        findsNothing,
      );
    });
  });
}
