import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:design_forge/design_forge.dart';
import 'package:design_forge_render/design_forge_render.dart';

/// Which face of the garment a print file is for.
enum PrintSide { front, back }

/// WHERE on the garment a design prints — the production boundary's own
/// vocabulary, chosen because the vocabulary underneath it is ambiguous.
///
/// The existing order pipeline speaks in strings, and one of them is
/// `'center'`, which the server maps to a 3.5" chest logo (deliberately: a
/// front ribbon auto-centred across the whole print area came out as a
/// "double backside" mockup). A full-front print and a centred chest logo are
/// therefore indistinguishable once a design becomes the word "center", and
/// the difference between them is the difference between a 12"-wide print and
/// a 3.5" one.
///
/// Nothing downstream of here may decide placement from a string.
enum PrintPlacement {
  /// The whole back print area.
  backFull,

  /// The whole front print area — NOT a chest logo.
  frontFull,

  /// A chest logo on the wearer's left (the viewer's right).
  frontLeftChest,

  /// A chest logo on the wearer's right (the viewer's left).
  frontRightChest,

  /// A wide band across the shoulders, just below the collar.
  backUpper,

  /// A small mark centred just below the back collar.
  backNeck,

  /// No print on this face. Produces no file at all, never a blank one.
  none;

  PrintSide? get side => switch (this) {
    PrintPlacement.backFull ||
    PrintPlacement.backUpper ||
    PrintPlacement.backNeck => PrintSide.back,
    PrintPlacement.none => null,
    _ => PrintSide.front,
  };

  bool get isChestLogo =>
      this == PrintPlacement.frontLeftChest ||
      this == PrintPlacement.frontRightChest;

  bool get printsSomething => this != PrintPlacement.none;
}

/// How the customer arranged the artwork inside its printable area.
///
/// The same three numbers the on-garment preview uses, in the same order
/// (translate about the fitted rect's centre by a fraction of the printable
/// area, then rotate, then scale) — expressed here so the production renderer
/// can apply them without reaching into the host app for its widget types.
class PrintArrangement {
  const PrintArrangement({
    this.translation = ui.Offset.zero,
    this.rotation = 0,
    this.scale = 1,
  });

  static const PrintArrangement identity = PrintArrangement();

  /// As a fraction of the printable area, not of the artwork.
  final ui.Offset translation;
  final double rotation;
  final double scale;

  bool get isIdentity =>
      translation == ui.Offset.zero && rotation == 0 && scale == 1;
}

/// The Roavvy brand mark: `roavvy.com`, small, one ink. Drawn by the same
/// code onto the print file and onto the shirt preview, so the two match.
abstract final class BrandMark {
  static const String text = 'roavvy.com';

  /// Near-black on a light shirt, near-white on a dark one.
  static ui.Color inkFor(ui.Color shirt) {
    double lin(double c) =>
        c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
    final l = 0.2126 * lin(shirt.r) + 0.7152 * lin(shirt.g) + 0.0722 * lin(shirt.b);
    return l > 0.35 ? const ui.Color(0xFF1C1C1C) : const ui.Color(0xFFF2F2F2);
  }

  static ui.Paragraph _para(String text, double fontSize, ui.Color ink) {
    final b =
        ui.ParagraphBuilder(
            ui.ParagraphStyle(textAlign: ui.TextAlign.center, maxLines: 1),
          )
          ..pushStyle(
            ui.TextStyle(
              color: ink,
              fontSize: fontSize,
              fontWeight: ui.FontWeight.w600,
              letterSpacing: fontSize * 0.06,
            ),
          )
          ..addText(text);
    return b.build()..layout(const ui.ParagraphConstraints(width: 1e6));
  }

  /// Paints [text] as large as fits inside [box], centred.
  static void paint(
    ui.Canvas canvas,
    ui.Rect box,
    ui.Color ink, {
    String text = BrandMark.text,
  }) {
    if (box.isEmpty) return;
    final probe = _para(text, 100, ink);
    final w = probe.longestLine, h = probe.height;
    probe.dispose();
    if (w <= 0 || h <= 0) return;
    final size = 100 * (box.width / w < box.height / h ? box.width / w : box.height / h);
    final p = _para(text, size, ink)
      ..layout(ui.ParagraphConstraints(width: box.width));
    canvas.save();
    canvas.clipRect(box);
    canvas.drawParagraph(p, ui.Offset(box.left, box.center.dy - p.height / 2));
    canvas.restore();
    p.dispose();
  }
}

