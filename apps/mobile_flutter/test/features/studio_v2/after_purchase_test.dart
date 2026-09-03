// M182 — after the purchase.
//
// The shirt is a travel brag, not a transaction, and the minute after buying
// is when someone most wants to show it. These cover the three things that
// minute owes them: a way to see where the order is, a way to share what they
// made, and the design kept so it never has to be rebuilt.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:design_forge/design_forge.dart';
import 'package:design_forge_render/design_forge_render.dart';
import 'package:design_studio/design_studio.dart';
import 'package:flutter/material.dart' hide Orientation;
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/studio_v2/commerce/garment_cart_request.dart';
import 'package:mobile_flutter/features/studio_v2_commerce/after_purchase_sheet.dart';

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

  late PersistentDesignLibrary library;

  StudioController make() => StudioController(
    generator: LabShowcaseGenerator(
      silhouettesByShape: const {},
      countryNames: const {},
    ),
    service: RenderService(_NoopResolver()),
    designContext: const DesignContext(
      flagCodes: ['us', 'fr', 'jp'],
      scopeKey: 'test:ordered',
    ),
    initialSeed: 13,
    library: library,
  );

  setUp(() => library = PersistentDesignLibrary(_MemoryStore()));

  group('the purchased design stays in the library', () {
    test('an order keeps the design, marked as printed', () {
      final c = make();
      addTearDown(c.dispose);
      c.setGarment('#FF1B2B');
      expect(library.library.garments, isEmpty);

      c.markOrdered();

      final saved = library.library.garments.single;
      expect(saved.garment!.garmentId, c.garment.garmentId);
      expect(saved.usedForTshirt, isTrue);
      expect(saved.usedAtEpochMs, isNotNull);
    });

    test('ordering a design already saved by hand keeps ONE entry', () {
      // Saving keys by garment identity, the older used-for-tshirt flag keys
      // by a single recipe id. Mixing them leaves the wardrobe entry untouched
      // and a second, faceless one beside it.
      final c = make();
      addTearDown(c.dispose);
      c.saveGarment();
      c.markOrdered();

      expect(library.library.garments, hasLength(1));
      expect(library.library.entries, hasLength(1));
      expect(library.library.garments.single.usedForTshirt, isTrue);
    });

    test('ordering twice does not duplicate it', () {
      final c = make();
      addTearDown(c.dispose);
      c.markOrdered();
      c.markOrdered();
      expect(library.library.garments, hasLength(1));
    });

    test('a re-order after editing keeps both designs', () {
      final c = make();
      addTearDown(c.dispose);
      c.markOrdered();
      c.selectSubject(2);
      c.markOrdered();
      expect(library.library.garments, hasLength(2));
    });
  });

  group('the Studio is told only when a shirt is really bought', () {
    test('the cart request carries the signal', () {
      final c = make();
      addTearDown(c.dispose);
      final req = buildGarmentCartRequest(c);
      expect(req.onOrdered, isNotNull);

      // Building the request is not buying: nothing is recorded until the
      // host fires it, because an abandoned checkout is not a shirt.
      expect(library.library.garments, isEmpty);
      req.onOrdered!();
      expect(library.library.garments.single.usedForTshirt, isTrue);
    });
  });

  group('the confirmation is not a dead end', () {
    Future<void> pump(WidgetTester tester, {String? title}) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AfterPurchaseSheet(
              artworkBytes: Uint8List.fromList(const [1, 2, 3]),
              title: title,
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('it offers showing it off and finding it', (tester) async {
      await pump(tester);
      expect(find.byKey(const Key('v2-after-share')), findsOneWidget);
      expect(find.byKey(const Key('v2-after-track')), findsOneWidget);
      // …and says where the design went, so nobody fears losing it.
      expect(find.textContaining('Your designs'), findsOneWidget);
    });

    testWidgets('the design is named when it has a name', (tester) async {
      await pump(tester, title: 'EUROPE 2026');
      expect(find.textContaining('EUROPE 2026'), findsOneWidget);
    });

    testWidgets('an untitled design still reads as a sentence', (tester) async {
      await pump(tester);
      expect(find.text('Your shirt is being made.'), findsOneWidget);
    });
  });
}
