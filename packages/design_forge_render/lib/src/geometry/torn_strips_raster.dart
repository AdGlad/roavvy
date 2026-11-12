import 'dart:math' as math;
import 'dart:typed_data';

import 'package:design_forge/design_forge.dart';

/// Rasterises the `portrait_torn_flag` artwork on the CPU: the flag turned to
/// portrait and torn into ragged hanging strips, with grunge distress and an
/// ink colour treatment.
///
/// Pure Dart on byte buffers — no `dart:ui`, no GPU drawing — so the torn
/// geometry, distress and colour are bit-identical on every device and can run
/// on a background isolate. The only GPU-dependent input is the flag raster
/// itself ([flagRgba], produced by the asset resolver).
///
/// Every length is derived from the rotated flag's pixel size, so the design
/// scales with the output: preview and print differ only in sampling density.
class TornStripsRaster {
  const TornStripsRaster();

  /// Where the rotated flag sits on a [canvasW]×[canvasH] canvas: the flag's
  /// length (its portrait height) in pixels. The width follows from
  /// [flagAspect] (length ÷ width). Reserves room for the strips' sideways sway.
  static int flagLengthFor(
      int canvasW, int canvasH, double flagAspect, TornStrips p) {
    final m = p.margin.clamp(0.0, 0.4);
    final boxW = canvasW * (1 - 2 * m);
    final boxH = canvasH * (1 - 2 * m);
    // Rotated width / height = 1 / aspect (aspect = flag width / height).
    final rotAspect = 1 / flagAspect;
    final swayRoom = 1 + 2 * _swayFraction(p);
    final byWidth = boxW / (rotAspect * swayRoom);
    return math.max(8, math.min(boxH, byWidth).floor());
  }

  /// The flag's own lengthwise colour boundaries — the edges of stripes that
  /// run the full length of the flag (horizontal stripes on the landscape
  /// flag, which hang vertically once it is turned to portrait).
  ///
  /// Returned as fractions (0..1) of the flag's height, top to bottom. A row
  /// boundary counts when the colour changes across it along at least 40% of
  /// the flag's length, so a US canton (which interrupts the upper stripes for
  /// 40–57% of the length, by artwork) still yields all 12 stripe edges, while diagonal,
  /// vertical, circular or emblem designs (Seychelles, France, Japan) yield
  /// none. [rgba] is premultiplied RGBA, [w]×[h].
  static List<double> lengthwiseBoundaries(Uint8List rgba, int w, int h) {
    if (h < 3 || w < 3) return const [];
    final step = math.max(1, w ~/ 240);
    var samples = 0;
    for (var x = 0; x < w; x += step) {
      samples++;
    }
    final rows = <int>[];
    for (var y = 0; y < h - 1; y++) {
      var changed = 0;
      for (var x = 0; x < w; x += step) {
        final a = (y * w + x) * 4, b = a + w * 4;
        final d = (rgba[a] - rgba[b]).abs() +
            (rgba[a + 1] - rgba[b + 1]).abs() +
            (rgba[a + 2] - rgba[b + 2]).abs();
        if (d > 60) changed++;
      }
      if (changed >= samples * 0.4) rows.add(y);
    }
    // Anti-aliased edges span a row or two: one boundary per run, at its
    // centre (the boundary lies after row y, i.e. at y + 1).
    final out = <double>[];
    var i = 0;
    while (i < rows.length) {
      var j = i;
      while (j + 1 < rows.length && rows[j + 1] - rows[j] <= 1) {
        j++;
      }
      final at = ((rows[i] + rows[j]) / 2 + 1) / h;
      final nearEdge = at < 0.02 || at > 0.98;
      final tooClose = out.isNotEmpty && at - out.last < 0.03;
      if (!nearEdge && !tooClose) out.add(at);
      i = j + 1;
    }
    return out;
  }

  static double _swayFraction(TornStrips p) =>
      p.curvature.clamp(0.0, 1.0) * 0.10;

