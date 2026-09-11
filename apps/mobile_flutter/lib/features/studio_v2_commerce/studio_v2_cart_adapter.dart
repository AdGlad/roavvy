import 'package:design_forge/design_forge.dart' show Trip;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shared_models/shared_models.dart'
    show CardTemplateType, TripRecord;

import '../../core/providers.dart';
import '../merch/merch_variant_lookup.dart' show tshirtColors;
import '../merch/shopify_pricing_repository.dart'
    show buyerCountryCode, shopifyPricingProvider;
import '../studio_v2/commerce/garment_cart_request.dart';
import 'studio_v2_cart_service.dart';
import 'studio_v2_size_sheet.dart';

/// **Studio V2 → commerce adapter** (M8). The single, thin boundary between the
/// isolated Studio V2 (`design_studio` / `design_forge`) and the EXISTING merch
/// cart / checkout / Printful flow. It lives OUTSIDE `features/studio_v2` (so the
/// V1-isolation guard stays green) and OUTSIDE `features/merch` (so V1 gains no
/// dependency on V2): it only *maps* a neutral [GarmentCartRequest] onto the
/// production commerce entrypoint, then reuses that flow verbatim.
///
/// It duplicates NO commerce logic: it converts the V2 request into the inputs
/// [LocalMockupPreviewScreen] already accepts and navigates there. That screen
/// owns everything past this boundary — the cart-item write, on-device print-file
/// processing, GCS upload, `createMerchCart`, the Printful mockup and Shopify
/// checkout — unchanged.
class StudioV2CartAdapter {
  const StudioV2CartAdapter({StudioV2CartService? service})
    : _service = service;

  /// Injected so the whole hand-off is testable without Firebase. Built on
  /// demand rather than held, so constructing an adapter costs nothing and
  /// touches no Firebase.
  final StudioV2CartService? _service;
  StudioV2CartService get service => _service ?? StudioV2CartService();

  /// Maps a [GarmentCartRequest] to the exact metadata inputs the existing
  /// commerce screen consumes (everything except the artwork bytes, which are
  /// rendered lazily in [addToCart]). Pure and deterministic — unit-testable
  /// without Firebase.
  static StudioV2CommerceInput map(GarmentCartRequest r) {
    return StudioV2CommerceInput(
      // The hero (back) face is the final, immutable print artwork.
      fixedArtwork: true,
      selectedCodes: r.selectedCountryCodes,
      // V2's selection IS the design's country set (no separate all-time axis).
      allCodes: r.selectedCountryCodes,
      trips: [for (final t in r.trips) _toTripRecord(t)],
      colourName: v1ColourName(r.garmentColourName) ?? tshirtColors.first,
      title: r.title,
      aspectRatio: r.aspectRatio,
      // Fixed artwork: template is irrelevant to rendering (never re-rendered),
      // but a concrete value is still required by the screen.
      template: CardTemplateType.grid,
      // Placement carried through in the existing commerce vocabulary. The V2
      // hero prints on the back; the front face is the chest ribbon. Fine
      // placement + physical XS–XXL size remain the commerce screen's concern.
      frontPosition: r.frontPosition,
      backPosition: r.backPosition,
    );
  }

  /// True while an add-to-cart is in flight.
  ///
  /// A second tap on a button that is already working must not render, upload
  /// and order the same shirt twice — and the render is slow enough that a
  /// customer will absolutely tap it again.
  static bool _busy = false;

