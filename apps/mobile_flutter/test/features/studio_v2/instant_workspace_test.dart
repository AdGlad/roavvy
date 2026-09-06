// M11 — Instant as a product screen: swipe finished shirts, dress them, and
// leave by one of three doors (buy, customise, save).
import 'dart:ui' as ui;

import 'package:design_forge/design_forge.dart';
import 'package:design_forge_render/design_forge_render.dart';
import 'package:design_studio/design_studio.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart' hide Orientation;
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/studio_v2/commerce/garment_cart_request.dart';
import 'package:mobile_flutter/features/studio_v2/widgets/instant_workspace.dart';
import 'package:mobile_flutter/features/studio_v2/widgets/shirt_preview.dart';

class _NoopResolver implements AssetResolver {
  @override
  Future<ui.Image> resolveFlag(
    String code, {
    required int width,
    required int height,
  }) => throw UnimplementedError();
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

class _MemoryStore implements DesignStore {
  String? contents;
  @override
  Future<String?> read() async => contents;
  @override
  Future<void> write(String c) async => contents = c;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StudioController controller;
  late PersistentDesignLibrary library;

  setUp(() {
    library = PersistentDesignLibrary(_MemoryStore());
    controller = StudioController(
      generator: LabShowcaseGenerator(
        silhouettesByShape: const {},
        countryNames: const {},
      ),
      service: RenderService(_NoopResolver()),
      designContext: const DesignContext(
        flagCodes: ['us', 'fr', 'jp', 'br'],
        scopeKey: 'test:instant',
      ),
      initialSeed: 4,
      library: library,
    );
  });

  tearDown(() => controller.dispose());