  /// Renders the artwork into a premultiplied RGBA buffer of
  /// [canvasW]×[canvasH] (transparent background).
  ///
  /// [flagRgba] is the UNROTATED flag, premultiplied RGBA, [flagW]×[flagH]
  /// (landscape, as drawn by the resolver). [lengthPx] is the rotated flag's
  /// length on the canvas; when it differs from [flagW] the artwork is
  /// stretched along its length (see [TornStrips.flagAspect]).
  Uint8List render({
    required Uint8List flagRgba,
    required int flagW,
    required int flagH,
    int? lengthPx,
    required int canvasW,
    required int canvasH,
    required TornStrips params,
    required int seed,
  }) {
    final out = Uint8List(canvasW * canvasH * 4);
    final p = params;
    // Rotated flag size: its width across, its length down.
    final rw = flagH.toDouble();
    final rh = (lengthPx ?? flagW).toDouble();
    final rowScale = flagW / rh;
    final ox = (canvasW - rw) / 2;
    final oy = (canvasH - rh) / 2;

    final layout = DeterministicRng(seed).stream('tornStrips:layout');
    final fringeRng = DeterministicRng(seed).stream('tornStrips:fringe');
    // Size unit for tear detail: one US-stripe width, so roughness, gaps and
    // wear read the same on every flag whatever its strip widths.
    final sw = rw / 13;

    // ---- cut lines ----------------------------------------------------------
    // `flag`: the flag's own lengthwise stripe edges, full length. A flag with
    // none gets a torn fringe instead — strips are never invented across a
    // design that has no stripes. `even`: evenly spaced, full length (a
    // stylised look, chosen explicitly). `fringe`: evenly spaced short tears
    // at the free end only; the flag stays whole above them.
    var mode = p.cutMode;
    var interior = <double>[];
    if (mode == TornStrips.cutsFromFlag) {
      for (final f in lengthwiseBoundaries(flagRgba, flagW, flagH)) {
        // Flag row fraction → rotated u (clockwise: the flag's top edge lands
        // on the right).
        final u = p.rotateClockwise ? rw * (1 - f) : rw * f;
        interior.add(p.mirror ? rw - u : u);
      }
      interior.sort();
      if (interior.isEmpty) mode = TornStrips.cutsFringe;
    }
    if (mode == TornStrips.cutsEven) {
      final count = p.stripCount.clamp(1, 64);
      final pitch = rw / count;
      final jitter = p.spacingJitter.clamp(0.0, 1.0) * 0.9 * pitch;
      interior = [
        for (var k = 1; k < count; k++)
          k * pitch + (layout.nextDouble() - 0.5) * jitter,
      ];
    }
    final fringe = mode == TornStrips.cutsFringe;
    // A fringe has no full-length cuts: the whole flag is one piece that
    // frays into tongues at its end (below).
    if (fringe) interior = [];
    final depth = p.fringeDepth.clamp(0.05, 1.0);
    double fringeStart() =>
        rh * (1 - depth * (0.55 + 0.45 * fringeRng.nextDouble()));

    // Full-length cuts first; where along the length each cut begins (cuts
    // are torn up from the free end — above that point the neighbours are
    // still one piece).
    final cuts = <double>[0.0];
    final cutStart = <double>[0.0];
    final full = [0.0, ...interior, rw];
    for (var k = 1; k < full.length; k++) {
      final a = full[k - 1], b = full[k];
      // A stripe much wider than a US stripe (Germany's thirds, or the whole
      // flag in fringe mode) is not torn into strips: it frays into short
      // tongues at its free end and stays whole above them.
      final wide = mode != TornStrips.cutsEven && b - a > 2.2 * sw;
      if (wide) {
        final tongues = fringe
            ? p.fringeCount.clamp(1, 64)
            : math.max(1, ((b - a) / (1.6 * sw)).round());
        final pitch = (b - a) / tongues;
        final jitter = p.spacingJitter.clamp(0.0, 1.0) * 0.9 * pitch;
        for (var j = 1; j < tongues; j++) {
          cuts.add(a + j * pitch + (fringeRng.nextDouble() - 0.5) * jitter);
          cutStart.add(fringeStart());
        }
      }
      cuts.add(b);
      cutStart.add(0);
    }
    final n = cuts.length - 1;

    // ---- intact block on the canton side ---------------------------------
    final hasBlock = p.blockWidth > 0.001 && p.blockHeight > 0.001 && n > 1;
    var blockCut = n; // strips with index >= blockCut (or < when mirrored)
    final blockH = p.blockHeight.clamp(0.0, 0.95) * rh;
    if (hasBlock) {
      final target = p.mirror
          ? p.blockWidth.clamp(0.0, 1.0) * rw
          : rw * (1 - p.blockWidth.clamp(0.0, 1.0));
      var best = 1;
      for (var k = 1; k < n; k++) {
        if ((cuts[k] - target).abs() < (cuts[best] - target).abs()) best = k;
      }
      blockCut = best;
    }
    bool underBlock(int i) =>
        hasBlock && (p.mirror ? i < blockCut : i >= blockCut);

    // ---- per-strip shape --------------------------------------------------
    final strips = <_Strip>[];
    final breaks = DeterministicRng(seed).stream('tornStrips:breaks');
    // Strips between the same pair of full-length cuts are siblings (tongues
    // of one stripe) and share that stripe's top.
    var parentTop = 0.0;
    for (var i = 0; i < n; i++) {
      var parentEnd = i + 1;
      while (parentEnd < n && cutStart[parentEnd] > 0) {
        parentEnd++;
      }
      var parentStart = i;
      while (parentStart > 0 && cutStart[parentStart] > 0) {
        parentStart--;
      }
      final parentW = cuts[parentEnd] - cuts[parentStart];
      final narrow = parentW <= 2.2 * sw;
      final under = underBlock(i);
      final a = cuts[i], b = cuts[i + 1];
      final w = b - a;
      // Hangs free from its own torn top only in the full-length cut modes;
      // a fringe tongue is joined to its neighbours above its cuts.
      final topRoll = layout.nextDouble();
      // A stripe starts lower the narrower it is (a wide band hanging at a
      // different height reads as a missing chunk, not a torn stripe).
      if (parentStart == i) {
        parentTop = fringe
            ? 0.0
            : topRoll *
                p.topVariation.clamp(0.0, 0.8) *
                rh *
                math.min(1.0, 2 * sw / parentW);
      }
      final top = under ? blockH : parentTop;
      final joinedTo = math.max(cutStart[i], cutStart[i + 1]);
      var end =
          rh * (1 - p.tearLength.clamp(0.0, 0.9) * math.pow(layout.nextDouble(), 0.7));
      end = math.max(end, top + 0.25 * rh);
      // A tongue always reaches below the point it tears free.
      if (joinedTo > 0) end = math.max(end, joinedTo + 0.06 * rh);
      // A free strip may be torn clean through partway down.
      var breakAt = 0.0, breakLen = 0.0;
      final breakRoll = breaks.nextDouble();
      final breakPos = breaks.nextDouble();
      final breakSize = breaks.nextDouble();
      if (!under &&
          narrow &&
          joinedTo == 0 &&
          breakRoll < p.breakChance.clamp(0.0, 1.0)) {
        breakAt = top + (0.06 + 0.22 * breakPos) * rh;
        breakLen = (0.025 + 0.05 * breakSize) * rh;
        if (breakAt + breakLen > end - 0.1 * rh) breakLen = 0;
      }
      strips.add(_Strip(
        breakAt: breakAt,
        breakLen: breakLen,
        a: a,
        b: b,
        w: w,
        under: under,
        hang: under ? blockH : 0,
        attach: under ? blockH : joinedTo,
        top: top,
        sharedTop: fringe && !under,
        joinL: cutStart[i],
        joinR: cutStart[i + 1],
        end: math.min(end, rh),
        tip: 0.25 + 0.5 * layout.nextDouble(),
        tipLen: p.tearPoint.clamp(0.0, 1.0) *
            (1.0 + 2.0 * layout.nextDouble()) *
            math.min(w, 2 * sw),
        slant: (layout.nextDouble() - 0.5) * 0.8 * math.min(w, 2 * sw),
        swayJitter: layout.nextDouble() * 2 - 1,
        noiseOff: layout.nextDouble() * 1000,
        noiseSeed: layout.nextInt(1 << 30),
      ));
    }
    final globalPhase = layout.nextDouble() * 2 * math.pi;
    final noise = _Noise(DeterministicRng(seed).stream('tornStrips:noise').nextInt(1 << 30));
    final distressNoise =
        _Noise(DeterministicRng(seed).stream('tornStrips:distress').nextInt(1 << 30));

    // Texture detail grows with resolution: each noise adds octaves until its
    // finest one is ~2px, so a print shows real grain where a preview (which
    // cannot resolve it) shows the same overall pattern.
    int octavesFor(double cyclesPerLength, {int min = 2, int max = 8}) {
      final finest = rh / (2 * cyclesPerLength);
      if (finest <= 1) return min;
      return (math.log(finest) / math.log(2.1)).floor().clamp(min, max);
    }

    // ---- shared knobs, in pixels -----------------------------------------
    final swayAmp = _swayFraction(p) * rw;
    final swayCycles = 0.5 + 2.5 * p.waviness.clamp(0.0, 1.0);
    final gapHalf = p.gap.clamp(0.0, 0.9) * sw / 2;
    final wobAmp = p.widthWobble.clamp(0.0, 1.0) * 0.22 * sw;
    final roughAmp = p.edgeRoughness.clamp(0.0, 1.0) * 0.10 * sw;
    final notchAmp = p.edgeRoughness.clamp(0.0, 1.0) * 0.28 * sw;
    final jagAmp = p.tearJag.clamp(0.0, 1.0) * 0.5;
    final blockTear = p.blockTear.clamp(0.0, 1.0);
    final edgeOctaves = octavesFor(70, min: 3);
    final coherence = p.swayCoherence.clamp(0.0, 1.0);

    double envelope(double v, double from) {
      final span = rh - from;
      if (span <= 0) return 0;
      final e = ((v - from) / span).clamp(0.0, 1.0);
      return math.pow(e, 1.2).toDouble();
    }

    // One shared wind wave (with a soft second harmonic for an S-curve) that
    // every strip follows from where it hangs, plus each strip's own wander
    // below the point where it tears free of its neighbours — so strips that
    // are still joined move as one piece.
    double sway(_Strip s, double v) {
      if (swayAmp == 0) return 0;
      final vn = v / rh;
      final wave = math.sin(2 * math.pi * swayCycles * vn + globalPhase) +
          0.3 * math.sin(4 * math.pi * swayCycles * vn + globalPhase * 1.7);
      final wander = noise.signed1(vn * 3 + s.noiseOff, s.noiseSeed);
      return swayAmp *
          (envelope(v, s.hang) * wave * (0.5 + 0.4 * coherence) +
              envelope(v, s.attach) *
                  (1 - coherence) *
                  (0.6 * wander + 0.3 * s.swayJitter));
    }

    // A tear line wanders to either side of its cut — where one strip loses
    // ink its neighbour gains it, so stripes keep their true width. Bounded so
    // neighbouring tear lines never cross.
    final cutOff = [for (var k = 0; k <= n; k++) 37.0 * k + 5.3];
    final cutLimit = [
      for (var k = 0; k <= n; k++)
        k == 0 || k == n
            ? 0.0
            : 0.4 * math.min(cuts[k] - cuts[k - 1], cuts[k + 1] - cuts[k]),
    ];
    double tearLine(int k, double v) {
      final vn = v / rh;
      final off = cutOff[k];
      final drift = wobAmp * noise.signed1(vn * 2.5 + off, 0x7A11 + k);
      final fine = roughAmp * 2 * (noise.fbm1(vn * 70 + off, 0x7A22 + k, edgeOctaves) - 0.5);
      final notch = notchAmp *
          math.pow(noise.value1(vn * 18 + off * 1.7, 0x7A33 + k), 4) *
          (noise.value1(vn * 9 + off, 0x7A44 + k) < 0.5 ? -1 : 1);
      return (drift + fine + notch).clamp(-cutLimit[k], cutLimit[k]);
    }

    // How open cut [k] is at [v]: 0 above where it starts, easing to 1 just
    // below it (so a strip tears away from its neighbour gradually).
    double opening(int k, double v) =>
        ((v - cutStart[k]) / (0.04 * rh)).clamp(0.0, 1.0);

    // A fringe flag's top edge is one continuous ragged edge.
    double sharedTop(double u) {
      final un = u / rw;
      return p.topVariation.clamp(0.0, 0.8) * 0.3 * rh * noise.fbm1(un * 5 + 4.1, 0x70F, 3) +
          jagAmp * 0.6 * sw * noise.fbm1(u / sw * 1.3 + 2.7, 0x71F, edgeOctaves);
    }

    // Edge erosion (positive = eats into the strip) at length position [v].
    double rough(double v, double off, int sd) {
      final vn = v / rh;
      final fine = noise.fbm1(vn * 70 + off, sd, edgeOctaves);
      final notch = math.pow(noise.value1(vn * 18 + off * 1.7, sd ^ 0x55), 4);
      return roughAmp * fine + notchAmp * notch;
    }

    // ---- colour + distress, per output pixel -----------------------------
    final sat = p.saturation.clamp(0.0, 2.0);
    final vin = p.vintage.clamp(0.0, 1.0);
    final distress = p.distress.clamp(0.0, 1.0);
    final edgeWear = p.edgeWear.clamp(0.0, 1.0);
    final speckleFreq = 260 - 190 * p.distressScale.clamp(0.0, 1.0);
    final scratchOctaves = octavesFor(speckleFreq * 0.9, min: 3);
    final speckOctaves = octavesFor(speckleFreq * 1.2);
    final mottleOctaves = octavesFor(speckleFreq * 0.35);
    final edgeFalloff = 0.15 * sw;
    final hue = p.hueShift * math.pi / 180;
    final hueCos = math.cos(hue), hueSin = math.sin(hue);
    final bright = p.brightness.clamp(-1.0, 1.0);

    // Writes one output pixel: samples the rotated flag at source (u, v) and
    // composites it over what is already there with [coverage].
    // [edgeDist] is the pixel distance to the nearest torn edge (wear grows
    // toward it).
    void shade(int x, int y, double u, double v, double coverage,
        [double edgeDist = 1e9]) {
      if (coverage <= 0) return;
      // Rotated (u, v) → unrotated flag pixel. Horizontal bilinear blend.
      var xr = u - 0.5;
      if (p.mirror) xr = rw - 1 - xr;
      final yr = (v - 0.5).clamp(0.0, rh - 1);
      final x0 = xr.floor().clamp(0, flagH - 1);
      final x1 = (x0 + 1).clamp(0, flagH - 1);
      final fx = (xr - x0).clamp(0.0, 1.0);
      final row = (yr * rowScale).round().clamp(0, flagW - 1);
      int idx(int xx) {
        // Clockwise: rotated (xx, row) ← flag (row, flagH-1-xx).
        final fxp = p.rotateClockwise ? row : flagW - 1 - row;
        final fyp = p.rotateClockwise ? flagH - 1 - xx : xx;
        return (fyp * flagW + fxp) * 4;
      }

      final i0 = idx(x0), i1 = idx(x1);
      var a = flagRgba[i0 + 3] * (1 - fx) + flagRgba[i1 + 3] * fx;
      if (a <= 0) return;
      // Premultiplied → straight.
      var r = (flagRgba[i0] * (1 - fx) + flagRgba[i1] * fx) * 255 / a;
      var g = (flagRgba[i0 + 1] * (1 - fx) + flagRgba[i1 + 1] * fx) * 255 / a;
      var bl = (flagRgba[i0 + 2] * (1 - fx) + flagRgba[i1 + 2] * fx) * 255 / a;

      if (p.knockoutWhite) {
        final mn = math.min(r, math.min(g, bl));
        final mx = math.max(r, math.max(g, bl));
        if (mn > 200 && mx - mn < 40) {
          a *= ((235 - mn) / 35).clamp(0.0, 1.0);
          if (a <= 0) return;
        }
      }
      if (sat != 1) {
        final lum = 0.299 * r + 0.587 * g + 0.114 * bl;
        r = lum + (r - lum) * sat;
        g = lum + (g - lum) * sat;
        bl = lum + (bl - lum) * sat;
      }
      if (hue != 0) {
        // Rotate chroma in YIQ space (luma preserved).
        final yy = 0.299 * r + 0.587 * g + 0.114 * bl;
        final ii = 0.596 * r - 0.274 * g - 0.322 * bl;
        final qq = 0.211 * r - 0.523 * g + 0.312 * bl;
        final i2 = ii * hueCos - qq * hueSin;
        final q2 = ii * hueSin + qq * hueCos;
        r = yy + 0.956 * i2 + 0.621 * q2;
        g = yy - 0.272 * i2 - 0.647 * q2;
        bl = yy - 1.106 * i2 + 1.703 * q2;
      }
      // Whites stay white under brightness and vintage: a grey or cream cast
      // reads as a stain on a white shirt.
      final whiteness =
          ((math.min(r, math.min(g, bl)) - 190) / 50).clamp(0.0, 1.0);
      if (bright > 0) {
        r += (255 - r) * bright * 0.6;
        g += (255 - g) * bright * 0.6;
        bl += (255 - bl) * bright * 0.6;
      } else if (bright < 0) {
        final k = 1 + bright * (1 - whiteness);
        r *= k;
        g *= k;
        bl *= k;
      }
      if (vin > 0) {
        final vv = vin * (1 - whiteness);
        r = r * (1 - 0.15 * vv) + 30 * vv;
        g = g * (1 - 0.18 * vv) + 22 * vv;
        bl = bl * (1 - 0.28 * vv) + 10 * vv;
      }

      var keep = coverage;
      if (distress > 0 || edgeWear > 0) {
        final xn = (x + 0.5) / rh, yn = (y + 0.5) / rh;
        final blotch = distressNoise.fbm2(xn * 3.5, yn * 2.2, 11, 3);
        final edge = edgeDist < 1e8 ? math.exp(-edgeDist / edgeFalloff) : 0.0;
        // Wear comes in patches with cleaner ink between them.
        final patch = ((blotch - 0.32) / 0.4).clamp(0.0, 1.0);
        final density =
            (distress * (0.4 + 0.6 * patch * patch * (3 - 2 * patch)) +
                    edgeWear * 0.8 * edge)
                .clamp(0.0, 1.0);
        // Scratches stretched along the strips' length — worn ink streaks the
        // way a hanging flag creases — plus fine round speckle.
        final scratch = distressNoise.fbm2n(
            xn * speckleFreq * 0.9, yn * speckleFreq * 0.22, 23, scratchOctaves);
        final speck = distressNoise.fbm2n(
            xn * speckleFreq * 1.2, yn * speckleFreq * 1.2, 31, speckOctaves);
        keep *= ((1 - density * 0.55 - scratch) / 0.03).clamp(0.0, 1.0);
        keep *= ((1 - density * 0.36 - speck) / 0.04).clamp(0.0, 1.0);
        // Mottled ink thinning between the scratches.
        final mottle = distressNoise.fbm2n(
            xn * speckleFreq * 0.35, yn * speckleFreq * 0.12, 41, mottleOctaves);
        keep *= 1 - 0.3 * distress * ((mottle - 0.45) / 0.35).clamp(0.0, 1.0);
        if (keep <= 0) return;
      }

      final srcA = (a / 255) * keep; // 0..1
      final o = (y * canvasW + x) * 4;
      final inv = 1 - srcA;
      out[o] = (r.clamp(0, 255) * srcA + out[o] * inv).round().clamp(0, 255);
      out[o + 1] = (g.clamp(0, 255) * srcA + out[o + 1] * inv).round().clamp(0, 255);
      out[o + 2] = (bl.clamp(0, 255) * srcA + out[o + 2] * inv).round().clamp(0, 255);
      out[o + 3] = (srcA * 255 + out[o + 3] * inv).round().clamp(0, 255);
    }

    final y0 = math.max(0, oy.floor());
    final y1 = math.min(canvasH, (oy + rh).ceil());

    // Block edges.
    final blockStart = hasBlock ? cuts[blockCut] : 0.0; // inner edge (u)
    double blockTop(double u) {
      final un = u / rw;
      final ragged = math.pow(noise.fbm1(un * 14 + 7.3, 0x0B10C, 4), 1.5);
      // A few deep bites torn out of the top, as on a worn hanging flag.
      final bite = math.pow(noise.value1(un * 7 + 3.1, 0x0B17E), 2.5);
      return blockTear * rh * (0.04 * ragged + 0.17 * bite);
    }

    for (var y = y0; y < y1; y++) {
      final v = y + 0.5 - oy;
      if (v < 0 || v > rh) continue;

      // -- the intact block, above blockH ----------------------------------
      if (hasBlock && v < blockH) {
        final inner = blockTear *
            sw *
            (0.25 * noise.fbm1(v / rh * 30 + 1.9, 0x1A, 3) +
                0.6 * math.pow(noise.value1(v / rh * 9 + 2.2, 0x1B), 3));
        final outer = rough(v, 91.0, 0x0E);
        final double lo, hi;
        if (p.mirror) {
          lo = outer;
          hi = blockStart - inner;
        } else {
          lo = blockStart + inner;
          hi = rw - outer;
        }
        final xs = math.max(0, (ox + lo).floor());
        final xe = math.min(canvasW, (ox + hi).ceil());
        for (var x = xs; x < xe; x++) {
          final u = x + 0.5 - ox;
          final top = blockTop(u);
          var cov = math.min(u - lo + 0.5, hi - u + 0.5).clamp(0.0, 1.0);
          cov = math.min(cov, (v - top + 0.5).clamp(0.0, 1.0));
          shade(x, y, u, v, cov,
              math.min(math.min(u - lo, hi - u), v - top));
        }
      }

      // -- the strips --------------------------------------------------------
      for (var i = 0; i < n; i++) {
        final s = strips[i];
        if (s.under && v < blockH) continue; // drawn as part of the block
        if (v < s.top || v > s.end + 2) continue;

        // Gaps open gradually below the block so a strip tears away from it.
        final blockScale = s.under
            ? ((v - blockH) / (0.05 * rh)).clamp(0.0, 1.0)
            : 1.0;
        double lo, hi;
        // Whether each side is a real (open) tear: a closed join between
        // still-connected tongues is not an edge and must not wear.
        var openL = 1.0, openR = 1.0;
        if (i == 0) {
          lo = s.a + rough(v, s.noiseOff + 13, s.noiseSeed ^ 0x11);
        } else {
          final o = opening(i, v) * blockScale;
          openL = o;
          // Closed (still joined): overlap the neighbour by half a pixel so
          // the seam is solid.
          lo = s.a + (tearLine(i, v) + gapHalf) * o - (o == 0 ? 0.5 : 0);
        }
        if (i == n - 1) {
          hi = s.b - rough(v, s.noiseOff + 29, s.noiseSeed ^ 0x22);
        } else {
          final o = opening(i + 1, v) * blockScale;
          openR = o;
          hi = s.b + (tearLine(i + 1, v) - gapHalf) * o + (o == 0 ? 0.5 : 0);
        }
        if (hi - lo < 0.5) continue;

        final d = sway(s, v);
        final xs = math.max(0, (ox + lo + d).floor());
        final xe = math.min(canvasW, (ox + hi + d).ceil());
        // Rows clear of the torn ends need no per-pixel end test.
        final tipW = math.min(s.w, 2 * sw);
        final endZone = s.end - s.tipLen - jagAmp * tipW - 1;
        final topZone = s.sharedTop
            ? 0.3 * p.topVariation.clamp(0.0, 0.8) * rh + jagAmp * 0.6 * sw + 1
            : s.top + jagAmp * 0.8 * sw + 1;
        for (var x = xs; x < xe; x++) {
          final u = x + 0.5 - ox - d;
          var cov = math.min(u - lo + 0.5, hi - u + 0.5).clamp(0.0, 1.0);
          if (cov <= 0) continue;
          final t = ((u - s.a) / s.w).clamp(0.0, 1.0);
          var edgeDist = math.min(openL < 0.5 ? 1e9 : u - lo,
              openR < 0.5 ? 1e9 : hi - u);
          if (v > endZone) {
            var bottom = s.end -
                s.tipLen * (t - s.tip).abs() * 2 +
                (t - s.tip) * s.slant +
                jagAmp * tipW * noise.signed1(t * 5 + s.noiseOff * 3, s.noiseSeed ^ 0x33);
            // A tongue's shoulders stay below where its side tears begin —
            // never a wedge cut up into fabric that is still joined.
            if (s.joinL > 0 || s.joinR > 0) {
              final floor = s.joinL + (s.joinR - s.joinL) * t + 0.02 * rh;
              if (bottom < floor) bottom = floor;
            }
            cov = math.min(cov, (bottom - v + 0.5).clamp(0.0, 1.0));
            edgeDist = math.min(edgeDist, bottom - v);
          }
          if (s.breakLen > 0 &&
              v > s.breakAt - tipW * 1.5 &&
              v < s.breakAt + s.breakLen + tipW * 1.5) {
            // Ragged edges either side of the break: the upper fragment's
            // torn bottom and the lower piece's torn top.
            final upper = s.breakAt +
                0.6 * tipW * noise.signed1(t * 6 + s.noiseOff * 5, s.noiseSeed ^ 0x55);
            final lower = s.breakAt +
                s.breakLen +
                0.6 * tipW * noise.signed1(t * 6 + s.noiseOff * 9, s.noiseSeed ^ 0x66);
            final keepPiece = math.max((upper - v + 0.5).clamp(0.0, 1.0),
                (v - lower + 0.5).clamp(0.0, 1.0));
            cov = math.min(cov, keepPiece);
            edgeDist = math.min(edgeDist, math.max(upper - v, v - lower).abs());
          }
          if (!s.under && v < topZone) {
            // Continuous across the strip's joined siblings.
            final topEdge = s.sharedTop
                ? sharedTop(u)
                : s.top + jagAmp * 0.8 * sw * noise.fbm1(u / sw * 1.3 + 9.1, 0x44, 3);
            cov = math.min(cov, (v - topEdge + 0.5).clamp(0.0, 1.0));
            edgeDist = math.min(edgeDist, v - topEdge);
          }
          shade(x, y, u, v, cov, edgeDist);
        }
      }
    }
    return out;
  }
}