/// A [BrandMark] on a print file, in canvas pixels.
class PrintMark {
  const PrintMark({required this.rect, required this.ink, this.text = BrandMark.text});

  final ui.Rect rect;
  final ui.Color ink;
  final String text;
}

/// Everything needed to turn one [DesignRecipe] into one print file, stated
/// once and explicitly.
///
/// The point of the type is that nothing downstream has to guess: the canvas
/// is the fulfiller's print file, [placement] is where on it the artwork
/// belongs, and both come from the host's real product configuration rather
/// than from a number someone typed into the renderer.
class ProductionRenderSpec {
  ProductionRenderSpec({
    required this.placement,
    required this.canvasWidthPx,
    required this.canvasHeightPx,
    required this.dpi,
    required this.artworkArea,
    this.transparent = true,
    this.format = ProductionImageFormat.png,
    this.arrangement = PrintArrangement.identity,
    this.productKey,
    this.marks = const [],
  }) {
    if (!placement.printsSomething) {
      throw ProductionRenderException(
        'PrintPlacement.none has no print file — do not build a spec for it',
      );
    }
    if (canvasWidthPx <= 0 || canvasHeightPx <= 0 || dpi <= 0) {
      throw ProductionRenderException(
        'a print file cannot be ${canvasWidthPx}x$canvasHeightPx at $dpi dpi',
      );
    }
    if (artworkArea.isEmpty ||
        artworkArea.left < 0 ||
        artworkArea.top < 0 ||
        artworkArea.right > canvasWidthPx + 0.5 ||
        artworkArea.bottom > canvasHeightPx + 0.5) {
      throw ProductionRenderException(
        'the print area $artworkArea does not fit a '
        '${canvasWidthPx}x$canvasHeightPx canvas',
      );
    }
    for (final m in marks) {
      if (m.rect.isEmpty ||
          m.rect.left < 0 ||
          m.rect.top < 0 ||
          m.rect.right > canvasWidthPx + 0.5 ||
          m.rect.bottom > canvasHeightPx + 0.5 ||
          m.rect.overlaps(artworkArea)) {
        throw ProductionRenderException(
          'the brand mark ${m.rect} must sit on the canvas, clear of the artwork',
        );
      }
    }
  }

  /// Small marks printed beside the artwork (the Roavvy mark at the back
  /// neck). Never inside [artworkArea].
  final List<PrintMark> marks;

  /// What this print IS. Never inferred from a string, never defaulted.
  final PrintPlacement placement;

  PrintSide get side => placement.side!;

  /// The fulfiller's print file, in pixels — the whole canvas, not the art.
  final int canvasWidthPx;
  final int canvasHeightPx;
  final int dpi;

  /// Where the artwork sits on that canvas, in canvas pixels. The artwork is
  /// rendered to fit inside this and never beyond it.
  final ui.Rect artworkArea;

  /// Print files composite onto fabric, so the garment colour is NOT baked in.
  final bool transparent;

  final ProductionImageFormat format;
  final PrintArrangement arrangement;

  /// What this spec was built for (e.g. `'tshirt'`), carried into the result
  /// so a commerce layer can tell one print file from another.
  final String? productKey;

  /// The canvas in inches, from its own pixels and dpi.
  (double, double) get physicalInches =>
      (canvasWidthPx / dpi, canvasHeightPx / dpi);
}

enum ProductionImageFormat {
  png;

  String get mimeType => 'image/png';
  String get extension => 'png';
}

/// A finished print file, and everything a commerce layer needs to know about
/// it without opening it.
class ProductionArtwork {
  const ProductionArtwork({
    required this.recipeId,
    required this.placement,
    required this.widthPx,
    required this.heightPx,
    required this.dpi,
    required this.format,
    required this.bytes,
    required this.imageHash,
    required this.engineVersion,
    required this.grammarVersion,
    required this.assetsVersion,
    required this.schemaVersion,
    required this.elapsed,
    this.garmentId,
    this.productKey,
  });

