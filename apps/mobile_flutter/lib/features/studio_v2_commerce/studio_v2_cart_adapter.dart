import 'package:design_forge/design_forge.dart' show Trip;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shared_models/shared_models.dart'
    show CardTemplateType, TripRecord;

import '../merch/local_mockup_preview_screen.dart';
import '../merch/merch_orders_screen.dart' show merchOrdersProvider;
import '../merch/merch_variant_lookup.dart' show tshirtColors;
import '../merch/product_mockup_specs.dart' show ImageSize;
import '../studio_v2/commerce/garment_cart_request.dart';
import 'after_purchase_sheet.dart';

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
  const StudioV2CartAdapter();

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

  /// Builds the [GarmentCartRequest] into the existing commerce flow: converts it
  /// to production inputs and pushes [LocalMockupPreviewScreen], which owns the
  /// entire cart/checkout/Printful pipeline from here on.
  Future<void> addToCart(BuildContext context, GarmentCartRequest r) async {
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
    final input = map(r);
    // Render the print files now (the host owns when the expensive rasterise
    // runs). The back is the main artwork; the front is the real V2 chest face
    // when enabled — a blank front (FrontFit.none) renders nothing, so the
    // commerce screen sends no front image and the shirt front stays empty.
    final backArtworkPng = await r.renderBackArtwork();
    final frontArtworkPng = await r.renderFrontArtwork?.call();
    if (!context.mounted) return;
    // How many orders existed before the buyer went to checkout. The commerce
    // screen owns everything past this point and reports nothing back, so this
    // is how the Studio learns whether a shirt was actually bought — an
    // abandoned checkout must not be recorded as one.
    final container = ProviderScope.containerOf(context, listen: false);
    final ordersBefore = await _orderCount(container);
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder:
            (_) => LocalMockupPreviewScreen(
              artworkImageBytes: backArtworkPng,
              fixedArtwork: input.fixedArtwork,
              // The real V2 front face replaces the V1 ribbon as the front print.
              frontArtworkOverride: frontArtworkPng,
              // Placement + print scale come from the design, not the V1 defaults.
              initialFrontPosition: input.frontPosition,
              initialBackPosition: input.backPosition,
              initialImageSize: ImageSize.large,
              selectedCodes: input.selectedCodes,
              allCodes: input.allCodes,
              trips: input.trips,
              initialColour: input.colourName,
              initialTemplate: input.template,
              titleOverride: input.title,
              confirmedAspectRatio: input.aspectRatio,
              transparentBackground: true,
            ),
      ),
    );

    // Back in the Studio. If an order appeared while they were away, the shirt
    // is real: keep it in the wardrobe for good, and offer the two things
    // wanted most in the minute after buying — showing it off, and knowing
    // where it is. Nothing is claimed when the count cannot be read.
    if (!context.mounted) return;
    final ordersAfter = await _orderCount(container, refresh: true);
    if (ordersBefore == null || ordersAfter == null) return;
    if (ordersAfter <= ordersBefore) return;
    r.onOrdered?.call();
    if (!context.mounted) return;
    await AfterPurchaseSheet.show(
      context,
      artworkBytes: backArtworkPng,
      title: r.title,
    );
  }

  /// The buyer's order count, or null when it cannot be read (signed out,
  /// offline, Firestore unavailable) — never a guess, because the difference
  /// between the two reads is what decides whether a shirt was bought.
  static Future<int?> _orderCount(
    ProviderContainer container, {
    bool refresh = false,
  }) async {
    try {
      return (refresh
              ? await container.refresh(merchOrdersProvider.future)
              : await container.read(merchOrdersProvider.future))
          .length;
    } catch (_) {
      return null;
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