class _Strip {
  _Strip({
    required this.breakAt,
    required this.breakLen,
    required this.a,
    required this.b,
    required this.w,
    required this.under,
    required this.hang,
    required this.attach,
    this.joinL = 0,
    this.joinR = 0,
    this.sharedTop = false,
    required this.top,
    required this.end,
    required this.tip,
    required this.tipLen,
    required this.slant,
    required this.swayJitter,
    required this.noiseOff,
    required this.noiseSeed,
  });

  /// Source span across the rotated flag, in pixels.
  final double a, b, w;

  /// Hangs from the intact block (joined at its bottom edge).
  final bool under;

  /// Length position the strip hangs from (the shared sway grows below it).
  final double hang;

  /// Length position where the strip tears free of its neighbours (its own
  /// wander grows below it; above it, it moves with them as one piece).
  final double attach;

  /// Where the tears on the strip's left / right sides begin (0 = a
  /// full-length cut or the flag's edge).
  final double joinL, joinR;

  /// The top edge is the flag's continuous torn edge, not the strip's own.
  final bool sharedTop;

  /// Where the strip's material starts and ends along its length.
  final double top, end;

  /// Across-strip position (0..1) of the torn end's spike.
  final double tip;

  /// How far the spike reaches beyond the strip's shoulders, in pixels.
  final double tipLen;

