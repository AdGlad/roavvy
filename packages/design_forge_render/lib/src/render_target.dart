import 'dart:typed_data';
import 'dart:ui' as ui;

/// Quality tier. The SAME pipeline runs for both — resolution and supersampling
/// are the only differences, so preview == print by construction.
enum RenderQuality {
  /// Fast, low-res, heavily cached — for gallery browsing.
  preview,

  /// Full print resolution (supersampled masks, full-res assets).
  print,
}

/// Where/how a recipe is rendered. Passed to every stage.
class RenderTarget {
  const RenderTarget({
    required this.width,
    required this.height,
    this.quality = RenderQuality.preview,
    this.background,
    this.paintBackground = true,
  });

  final int width;
  final int height;
  final RenderQuality quality;

  /// Optional flat background fill (e.g. garment colour). Null = transparent.
  ///
  /// Stages also read this to choose a legible ink — title text, contrast
  /// re-colouring, passport stamp ink all key off the tone behind the artwork.
  final ui.Color? background;

  /// Whether [background] is actually painted behind the artwork.
  ///
  /// False renders the artwork LAYER alone on transparency while still telling
  /// the stages what tone it will sit against. That distinction matters: an
  /// on-garment preview composites the design onto real fabric, so no flat fill
  /// may be baked in — but the title still has to be inked for a white shirt
  /// rather than for the transparency it is drawn on.
  final bool paintBackground;

  /// A standard preview square.
  factory RenderTarget.preview({
    int size = 768,
    ui.Color? background,
    bool paintBackground = true,
  }) =>
      RenderTarget(
        width: size,
        height: size,
        quality: RenderQuality.preview,
        background: background,
        paintBackground: paintBackground,
      );

  /// The Printful print-file target (1800×2400 @ 150 DPI).
  factory RenderTarget.print({
    int width = 1800,
    int height = 2400,
    ui.Color? background,
    bool paintBackground = true,
  }) =>
      RenderTarget(
        width: width,
        height: height,
        quality: RenderQuality.print,
        background: background,
        paintBackground: paintBackground,
      );

  ui.Size get size => ui.Size(width.toDouble(), height.toDouble());
}

/// The output of a render: the live image plus PNG bytes and stable hashes.
class RenderResult {
  RenderResult({
    required this.image,
    required this.pngBytes,
    required this.recipeId,
    required this.imageHash,
    required this.elapsedMicros,
  });

  final ui.Image image;
  final Uint8List pngBytes;

  /// The recipe's content hash (from the recipe, not the pixels).
  final String recipeId;

  /// A stable hash of the PNG bytes — lets tests assert determinism without
  /// pixel-equality across GPUs.
  final String imageHash;

  final int elapsedMicros;
}
