import 'package:design_forge/design_forge.dart' show Trip;
import 'package:flutter/material.dart';

import 'package:shared_models/shared_models.dart' show CardTemplateType, TripRecord;

import '../merch/local_mockup_preview_screen.dart';
import '../merch/merch_variant_lookup.dart' show tshirtColors;
import '../studio_v2/commerce/garment_cart_request.dart';

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
      colourName: v1ColourName(r.garmentColourName),
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
    final input = map(r);
    // Render the print file now (the host owns when the expensive rasterise runs).
    final backArtworkPng = await r.renderBackArtwork();
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LocalMockupPreviewScreen(
          artworkImageBytes: backArtworkPng,
          fixedArtwork: input.fixedArtwork,
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
  }

  /// Maps a Studio garment-colour label to the nearest existing t-shirt colour
  /// (`tshirtColors`). The Studio palette is a superset (Navy/Sand/Olive), so
  /// unknown labels fall back to the closest neutral, and anything else to Black.
  static String v1ColourName(String studioName) {
    const map = {
      'Black': 'Black',
      'White': 'White',
      'Navy': 'Blue',
      'Blue': 'Blue',
      'Grey': 'Grey',
      'Gray': 'Grey',
      'Sand': 'White',
      'Olive': 'Grey',
      'Red': 'Red',
    };
    final resolved = map[studioName];
    if (resolved != null && tshirtColors.contains(resolved)) return resolved;
    return tshirtColors.first; // 'Black'
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