  /// Diagonal lean of the torn end, in pixels across the strip.
  final double slant;

  /// A torn break through the strip: material is missing from about
  /// [breakAt] for [breakLen] pixels (0 = unbroken).
  final double breakAt, breakLen;

  final double swayJitter;
  final double noiseOff;
  final int noiseSeed;
}

/// Hash value noise (1-D and 2-D), deterministic from integer seeds. Pure
/// integer hashing masked to 32 bits, so results are identical on every
/// 64-bit Dart VM.
class _Noise {
  _Noise(this.seed);

  final int seed;

  static int _mix(int h) {
    h &= 0xFFFFFFFF;
    h ^= h >> 16;
    h = (h * 0x7FEB352D) & 0xFFFFFFFF;
    h ^= h >> 15;
    h = (h * 0x846CA68B) & 0xFFFFFFFF;
    h ^= h >> 16;
    return h;
  }

  double _lattice1(int i, int sd) =>
      (_mix(i * 0x9E3779B1 + (seed ^ sd) * 0x85EBCA77) & 0xFFFFFF) / 0xFFFFFF;

  double _lattice2(int i, int j, int sd) =>
      (_mix(_mix(i * 0x9E3779B1 + (seed ^ sd)) + j * 0xC2B2AE3D) & 0xFFFFFF) /
      0xFFFFFF;

