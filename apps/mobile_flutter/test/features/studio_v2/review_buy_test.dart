// M22 — Review & Buy: the finished product, and nothing that could change it.
//
// Every other Studio step is allowed to alter the design. This one is not, and
// most of what follows is that single promise checked from every angle — plus
// the one that costs real money: the cart must receive the artwork on screen.
import 'dart:typed_data';

import 'package:country_lookup/country_lookup.dart';
import 'package:design_forge/design_forge.dart';
import 'package:design_studio/design_studio.dart';
import 'package:flutter/material.dart' hide Orientation;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/providers.dart';
import 'package:mobile_flutter/features/studio_v2/commerce/garment_cart_request.dart';
import 'package:mobile_flutter/features/studio_v2/studio_v2_app.dart';
import 'package:mobile_flutter/features/studio_v2/studio_v2_screen.dart';
import 'package:mobile_flutter/features/studio_v2/studio_v2_stage.dart';
import 'package:mobile_flutter/features/studio_v2/widgets/shirt_preview.dart';
import 'package:region_lookup/region_lookup.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StudioController controller;
  late List<GarmentCartRequest> carts;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    controller = buildStudioV2Controller();
    carts = [];
  });
  tearDown(() => controller.dispose());

  int subject(String label) =>
      StudioController.subjects.indexWhere((s) => s.$3 == label);

  /// A session carrying an edit from every step, so anything M22 disturbs
  /// shows up by name.
  void finish(StudioController c) {
    c.selectSubject(subject('Flags'));
    c.applyDetailChoice('heart');
    c.setGarment('#FF1B2B');
    c.setSize(SizeClass.small); // M17
    final (style, styled) = c.vibeStyleOptions()[LabStyle.retro.index];
    c.onStyleTap(style, styled); // M15
    c.commitFineTune(
      c.colourChoices()
          .firstWhere((x) => x.id == 'printStyle')
          .write(c.current, 'riso'), // M19
    );
    c.commitTitle('EUROPE 2026'); // M20
    c.setFrontFit(FrontFit.chest); // M21
    c.setFrontArt(FrontArt.ribbon);
  }

  ({String back, String front, String? title, String? garment, SizeClass size})
  sessionOf(StudioController c) => (
    back: c.hero.recipeId,
    front: c.frontFace.recipeId,
    title: c.hero.content.meta['title'] as String?,
    garment: c.hero.palette?.garmentColour,
    size: c.hero.composition.sizeClass,
  );

  Future<StudioV2ScreenState> pump(
    WidgetTester tester, {
    String? priceLabel,
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
          home: StudioV2Screen(
            key: key,
            controller: controller,
            priceLabel: priceLabel,
            onAddToCart: (context, req) async => carts.add(req),
          ),
        ),
      ),
    );
    await tester.pump();
    return key.currentState!;
  }

  Future<StudioV2ScreenState> pumpReview(
    WidgetTester tester, {
    String? priceLabel,
  }) async {
    final state = await pump(tester, priceLabel: priceLabel);
    state.goToStage(StudioStage.review);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    return state;
  }

  Future<void> reveal(WidgetTester tester, Key key) async {
    await tester.scrollUntilVisible(
      find.byKey(key),
      200,
      scrollable:
          find
              .descendant(
                of: find.byKey(const Key('v2-review-scroll')),
                matching: find.byType(Scrollable),
              )
              .first,
    );
    await tester.ensureVisible(find.byKey(key));
    await tester.pump();
  }

  group('the design arrives finished, and stays finished', () {
    testWidgets('entering Review regenerates nothing', (tester) async {
      finish(controller);
      final before = sessionOf(controller);
      final history = controller.history.length;

      final state = await pump(tester);
      state.goToStage(StudioStage.review);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(sessionOf(controller), before);
      expect(controller.history.length, history, reason: 'review is not an edit');
      expect(controller.currentDetailId, 'heart');
      expect(controller.currentStyle, LabStyle.retro);
      expect(controller.hero.effects!.riso, greaterThan(0), reason: 'M19');
      expect(controller.hero.composition.sizeClass, SizeClass.small);
    });

    testWidgets('both finished faces are shown, and labelled', (tester) async {
      finish(controller);
      await pumpReview(tester);

      final front = tester.widget<ShirtPreview>(
        find.byKey(const Key('v2-review-front')),
      );
      final back = tester.widget<ShirtPreview>(
        find.byKey(const Key('v2-review-back')),
      );
      expect(front.front, isTrue);
      expect(back.front, isFalse);
      // The EXACT recipes the session ended with — not re-derived.
      expect(front.recipe.recipeId, controller.frontFace.recipeId);
      expect(back.recipe.recipeId, controller.hero.recipeId);
      expect(find.text('Front'), findsOneWidget);
      expect(find.text('Back'), findsOneWidget);
    });

    testWidgets('a None front reviews as a plain shirt', (tester) async {
      finish(controller);
      controller.setFrontFit(FrontFit.none);
      await pumpReview(tester);
      final front = tester.widget<ShirtPreview>(
        find.byKey(const Key('v2-review-front')),
      );
      expect(front.printArea, Rect.zero, reason: 'nothing prints on the front');
      expect(find.byKey(const Key('v2-review-back')), findsOneWidget);
    });

    testWidgets('the design phase is over: no engine controls here', (
      tester,
    ) async {
      finish(controller);
      await pumpReview(tester);
      for (final k in [
        'v2-finetune-scroll',
        'v2-finetune-reset',
        'v2-customise-next',
        'v2-recipe-undo',
        'v2-next',
        'v2-title-field',
        'v2-front-fit-full',
      ]) {
        expect(
          find.byKey(Key(k)),
          findsNothing,
          reason: '$k is a design control and does not belong on Review',
        );
      }
    });
  });

  group('the summary speaks to a customer', () {
    testWidgets('it shows the meaningful choices, not the recipe', (
      tester,
    ) async {
      finish(controller);
      await pumpReview(tester);

      expect(find.text('Your design'), findsOneWidget);
      expect(find.text(controller.garmentName), findsOneWidget);
      expect(find.text('Flags'), findsOneWidget);
      expect(find.text('Retro'), findsOneWidget);
      expect(find.text('EUROPE 2026'), findsOneWidget);
      expect(find.text(controller.frontLabel), findsOneWidget);

      // …and none of the engine's own vocabulary.
      for (final jargon in ['recipeId', 'FillAlgorithm', 'ColourStrategy']) {
        expect(find.textContaining(jargon), findsNothing);
      }
    });
  });

  group('save and favourite', () {
    testWidgets('Save keeps BOTH faces as one reproducible garment', (
      tester,
    ) async {
      finish(controller);
      final before = sessionOf(controller);
      await pumpReview(tester);

      await reveal(tester, const Key('v2-review-save'));
      await tester.tap(find.byKey(const Key('v2-review-save')));
      await tester.pump();

      final lib = controller.library!.library;
      expect(lib.contains(controller.garment.garmentId), isTrue);
      expect(sessionOf(controller), before, reason: 'saving changed the design');
    });

    testWidgets('Favourite hearts the design through the existing library', (
      tester,
    ) async {
      finish(controller);
      final before = sessionOf(controller);
      await pumpReview(tester);
      expect(controller.isFavourite, isFalse);

      await reveal(tester, const Key('v2-review-favourite'));
      await tester.tap(find.byKey(const Key('v2-review-favourite')));
      await tester.pump();

      expect(controller.isFavourite, isTrue);
      expect(
        controller.library!.library.isLiked(controller.hero.recipeId),
        isTrue,
      );
      expect(sessionOf(controller), before, reason: 'the heart is a marker');
    });

    test('the heart follows the design, not the side being viewed', () {
      final c = buildStudioV2Controller();
      addTearDown(c.dispose);
      c.setSide(true); // looking at the front
      c.toggleFavourite();
      expect(c.isFavourite, isTrue);
      c.setSide(false);
      expect(
        c.isFavourite,
        isTrue,
        reason: 'the heart meant something different depending on the view',
      );
    });
  });

  group('the cart', () {
    testWidgets('Add to cart sends the exact finished session', (tester) async {
      finish(controller);
      await pumpReview(tester);
      final before = sessionOf(controller);

      await tester.tap(find.byKey(const Key('v2-review-add-to-cart')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(carts, hasLength(1));
      final req = carts.single;
      expect(req.garment.back!.recipeId, controller.hero.recipeId);
      expect(req.garment.front!.recipeId, controller.frontFace.recipeId);
      expect(req.title, 'EUROPE 2026');
      expect(req.garmentColourHex, '#FF1B2B');
      expect(req.renderFrontArtwork, isNotNull, reason: 'a chest print');
      // Handing off to commerce is not a design change.
      expect(sessionOf(controller), before);
    });

    testWidgets('a None front sends no front artwork', (tester) async {
      finish(controller);
      controller.setFrontFit(FrontFit.none);
      await pumpReview(tester);

      await tester.tap(find.byKey(const Key('v2-review-add-to-cart')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(carts.single.renderFrontArtwork, isNull);
      expect(carts.single.frontPosition, 'none');
    });

    testWidgets('size and quantity are the commerce screen\'s business', (
      tester,
    ) async {
      // They are physical product state, not design state, and the flow this
      // hands off to already asks for them. Asking twice means two answers.
      finish(controller);
      await pumpReview(tester);
      for (final t in ['Quantity', 'Size', 'Size: L', 'Total']) {
        expect(find.text(t), findsNothing, reason: '$t belongs to commerce');
      }
    });
  });

  group('price', () {
    testWidgets('it comes from the store, never from a mockup', (tester) async {
      finish(controller);
      await pumpReview(tester, priceLabel: r'$41.00');
      expect(find.textContaining(r'$41.00'), findsOneWidget);
      // The mockup's number must never appear on its own.
      expect(find.textContaining(r'$34.00'), findsNothing);
    });

    testWidgets('with no price from the store, none is invented', (
      tester,
    ) async {
      finish(controller);
      await pumpReview(tester);
      expect(find.text('Add to cart'), findsOneWidget);
      expect(find.textContaining(r'$'), findsNothing);
    });
  });

  group('navigation', () {
    testWidgets('Back returns to Front Design with the session intact', (
      tester,
    ) async {
      finish(controller);
      final state = await pump(tester);
      state.goToStage(StudioStage.front);
      await tester.pump();
      final before = sessionOf(controller);

      await tester.tap(find.byKey(const Key('v2-customise-next')));
      await tester.pump();
      expect(state.stage, StudioStage.placement);
      state.goToStage(StudioStage.review);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byKey(const Key('v2-review-workflow-back')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(state.stage, StudioStage.placement);
      expect(sessionOf(controller), before);
    });

    testWidgets('a later front edit is reflected on the way back in', (
      tester,
    ) async {
      finish(controller);
      final state = await pumpReview(tester);
      final firstFront =
          tester
              .widget<ShirtPreview>(find.byKey(const Key('v2-review-front')))
              .recipe
              .recipeId;

      state.goToStage(StudioStage.front);
      await tester.pump();
      controller.setFrontArt(FrontArt.matchBack);
      await tester.pump();
      state.goToStage(StudioStage.review);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final shown =
          tester
              .widget<ShirtPreview>(find.byKey(const Key('v2-review-front')))
              .recipe
              .recipeId;
      expect(shown, isNot(firstFront));
      expect(shown, controller.frontFace.recipeId);
    });

    testWidgets('nothing overflows a phone', (tester) async {
      finish(controller);
      await pumpReview(tester);
      expect(tester.takeException(), isNull);
    });
  });
}
