import 'package:design_studio/design_studio.dart';
import 'package:flutter/painting.dart' show Rect;

import '../merch/merch_variant_lookup.dart';
import '../shared/garment_mockup/mockup_transform.dart';

/// The Roavvy t-shirt's print geometry, in one place, with the provenance of
/// every number written next to it.
///
/// The distinction this type exists to keep is between what the PROVIDER says
/// and what our MOCKUP says. They are not the same, they have drifted, and a
/// print file must be built from the first.
///
/// **Provider-backed** (Printful catalog product 12 / Gildan 64000):
///  * canvas 1800×2400 at 150 DPI = 12"×16", transparent — `printfile_id 1`
///    from `GET /mockup-generator/printfiles/12`, recorded in
///    `resolvePrintDimensions` and mirrored in `apps/functions/src/printDimensions.ts`.
///  * front AND back DTG print areas are both 12"×16" — `GET
///    /v2/catalog-products/12/mockup-styles?technique=dtg` (2026-05-07),
///    recorded at the top of `apps/functions/src/index.ts`.
///  * the back placement's own print area is 1014×1352 on Printful's 3000×3000
///    template — **0.75 aspect**, queried in M190 (commit e8c0eb85).
///  * chest logos: 3.5"×3.5", 3.0" below the top of the print area, centred
///    10.0" (wearer's left) or 2.0" (wearer's right) from the canvas left —
///    the M167 constants in `index.ts` that the live order pipeline prints to.
///
/// **Mockup-only, and NOT usable as print geometry**:
/// `BundledGarments.backPrintArea` is `(0.29, 0.10, 0.42, 0.56)` on a 487×640
/// photograph, an aspect of 0.571. Its WIDTH is provider-derived and correct —
/// 0.75 of the photographed torso, which measures 0.565 wide, giving 0.424 ≈
/// 0.42. Its HEIGHT is not: a 12"×16" print 0.42 photo-widths across is 0.426
/// photo-heights tall, not 0.56. The height was anchored to garment landmarks
/// ("just below the collar") rather than derived from the 12:16 ratio, so the
/// rect is 31% taller than the print it was calibrated from. It is preview
/// geometry, and production does not read it.
///
/// See `docs/engineering` — and the measurement checklist in the M26.1 report —
/// for what still needs a physical sample to confirm.
abstract final class TshirtPrintProfile {
  /// Printful catalog product (Gildan 64000) and its DTG printfile.
  static const int providerProductId = 12;
  static const int providerPrintfileId = 1;

  /// The printable area, in inches. Front and back are the same area.
  static const double printAreaWidthInches = 12.0;
  static const double printAreaHeightInches = 16.0;

  /// Chest-logo geometry, in inches on the print file (M167, `index.ts`).
  static const double logoInches = 3.5;
  static const double logoTopInches = 3.0;
  static const double leftChestCentreInches = 10.0;
  static const double rightChestCentreInches = 2.0;

  static MerchPrintDimensions get dimensions {
    final dims = resolvePrintDimensions(product: MerchProduct.tshirt);
    if (dims == null) {
      throw ProductionRenderException(
        'no print dimensions are configured for the t-shirt',
      );
    }
    return dims;
  }

  /// The canvas, as pixels.
  static Rect get canvas {
    final d = dimensions;
    return Rect.fromLTWH(0, 0, d.widthPx.toDouble(), d.heightPx.toDouble());
  }

  /// Where artwork may print, in canvas pixels, for [placement].
  ///
  /// A full print fills the whole printable area — the canvas IS the printable
  /// area, at 12"×16". A chest logo is a fixed physical size in a fixed
  /// physical place, so it is measured in inches exactly as the fulfiller
  /// measures it.
  static Rect artworkArea(PrintPlacement placement) {
    final d = dimensions;
    switch (placement) {
      case PrintPlacement.backFull:
      case PrintPlacement.frontFull:
        return canvas;
      case PrintPlacement.frontLeftChest:
      case PrintPlacement.frontRightChest:
        final px = logoInches * d.dpi;
        final centre =
            (placement == PrintPlacement.frontLeftChest
                ? leftChestCentreInches
                : rightChestCentreInches) *
            d.dpi;
        return Rect.fromLTWH(
          centre - px / 2,
          logoTopInches * d.dpi,
          px,
          px,
        );
      case PrintPlacement.none:
        throw ProductionRenderException(
          'PrintPlacement.none has no printable area',
        );
    }
  }
}

