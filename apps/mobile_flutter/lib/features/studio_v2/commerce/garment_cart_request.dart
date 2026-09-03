import 'dart:typed_data';

import 'package:design_forge/design_forge.dart';
import 'package:design_studio/design_studio.dart';
import 'package:flutter/widgets.dart' hide Orientation;

import '../../shared/garment_mockup/garment_mockup_spec.dart';
import '../../shared/garment_mockup/mockup_transform.dart';
import '../../shared/garment_mockup/placement_bake.dart';

/// The V1-agnostic hand-off payload the Review step produces so a host-side
/// commerce adapter can drop a Studio V2 design into the EXISTING merch cart /
/// checkout / Printful flow.
///
/// Studio V2 stays isolated from `features/merch` (see the V1-isolation guard):
/// it only ever builds this neutral request and hands it to an injected
/// [AddToCartCallback]. Everything a print-on-demand order needs is carried
/// here — the rendered back artwork, the shared garment colour, the print
/// placements, the travel metadata — WITHOUT any dependency on the V1 models.
///
/// It deliberately carries NO physical garment size (XS–XXL): that stays a
/// cart/checkout concern owned by the existing commerce screen, never the
/// Studio (the S/M/L here is the artwork print scale, a different axis).
class GarmentCartRequest {
  const GarmentCartRequest({
    required this.garment,
    required this.renderBackArtwork,
    required this.renderFrontArtwork,
    required this.garmentColourHex,
    required this.garmentColourName,
    required this.selectedCountryCodes,
    required this.trips,
    required this.frontPosition,
    required this.backPosition,
    required this.aspectRatio,
    this.title,
    this.onOrdered,
  });

  /// The full two-face design (both faces + colour + theme) — the deterministic,
  /// reproducible identity of what is being ordered.
  final GarmentDesign garment;

  /// Lazily renders the hero (back) face to a transparent, print-resolution PNG —
  /// the print file for the shirt back (composites onto fabric, so no garment
  /// fill is baked in). Deferred (not eager bytes) so the Review hand-off stays
  /// synchronous and the host owns exactly when the (expensive) rasterise runs.
  final Future<Uint8List> Function() renderBackArtwork;

  /// Lazily renders the front (chest) face to a transparent, print-resolution PNG
  /// — the print file for the shirt front. **Null when the design has no front
  /// print** (FrontFit.none): the commerce flow then sends no front image, so the
  /// shirt front stays blank. Deferred like [renderBackArtwork] so the Review
  /// hand-off stays synchronous and the host controls when the rasterise runs.
  final Future<Uint8List> Function()? renderFrontArtwork;

  /// The shared garment (blank) colour as a hex string, and its Studio label.
  final String? garmentColourHex;
  final String garmentColourName;

  /// The design's travel countries (lowercase ISO codes) and the trips behind
  /// them — carried so the existing front-ribbon render and order metadata match.
  final List<String> selectedCountryCodes;
  final List<Trip> trips;

  /// Print placement intent, in the existing commerce vocabulary:
  ///   front: `'left_chest' | 'center' | 'right_chest' | 'none'`
  ///   back:  `'center' | 'none'`
  /// The V2 hero is the main artwork → it prints on the BACK; the front face is
  /// the chest ribbon.
  final String frontPosition;
  final String backPosition;

  /// Artwork aspect ratio (width / height) from the chosen orientation.
  final double aspectRatio;

  /// Optional design title (order/branding metadata).
  final String? title;

  /// Called by the host once this design has actually become an order — not
  /// when checkout was opened. An abandoned checkout is not a shirt, so the
  /// Studio must not record one; when this fires it keeps the design in the
  /// wardrobe permanently, tagged as printed.
  final VoidCallback? onOrdered;
}

/// Injected by the host so the isolated Review screen can reach commerce. Given
/// the built [GarmentCartRequest], the host adapter maps it onto the existing
/// merch cart/checkout flow and navigates there. Null in dev/test builds with no
/// commerce wired — the Review step then surfaces that gracefully.
typedef AddToCartCallback =
    Future<void> Function(BuildContext context, GarmentCartRequest request);

/// Builds the cart hand-off from a live [StudioController] session.
///
/// Shared so every route to the checkout — Review's "Add to cart", Instant's
/// "Buy it" and the footer's Buy Now — sends byte-identical inputs. A second
/// hand-rolled copy is how the quick path quietly starts ordering something
/// other than what the careful path orders.
///
/// [frontPlacement] and [backPlacement] are what the traveller arranged on the
/// Placement step. They are baked into the print files here rather than passed
/// alongside them, because the fulfiller drops the image into a fixed printable
/// area — so an arrangement that lives outside the image simply does not
/// survive the hand-off. An identity placement changes nothing.
GarmentCartRequest buildGarmentCartRequest(
  StudioController c, {
  MockupTransform frontPlacement = MockupTransform.identity,
  MockupTransform backPlacement = MockupTransform.identity,
}) {
  final hero = c.hero;
  final service = c.service;
  final frontFace = c.frontFace;
  final hasFrontPrint = c.frontFit != FrontFit.none;
  return GarmentCartRequest(
    garment: c.garment,
    renderBackArtwork:
        () async => bakePlacement(
          (await service.renderArtwork(hero)).pngBytes,
          backPlacement,
          printAreaAspect: printAreaAspect(
            BundledGarments.backPrintArea,
            BundledGarments.tintBaseBackSize,
          ),
        ),
    renderFrontArtwork:
        hasFrontPrint
            ? () async => bakePlacement(
              (await service.renderArtwork(frontFace)).pngBytes,
              frontPlacement,
              printAreaAspect: printAreaAspect(
                c.frontPrintRect(),
                BundledGarments.tintBaseFrontSize,
              ),
            )
            : null,
    garmentColourHex: hero.palette?.garmentColour,
    garmentColourName: c.garmentName,
    selectedCountryCodes: c.selectedCountryCodes.toList(),
    trips: c.context.trips,
    frontPosition: switch (c.frontFit) {
      FrontFit.full => 'center',
      FrontFit.chest => c.chestRight ? 'right_chest' : 'left_chest',
      FrontFit.none => 'none',
    },
    backPosition: 'center',
    aspectRatio: switch (hero.composition.orientation) {
      Orientation.portrait => 4 / 5,
      Orientation.landscape => 5 / 4,
      Orientation.square => 1.0,
    },
    title: c.currentTitle.isEmpty ? null : c.currentTitle,
    onOrdered: c.markOrdered,
  );
}
