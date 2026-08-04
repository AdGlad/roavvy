import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

/// Deterministic, seeded procedural textures used by the print-style pipeline.
///
/// All generators are **pure**: the same `(seed, size, …)` always produces
/// byte-identical output, on any platform, with no dependence on wall-clock or
/// frame timing. Textures are grayscale packed into RGBA (R=G=B=value, A=255)
/// so they can be sampled as either a colour overlay or, via a channel, an
/// alpha mask.
///
/// The textures are designed to be **tileable** (wrap seamlessly) so a small
/// cached image can cover any artwork via [ui.TileMode.repeated], keeping memory
/// bounded regardless of print resolution.
///
/// The pure `generate*Bytes` functions are the unit-test surface; the
/// [PrintStyleTextures] cache wraps them in [ui.Image]s for the compositor.

// ── Deterministic hash noise ──────────────────────────────────────────────────

/// Integer hash → `0..1`. Deterministic, no state. Based on a 32-bit
/// integer-avalanche (Wang/xorshift style) so neighbouring inputs decorrelate.
double _hash01(int x) {
  var h = x & 0xFFFFFFFF;
  h = (h ^ (h >> 16)) & 0xFFFFFFFF;
  h = (h * 0x7feb352d) & 0xFFFFFFFF;
  h = (h ^ (h >> 15)) & 0xFFFFFFFF;
  h = (h * 0x846ca68b) & 0xFFFFFFFF;
  h = (h ^ (h >> 16)) & 0xFFFFFFFF;
  return h / 0xFFFFFFFF;
}

/// 2-D value hash for coordinate `(x, y)` and [seed].
double _hash2(int x, int y, int seed) =>
    _hash01((x * 73856093) ^ (y * 19349663) ^ (seed * 83492791));

int _packGray(int v) {
  final g = v.clamp(0, 255);
  return (0xFF << 24) | (g << 16) | (g << 8) | g;
}

Uint8List _toRgba(Int32List argb) {
  // Store as RGBA byte order expected by ui.decodeImageFromPixels
  // (PixelFormat.rgba8888).
  final out = Uint8List(argb.length * 4);
  for (var i = 0; i < argb.length; i++) {
    final v = argb[i] & 0xFF; // gray value in low byte
    final o = i * 4;
    out[o] = v; // R
    out[o + 1] = v; // G
    out[o + 2] = v; // B
    out[o + 3] = 0xFF; // A
  }
  return out;
}

// ── White-noise grain ─────────────────────────────────────────────────────────

/// Per-pixel white-noise grain, mean ~128. Deterministic in `(seed, size)`.
/// Used with [ui.BlendMode.overlay]/`softLight` for film grain.
Uint8List generateGrainBytes({required int seed, int size = 256}) {
  final argb = Int32List(size * size);
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final n = _hash2(x, y, seed);
      // Centre around 128 with full spread.
      final v = (n * 255).round();
      argb[y * size + x] = _packGray(v);
    }
  }
  return _toRgba(argb);
}

// ── Low-frequency blotch (value noise) ────────────────────────────────────────

/// Smooth tileable value noise built from a coarse [cells]×[cells] lattice with
/// bilinear interpolation and wrap-around. Bright = keep ink, dark = ink loss.
/// Used to drive **distress → transparency** and uneven stamp ink.
Uint8List generateBlotchBytes({
  required int seed,
  int size = 256,
  int cells = 8,
}) {
  // Precompute lattice values (wrap on [cells]).
  final lattice = List<double>.generate(
    cells * cells,
    (i) => _hash2(i % cells, i ~/ cells, seed),
  );
  double latticeAt(int cx, int cy) =>
      lattice[(cy % cells) * cells + (cx % cells)];

  final argb = Int32List(size * size);
  final cellSize = size / cells;
  for (var y = 0; y < size; y++) {
    final fy = y / cellSize;
    final y0 = fy.floor();
    final ty = fy - y0;
    final wy = ty * ty * (3 - 2 * ty); // smoothstep
    for (var x = 0; x < size; x++) {
      final fx = x / cellSize;
      final x0 = fx.floor();
      final tx = fx - x0;
      final wx = tx * tx * (3 - 2 * tx);
      final v00 = latticeAt(x0, y0);
      final v10 = latticeAt(x0 + 1, y0);
      final v01 = latticeAt(x0, y0 + 1);
      final v11 = latticeAt(x0 + 1, y0 + 1);
      final top = v00 + (v10 - v00) * wx;
      final bot = v01 + (v11 - v01) * wx;
      final v = top + (bot - top) * wy;
      argb[y * size + x] = _packGray((v * 255).round());
    }
  }
  return _toRgba(argb);
}

