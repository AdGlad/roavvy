import 'package:design_studio/design_studio.dart';
import 'package:flutter/painting.dart' show Rect;

import '../merch/merch_variant_lookup.dart';
import '../shared/garment_mockup/garment_mockup_spec.dart';
import '../shared/garment_mockup/mockup_transform.dart';
import '../shared/garment_mockup/placement_bake.dart';

/// The Roavvy t-shirt's real print file, from the product configuration that
/// already exists — never a number invented here.
///
/// Source of truth: `resolvePrintDimensions(MerchProduct.tshirt)`, verified
/// against Printful's own printfile for product 12 (printfile_id 1: 1800×2400
/// at 150 DPI = 12"×16") and mirrored server-side in
/// `apps/functions/src/printDimensions.ts`.
///
/// This is the one layer allowed to know both the Studio and commerce, which
/// is why the mapping lives here: `features/studio_v2` may not import the
/// merch feature, and the design engine has no business knowing what a
/// fulfiller's canvas is.
abstract final class TshirtPrintFile {
  /// Chest-logo geometry, in inches on the print file. These are the M167
  /// server-side constants (`apps/functions/src/index.ts`) that the existing
  /// order pipeline already prints to — restating them differently here is how
  /// a chest logo comes out in a different place than the one that shipped.
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
}

/// The print file spec for one face of the customer's finished design.
///
/// Returns **null** for a front with no print (`FrontFit.none`): there is no
/// artwork, so there is no file, and the commerce layer sends nothing rather
/// than a blank image.
///
/// [arrangement] is what the customer left on the Placement step. It is baked
/// into the file because the fulfiller drops the image into a fixed printable
/// area — an arrangement that lives outside the image does not survive the
/// hand-off.
ProductionRenderSpec? tshirtPrintSpec(
  StudioController c,
  PrintSide side, {
  MockupTransform arrangement = MockupTransform.identity,
}) {
  if (side == PrintSide.front && c.frontFit == FrontFit.none) return null;

  final dims = TshirtPrintFile.dimensions;
  final canvas = Rect.fromLTWH(
    0,
    0,
    dims.widthPx.toDouble(),
    dims.heightPx.toDouble(),
  );

  final Rect placement;
  if (side == PrintSide.front && c.frontFit == FrontFit.chest) {
    // A chest logo is a fixed physical size in a fixed physical place, so it
    // is measured in inches on the canvas, exactly as the fulfiller measures
    // it — not scaled off the mockup photograph.
    final px = TshirtPrintFile.logoInches * dims.dpi;
    final centre =
        (c.chestRight
            ? TshirtPrintFile.rightChestCentreInches
            : TshirtPrintFile.leftChestCentreInches) *
        dims.dpi;
    placement = Rect.fromLTWH(
      centre - px / 2,
      TshirtPrintFile.logoTopInches * dims.dpi,
      px,
      px,
    );
  } else {
    // Everything else fills the printable area — at the SHAPE the preview
    // showed it in. The garment's print region is normalised to its
    // photograph, so its true aspect depends on the photo's proportions;
    // reading it off the fractions alone is how a design previews at one shape
    // and prints at another.
    final (area, photo) =
        side == PrintSide.front
            ? (c.frontPrintRect(), BundledGarments.tintBaseFrontSize)
            : (BundledGarments.backPrintArea, BundledGarments.tintBaseBackSize);
    placement = ProductionRenderer.fitInside(
      canvas,
      printAreaAspect(area, photo),
    );
  }

  return ProductionRenderSpec(
    side: side,
    canvasWidthPx: dims.widthPx,
    canvasHeightPx: dims.heightPx,
    dpi: dims.dpi,
    placement: placement,
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

  for (final (side, recipe, arrangement) in [
    (PrintSide.back, c.hero, backPlacement),
    (PrintSide.front, c.frontFace, frontPlacement),
  ]) {
    final spec = tshirtPrintSpec(c, side, arrangement: arrangement);
    if (spec == null) continue;
    final art = await printer.render(recipe, spec);
    out.add(
      ProductionArtwork(
        recipeId: art.recipeId,
        garmentId: garment.garmentId,
        side: art.side,
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