  /// Puts the approved design in the existing Roavvy cart.
  ///
  /// The route this DOES NOT take is the point: the V1 preview screen, and
  /// with it `MerchImageProcessor`, which would re-fit the artwork into the
  /// print canvas and re-place it from a string. The bytes that reach the
  /// store are the exact bytes M26's production renderer produced, each
  /// carried with its own [PrintPlacement].
  Future<void> addToCart(BuildContext context, GarmentCartRequest r) async {
    if (_busy) return;

    // Refuse a colour the store cannot actually make, by name. Falling through
    // to a substitute here would charge for one shirt and ship another.
    if (v1ColourName(r.garmentColourName) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${r.garmentColourName} isn\'t available to order yet — '
            'pick another shirt colour.',
          ),
        ),
      );
      return;
    }

    final container = ProviderScope.containerOf(context, listen: false);
    final uid = container.read(currentUidProvider);
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to order a shirt.')),
      );
      return;
    }

    // Size and quantity are commerce's questions, asked once, here — never
    // added to the Studio's creative controls.
    final options = await StudioV2SizeSheet.show(
      context,
      priceLabel: container
          .read(shopifyPricingProvider)
          .whenOrNull(data: (p) => p.tshirtFromPrice),
    );
    if (options == null || !context.mounted) return;

    _busy = true;
    final messenger = ScaffoldMessenger.of(context)
      ..showSnackBar(
        const SnackBar(
          duration: Duration(minutes: 2),
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 14),
              Text('Preparing your print files…'),
            ],
          ),
        ),
      );

    final StudioV2CartOutcome outcome;
    try {
      outcome = await service.addToCart(
        request: r,
        options: options,
        uid: uid,
        buyerCountry: buyerCountryCode(),
        // Fail-CLOSED until M26.1's placement is measured on a real garment.
        fulfilmentEnabled: container.read(studioV2FulfilmentEnabledProvider),
      );
    } finally {
      _busy = false;
    }
    messenger.hideCurrentSnackBar();
    if (!context.mounted) return;

    switch (outcome) {
      case StudioV2CartAdded(:final metadata):
        // Deliberately NOT r.onOrdered(): a cart is not a purchase, and the
        // wardrobe's "printed" tag has to mean printed. The design is marked
        // when the order actually completes, in the cart flow that owns
        // checkout — not here.
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Added to your cart — ${metadata.colour} ${metadata.size}'
              '${metadata.quantity > 1 ? ' ×${metadata.quantity}' : ''}',
            ),
          ),
        );
      case StudioV2CartPrepared(:final metadata):
        // Everything ran except the part that spends money.
        messenger.showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 6),
            content: Text(
              'Print files ready (${metadata.faces.length} '
              '${metadata.faces.length == 1 ? 'face' : 'faces'}) — ordering is '
              'switched off until the print placement is checked on a real '
              'shirt.',
            ),
          ),
        );
      case StudioV2CartFailed(:final message):
        // The design is untouched, so Retry runs the same design again — it
        // never re-rolls or rebuilds it.
        messenger.showSnackBar(
          SnackBar(
            content: Text(message),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => addToCart(context, r),
            ),
          ),
        );
    }
  }

  /// Studio garment colours that the store has no variant for yet.
  ///
  /// The Studio offers the blank's full stocked range; Shopify carries variants
  /// for only some of it. A colour listed here can be designed but not ordered,
  /// and [addToCart] refuses it by name rather than letting
  /// `resolveVariantGid` fall through to its first entry — which would take
  /// payment for one colour and ship another.
  ///
  /// Empty this list by adding the real variants, not by guessing a substitute.
  ///
  /// Royal is here because the store's only blue IS Navy (the 'Blue' option
  /// label sits on Printful's Navy variant). Mapping Royal onto it would ship a
  /// navy shirt to someone who chose a bright blue — a difference nobody would
  /// call close enough.
  static const unstockedColours = <String>{'Orange', 'Royal'};

  /// Maps a Studio garment colour onto the store's variant colour.
  ///
  /// Exact where the store carries the same shirt (Black, White, Red); nearest
  /// where it carries a close relative (both blues map to Blue, both greys to
  /// Grey) — approximations the buyer sees in the commerce screen, not silent
  /// substitutions at checkout. Returns null for [unstockedColours].
  static String? v1ColourName(String studioName) {
    if (unstockedColours.contains(studioName)) return null;
    const map = {
      // Exact matches. 'Blue' and 'Grey' are Shopify option labels for what are
      // really Navy and Heather Grey variants — see [tshirtColors].
      'Black': 'Black',
      'White': 'White',
      'Red': 'Red',
      'Navy': 'Blue',
      // Near matches: the store carries ONE heather, so both of the blank's
      // greys resolve to it. Worth confirming which of Gildan's two it is.
      'Dark Heather': 'Grey',
      'Sport Grey': 'Grey',
      // Legacy Studio palette, kept so older saved designs still resolve.
      'Grey': 'Grey',
      'Gray': 'Grey',
      'Blue': 'Blue',
      'Sand': 'White',
      'Olive': 'Grey',
    };
    final resolved = map[studioName];
    if (resolved != null && tshirtColors.contains(resolved)) return resolved;
    return null;
  }

  static TripRecord _toTripRecord(Trip t) => TripRecord(
    id: '${t.countryCode}_${t.startedOn.toIso8601String()}',
    countryCode: t.countryCode,
    startedOn: t.startedOn,
    endedOn: t.endedOn,
    photoCount: t.photoCount,
    isManual: false,
  );
}

/// The production inputs [LocalMockupPreviewScreen] consumes, derived purely from
/// a [GarmentCartRequest]. Kept as a small value object so the mapping is
/// unit-testable independently of navigation/Firebase.
class StudioV2CommerceInput {
  const StudioV2CommerceInput({
    required this.fixedArtwork,
    required this.selectedCodes,
    required this.allCodes,
    required this.trips,
    required this.colourName,
    required this.title,
    required this.aspectRatio,
    required this.template,
    required this.frontPosition,
    required this.backPosition,
  });

  final bool fixedArtwork;
  final List<String> selectedCodes;
  final List<String> allCodes;
  final List<TripRecord> trips;
  final String colourName;
  final String? title;
  final double aspectRatio;
  final CardTemplateType template;
  final String frontPosition;
  final String backPosition;
}
