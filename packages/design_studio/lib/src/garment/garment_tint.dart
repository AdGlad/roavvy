import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

/// Recolours a photographed garment to an arbitrary colour while keeping its
/// real folds, so a palette can offer colours no photograph exists for.
///
/// The method, in one line: strip the studio backdrop, normalise the garment's
/// luminance to a neutral white reference, then multiply by the target colour.
///
///  1. **Backdrop removal.** The bundled photos sit on a pure-white sweep. A
///     flood fill inward from the image border claims every near-white pixel
///     *connected to the edge* — so the sweep goes transparent while a white
///     shirt's own bright highlights, which are enclosed by garment, survive.
///     A plain brightness threshold would eat those highlights and leave the
///     shirt full of holes.
///  2. **Exposure anchoring.** The garment's *lit* tone — its 95th luminance
///     percentile, not its mean — is scaled to 1.0. Anchoring the mean instead
///     would push most of the shirt past full brightness, clipping the folds
///     flat; anchoring the lit tone leaves the whole fold range intact below it.
///  3. **Tint.** Multiplying by the target colour then puts the lit fabric on
///     the requested hex, with every fold shading away beneath it — which is
///     what a photograph of a garment in that colour actually looks like. Light
///     falling on cloth can only ever darken the dye, so the model is a pure
///     multiply; no highlight is invented that the fabric would not have.
///
/// The result is an image with a transparent background, which also lets the
/// garment sit on a dark surface without a white card behind it.
abstract final class GarmentTint {
  /// A pixel is backdrop-ish when every channel is at least this bright. The
  /// sweep is pure 255; shirt highlights on the white tee measure well below.
  static const int _backdropFloor = 244;

  /// The luminance percentile treated as "fully lit" and mapped onto the target
  /// colour. The very brightest pixels (specular sheen on a fold) are allowed to
  /// clip past it; taking the true maximum instead would let one hot pixel
  /// darken the entire shirt.
  static const double _litPercentile = 0.95;

  /// Builds the recoloured, background-free garment layer from [source].
  ///
  /// Returns a new image the caller owns; [source] is left untouched. When the
  /// image has no detectable garment (an unexpected asset), the source is
  /// returned re-encoded rather than a blank, so a mockup never renders empty.
  static Future<ui.Image> recolour(ui.Image source, ui.Color colour) async {
    final byteData = await source.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    if (byteData == null) return source;

    final w = source.width;
    final h = source.height;
    final px = byteData.buffer.asUint8List();

    final isBackdrop = _floodBackdrop(px, w, h);
    // The garment's own lit tone becomes the requested colour; the photo's
    // exposure therefore cannot tint the result.
    final gain = _exposureGain(px, isBackdrop);

    final r = colour.r, g = colour.g, b = colour.b;
    for (var i = 0, p = 0; i < w * h; i++, p += 4) {
      if (isBackdrop[i]) {
        px[p] = 0;
        px[p + 1] = 0;
        px[p + 2] = 0;
        px[p + 3] = 0;
        continue;
      }
      // Clamp the LUMINANCE, not the tinted product: letting it run past 1.0
      // would push lit fabric brighter than the swatch it is meant to be.
      final lum = ((px[p] * 0.2126 + px[p + 1] * 0.7152 + px[p + 2] * 0.0722) /
              255.0 *
              gain)
          .clamp(0.0, 1.0);
      px[p] = _byte(lum * r);
      px[p + 1] = _byte(lum * g);
      px[p + 2] = _byte(lum * b);
      px[p + 3] = 255;
    }

    return _decode(px, w, h);
  }

  /// The garment's folds alone: backdrop stripped, exposure anchored so the lit
  /// fabric reads white, and colour discarded entirely.
  ///
  /// **This is what the mockup painter's shading pass must be fed.** That pass
  /// multiplies its source over the print, so any colour the source carries is
  /// multiplied into the ink: hand it a red shirt — photographed or recoloured
  /// — and every flag is dragged towards red while white lettering disappears.
  /// Anchoring the lit tone to white leaves a map that can only ever *darken*,
  /// and only where the cloth actually folds, whatever colour the shirt is.
  ///
  /// Uses the same backdrop flood fill and exposure anchor as [recolour], so
  /// the folds land in register with the garment layer.
  static Future<ui.Image> luminanceMap(ui.Image source) async {
    final byteData = await source.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    if (byteData == null) return source;

    final w = source.width;
    final h = source.height;
    final px = byteData.buffer.asUint8List();

    final isBackdrop = _floodBackdrop(px, w, h);
    final gain = _exposureGain(px, isBackdrop);

    for (var i = 0, p = 0; i < w * h; i++, p += 4) {
      if (isBackdrop[i]) {
        px[p] = 0;
        px[p + 1] = 0;
        px[p + 2] = 0;
        px[p + 3] = 0;
        continue;
      }
      final lum = ((px[p] * 0.2126 + px[p + 1] * 0.7152 + px[p + 2] * 0.0722) /
              255.0 *
              gain)
          .clamp(0.0, 1.0);
      final g = _byte(lum);
      px[p] = g;
      px[p + 1] = g;
      px[p + 2] = g;
      px[p + 3] = 255;
    }

    return _decode(px, w, h);
  }

