import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:design_studio/design_studio.dart';

import '../merch/merch_cart_item.dart';
import '../merch/merch_cart_repository.dart';
import '../merch/merch_storage_uploader.dart';
import '../merch/merch_variant_lookup.dart';
import '../merch/shopify_pricing_repository.dart' show MerchPrices;
import '../merch/product_mockup_specs.dart' show ImageSize;
import '../shared/garment_mockup/mockup_transform.dart';
import '../studio_v2/commerce/garment_cart_request.dart';
import 'production_print_specs.dart';
import 'studio_v2_cart_adapter.dart' show StudioV2CartAdapter;

/// What COMMERCE needs the customer to decide, and the design does not.
///
/// Size and quantity are not design properties and never reach a
/// [DesignRecipe]: the same shirt design is the same design in S or in 2XL.
/// They live here, beside the variant they resolve.
class StudioV2PurchaseOptions {
  const StudioV2PurchaseOptions({required this.size, this.quantity = 1});

  final String size;
  final int quantity;

  bool get isValid =>
      tshirtSizes.contains(size) && quantity >= 1 && quantity <= 10;
}

/// Where an attempt stopped. Carried on a failure so the customer sees one
/// sentence and the log sees the truth.
enum StudioV2CartStage { colour, variant, options, render, upload, order }

/// The result of trying to put a Studio design in the cart.
sealed class StudioV2CartOutcome {
  const StudioV2CartOutcome();
}

/// It is in the cart, and there is a checkout waiting.
class StudioV2CartAdded extends StudioV2CartOutcome {
  const StudioV2CartAdded({
    required this.cartItemId,
    required this.metadata,
    this.checkoutUrl,
    this.totalPrice,
  });

  final String cartItemId;
  final StudioV2CartMetadata metadata;
  final String? checkoutUrl;
  final String? totalPrice;
}

/// Everything worked except the part that spends money.
///
/// The print files are rendered and uploaded and the variant is resolved —
/// the whole pipeline has run — but `createMerchCart` was withheld because
/// Studio V2 fulfilment is gated (M26.1: the print placement has not been
/// measured on a physical garment yet). Nothing is in the cart, and nothing
/// can be paid for.
class StudioV2CartPrepared extends StudioV2CartOutcome {
  const StudioV2CartPrepared(this.metadata);

  final StudioV2CartMetadata metadata;
}

/// It did not work, and nothing was created.
class StudioV2CartFailed extends StudioV2CartOutcome {
  const StudioV2CartFailed(this.stage, this.message, {this.cause});

  final StudioV2CartStage stage;

  /// One sentence, for the customer.
  final String message;
  final Object? cause;
}

/// What a cart item remembers about the design that made it.
///
/// The cart is commerce's model, not the design's — so this is metadata ON a
/// cart item, never a [DesignRecipe] pretending to be one. It is enough to
/// trace any shirt back to the exact design a customer approved, and to tell
/// whether two attempts produced the same file.
class StudioV2CartMetadata {
  const StudioV2CartMetadata({
    required this.garmentId,
    required this.variantId,
    required this.colour,
    required this.size,
    required this.quantity,
    required this.faces,
    required this.configId,
    this.title,
  });

  final String garmentId;
  final String variantId;
  final String colour;
  final String size;
  final int quantity;

  /// One entry per printed face, keyed by its explicit placement.
  final List<StudioV2PrintedFace> faces;

  /// The id the uploaded files and the server-side config share.
  final String configId;
  final String? title;

  StudioV2PrintedFace? faceAt(PrintPlacement placement) {
    for (final f in faces) {
      if (f.placement == placement) return f;
    }
    return null;
  }

  bool get hasFrontPrint =>
      faces.any((f) => f.placement.side == PrintSide.front);

  Map<String, dynamic> toMap() => {
    'studioV2': {
      'garmentId': garmentId,
      'configId': configId,
      if (title != null) 'title': title,
      'faces': [for (final f in faces) f.toMap()],
    },
  };
}

/// One print file, and which placement it is for.
class StudioV2PrintedFace {
  const StudioV2PrintedFace({
    required this.placement,
    required this.recipeId,
    required this.imageHash,
    required this.storagePath,
    required this.widthPx,
    required this.heightPx,
    required this.dpi,
    required this.engineVersion,
  });

  final PrintPlacement placement;

  /// The design this file IS — the same content hash the Studio and the
  /// wardrobe use.
  final String recipeId;

  /// A hash of the bytes actually uploaded. Two identical attempts produce the
  /// same value, which is what makes a repeat tap safe to recognise.
  final String imageHash;
  final String storagePath;
  final int widthPx;
  final int heightPx;
  final int dpi;
  final String engineVersion;

  Map<String, dynamic> toMap() => {
    'placement': placement.name,
    'recipeId': recipeId,
    'imageHash': imageHash,
    'storagePath': storagePath,
    'widthPx': widthPx,
    'heightPx': heightPx,
    'dpi': dpi,
    'engineVersion': engineVersion,
  };
}