// ── Scratches / ink chips ─────────────────────────────────────────────────────

/// Sparse dark streaks on a bright field — screen-print scratches / ink loss.
/// Bright (255) = keep ink, dark (0) = scratched away. [density] scales the
/// number of streaks. Deterministic in `(seed, size, density)`.
Uint8List generateScratchBytes({
  required int seed,
  int size = 256,
  double density = 1.0,
}) {
  // Start bright (no scratches).
  final gray = Uint8List(size * size)..fillRange(0, size * size, 255);

  final streakCount = (size * 0.5 * density).round().clamp(0, size * 4);
  for (var s = 0; s < streakCount; s++) {
    // Deterministic streak parameters.
    final r0 = _hash01(seed * 6151 + s * 3);
    final r1 = _hash01(seed * 6151 + s * 3 + 1);
    final r2 = _hash01(seed * 6151 + s * 3 + 2);
    var x = (r0 * size).floor();
    var y = (r1 * size).floor();
    final len = (r2 * size * 0.6).round() + 4;
    // Mostly-horizontal drift with slight vertical wander.
    for (var i = 0; i < len; i++) {
      final wander = _hash01(seed * 131 + s * 977 + i);
      x = (x + 1) % size;
      if (wander > 0.82) y = (y + 1) % size;
      if (wander < 0.10) y = (y + size - 1) % size;
      final idx = y * size + x;
      // Darken (multiplicative so overlaps deepen).
      gray[idx] = (gray[idx] * 0.15).round();
    }
  }

  final out = Uint8List(size * size * 4);
  for (var i = 0; i < gray.length; i++) {
    final v = gray[i];
    final o = i * 4;
    out[o] = v;
    out[o + 1] = v;
    out[o + 2] = v;
    out[o + 3] = 0xFF;
  }
  return out;
}

// ── ui.Image cache ────────────────────────────────────────────────────────────

/// Kinds of cached base texture. Halftone dots are generated by the pipeline
/// per artwork (not here) because their cell size is artwork-normalised.
///
/// [stampInk] is a finer, higher-contrast blotch used for the uneven ink and
/// rough edges of the Passport Stamp style.
enum PrintTextureKind { grain, blotch, scratch, stampInk }

/// Caches decoded [ui.Image] textures keyed by `(kind, seed, size)`. A handful
/// of small tileable images serve every design (tiled via
/// [ui.TileMode.repeated]), so memory stays bounded regardless of print size.
class PrintStyleTextures {
  PrintStyleTextures._();

  static final PrintStyleTextures instance = PrintStyleTextures._();

  final Map<String, ui.Image> _cache = {};

  String _key(PrintTextureKind kind, int seed, int size) =>
      '${kind.name}_${seed}_$size';

  Future<ui.Image> get(
    PrintTextureKind kind,
    int seed, {
    int size = 256,
  }) async {
    final key = _key(kind, seed, size);
    final cached = _cache[key];
    if (cached != null) return cached;

    final bytes = switch (kind) {
      PrintTextureKind.grain => generateGrainBytes(seed: seed, size: size),
      PrintTextureKind.blotch => generateBlotchBytes(seed: seed, size: size),
      PrintTextureKind.scratch => generateScratchBytes(seed: seed, size: size),
      PrintTextureKind.stampInk =>
        generateBlotchBytes(seed: seed, size: size, cells: 18),
    };

    final image = await _decode(bytes, size);
    _cache[key] = image;
    return image;
  }

  Future<ui.Image> _decode(Uint8List rgba, int size) {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      rgba,
      size,
      size,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    return completer.future;
  }

  void dispose() {
    for (final img in _cache.values) {
      img.dispose();
    }
    _cache.clear();
  }
}
