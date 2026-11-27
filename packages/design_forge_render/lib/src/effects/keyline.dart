import 'dart:async';
import 'dart:collection';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

/// A keyline around an artwork's OUTER edge (Composition.outlineWidth).
///
/// Only the silhouette is outlined: the artwork's edge against the outside,
/// including the gaps between torn strips that open to the outside. Holes
/// INSIDE the artwork (distress speckle) are left alone, so worn ink still
/// shows the garment rather than a dark blot. Pure over RGBA bytes
/// ([outline]) and run on a background isolate ([apply]).
class Keyline {
  const Keyline._();

  /// Dark keyline for light garments, light for dark ones.
  static const ui.Color dark = ui.Color(0xFF141414);
  static const ui.Color light = ui.Color(0xFFF5F5F5);

  /// The automatic keyline colour against [garment] (null = assume light).
  static ui.Color autoFor(ui.Color? garment) =>
      garment == null || garment.computeLuminance() >= 0.3 ? dark : light;

  /// Parses `#RRGGBB`; null otherwise.
  static ui.Color? parse(String hex) {
    if (!RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(hex)) return null;
    return ui.Color(0xFF000000 | int.parse(hex.substring(1), radix: 16));
  }

  /// [art] with a keyline of [radius] px in [colour] behind its silhouette.
  static Future<ui.Image> apply(
      ui.Image art, double radius, ui.Color colour) async {
    if (radius <= 0) return art;
    final data = await art.toByteData(format: ui.ImageByteFormat.rawRgba);
    final w = art.width, h = art.height;
    final bytes = data!.buffer.asUint8List();
    final rgb = [
      (colour.r * 255).round(),
      (colour.g * 255).round(),
      (colour.b * 255).round(),
    ];
    final out = await Isolate.run(() => outline(bytes, w, h, radius, rgb));
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(out, w, h, ui.PixelFormat.rgba8888, completer.complete);
    return completer.future;
  }

  /// Pure keyline pass over PREMULTIPLIED RGBA (what `rawRgba` gives and
  /// `decodeImageFromPixels` takes). Returns a new premultiplied buffer.
  static Uint8List outline(
      Uint8List rgba, int w, int h, double radius, List<int> rgb,
      {int inkAlpha = 64}) {
    final n = w * h;
    final ink = Uint8List(n);
    for (var i = 0; i < n; i++) {
      if (rgba[i * 4 + 3] > inkAlpha) ink[i] = 1;
    }

    // Smooth the silhouette a little (morphological closing) so the keyline
    // doesn't trace every crack of the worn edge.
    final c = math.max(1.0, radius * 0.75);
    final toInk = distanceTo(ink, w, h);
    final dilated = Uint8List(n);
    for (var i = 0; i < n; i++) {
      if (toInk[i] <= c) dilated[i] = 1;
    }
    final notDilated = Uint8List(n);
    for (var i = 0; i < n; i++) {
      notDilated[i] = 1 - dilated[i];
    }
    final toOutside = distanceTo(notDilated, w, h, borderIsSet: true);
    final closed = Uint8List(n);
    for (var i = 0; i < n; i++) {
      if (dilated[i] == 1 && toOutside[i] > c) closed[i] = 1;
    }
    // Keep original ink too (thin features the closing eroded).
    for (var i = 0; i < n; i++) {
      if (ink[i] == 1) closed[i] = 1;
    }

    // Silhouette = everything not reachable from the canvas border through
    // empty pixels, so interior holes count as inside.
    final exterior = Uint8List(n);
    final queue = Queue<int>();
    void seed(int i) {
      if (closed[i] == 0 && exterior[i] == 0) {
        exterior[i] = 1;
        queue.add(i);
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
    while (queue.isNotEmpty) {
      final i = queue.removeFirst();
      final x = i % w;
      if (x > 0) seed(i - 1);
      if (x < w - 1) seed(i + 1);
      if (i >= w) seed(i - w);
      if (i < n - w) seed(i + w);
    }
    final silhouette = Uint8List(n);
    for (var i = 0; i < n; i++) {
      silhouette[i] = 1 - exterior[i];
    }

    final toSil = distanceTo(silhouette, w, h);
    final out = Uint8List(n * 4);
    for (var i = 0; i < n; i++) {
      // Keyline coverage outside the silhouette, anti-aliased at its rim.
      final d = toSil[i];
      final oa = silhouette[i] == 1
          ? 0.0
          : (radius + 0.5 - d).clamp(0.0, 1.0).toDouble();
      final aa = rgba[i * 4 + 3] / 255.0;
      // Artwork OVER keyline, premultiplied: c = c_art + c_line·a_line·(1-a_art).
      final under = oa * (1 - aa);
      for (var k = 0; k < 3; k++) {
        out[i * 4 + k] = (rgba[i * 4 + k] + rgb[k] * under).round().clamp(0, 255);
      }
      out[i * 4 + 3] = ((aa + under) * 255).round().clamp(0, 255);
    }
    return out;
  }

  /// Chamfer (1, √2) distance from every pixel to the nearest set pixel of
  /// [mask]. With [borderIsSet], the area outside the canvas counts as set.
  static Float32List distanceTo(Uint8List mask, int w, int h,
      {bool borderIsSet = false}) {
    const inf = 1e9, d1 = 1.0, d2 = 1.41421356;
    final d = Float32List(w * h);
    for (var i = 0; i < w * h; i++) {
      d[i] = mask[i] == 1 ? 0 : inf;
    }
    double at(int x, int y) {
      if (x < 0 || y < 0 || x >= w || y >= h) return borderIsSet ? 0 : inf;
      return d[y * w + x];
    }

    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final i = y * w + x;
        var v = d[i];
        if (v == 0) continue;
        v = math.min(v, at(x - 1, y) + d1);
        v = math.min(v, at(x, y - 1) + d1);
        v = math.min(v, at(x - 1, y - 1) + d2);
        v = math.min(v, at(x + 1, y - 1) + d2);
        d[i] = v;
      }
    }
    for (var y = h - 1; y >= 0; y--) {
      for (var x = w - 1; x >= 0; x--) {
        final i = y * w + x;
        var v = d[i];
        if (v == 0) continue;
        v = math.min(v, at(x + 1, y) + d1);
        v = math.min(v, at(x, y + 1) + d1);
        v = math.min(v, at(x + 1, y + 1) + d2);
        v = math.min(v, at(x - 1, y + 1) + d2);
        d[i] = v;
      }
    }
    return d;
  }
}