/// Calls the existing `createMerchCart` Cloud Function.
///
/// Every Printful credential and every privileged call stays server-side, as
/// it already does for V1: the client sends storage paths and a variant, and
/// gets back a checkout URL.
typedef CreateMerchCart =
    Future<Map<String, dynamic>> Function(Map<String, dynamic> payload);

Future<Map<String, dynamic>> _callCreateMerchCart(
  Map<String, dynamic> payload,
) async {
  final callable = FirebaseFunctions.instance.httpsCallable('createMerchCart');
  final response = await callable
      .call<Map<String, dynamic>>(payload)
      .timeout(StudioV2CartService.callTimeout);
  return response.data;
}

/// Puts a finished Studio design into the EXISTING Roavvy cart.
///
/// The whole point of this class is what it does NOT do. It does not process
/// images — the bytes that reach Storage are the exact bytes
/// [renderPrintFiles] produced, never re-fitted, re-scaled or re-placed by
/// [MerchImageProcessor]. It does not decide placement from a string: each
/// file is carried with its [PrintPlacement] and mapped to Printful's own
/// vocabulary at the last moment. And it does not build a cart: it writes a
/// [MerchCartItem] through the repository V1 already uses, calls the same
/// `createMerchCart` function, and stops.
class StudioV2CartService {
  StudioV2CartService({
    MerchStorageUploader? uploader,
    CreateMerchCart? createMerchCart,
    FirebaseFirestore? firestore,
    this.now = DateTime.now,
  }) : _uploader = uploader,
       _createMerchCart = createMerchCart ?? _callCreateMerchCart,
       _firestore = firestore;

  /// Everything Firebase is resolved lazily and on use. Touching
  /// `FirebaseStorage.instance` or `FirebaseFirestore.instance` in a
  /// constructor throws on a build with no Firebase — which is how the Studio
  /// came to open to a black screen once already.
  final MerchStorageUploader? _uploader;
  MerchStorageUploader get _storage => _uploader ?? MerchStorageUploader();

  /// The existing server-side commerce entrypoint. Injected so the hand-off is
  /// testable, and resolved lazily inside the default implementation: with
  /// fulfilment closed the whole pipeline runs without Cloud Functions
  /// existing at all.
  final CreateMerchCart _createMerchCart;
  final FirebaseFirestore? _firestore;
  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;
  final DateTime Function() now;

  static const Duration callTimeout = Duration(seconds: 90);

  /// Printful's own placement names. The bridge from the explicit model to the
  /// provider's vocabulary happens HERE and nowhere else, so no ambiguous word
  /// can travel through the app carrying a decision with it.
  static String printfulPlacement(PrintPlacement p) => switch (p) {
    PrintPlacement.backFull => 'back',
    PrintPlacement.frontFull => 'front',
    PrintPlacement.frontLeftChest => 'front_left',
    PrintPlacement.frontRightChest => 'front_right',
    PrintPlacement.none => throw ArgumentError(
      'PrintPlacement.none has no Printful placement — send no file instead',
    ),
  };

  /// Where a face's print file is uploaded. Front and back can never collide,
  /// so back bytes cannot end up at a front path.
  static String storagePathFor(PrintPlacement p, String configId) =>
      p.side == PrintSide.back
          ? 'back_print_files/$configId.png'
          : 'front_print_files/$configId.png';

