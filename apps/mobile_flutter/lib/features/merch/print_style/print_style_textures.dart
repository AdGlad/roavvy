import 'dart:async';
import 'dart:math' as math;
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

// ── Cracks (Voronoi cell edges) ───────────────────────────────────────────────

/// A branching crack network built from the boundaries of a jittered Voronoi
/// lattice (where the two nearest feature points are ~equidistant). Bright
/// (255) = intact, dark (0) = crack — used to erase thin transparent fissures
/// through the ink (grunge / cracked-ink look). Tileable via toroidal wrap.
///
/// [cells] controls crack spacing (more cells → finer, denser cracks);
/// [thickness] is the crack width as a fraction of a cell.
Uint8List generateCrackBytes({
  required int seed,
  int size = 256,
  int cells = 7,
  double thickness = 0.09,
}) {
  final cellSize = size / cells;
  // Jittered feature point per lattice cell, in pixel space.
  final px = List<double>.filled(cells * cells, 0);
  final py = List<double>.filled(cells * cells, 0);
  for (var gy = 0; gy < cells; gy++) {
    for (var gx = 0; gx < cells; gx++) {
      final i = gy * cells + gx;
      px[i] = (gx + _hash2(gx, gy, seed)) * cellSize;
      py[i] = (gy + _hash2(gx, gy, seed * 2654435761)) * cellSize;
    }
  }

  double wrapDelta(double d) {
    if (d > size / 2) return d - size;
    if (d < -size / 2) return d + size;
    return d;
  }

  final band = thickness * cellSize;
  final out = Uint8List(size * size * 4);
  for (var y = 0; y < size; y++) {
    final cyi = (y / cellSize).floor();
    for (var x = 0; x < size; x++) {
      final cxi = (x / cellSize).floor();
      var d1 = double.infinity, d2 = double.infinity;
      // Search the 3×3 neighbouring lattice cells (with wrap).
      for (var oy = -1; oy <= 1; oy++) {
        for (var ox = -1; ox <= 1; ox++) {
          final gx = (cxi + ox + cells) % cells;
          final gy = (cyi + oy + cells) % cells;
          final i = gy * cells + gx;
          final dx = wrapDelta(x - px[i]);
          final dy = wrapDelta(y - py[i]);
          final d = dx * dx + dy * dy;
          if (d < d1) {
            d2 = d1;
            d1 = d;
          } else if (d < d2) {
            d2 = d;
          }
        }
      }
      final edge = math.sqrt(d2) - math.sqrt(d1); // 0 on a cell boundary
      // crack = 1 near a boundary, fading out over `band`.
      final crack = (1 - (edge / band)).clamp(0.0, 1.0);
      final v = (255 * (1 - crack)).round();
      final o = (y * size + x) * 4;
      out[o] = v;
      out[o + 1] = v;
      out[o + 2] = v;
      out[o + 3] = 0xFF;
    }
  }
  return out;
}

// ── Torn edges ────────────────────────────────────────────────────────────────

/// A ragged brush-stroke edge mask sized to the artwork ([w]×[h]). Alpha
/// encodes how much ink to **erase** (rgb=0), so it can be applied directly with
/// [ui.BlendMode.dstOut]. The erosion is concentrated near the rectangle border
/// with a jagged, noise-varied depth so the design frays into the garment
/// instead of ending on a clean rectangle (refs: distressed.jpeg / grunge.jpeg).
///
/// [margin] is the max torn depth as a fraction of the shorter side; [strength]
/// scales the erase amount (0..1). Deterministic in `(seed, w, h, …)`.
Uint8List generateTornEdgeBytes({
  required int seed,
  required int w,
  required int h,
  double margin = 0.14,
  double strength = 1.0,
}) {
  final out = Uint8List(w * h * 4);
  // Coarse value along each border controls how deep the tear reaches there;
  // a finer value breaks the tear line up into tongues/specks.
  double borderDepth(double t, int salt) {
    // t in 0..1 around a border; sample a smooth 1-D value noise.
    final p = t * 11.0;
    final i0 = p.floor();
    final f = p - i0;
    final a = _hash01(i0 * 374761393 ^ (seed + salt) * 668265263);
    final b = _hash01((i0 + 1) * 374761393 ^ (seed + salt) * 668265263);
    final s = f * f * (3 - 2 * f);
    return a + (b - a) * s; // 0..1
  }

  for (var y = 0; y < h; y++) {
    final ny = y / (h - 1);
    for (var x = 0; x < w; x++) {
      final nx = x / (w - 1);
      // Normalised distance to each edge.
      final dl = nx, dr = 1 - nx, dt = ny, db = 1 - ny;
      // Per-edge torn depth (varies along the edge), then erosion if inside it.
      double erode = 0;
      void consider(double dist, double along, int salt) {
        final depth = margin * (0.25 + 1.5 * borderDepth(along, salt));
        if (dist < depth) {
          final e = 1 - dist / depth; // 1 at the very edge → 0 at depth
          if (e > erode) erode = e;
        }
      }

      consider(dl, ny, 1);
      consider(dr, ny, 2);
      consider(dt, nx, 3);
      consider(db, nx, 4);

      if (erode > 0) {
        // Break the tear up with fine speckle so it isn't a smooth ramp.
        final speck = _hash2(x, y, seed ^ 0x1234);
        final a = (erode * strength * (0.6 + 0.4 * speck) * 255)
            .round()
            .clamp(0, 255);
        out[(y * w + x) * 4 + 3] = a;
      }
    }
  }
  return out;
}

// ── ui.Image cache ────────────────────────────────────────────────────────────

/// Kinds of cached base texture. Halftone dots are generated by the pipeline
/// per artwork (not here) because their cell size is artwork-normalised.
///
/// [stampInk] is a finer, higher-contrast blotch used for the uneven ink and
/// rough edges of the Passport Stamp style. [mottle] is a dense fine blotch for
/// grungy ink breakup; [crack] is the Voronoi crack network.
enum PrintTextureKind { grain, blotch, scratch, stampInk, mottle, crack }

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
      PrintTextureKind.mottle =>
        generateBlotchBytes(seed: seed, size: size, cells: 34),
      PrintTextureKind.crack => generateCrackBytes(seed: seed, size: size),
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