  static double _smooth(double f) => f * f * (3 - 2 * f);

  /// 0..1 smooth value noise.
  double value1(double x, int sd) {
    final i = x.floor();
    final f = _smooth(x - i);
    final a = _lattice1(i, sd), b = _lattice1(i + 1, sd);
    return a + (b - a) * f;
  }

  /// -1..1 smooth value noise.
  double signed1(double x, int sd) => value1(x, sd) * 2 - 1;

  /// 0..1 fractal value noise.
  double fbm1(double x, int sd, int octaves) {
    var sum = 0.0, amp = 1.0, norm = 0.0, f = 1.0;
    for (var o = 0; o < octaves; o++) {
      sum += value1(x * f, sd + o * 131) * amp;
      norm += amp;
      amp *= 0.5;
      f *= 2.03;
    }
    return sum / norm;
  }

  double value2(double x, double y, int sd) {
    final i = x.floor(), j = y.floor();
    final fx = _smooth(x - i), fy = _smooth(y - j);
    final a = _lattice2(i, j, sd), b = _lattice2(i + 1, j, sd);
    final c = _lattice2(i, j + 1, sd), d = _lattice2(i + 1, j + 1, sd);
    final top = a + (b - a) * fx;
    final bot = c + (d - c) * fx;
    return top + (bot - top) * fy;
  }