  Future<({int customise, List<GarmentCartRequest> carts})> pump(
    WidgetTester tester, {
    bool withCart = true,
    Size size = const Size(390, 844),
  }) async {
    var customise = 0;
    final carts = <GarmentCartRequest>[];
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InstantWorkspace(
            controller: controller,
            onCustomise: () => customise++,
            onAddToCart:
                withCart ? (context, req) async => carts.add(req) : null,
          ),
        ),
      ),
    );
    await tester.pump();
    return (customise: customise, carts: carts);
  }

  group('it opens on a finished shirt', () {
    testWidgets('the garment is on screen with all three ways out', (
      tester,
    ) async {
      await pump(tester);
      expect(find.byKey(const Key('v2-instant-deck')), findsOneWidget);
      expect(find.byKey(const Key('v2-instant-buy')), findsOneWidget);
      expect(find.byKey(const Key('v2-instant-customise')), findsOneWidget);
      expect(find.byKey(const Key('v2-instant-save')), findsOneWidget);
      expect(find.byKey(const Key('v2-instant-title')), findsOneWidget);
    });

    testWidgets('there is ONE Customise, not Configure and Start custom', (
      tester,
    ) async {
      await pump(tester);
      expect(find.byKey(const Key('v2-instant-configure')), findsNothing);
      expect(find.byKey(const Key('v2-instant-custom')), findsNothing);
      expect(find.text('Customise'), findsOneWidget);
    });

    testWidgets('the shirt dominates the screen', (tester) async {
      // The promise is "here is your shirt". A shirt in the bottom third of a
      // configuration screen does not make it.
      await pump(tester);
      final deck = tester.getSize(find.byKey(const Key('v2-instant-deck')));
      expect(
        deck.height,
        greaterThan(844 * 0.45),
        reason: 'the garment should own most of the useful area',
      );
    });

    testWidgets('no engine terminology reaches this screen', (tester) async {
      await pump(tester);
      for (final word in [
        'Direction',
        'Vibe',
        'Focus',
        'Fine Tune',
        'Recipe',
        'Seed',
      ]) {
        expect(
          find.textContaining(word),
          findsNothing,
          reason: '"$word" is engine vocabulary, not a customer\'s',
        );
      }
    });

    testWidgets('one representation of the design, not two', (tester) async {
      // A hero above a deck of the same design gives the page two things that
      // can disagree with each other.
      await pump(tester);
      final shown = tester.widgetList<ShirtPreview>(find.byType(ShirtPreview));
      expect(shown.map((p) => p.front).toSet(), hasLength(1));
    });
  });

  group('browsing finished designs', () {
    testWidgets('a finger swipe pages forward and back', (tester) async {
      await pump(tester);
      expect(controller.instantIndex, 0);
      final deck = find.byKey(const Key('v2-instant-deck'));

      Future<void> swipe(double dx) async {
        final g = await tester.startGesture(
          tester.getCenter(deck),
          kind: PointerDeviceKind.touch,
        );
        for (var i = 0; i < 6; i++) {
          await g.moveBy(Offset(dx, 0));
          await tester.pump(const Duration(milliseconds: 16));
        }
        await g.up();
        await tester.pumpAndSettle();
      }

      await swipe(-45);
      expect(controller.instantIndex, 1);
      await swipe(45);
      expect(
        controller.instantIndex,
        0,
        reason: 'browsing back must return to the same design',
      );
    });

    testWidgets('a mouse drag works too, not just touch', (tester) async {
      // Flutter's desktop scroll behaviour omits the mouse, which left the
      // deck completely unswipeable on macOS.
      await pump(tester);
      final centre = tester.getCenter(find.byKey(const Key('v2-instant-deck')));
      final mouse = await tester.startGesture(
        centre,
        kind: PointerDeviceKind.mouse,
      );
      for (var i = 0; i < 4; i++) {
        await mouse.moveBy(const Offset(-70, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await mouse.up();
      await tester.pumpAndSettle();
      expect(controller.instantIndex, 1);
    });

    testWidgets('the arrows step the deck, and wrap', (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const Key('v2-instant-next')));
      await tester.pumpAndSettle();
      expect(controller.instantIndex, 1);

      await tester.tap(find.byKey(const Key('v2-instant-prev')));
      await tester.pumpAndSettle();
      expect(controller.instantIndex, 0);

      await tester.tap(find.byKey(const Key('v2-instant-prev')));
      await tester.pumpAndSettle();
      expect(controller.instantIndex, controller.instantPicks.length - 1);
    });

    testWidgets('only a page or two is rendered, never the whole deck', (
      tester,
    ) async {
      // Eight full-size garment renders on open would put a shopping screen
      // behind a spinner. The PageView must stay lazy.
      await pump(tester);
      final shown =
          tester.widgetList<ShirtPreview>(find.byType(ShirtPreview)).length;
      expect(shown, lessThan(controller.instantPicks.length));
    });

    testWidgets('a swipe never regenerates the deck, or renders past its '
        'neighbours', (tester) async {
      // The two ways a browse screen turns to treacle: rebuilding the whole
      // deck on every drag frame, and holding a full-size render of all eight
      // shirts at once. Neither may happen even mid-gesture.
      await pump(tester);
      final deckBefore = controller.instantPicks;
      final idsBefore = [for (final p in deckBefore) p.recipeId];

      final g = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('v2-instant-deck'))),
        kind: PointerDeviceKind.touch,
      );
      for (var i = 0; i < 6; i++) {
        await g.moveBy(const Offset(-45, 0));
        await tester.pump(const Duration(milliseconds: 16));
        expect(
          identical(controller.instantPicks, deckBefore),
          isTrue,
          reason: 'the deck was rebuilt mid-drag',
        );
        expect(
          tester.widgetList<ShirtPreview>(find.byType(ShirtPreview)).length,
          lessThanOrEqualTo(3),
          reason: 'more than an adjacent-page buffer is rendering',
        );
      }
      await g.up();
      await tester.pumpAndSettle();

      expect([for (final p in controller.instantPicks) p.recipeId], idsBefore);
      expect(controller.instantIndex, 1);
    });

    testWidgets('browsing leaves the travel context alone', (tester) async {
      await pump(tester);
      final codes = [...controller.selectedCountryCodes];
      await tester.tap(find.byKey(const Key('v2-instant-next')));
      await tester.pumpAndSettle();
      expect(controller.selectedCountryCodes, codes);
    });
  });

  group('dressing the shirt never redraws it', () {
    testWidgets('the shirt colour preserves the design', (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const Key('v2-instant-next')));
      await tester.pumpAndSettle();
      final design = controller.hero;

      await tester.tap(find.byKey(const Key('v2-instant-garment-Red')));
      await tester.pumpAndSettle();
      expect(controller.hero.palette?.garmentColour, '#FF1B2B');
      expect(controller.hero.composition.family, design.composition.family);
      expect(controller.hero.clip?.shapeId, design.clip?.shapeId);
      expect(controller.hero.seed, design.seed);
      expect(controller.instantIndex, 1, reason: 'still the same pick');
    });

    testWidgets('Front/Back shows the other side of the SAME design', (
      tester,
    ) async {
      await pump(tester);
      final back = controller.hero.recipeId;
      await tester.tap(find.byKey(const Key('v2-instant-side-front')));
      await tester.pumpAndSettle();
      expect(controller.onFront, isTrue);
      expect(controller.hero.recipeId, back, reason: 'the design is untouched');

      await tester.tap(find.byKey(const Key('v2-instant-side-back')));
      await tester.pumpAndSettle();
      expect(controller.onFront, isFalse);
      expect(controller.hero.recipeId, back);
    });
  });

  group('the three doors', () {
    testWidgets('Add to Cart hands the design straight to commerce', (
      tester,
    ) async {
      final r = await pump(tester);
      await tester.tap(find.byKey(const Key('v2-instant-buy')));
      await tester.pumpAndSettle();
      expect(r.carts, hasLength(1));
      final req = r.carts.single;
      expect(req.garmentColourHex, controller.hero.palette?.garmentColour);
      expect(req.renderBackArtwork, isNotNull);
    });

    testWidgets('Add to Cart with none wired says so', (tester) async {
      final r = await pump(tester, withCart: false);
      await tester.tap(find.byKey(const Key('v2-instant-buy')));
      await tester.pump();
      expect(r.carts, isEmpty);
      expect(find.textContaining('not available'), findsOneWidget);
    });

    testWidgets('Customise carries the browsed design across untouched', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.byKey(const Key('v2-instant-next')));
      await tester.pumpAndSettle();
      final chosen = controller.hero.recipeId;

      await tester.tap(find.byKey(const Key('v2-instant-customise')));
      await tester.pumpAndSettle();
      expect(
        controller.hero.recipeId,
        chosen,
        reason: 'Customise edits THIS design; it must not roll a new one',
      );
    });

    testWidgets('Save keeps the design in the wardrobe', (tester) async {
      await pump(tester);
      expect(library.library.garments, isEmpty);
      await tester.tap(find.byKey(const Key('v2-instant-save')));
      await tester.pumpAndSettle();
      expect(
        library.library.garments.single.garment!.garmentId,
        controller.garment.garmentId,
      );
    });
  });

  group('it fits a phone', () {
    for (final (label, size) in [
      ('an iPhone 15', const Size(390, 844)),
      ('an iPhone SE', const Size(375, 667)),
    ]) {
      testWidgets('nothing overflows on $label', (tester) async {
        await pump(tester, size: size);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
