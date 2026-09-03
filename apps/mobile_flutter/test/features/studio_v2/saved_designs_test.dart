// M181 — saved designs.
//
// Deterministic recipes only pay off if a shirt can come back exactly as it
// was. These cover the three parts of that: the wardrobe can be browsed, a
// design reopens as itself rather than as a lookalike, and it can be ordered
// again without being rebuilt.
import 'dart:ui' as ui;

import 'package:design_forge/design_forge.dart';
import 'package:design_forge_render/design_forge_render.dart';
import 'package:design_studio/design_studio.dart';
import 'dart:typed_data';

import 'package:flutter/material.dart' hide Orientation;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/providers.dart';
import 'package:mobile_flutter/features/studio_v2/studio_v2_screen.dart';
import 'package:mobile_flutter/features/studio_v2/commerce/garment_cart_request.dart';
import 'package:mobile_flutter/features/studio_v2/studio_v2_stage.dart';
import 'package:mobile_flutter/features/studio_v2/widgets/saved_designs_sheet.dart';

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

/// An in-memory [DesignStore] that survives being handed to a second library —
/// which is what "survives an app restart" actually means.
class _MemoryStore implements DesignStore {
  String? contents;
  int writes = 0;

  @override
  Future<String?> read() async => contents;

  @override
  Future<void> write(String c) async {
    contents = c;
    writes++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MemoryStore store;
  late PersistentDesignLibrary library;

  StudioController make() => StudioController(
    generator: LabShowcaseGenerator(
      silhouettesByShape: const {},
      countryNames: const {},
    ),
    service: RenderService(_NoopResolver()),
    designContext: const DesignContext(
      flagCodes: ['us', 'fr', 'jp'],
      scopeKey: 'test:saved',
    ),
    initialSeed: 11,
    library: library,
  );

  setUp(() {
    store = _MemoryStore();
    library = PersistentDesignLibrary(store);
  });

  group('a saved design comes back as itself', () {
    test('reopening restores the same garment identity, not a lookalike', () {
      final c = make();
      addTearDown(c.dispose);
      c.setGarment('#FF1B2B');
      c.selectSubject(1);
      c.saveGarment();
      final saved = library.library.garments.single.garment!;

      // Wander off: a different subject, a different colour.
      c.selectSubject(2);
      c.setGarment('#0F1830');
      expect(c.garment.garmentId, isNot(saved.garmentId));

      c.loadGarment(saved);
      expect(c.garment.garmentId, saved.garmentId);
      expect(c.hero.recipeId, saved.back!.recipeId);
      expect(c.frontFace.recipeId, saved.front!.recipeId);
      expect(c.hero.palette?.garmentColour, '#FF1B2B');
      expect(
        c.onFront,
        isFalse,
        reason: 'lands on the main face, as Review does',
      );
    });

    test('saving the same design twice keeps one entry', () {
      final c = make();
      addTearDown(c.dispose);
      c.saveGarment();
      c.saveGarment();
      expect(library.library.garments, hasLength(1));
    });

    test('saved designs survive a restart', () async {
      final c = make();
      addTearDown(c.dispose);
      c.selectSubject(1);
      c.saveGarment();
      final id = c.garment.garmentId;
      // saveGarment persists without being awaited; let it land.
      await Future<void>.delayed(Duration.zero);
      expect(store.contents, isNotNull, reason: 'nothing was written to disk');

      // A fresh launch: a new library over the same store.
      final reopened = PersistentDesignLibrary(store);
      await reopened.load();
      expect(reopened.library.garments.map((e) => e.garment!.garmentId), [id]);
    });
  });

  group('the wardrobe can be browsed', () {
    Future<void> pump(
      WidgetTester tester,
      StudioController c, {
      AddToCartCallback? onAddToCart,
      ValueChanged<GarmentDesign>? onOpen,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SavedDesignsSheet(
              controller: c,
              onAddToCart: onAddToCart,
              onOpen: onOpen ?? (_) {},
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('an empty wardrobe says so rather than showing nothing', (
      tester,
    ) async {
      final c = make();
      addTearDown(c.dispose);
      await pump(tester, c);
      expect(find.byKey(const Key('v2-saved-empty')), findsOneWidget);
      expect(find.textContaining('Nothing saved yet'), findsOneWidget);
    });

    testWidgets('every saved design is listed', (tester) async {
      final c = make();
      addTearDown(c.dispose);
      c.saveGarment();
      final first = c.garment.garmentId;
      c.selectSubject(2);
      c.saveGarment();
      final second = c.garment.garmentId;
      expect(first, isNot(second));

      await pump(tester, c);
      expect(find.byKey(const Key('v2-saved-list')), findsOneWidget);
      expect(find.byKey(Key('v2-saved-open-$first')), findsOneWidget);
      expect(find.byKey(Key('v2-saved-open-$second')), findsOneWidget);
    });

    testWidgets('tapping one reopens it and hands back to the host', (
      tester,
    ) async {
      final c = make();
      addTearDown(c.dispose);
      c.setGarment('#2665CC');
      c.saveGarment();
      final id = c.garment.garmentId;

      c.selectSubject(3);
      c.setGarment('#FFFFFF');
      expect(c.garment.garmentId, isNot(id));

      GarmentDesign? opened;
      await pump(tester, c, onOpen: (g) => opened = g);
      await tester.tap(find.byKey(Key('v2-saved-open-$id')));
      await tester.pump();

      expect(c.garment.garmentId, id);
      expect(opened?.garmentId, id);
    });
  });

  group('re-ordering is not re-designing', () {
    testWidgets('the reorder action carts the saved design as it was', (
      tester,
    ) async {
      final c = make();
      addTearDown(c.dispose);
      c.setGarment('#FF1B2B');
      c.saveGarment();
      final id = c.garment.garmentId;
      final colour = c.hero.palette?.garmentColour;

      // Drift somewhere else entirely before re-ordering.
      c.selectSubject(2);
      c.setGarment('#FFFFFF');

      final carts = <GarmentCartRequest>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SavedDesignsSheet(
              controller: c,
              onOpen: (_) {},
              onAddToCart: (context, r) async => carts.add(r),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(Key('v2-saved-reorder-$id')));
      await tester.pump();

      expect(carts, hasLength(1));
      expect(carts.single.garment.garmentId, id);
      expect(carts.single.garmentColourHex, colour);
    });

    testWidgets('with no commerce wired there is nothing to press', (
      tester,
    ) async {
      final c = make();
      addTearDown(c.dispose);
      c.saveGarment();
      final id = c.garment.garmentId;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SavedDesignsSheet(controller: c, onOpen: (_) {}),
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(Key('v2-saved-reorder-$id')), findsNothing);
    });
  });

  group('the wardrobe is reachable from the flow', () {
    testWidgets('the app bar opens it from any step', (tester) async {
      final c = make();
      addTearDown(c.dispose);
      c.saveGarment();
      final id = c.garment.garmentId;

      tester.view.physicalSize = const Size(1400, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final key = GlobalKey<StudioV2ScreenState>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [geodataBytesProvider.overrideWithValue(Uint8List(0))],
          child: MaterialApp(home: StudioV2Screen(key: key, controller: c)),
        ),
      );
      await tester.pump();

      // Like buying, your wardrobe is not something to walk to the end of the
      // flow for — it opens from wherever you are.
      for (final stage in [StudioStage.vibe, StudioStage.review]) {
        key.currentState!.goToStage(stage);
        await tester.pump();
        await tester.tap(find.byKey(const Key('v2-saved-designs')));
        await tester.pump(const Duration(milliseconds: 600));
        expect(find.byKey(Key('v2-saved-open-$id')), findsOneWidget);
        Navigator.of(key.currentContext!).pop();
        await tester.pump(const Duration(milliseconds: 600));
      }
    });
  });
}