  /// Fractal value noise; octaves after the first are rotated (~37° each) so
  /// the lattice never lines up into axis-aligned blocks.
  double fbm2(double x, double y, int sd, int octaves) {
    var sum = 0.0, amp = 1.0, norm = 0.0, f = 1.0;
    var px = x, py = y;
    for (var o = 0; o < octaves; o++) {
      sum += value2(px * f, py * f, sd + o * 977) * amp;
      norm += amp;
      amp *= 0.5;
      f *= 2.17;
      final rx = px * _rotCos - py * _rotSin;
      py = px * _rotSin + py * _rotCos;
      px = rx;
    }
    return sum / norm;
  }

  /// [fbm2] with its contrast held constant whatever the octave count (as
  /// three octaves would give), so adding detail at print resolution does not
  /// thin out the wear a threshold carves from it.
  double fbm2n(double x, double y, int sd, int octaves) {
    var norm = 0.0, sq = 0.0, amp = 1.0;
    for (var o = 0; o < octaves; o++) {
      norm += amp;
      sq += amp * amp;
      amp *= 0.5;
    }
    const threeOctaveSpread = 0.6547; // sqrt(1 + 1/4 + 1/16) / 1.75
    final k = threeOctaveSpread * norm / math.sqrt(sq);
    return 0.5 + (fbm2(x, y, sd, octaves) - 0.5) * k;
  }

  static const double _rotCos = 0.8; // cos ≈ 36.9°
  static const double _rotSin = 0.6;
}