  /// The design this file IS — the same content hash the preview and the
  /// wardrobe use, so a print file can always be traced back to the design a
  /// customer approved.
  final String recipeId;

  /// The two-face garment it belongs to, when rendered as part of one.
  final String? garmentId;

  /// What this file is a print of — the unambiguous answer M27 orders from.
  final PrintPlacement placement;

  PrintSide get side => placement.side!;

  final int widthPx;
  final int heightPx;
  final int dpi;
  final ProductionImageFormat format;
  final Uint8List bytes;

  /// Stable hash of the encoded bytes — how a caller asserts that the same
  /// inputs produced the same file, without comparing pixels across GPUs.
  final String imageHash;

  /// The reproducibility contract: the same recipe re-rendered under these
  /// versions produces this file again.
  final String engineVersion;
  final String grammarVersion;
  final String assetsVersion;
  final int schemaVersion;

  final String? productKey;
  final Duration elapsed;

  (double, double) get physicalInches => (widthPx / dpi, heightPx / dpi);

  @override
  String toString() =>
      'ProductionArtwork(${side.name} $widthPx×$heightPx @${dpi}dpi '
      '${format.extension} recipe=$recipeId hash=$imageHash)';
}

/// Thrown when a print file cannot be produced.
///
/// Deliberately loud. A production render that quietly returns something else
/// — a default, a smaller image, the other face — is worse than one that
/// fails, because the failure is then discovered by a customer holding a
/// shirt.
class ProductionRenderException implements Exception {
  ProductionRenderException(this.message, {this.recipeId, this.cause});

  final String message;
  final String? recipeId;
  final Object? cause;

  @override
  String toString() =>
      'ProductionRenderException: $message'
      '${recipeId == null ? '' : ' (recipe $recipeId)'}'
      '${cause == null ? '' : '\ncaused by: $cause'}';
}

/// Renders a recipe to a print file.
///
/// The SAME [Renderer] that draws the preview draws this — the difference
/// between the two is the pixel count and nothing else. There is no second
/// engine, no screenshot of the garment mockup, and no upscaling of a preview:
/// the artwork is rendered natively at the size it will occupy on the print
/// file, then placed on the canvas at 1:1.
class ProductionRenderer {
  ProductionRenderer(this.renderer);

  final Renderer renderer;

  /// The largest rect of [aspect] (w/h) that fits inside [box], centred.
  static ui.Rect fitInside(ui.Rect box, double aspect) {
    if (aspect <= 0 || box.isEmpty) return box;
    var w = box.width, h = box.width / aspect;
    if (h > box.height) {
      h = box.height;
      w = box.height * aspect;
    }
    return ui.Rect.fromLTWH(
      box.left + (box.width - w) / 2,
      box.top + (box.height - h) / 2,
      w,
      h,
    );
  }

  /// The recipe's own aspect (width / height), from its orientation.
  static double aspectOf(DesignRecipe r) => switch (r.composition.canvasOrientation) {
    Orientation.portrait => 0.8,
    Orientation.landscape => 1.25,
    Orientation.square => 1.0,
  };