  /// Renders, uploads and (when fulfilment is open) orders.
  ///
  /// Atomic in the only sense that matters to a customer: a cart item is
  /// written **after** every print file has rendered and uploaded and the
  /// order call has succeeded. A failure at any earlier step leaves the cart
  /// exactly as it was, and leaves the Studio session untouched.
  Future<StudioV2CartOutcome> addToCart({
    required GarmentCartRequest request,
    required StudioV2PurchaseOptions options,
    required String uid,
    required String buyerCountry,
    required bool fulfilmentEnabled,
    MockupTransform frontPlacement = MockupTransform.identity,
    MockupTransform backPlacement = MockupTransform.identity,
  }) async {
    if (!options.isValid) {
      return const StudioV2CartFailed(
        StudioV2CartStage.options,
        'Choose a size before adding this to your cart.',
      );
    }

    // ── The shirt the store can actually make ────────────────────────────
    final colour = StudioV2CartAdapter.v1ColourName(request.garmentColourName);
    if (colour == null) {
      return StudioV2CartFailed(
        StudioV2CartStage.colour,
        "${request.garmentColourName} isn't available to order yet — "
            'pick another shirt colour.',
      );
    }
    final String variantId;
    try {
      variantId = resolveVariantGid(
        product: MerchProduct.tshirt,
        colour: colour,
        size: options.size,
      );
    } catch (e) {
      return StudioV2CartFailed(
        StudioV2CartStage.variant,
        "That size isn't in stock in this colour.",
        cause: e,
      );
    }

    // ── The artwork the customer approved ────────────────────────────────
    final List<ProductionArtwork> files;
    try {
      files = await renderPrintFiles(
        request.session,
        frontPlacement: frontPlacement,
        backPlacement: backPlacement,
      );
    } catch (e) {
      return StudioV2CartFailed(
        StudioV2CartStage.render,
        "We couldn't prepare your design for printing. Try again.",
        cause: e,
      );
    }
    final back = files.where((f) => f.placement == PrintPlacement.backFull);
    if (back.length != 1) {
      return StudioV2CartFailed(
        StudioV2CartStage.render,
        "We couldn't prepare your design for printing. Try again.",
        cause: StateError('expected one back print file, got ${back.length}'),
      );
    }

    // ── Upload, all of it or none of it ──────────────────────────────────
    final configId = '${request.garment.garmentId}-${now().millisecondsSinceEpoch}';
    final faces = <StudioV2PrintedFace>[];
    try {
      for (final f in files) {
        final path = storagePathFor(f.placement, configId);
        await _storage.upload(f.bytes, path);
        faces.add(
          StudioV2PrintedFace(
            placement: f.placement,
            recipeId: f.recipeId,
            imageHash: f.imageHash,
            storagePath: path,
            widthPx: f.widthPx,
            heightPx: f.heightPx,
            dpi: f.dpi,
            engineVersion: f.engineVersion,
          ),
        );
      }
    } catch (e) {
      // Nothing has been created yet, so there is nothing to unwind — the cart
      // is untouched and an orphaned upload costs a few hundred kilobytes.
      return StudioV2CartFailed(
        StudioV2CartStage.upload,
        "We couldn't upload your design. Check your connection and try again.",
        cause: e,
      );
    }

    final metadata = StudioV2CartMetadata(
      garmentId: request.garment.garmentId,
      variantId: variantId,
      colour: colour,
      size: options.size,
      quantity: options.quantity,
      faces: faces,
      configId: configId,
      title: request.title,
    );

    // ── The gate ─────────────────────────────────────────────────────────
    // Everything above is reversible. `createMerchCart` is where a design
    // becomes a checkout somebody can pay for, so it is the step that waits
    // for a physical print to be measured.
    if (!fulfilmentEnabled) return StudioV2CartPrepared(metadata);

    final Map<String, dynamic> result;
    try {
      result = await _createMerchCart({
            'variantId': variantId,
            'selectedCountryCodes': request.selectedCountryCodes,
            'buyerCountry': buyerCountry,
            'quantity': options.quantity,
            'clientConfigId': configId,
            'backPrintStoragePath':
                metadata.faceAt(PrintPlacement.backFull)!.storagePath,
            // Placement travels as Printful's own name, derived from the
            // explicit model. A front that prints nothing sends no path and no
            // placement, so a blank front cannot become a blank image.
            'backPosition': printfulPlacement(PrintPlacement.backFull),
            for (final f in faces)
              if (f.placement.side == PrintSide.front) ...{
                'frontPrintStoragePath': f.storagePath,
                'frontPosition': printfulPlacement(f.placement),
              },
      });
    } catch (e) {
      return StudioV2CartFailed(
        StudioV2CartStage.order,
        "We couldn't reach the store. Your design is safe — try again.",
        cause: e,
      );
    }

    // ── Only now does a cart item exist ──────────────────────────────────
    final item = MerchCartItem(
      id: configId,
      status: MerchCartItemStatus.mockupReady,
      productType: 'tshirt',
      variantId: variantId,
      // V2 designs are not built from V1 card templates; the field is required
      // by the existing model, and 'grid' is its neutral value.
      templateType: 'grid',
      colour: colour,
      size: options.size,
      // The cart's own placement vocabulary, kept truthful: a V2 back is
      // always a full back print, and the front says which of the three it is.
      frontPosition: _cartFrontPosition(faces),
      backPosition: 'center',
      imageSize: ImageSize.large,
      selectedCountryCodes: request.selectedCountryCodes,
      createdAt: now().toUtc(),
      updatedAt: now().toUtc(),
      title: request.title,
      merchConfigId: result['merchConfigId'] as String?,
      checkoutUrl: result['checkoutUrl'] as String?,
      frontMockupUrl: result['frontMockupUrl'] as String?,
      backMockupUrl: result['backMockupUrl'] as String?,
    );
    final repo = MerchCartRepository(_db);
    await repo.create(uid, item);
    // The design's own identity, on the cart document rather than in the cart
    // model: commerce does not need to understand a recipe to carry its id.
    await repo.update(uid, item.id, metadata.toMap());

    return StudioV2CartAdded(
      cartItemId: item.id,
      metadata: metadata,
      checkoutUrl: item.checkoutUrl,
      totalPrice: MerchPrices.formatMoney(result['totalPrice']),
    );
  }

  /// The existing cart's word for where the front print sits. Derived from the
  /// explicit placement, never chosen independently of it.
  static String _cartFrontPosition(List<StudioV2PrintedFace> faces) {
    for (final f in faces) {
      switch (f.placement) {
        case PrintPlacement.frontFull:
          return 'center';
        case PrintPlacement.frontLeftChest:
          return 'left_chest';
        case PrintPlacement.frontRightChest:
          return 'right_chest';
        case PrintPlacement.backFull:
        case PrintPlacement.none:
          continue;
      }
    }
    return 'none';
  }
}
