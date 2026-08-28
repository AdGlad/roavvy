import 'dart:typed_data';

import 'package:design_forge/design_forge.dart';
import 'package:flutter/widgets.dart';

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
    required this.garmentColourHex,
    required this.garmentColourName,
    required this.selectedCountryCodes,
    required this.trips,
    required this.frontPosition,
    required this.backPosition,
    required this.aspectRatio,
    this.title,
  });

  /// The full two-face design (both faces + colour + theme) — the deterministic,
  /// reproducible identity of what is being ordered.
  final GarmentDesign garment;

  /// Lazily renders the hero (back) face to a transparent, print-resolution PNG —
  /// the print file for the shirt back (composites onto fabric, so no garment
  /// fill is baked in). Deferred (not eager bytes) so the Review hand-off stays
  /// synchronous and the host owns exactly when the (expensive) rasterise runs.
  final Future<Uint8List> Function() renderBackArtwork;

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
}

/// Injected by the host so the isolated Review screen can reach commerce. Given
/// the built [GarmentCartRequest], the host adapter maps it onto the existing
/// merch cart/checkout flow and navigates there. Null in dev/test builds with no
/// commerce wired — the Review step then surfaces that gracefully.
typedef AddToCartCallback = Future<void> Function(
    BuildContext context, GarmentCartRequest request);