/// What the customer's front choice means at the production boundary.
///
/// Total and explicit: every [FrontFit] maps to exactly one [PrintPlacement],
/// and `full` maps to [PrintPlacement.frontFull] — which is a different thing
/// from a chest logo and can no longer be confused with one, because no string
/// is involved.
PrintPlacement frontPlacementOf(StudioController c) => switch (c.frontFit) {
  FrontFit.none => PrintPlacement.none,
  FrontFit.full => PrintPlacement.frontFull,
  FrontFit.chest =>
    c.chestRight
        ? PrintPlacement.frontRightChest
        : PrintPlacement.frontLeftChest,
};

/// The print file spec for one [placement] of the customer's finished design.
///
/// Returns **null** for [PrintPlacement.none]: there is no artwork, so there is
/// no file, and the commerce layer sends nothing rather than a blank image.
///
/// [arrangement] is what the customer left on the Placement step. It is baked
/// into the file because the fulfiller drops the image into a fixed printable
/// area — an arrangement that lives outside the image does not survive the
/// hand-off.
ProductionRenderSpec? tshirtPrintSpec(
  PrintPlacement placement, {
  MockupTransform arrangement = MockupTransform.identity,
}) {
  if (!placement.printsSomething) return null;
  final dims = TshirtPrintProfile.dimensions;
  return ProductionRenderSpec(
    placement: placement,
    canvasWidthPx: dims.widthPx,
    canvasHeightPx: dims.heightPx,
    dpi: dims.dpi,
    artworkArea: TshirtPrintProfile.artworkArea(placement),
    transparent: dims.transparent,
    productKey: 'tshirt',
    arrangement: PrintArrangement(
      translation: arrangement.translation,
      rotation: arrangement.rotation,
      scale: arrangement.scale,
    ),
  );
}

/// Both print files for the design the customer approved.
///
/// The explicit production boundary: nothing in the Studio calls this, so no
/// amount of editing, scrolling or re-rendering can trigger a print render.
/// A host calls it once, deliberately, when a design is being turned into
/// something physical.
///
/// The BACK is the primary design and is always produced. The FRONT is
/// produced only when the customer chose one. Each face is rendered from its
/// own recipe, independently — rendering one cannot disturb the other, and
/// neither touches the live session.
Future<List<ProductionArtwork>> renderPrintFiles(
  StudioController c, {
  MockupTransform frontPlacement = MockupTransform.identity,
  MockupTransform backPlacement = MockupTransform.identity,
}) async {
  final printer = ProductionRenderer(c.service.renderer);
  final garment = c.garment;
  final out = <ProductionArtwork>[];

  for (final (placement, recipe, arrangement) in [
    (PrintPlacement.backFull, c.hero, backPlacement),
    (frontPlacementOf(c), c.frontFace, frontPlacement),
  ]) {
    final spec = tshirtPrintSpec(placement, arrangement: arrangement);
    if (spec == null) continue;
    final art = await printer.render(recipe, spec);
    out.add(
      ProductionArtwork(
        recipeId: art.recipeId,
        garmentId: garment.garmentId,
        placement: art.placement,
        widthPx: art.widthPx,
        heightPx: art.heightPx,
        dpi: art.dpi,
        format: art.format,
        bytes: art.bytes,
        imageHash: art.imageHash,
        engineVersion: art.engineVersion,
        grammarVersion: art.grammarVersion,
        assetsVersion: art.assetsVersion,
        schemaVersion: art.schemaVersion,
        productKey: art.productKey,
        elapsed: art.elapsed,
      ),
    );
  }
  return out;
}
