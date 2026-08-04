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

// ── Tileable value noise + fBm ─────────────────────────────────────────────────

double _smooth(double t) => t * t * (3 - 2 * t);

/// One octave of tileable value noise sampled at normalised `(nx, ny)` in 0..1
/// over a `cells×cells` lattice (wraps seamlessly). Bilinear + smoothstep.
double _valueNoise(double nx, double ny, int cells, int seed) {
  final fx = nx * cells;
  final fy = ny * cells;
  final x0 = fx.floor();
  final y0 = fy.floor();
  final tx = _smooth(fx - x0);
  final ty = _smooth(fy - y0);
  double lat(int cx, int cy) =>
      _hash2(((cx % cells) + cells) % cells, ((cy % cells) + cells) % cells, seed);
  final v00 = lat(x0, y0);
  final v10 = lat(x0 + 1, y0);
  final v01 = lat(x0, y0 + 1);
  final v11 = lat(x0 + 1, y0 + 1);
  final top = v00 + (v10 - v00) * tx;
  final bot = v01 + (v11 - v01) * tx;
  return top + (bot - top) * ty;
}

/// Fractal Brownian motion: sums [octaves] of [_valueNoise] at doubling
/// frequency and [persistence]-scaled amplitude, starting from [baseCells].
/// Tileable (every octave wraps), normalised to 0..1. This is what gives the
/// textures natural, multi-scale worn detail instead of soft single-octave blobs.
double _fbm(
  double nx,
  double ny,
  int baseCells,
  int octaves,
  double persistence,
  int seed,
) {
  var sum = 0.0;
  var amp = 1.0;
  var ampSum = 0.0;
  var cells = baseCells;
  for (var o = 0; o < octaves; o++) {
    sum += amp * _valueNoise(nx, ny, cells, seed + o * 1013904223);
    ampSum += amp;
    amp *= persistence;
    cells *= 2;
  }
  return ampSum <= 0 ? 0.5 : (sum / ampSum).clamp(0.0, 1.0);
}

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

/// Clumped film grain, mean ~128. Per-pixel white noise **modulated by a
/// low-frequency fBm envelope** so the grain clusters into patches (like real
/// film / heavy-ink screen print) instead of uniform TV static. Deterministic
/// in `(seed, size)`. Used with [ui.BlendMode.softLight]/`overlay`.
Uint8List generateGrainBytes({required int seed, int size = 256}) {
  final argb = Int32List(size * size);
  final inv = 1.0 / size;
  for (var y = 0; y < size; y++) {
    final ny = y * inv;
    for (var x = 0; x < size; x++) {
      final wn = _hash2(x, y, seed); // white noise 0..1
      // Envelope 0.35..1.0: grain is stronger in some patches, faint in others.
      final env = 0.35 + 0.65 * _fbm(x * inv, ny, 20, 2, 0.6, seed ^ 0x51ed270b);
      final v = (128 + (wn - 0.5) * 235 * env).round().clamp(0, 255);
      argb[y * size + x] = _packGray(v);
    }
  }
  return _toRgba(argb);
}

// ── Low-frequency blotch (value noise) ────────────────────────────────────────

/// Tileable **fractal** value noise ([_fbm]) over a `cells`-cell base lattice.
/// Bright = keep ink, dark = ink loss. Used to drive **distress → transparency**
/// and uneven stamp ink. Multiple octaves give worn ink its natural, multi-scale
/// grain instead of soft uniform blobs.
///
/// [octaves]/[persistence] set the fractal detail; [contrast] (>1) pushes values
/// toward black/white around the midpoint, turning a soft fade into sharp worn
/// chunks. Deterministic in every argument.
Uint8List generateBlotchBytes({
  required int seed,
  int size = 256,
  int cells = 6,
  int octaves = 5,
  double persistence = 0.62,
  double contrast = 1.0,
}) {
  final argb = Int32List(size * size);
  final inv = 1.0 / size;
  for (var y = 0; y < size; y++) {
    final ny = y * inv;
    for (var x = 0; x < size; x++) {
      var v = _fbm(x * inv, ny, cells, octaves, persistence, seed);
      if (contrast != 1.0) {
        // Steepen around 0.5 → sharper light/dark separation (worn chunks).
        v = (0.5 + (v - 0.5) * contrast).clamp(0.0, 1.0);
      }
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
    final r3 = _hash01(seed * 6151 + s * 3 + 7);
    var x = r0 * size;
    var y = r1 * size;
    final len = (r2 * size * 0.55).round() + 4;
    // Each streak runs at its own angle (not all horizontal), so the ink loss
    // looks scratched/scuffed from every direction. Slightly biased horizontal.
    final angle = (r3 - 0.5) * 2.4; // ~ -1.2..1.2 rad off horizontal
    final dx = math.cos(angle);
    final dy = math.sin(angle);
    // Darkness varies per streak: some faint scuffs, some deep gouges.
    final keep = 0.08 + _hash01(seed * 40961 + s) * 0.45;
    for (var i = 0; i < len; i++) {
      final jitter = _hash01(seed * 131 + s * 977 + i) - 0.5;
      x = (x + dx + jitter * 0.5) % size;
      y = (y + dy + jitter * 0.5) % size;
      final ix = ((x % size) + size).floor() % size;
      final iy = ((y % size) + size).floor() % size;
      final idx = iy * size + ix;
      // Darken (multiplicative so overlaps deepen).
      gray[idx] = (gray[idx] * keep).round();
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
  // Value along each border controls how deep the tear reaches there. Two
  // frequencies combine so the tear line has both broad bays and fine tongues —
  // a ragged paper rip, not a smooth wave.
  double octave(double t, int cells, int salt) {
    final p = t * cells;
    final i0 = p.floor();
    final f = p - i0;
    final a = _hash01(i0 * 374761393 ^ (seed + salt) * 668265263);
    final b = _hash01((i0 + 1) * 374761393 ^ (seed + salt) * 668265263);
    final s = f * f * (3 - 2 * f);
    return a + (b - a) * s; // 0..1
  }

  double borderDepth(double t, int salt) =>
      (0.62 * octave(t, 11, salt) + 0.38 * octave(t, 37, salt + 101))
          .clamp(0.0, 1.0);

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
enum PrintTextureKind { grain, blotch, scratch, stampInk, mottle, crack, wash }

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
      // Coarse worn breakup with fractal detail + contrast → chunky ink loss.
      PrintTextureKind.blotch => generateBlotchBytes(
          seed: seed, size: size, cells: 5, octaves: 5, contrast: 1.35),
      PrintTextureKind.scratch => generateScratchBytes(seed: seed, size: size),
      // Fine, high-contrast uneven ink for the rubber-stamp look.
      PrintTextureKind.stampInk => generateBlotchBytes(
          seed: seed, size: size, cells: 12, octaves: 4, contrast: 1.55),
      // Dense fine mottle layered over the coarse blotch.
      PrintTextureKind.mottle => generateBlotchBytes(
          seed: seed, size: size, cells: 22, octaves: 3, contrast: 1.25),
      PrintTextureKind.crack => generateCrackBytes(seed: seed, size: size),
      // Big, soft, low-contrast cloud for the acid-wash bleach patches.
      PrintTextureKind.wash => generateBlotchBytes(
          seed: seed, size: size, cells: 4, octaves: 4, contrast: 0.9),
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