  /// Renders [recipe] onto [spec]'s canvas.
  ///
  /// Never mutates the recipe, never re-rolls it, and never touches the Studio
  /// session it came from — it is handed a finished design and turns it into
  /// pixels.
  Future<ProductionArtwork> render(
    DesignRecipe recipe,
    ProductionRenderSpec spec,
  ) async {
    final sw = Stopwatch()..start();

    // Where the artwork lands, at the recipe's own aspect so nothing is
    // stretched, and never wider than the printable area.
    final art = fitInside(spec.artworkArea, aspectOf(recipe));
    final artW = art.width.round(), artH = art.height.round();
    if (artW <= 0 || artH <= 0) {
      throw ProductionRenderException(
        'the artwork would be ${artW}x$artH px on this print file',
        recipeId: recipe.recipeId,
      );
    }

    // Rendered AT the destination size — the whole point. A preview-sized
    // render scaled up here would be a blurred shirt at 150 dpi.
    final RenderResult rendered;
    try {
      rendered = await renderer.render(
        recipe,
        RenderTarget(
          width: artW,
          height: artH,
          quality: RenderQuality.print,
          background: const ui.Color(0x00000000),
          // The artwork alone: a print file composites onto fabric, so a
          // garment fill baked in here would print as a coloured rectangle.
          paintBackground: false,
        ),
      );
    } catch (e) {
      throw ProductionRenderException(
        'the renderer could not draw this design at $artW×$artH',
        recipeId: recipe.recipeId,
        cause: e,
      );
    }

    final ui.Image canvasImage;
    try {
      canvasImage = await _compose(rendered.image, art, spec);
    } finally {
      rendered.image.dispose();
    }

    try {
      final data = await canvasImage.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (data == null) {
        throw ProductionRenderException(
          'the print file could not be encoded as ${spec.format.extension}',
          recipeId: recipe.recipeId,
        );
      }
      final bytes = data.buffer.asUint8List();
      return ProductionArtwork(
        recipeId: recipe.recipeId,
        placement: spec.placement,
        widthPx: spec.canvasWidthPx,
        heightPx: spec.canvasHeightPx,
        dpi: spec.dpi,
        format: spec.format,
        bytes: bytes,
        imageHash: fnv1aBytes(bytes),
        engineVersion: recipe.engineVersion,
        grammarVersion: recipe.grammarVersion,
        assetsVersion: recipe.assetsVersion,
        schemaVersion: recipe.schemaVersion,
        productKey: spec.productKey,
        elapsed: sw.elapsed,
      );
    } finally {
      canvasImage.dispose();
    }
  }

  /// Draws the rendered artwork onto the print file's canvas, under the
  /// customer's arrangement.
  ///
  /// The arrangement is applied exactly as the on-garment preview applies it —
  /// translate about the fitted rect's centre by a fraction of the printable
  /// area, then rotate, then scale — so the two cannot disagree about where a
  /// moved design ended up.
  Future<ui.Image> _compose(
    ui.Image art,
    ui.Rect dst,
    ProductionRenderSpec spec,
  ) async {
    final canvasRect = ui.Rect.fromLTWH(
      0,
      0,
      spec.canvasWidthPx.toDouble(),
      spec.canvasHeightPx.toDouble(),
    );
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder, canvasRect);
    if (!spec.transparent) {
      canvas.drawRect(canvasRect, ui.Paint()..color = const ui.Color(0xFFFFFFFF));
    }
    // Nothing may print outside the printable area, however it was arranged.
    canvas.save();
    canvas.clipRect(spec.artworkArea);

    final a = spec.arrangement;
    if (!a.isIdentity) {
      final c = dst.center;
      canvas.translate(
        c.dx + a.translation.dx * spec.artworkArea.width,
        c.dy + a.translation.dy * spec.artworkArea.height,
      );
      canvas.rotate(a.rotation);
      canvas.scale(a.scale);
      canvas.translate(-c.dx, -c.dy);
    }
    canvas.drawImageRect(
      art,
      ui.Rect.fromLTWH(0, 0, art.width.toDouble(), art.height.toDouble()),
      dst,
      ui.Paint()..filterQuality = ui.FilterQuality.high,
    );
    canvas.restore();
    for (final m in spec.marks) {
      BrandMark.paint(canvas, m.rect, m.ink, text: m.text);
    }

    final picture = recorder.endRecording();
    try {
      return await picture.toImage(spec.canvasWidthPx, spec.canvasHeightPx);
    } finally {
      picture.dispose();
    }
  }
}

/// Stable 64-bit FNV-1a over bytes → 16-char hex, matching the renderer's own
/// so the two hashes are comparable.
String fnv1aBytes(List<int> bytes) {
  const int mask = 0xFFFFFFFFFFFFFFFF;
  var h = 0xCBF29CE484222325;
  for (final b in bytes) {
    h = (h ^ (b & 0xFF)) & mask;
    h = (h * 0x100000001B3) & mask;
  }
  return (h & 0x7FFFFFFFFFFFFFFF).toRadixString(16).padLeft(16, '0');
}
