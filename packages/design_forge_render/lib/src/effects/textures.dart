import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

/// Deterministic procedural textures for the effect stages. All seeded from the
/// recipe seed so treatments are reproducible (print == preview).
class EffectTextures {
  const EffectTextures._();

  static int _hash(int i, int seed) {
    var h = (i ^ seed) & 0x7FFFFFFFFFFFFFFF;
    h = ((h ^ (h >> 30)) * 0xBF58476D1CE4E5B9) & 0x7FFFFFFFFFFFFFFF;
    h = ((h ^ (h >> 27)) * 0x94D049BB133111EB) & 0x7FFFFFFFFFFFFFFF;
    return (h ^ (h >> 31)) & 0x7FFFFFFFFFFFFFFF;
  }

  static double _rand(int i, int seed) => (_hash(i, seed) & 0xFFFFFF) / 0xFFFFFF;

  /// Opaque grayscale value-noise image (for grain overlays). Two smoothed
  /// octaves so it reads as film grain rather than TV static.
  static Future<ui.Image> grain(int w, int h, int seed) {
    final rgba = Uint8List(w * h * 4);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final n1 = _rand(y * w + x, seed);
        final n2 = _rand(((y >> 1) * w + (x >> 1)), seed ^ 0x1234);
        final v = ((n1 * 0.6 + n2 * 0.4) * 255).clamp(0, 255).toInt();
        final i = (y * w + x) * 4;
        rgba[i] = v;
        rgba[i + 1] = v;
        rgba[i + 2] = v;
        rgba[i + 3] = 255;
      }
    }
    return _decode(rgba, w, h);
  }

  /// Alpha speckle mask (opaque where material should be eroded). [amount] 0..1
  /// controls speckle density; clustered via a coarse noise so it mottles
  /// rather than sprinkling uniformly.
  static Future<ui.Image> speckle(int w, int h, int seed, double amount) {
    final rgba = Uint8List(w * h * 4);
    final thresh = amount.clamp(0.0, 1.0) * 0.5;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final fine = _rand(y * w + x, seed ^ 0xABCD);
        final coarse = _rand((y >> 3) * w + (x >> 3), seed ^ 0x77);
        final erode = (fine < thresh) && (coarse < 0.6 + amount * 0.4);
        final i = (y * w + x) * 4;
        rgba[i] = 255;
        rgba[i + 1] = 255;
        rgba[i + 2] = 255;
        rgba[i + 3] = erode ? 255 : 0;
      }
    }
    return _decode(rgba, w, h);
  }

  static Future<ui.Image> _decode(Uint8List rgba, int w, int h) {
    final c = Completer<ui.Image>();
    ui.decodeImageFromPixels(rgba, w, h, ui.PixelFormat.rgba8888, c.complete);
    return c.future;
  }
}
