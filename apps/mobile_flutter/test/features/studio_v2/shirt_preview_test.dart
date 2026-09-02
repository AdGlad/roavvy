// The Studio hero on a real garment: the design shown on the shirt colour you
// actually chose, with a toggle back to the flat artwork.
import 'dart:ui' as ui;

import 'package:design_forge/design_forge.dart';
import 'package:design_studio/design_studio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/shared/garment_mockup/garment_mockup_spec.dart';
import 'package:mobile_flutter/features/studio_v2/host/studio_garments.dart';
import 'package:mobile_flutter/features/studio_v2/studio_v2_app.dart';
import 'package:mobile_flutter/features/studio_v2/studio_v2_screen.dart';
import 'package:mobile_flutter/features/studio_v2/widgets/garment_preview.dart';
import 'package:mobile_flutter/features/studio_v2/widgets/shirt_preview.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StudioGarments', () {
    test('every Studio palette colour tints to its exact hex', () {
      // The palette is wider than the photography; none of these may silently
      // become a near-miss photo.
      for (final (hex, label) in StudioController.garments) {
        final spec = StudioGarments.specFor(garmentColour: hex, front: true);
        expect(spec.tintColour, isNotNull, reason: '$label was not tinted');
        expect(
          spec.tintColour!.toARGB32().toRadixString(16).substring(2),
          hex.replaceFirst('#', '').toLowerCase(),
          reason: '$label did not render its own colour',
        );
      }
    });

    test('the two faces use the two garment photos', () {
      final front = StudioGarments.specFor(
        garmentColour: '#1F2B33',
        front: true,
      );
      final back = StudioGarments.specFor(
        garmentColour: '#1F2B33',
        front: false,
      );
      expect(front.assetPath, BundledGarments.tintBaseFront);
      expect(back.assetPath, BundledGarments.tintBaseBack);
      expect(front.printAreaNorm, isNot(back.printAreaNorm));
    });

    test('a missing or malformed colour falls back, never crashes', () {
      for (final bad in [null, '', 'nonsense', '#12']) {
        final spec = StudioGarments.specFor(garmentColour: bad, front: true);
        expect(spec.tintColour, StudioGarments.defaultColour);
      }
    });

    test('each colour is a distinct cache entry', () {
      final olive = StudioGarments.specFor(
        garmentColour: '#6B7350',
        front: true,
      );
      final sand = StudioGarments.specFor(
        garmentColour: '#D8C9A3',
        front: true,
      );
      expect(olive.garmentKey, isNot(sand.garmentKey));
      // …but the same colour on the same face is one entry.
      final again = StudioGarments.specFor(
        garmentColour: '#6B7350',
        front: true,
      );
      expect(olive.garmentKey, again.garmentKey);
    });

    test('parseHex handles both hex forms', () {
      expect(StudioGarments.parseHex('#6B7350')!.toARGB32(), 0xFF6B7350);
      expect(StudioGarments.parseHex('FF6B7350')!.toARGB32(), 0xFF6B7350);
      expect(StudioGarments.parseHex('zzz'), isNull);
    });
  });

  group('how a design meets the fabric', () {
    DesignRecipe recipe(DesignFamily family, {Clip? clip}) => DesignRecipe(
      seed: 1,
      content: const RecipeContent(flags: [FlagRef('us')]),
      composition: Composition(family: family),
      clip: clip,
    );

    test('a flag composition is multiplied into the cloth', () {
      // Full-bleed: painting it over the shirt would stamp a white rectangle
      // around the design — the bug this rule exists to prevent.
      for (final f in [
        DesignFamily.grid,
        DesignFamily.singleHero,
        DesignFamily.duoBlend,
        DesignFamily.tornHero,
      ]) {
        expect(
          ShirtPreview.blendFor(recipe(f)),
          ui.BlendMode.multiply,
          reason: '\$f fills its canvas and must multiply',
        );
      }
    });

    test('a clipped design keeps its own colours', () {
      // It carries real transparency, so it composites over the shirt and stays
      // true on a dark garment instead of going muddy.
      expect(
        ShirtPreview.blendFor(
          recipe(DesignFamily.grid, clip: const Clip(shapeId: 'heart')),
        ),
        ui.BlendMode.srcOver,
      );
      expect(
        ShirtPreview.blendFor(
          recipe(DesignFamily.grid, clip: const Clip(shapeId: 'passportPage')),
        ),
        ui.BlendMode.srcOver,
      );
    });

    test('an explicit no-clip still counts as full-bleed', () {
      expect(
        ShirtPreview.blendFor(
          recipe(DesignFamily.grid, clip: const Clip(shapeId: 'none')),
        ),
        ui.BlendMode.multiply,
      );
    });

    test('data-driven families composite over the shirt', () {
      for (final f in [
        DesignFamily.timeline,
        DesignFamily.journeys,
        DesignFamily.wordCloud,
        DesignFamily.badge,
        DesignFamily.stats,
        DesignFamily.achievements,
        DesignFamily.frontRibbon,
      ]) {
        expect(
          ShirtPreview.blendFor(recipe(f)),
          ui.BlendMode.srcOver,
          reason: '\$f draws on transparency',
        );
      }
    });
  });

  group('Studio hero', () {
    late StudioController controller;

    setUp(() => controller = buildStudioV2Controller());
    tearDown(() => controller.dispose());

    Future<void> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1600, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(home: StudioV2Screen(controller: controller)),
      );
      await tester.pump(); // the preview spinner never settles
    }

    testWidgets('opens on the shirt, not the flat artwork', (tester) async {
      await pump(tester);
      expect(find.byType(ShirtPreview), findsOneWidget);
      expect(find.byType(GarmentPreview), findsNothing);
      // The hero keeps its identity either way.
      expect(find.byKey(const Key('v2-garment-preview')), findsOneWidget);
    });

    testWidgets('the toggle switches to flat artwork and back', (tester) async {
      await pump(tester);

      await tester.tap(find.byKey(const Key('v2-view-artwork')));
      await tester.pump();
      expect(find.byType(GarmentPreview), findsOneWidget);
      expect(find.byType(ShirtPreview), findsNothing);

      await tester.tap(find.byKey(const Key('v2-view-shirt')));
      await tester.pump();
      expect(find.byType(ShirtPreview), findsOneWidget);
    });

    testWidgets('switching the view never touches the design', (tester) async {
      await pump(tester);
      final before = controller.current.recipeId;
      final historyBefore = controller.history.length;

      await tester.tap(find.byKey(const Key('v2-view-artwork')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('v2-view-shirt')));
      await tester.pump();

      expect(controller.current.recipeId, before);
      expect(
        controller.history.length,
        historyBefore,
        reason: 'a view toggle must not enter the undo history',
      );
    });

    testWidgets('the shirt follows the garment colour the user picks', (
      tester,
    ) async {
      await pump(tester);
      controller.setGarment('#FF5723'); // Orange — no photograph exists
      await tester.pump();

      final preview = tester.widget<ShirtPreview>(find.byType(ShirtPreview));
      expect(preview.recipe.palette?.garmentColour, '#FF5723');
      final spec = StudioGarments.specFor(
        garmentColour: preview.recipe.palette?.garmentColour,
        front: preview.front,
      );
      expect(spec.tintColour!.toARGB32(), 0xFFFF5723);
    });

    testWidgets('the shirt follows the front/back side selector', (
      tester,
    ) async {
      await pump(tester);
      final front =
          tester.widget<ShirtPreview>(find.byType(ShirtPreview)).front;

      await tester.tap(
        find.byKey(Key(front ? 'v2-side-back' : 'v2-side-front')),
      );
      await tester.pump();
      expect(
        tester.widget<ShirtPreview>(find.byType(ShirtPreview)).front,
        !front,
      );
    });
  });
}
