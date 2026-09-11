// M27 — what the customer approved is what reaches the store.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:design_forge/design_forge.dart';
import 'package:design_forge_render/design_forge_render.dart';
import 'package:design_studio/design_studio.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/merch/merch_storage_uploader.dart';
import 'package:mobile_flutter/features/studio_v2/commerce/garment_cart_request.dart';
import 'package:mobile_flutter/features/studio_v2/studio_v2_app.dart';
import 'package:mobile_flutter/features/studio_v2_commerce/production_print_specs.dart';
import 'package:mobile_flutter/features/studio_v2_commerce/studio_v2_cart_service.dart';

class _FlatResolver implements AssetResolver {
  @override
  Future<ui.Image> resolveFlag(
    String code, {
    required int width,
    required int height,
  }) async {
    final r = ui.PictureRecorder();
    ui.Canvas(r).drawRect(
      ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      ui.Paint()..color = const ui.Color(0xFF1E88E5),
    );
    final p = r.endRecording();
    final i = await p.toImage(width, height);
    p.dispose();
    return i;
  }

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

/// Records what was uploaded where, and can be made to fail.
class _RecordingUploader implements MerchStorageUploader {
  final Map<String, Uint8List> uploaded = {};
  bool fail = false;

  @override
  Future<String> upload(Uint8List bytes, String storagePath) async {
    if (fail) throw StateError('storage unavailable');
    uploaded[storagePath] = bytes;
    return storagePath;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

StudioController studio() {
  final c = StudioController(
    generator: LabShowcaseGenerator(
      silhouettesByShape: const {},
      countryNames: const {},
    ),
    service: RenderService(_FlatResolver()),
    designContext: demoStudioContext.toDesignContext(),
    initialSeed: 7,
  );
  // A shirt the store actually carries, so these tests are about the hand-off
  // rather than about the colour range.
  c.setGarment('#0E0E0E');
  return c;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _RecordingUploader uploader;
  late FakeFirebaseFirestore firestore;

  setUp(() {
    uploader = _RecordingUploader();
    firestore = FakeFirebaseFirestore();
  });

  StudioV2CartService service() => StudioV2CartService(
    uploader: uploader,
    firestore: firestore,
    now: () => DateTime.utc(2026, 9, 11, 12),
  );

  const options = StudioV2PurchaseOptions(size: 'L', quantity: 2);

  /// Runs the hand-off up to the gate — which is as far as anything can go
  /// without Cloud Functions, and as far as anything SHOULD go until the print
  /// placement has been measured.
  Future<StudioV2CartOutcome> prepare(
    WidgetTester tester,
    StudioController c, {
    StudioV2PurchaseOptions opts = options,
  }) async {
    late StudioV2CartOutcome out;
    await tester.runAsync(() async {
      out = await service().addToCart(
        request: buildGarmentCartRequest(c),
        options: opts,
        uid: 'uid-alice',
        buyerCountry: 'AU',
        fulfilmentEnabled: false,
      );
    });
    return out;
  }

  group('the artwork that reaches the store', () {
    testWidgets('is the exact bytes the production renderer made', (
      tester,
    ) async {
      final c = studio();
      addTearDown(c.dispose);

      late List<ProductionArtwork> rendered;
      await tester.runAsync(() async => rendered = await renderPrintFiles(c));
      final out = await prepare(tester, c);

      final meta = (out as StudioV2CartPrepared).metadata;
      final back = meta.faceAt(PrintPlacement.backFull)!;
      final source = rendered.firstWhere(
        (f) => f.placement == PrintPlacement.backFull,
      );

      expect(back.imageHash, source.imageHash);
      expect(uploader.uploaded[back.storagePath], source.bytes);
      expect(back.recipeId, c.hero.recipeId);
      expect(back.widthPx, 1800);
      expect(back.heightPx, 2400);
      expect(back.dpi, 150);
    });

    testWidgets('is never re-processed on the way — 1800x2400 as rendered', (
      tester,
    ) async {
      // The V1 path would contain-fit these bytes into the print canvas and
      // re-place them from a string. Nothing between the renderer and Storage
      // touches them here.
      final c = studio();
      addTearDown(c.dispose);
      final out = await prepare(tester, c);
      final meta = (out as StudioV2CartPrepared).metadata;

      for (final f in meta.faces) {
        final bytes = uploader.uploaded[f.storagePath]!;
        late ui.Image img;
        await tester.runAsync(() async {
          img = (await (await ui.instantiateImageCodec(bytes)).getNextFrame())
              .image;
        });
        expect((img.width, img.height), (1800, 2400));
        img.dispose();
      }
    });

    testWidgets('carries its design identity for anyone tracing it back', (
      tester,
    ) async {
      final c = studio();
      addTearDown(c.dispose);
      final out = await prepare(tester, c);
      final meta = (out as StudioV2CartPrepared).metadata;

      expect(meta.garmentId, c.garment.garmentId);
      expect(meta.faceAt(PrintPlacement.backFull)!.recipeId, c.hero.recipeId);
      expect(meta.faces.every((f) => f.imageHash.isNotEmpty), isTrue);
      expect(meta.toMap()['studioV2'], isA<Map<String, dynamic>>());
    });
  });

  group('placement, explicitly', () {
    testWidgets('the back is always a full back print', (tester) async {
      final c = studio();
      addTearDown(c.dispose);
      final meta =
          ((await prepare(tester, c)) as StudioV2CartPrepared).metadata;
      final back = meta.faceAt(PrintPlacement.backFull)!;
      expect(back.storagePath, startsWith('back_print_files/'));
      expect(
        StudioV2CartService.printfulPlacement(PrintPlacement.backFull),
        'back',
      );
    });

    testWidgets('a full front is a full front, not a chest logo', (
      tester,
    ) async {
      final c = studio();
      addTearDown(c.dispose);
      c.setSide(true);
      c.setFrontFit(FrontFit.full);

      final meta =
          ((await prepare(tester, c)) as StudioV2CartPrepared).metadata;
      expect(meta.faceAt(PrintPlacement.frontFull), isNotNull);
      expect(meta.faceAt(PrintPlacement.frontLeftChest), isNull);
      expect(
        StudioV2CartService.printfulPlacement(PrintPlacement.frontFull),
        'front',
      );
    });

    testWidgets('left and right chest stay on their own sides', (tester) async {
      for (final (right, placement, printful) in [
        (false, PrintPlacement.frontLeftChest, 'front_left'),
        (true, PrintPlacement.frontRightChest, 'front_right'),
      ]) {
        final c = studio();
        addTearDown(c.dispose);
        c.setSide(true);
        c.setFrontFit(FrontFit.chest);
        c.setChestSide(right);

        final meta =
            ((await prepare(tester, c)) as StudioV2CartPrepared).metadata;
        expect(meta.faceAt(placement), isNotNull);
        expect(StudioV2CartService.printfulPlacement(placement), printful);
      }
    });

    testWidgets('a blank front sends no file and no placement', (tester) async {
      final c = studio();
      addTearDown(c.dispose);
      c.setSide(true);
      c.setFrontFit(FrontFit.none);

      final meta =
          ((await prepare(tester, c)) as StudioV2CartPrepared).metadata;
      expect(meta.faces, hasLength(1));
      expect(meta.hasFrontPrint, isFalse);
      expect(
        uploader.uploaded.keys.where((k) => k.startsWith('front_')),
        isEmpty,
      );
      expect(
        () => StudioV2CartService.printfulPlacement(PrintPlacement.none),
        throwsArgumentError,
      );
    });

    testWidgets('back bytes cannot land at a front path', (tester) async {
      final c = studio();
      addTearDown(c.dispose);
      c.setSide(true);
      c.setFrontFit(FrontFit.full);

      final meta =
          ((await prepare(tester, c)) as StudioV2CartPrepared).metadata;
      final back = meta.faceAt(PrintPlacement.backFull)!;
      final front = meta.faceAt(PrintPlacement.frontFull)!;
      expect(back.storagePath, startsWith('back_print_files/'));
      expect(front.storagePath, startsWith('front_print_files/'));
      expect(back.imageHash, isNot(front.imageHash));
      expect(
        uploader.uploaded[back.storagePath],
        isNot(uploader.uploaded[front.storagePath]),
      );
    });

    test('no ambiguous word decides a placement', () {
      for (final p in PrintPlacement.values) {
        if (p == PrintPlacement.none) continue;
        expect(StudioV2CartService.printfulPlacement(p), isNot('center'));
      }
    });
  });

  group('size and quantity belong to commerce', () {
    testWidgets('they reach the variant, never the design', (tester) async {
      final c = studio();
      addTearDown(c.dispose);
      final recipeBefore = c.hero.toJson();

      final meta =
          ((await prepare(tester, c)) as StudioV2CartPrepared).metadata;

      expect(meta.size, 'L');
      expect(meta.quantity, 2);
      expect(meta.variantId, contains('gid://shopify/ProductVariant/'));
      expect(
        c.hero.toJson(),
        recipeBefore,
        reason: 'a size is not a design property',
      );
      expect(recipeBefore.toString(), isNot(contains('"L"')));
    });

    testWidgets('a size the store does not carry is refused, not substituted', (
      tester,
    ) async {
      final c = studio();
      addTearDown(c.dispose);
      final out = await prepare(
        tester,
        c,
        opts: const StudioV2PurchaseOptions(size: 'XXXL'),
      );
      expect(out, isA<StudioV2CartFailed>());
      expect((out as StudioV2CartFailed).stage, StudioV2CartStage.options);
      expect(uploader.uploaded, isEmpty);
    });

    testWidgets('an unstocked colour never renders anything', (tester) async {
      final c = studio();
      addTearDown(c.dispose);
      // Royal: the store's only blue IS Navy.
      c.setGarment('#2665CC');
      final out = await prepare(tester, c);
      expect((out as StudioV2CartFailed).stage, StudioV2CartStage.colour);
      expect(uploader.uploaded, isEmpty);
    });
  });

  group('a failure leaves nothing behind', () {
    testWidgets('an upload that fails writes no cart item', (tester) async {
      uploader.fail = true;
      final c = studio();
      addTearDown(c.dispose);

      final out = await prepare(tester, c);
      expect((out as StudioV2CartFailed).stage, StudioV2CartStage.upload);
      expect(out.message, isNotEmpty);

      final cart =
          await firestore
              .collection('users')
              .doc('uid-alice')
              .collection('cartItems')
              .get();
      expect(cart.docs, isEmpty);
    });

    testWidgets('and the Studio session is exactly where it was', (
      tester,
    ) async {
      uploader.fail = true;
      final c = studio();
      addTearDown(c.dispose);
      c.setSelectedCountries(const ['fr', 'jp']);
      final before = (c.hero.recipeId, c.frontFace.recipeId, c.history.length);

      await prepare(tester, c);

      expect(
        (c.hero.recipeId, c.frontFace.recipeId, c.history.length),
        before,
      );
    });

    testWidgets('retrying prints the same design, not a new one', (
      tester,
    ) async {
      final c = studio();
      addTearDown(c.dispose);

      uploader.fail = true;
      await prepare(tester, c);
      uploader.fail = false;
      final first =
          ((await prepare(tester, c)) as StudioV2CartPrepared).metadata;
      final second =
          ((await prepare(tester, c)) as StudioV2CartPrepared).metadata;

      expect(second.garmentId, first.garmentId);
      expect(
        second.faceAt(PrintPlacement.backFull)!.imageHash,
        first.faceAt(PrintPlacement.backFull)!.imageHash,
        reason: 'a retry must not reroll the design',
      );
    });
  });

  group('with the gate open', () {
    late List<Map<String, dynamic>> calls;
    late bool orderFails;

    setUp(() {
      calls = [];
      orderFails = false;
    });

    Future<StudioV2CartOutcome> order(
      WidgetTester tester,
      StudioController c,
    ) async {
      late StudioV2CartOutcome out;
      await tester.runAsync(() async {
        out = await StudioV2CartService(
          uploader: uploader,
          firestore: firestore,
          now: () => DateTime.utc(2026, 9, 11, 12),
          createMerchCart: (payload) async {
            calls.add(payload);
            if (orderFails) throw StateError('functions unreachable');
            return {
              'checkoutUrl': 'https://shop.example/checkout/1',
              'merchConfigId': 'cfg-1',
              'totalPrice': {'amount': '49.00', 'currencyCode': 'AUD'},
            };
          },
        ).addToCart(
          request: buildGarmentCartRequest(c),
          options: options,
          uid: 'uid-alice',
          buyerCountry: 'AU',
          fulfilmentEnabled: true,
        );
      });
      return out;
    }

    Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> cart() async =>
        (await firestore
                .collection('users')
                .doc('uid-alice')
                .collection('cartItems')
                .get())
            .docs;

    testWidgets('the item lands in the existing cart, once', (tester) async {
      final c = studio();
      addTearDown(c.dispose);
      c.setSide(true);
      c.setFrontFit(FrontFit.chest);
      c.setChestSide(true);

      final out = await order(tester, c);
      expect(out, isA<StudioV2CartAdded>());
      final added = out as StudioV2CartAdded;
      expect(added.checkoutUrl, 'https://shop.example/checkout/1');

      final docs = await cart();
      expect(docs, hasLength(1));
      final data = docs.single.data();
      expect(data['productType'], 'tshirt');
      expect(data['variantId'], added.metadata.variantId);
      expect(data['colour'], 'Black');
      expect(data['size'], 'L');
      expect(data['frontPosition'], 'right_chest');
      expect(data['backPosition'], 'center');
      // …carrying the design it came from.
      final v2 = data['studioV2'] as Map<String, dynamic>;
      expect(v2['garmentId'], c.garment.garmentId);
      expect((v2['faces'] as List), hasLength(2));
    });

    testWidgets('the call names Printful placements, never "center"', (
      tester,
    ) async {
      final c = studio();
      addTearDown(c.dispose);
      c.setSide(true);
      c.setFrontFit(FrontFit.full);

      await order(tester, c);
      final payload = calls.single;
      expect(payload['backPosition'], 'back');
      expect(payload['frontPosition'], 'front');
      expect(payload['quantity'], 2);
      expect(payload['buyerCountry'], 'AU');
      expect(
        payload['backPrintStoragePath'],
        startsWith('back_print_files/'),
      );
      expect(
        payload['frontPrintStoragePath'],
        startsWith('front_print_files/'),
      );
    });

    testWidgets('a blank front sends no front path at all', (tester) async {
      final c = studio();
      addTearDown(c.dispose);
      c.setSide(true);
      c.setFrontFit(FrontFit.none);

      await order(tester, c);
      expect(calls.single.containsKey('frontPrintStoragePath'), isFalse);
      expect(calls.single.containsKey('frontPosition'), isFalse);
      expect((await cart()).single.data()['frontPosition'], 'none');
    });

    testWidgets('an order that fails writes no cart item', (tester) async {
      orderFails = true;
      final c = studio();
      addTearDown(c.dispose);

      final out = await order(tester, c);
      expect((out as StudioV2CartFailed).stage, StudioV2CartStage.order);
      expect(await cart(), isEmpty);
      expect(c.history, isEmpty);
    });
  });

  group('the fulfilment gate', () {
    testWidgets('closed: everything runs except the part that spends money', (
      tester,
    ) async {
      final c = studio();
      addTearDown(c.dispose);
      final out = await prepare(tester, c);

      expect(out, isA<StudioV2CartPrepared>());
      // The pipeline really ran…
      expect(uploader.uploaded, isNotEmpty);
      expect(
        (out as StudioV2CartPrepared).metadata.variantId,
        isNotEmpty,
      );
      // …and nothing was ordered.
      final cart =
          await firestore
              .collection('users')
              .doc('uid-alice')
              .collection('cartItems')
              .get();
      expect(cart.docs, isEmpty);
    });
  });
}