  /// Strips the backdrop without recolouring — the garment on transparency, at
  /// its photographed colour. Used for the palette's real photographs so they
  /// sit on a dark surface the same way tinted ones do.
  static Future<ui.Image> cutout(ui.Image source) async {
    final byteData = await source.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    if (byteData == null) return source;

    final w = source.width;
    final h = source.height;
    final px = byteData.buffer.asUint8List();
    final isBackdrop = _floodBackdrop(px, w, h);
    for (var i = 0, p = 0; i < w * h; i++, p += 4) {
      if (isBackdrop[i]) {
        px[p] = 0;
        px[p + 1] = 0;
        px[p + 2] = 0;
        px[p + 3] = 0;
      }
    }
    return _decode(px, w, h);
  }

  /// Flood fill inward from every border pixel across near-white neighbours.
  /// Returns a per-pixel flag: true = studio backdrop, false = garment.
  static List<bool> _floodBackdrop(Uint8List px, int w, int h) {
    final out = List<bool>.filled(w * h, false);
    // A plain int queue (indices) — cheaper than allocating Point objects for
    // a third of a million pixels.
    final queue = Int32List(w * h);
    var head = 0, tail = 0;

    bool nearWhite(int i) {
      final p = i * 4;
      return px[p] >= _backdropFloor &&
          px[p + 1] >= _backdropFloor &&
          px[p + 2] >= _backdropFloor;
    }

    void seed(int i) {
      if (!out[i] && nearWhite(i)) {
        out[i] = true;
        queue[tail++] = i;
      }
    }

    for (var x = 0; x < w; x++) {
      seed(x);
      seed((h - 1) * w + x);
    }
    for (var y = 0; y < h; y++) {
      seed(y * w);
      seed(y * w + w - 1);
    }

    while (head < tail) {
      final i = queue[head++];
      final x = i % w, y = i ~/ w;
      if (x > 0) seed(i - 1);
      if (x < w - 1) seed(i + 1);
      if (y > 0) seed(i - w);
      if (y < h - 1) seed(i + w);
    }
    return out;
  }

  /// The multiplier that puts the garment's lit tone ([_litPercentile]) at 1.0,
  /// measured from a 256-bin luminance histogram. Because it is measured per
  /// photo, two shots at different exposures recolour to the same shirt.
  static double _exposureGain(Uint8List px, List<bool> isBackdrop) {
    final histogram = Int32List(256);
    var count = 0;
    for (var i = 0, p = 0; i < isBackdrop.length; i++, p += 4) {
      if (isBackdrop[i]) continue;
      final lum =
          (px[p] * 0.2126 + px[p + 1] * 0.7152 + px[p + 2] * 0.0722).round();
      histogram[lum < 0 ? 0 : (lum > 255 ? 255 : lum)]++;
      count++;
    }
    if (count == 0) return 1.0;

    final target = (count * _litPercentile).floor();
    var seen = 0;
    for (var v = 0; v < 256; v++) {
      seen += histogram[v];
      if (seen >= target) {
        final lit = v / 255.0;
        // A near-black garment photo would otherwise demand a huge gain and
        // amplify its own sensor noise into the tint.
        return lit <= 0.05 ? 1.0 : (1.0 / lit).clamp(1.0, 4.0);
      }
    }
    return 1.0;
  }

  static int _byte(double v) =>
      v <= 0 ? 0 : (v >= 1.0 ? 255 : (v * 255).round());

  static Future<ui.Image> _decode(Uint8List rgba, int w, int h) {
    final done = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      rgba,
      w,
      h,
      ui.PixelFormat.rgba8888,
      done.complete,
    );
    return done.future;
  }
}
