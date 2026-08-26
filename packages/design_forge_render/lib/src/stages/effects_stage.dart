import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:design_forge/design_forge.dart';

import '../effects/textures.dart';
import 'render_stage.dart';

/// Continuous treatments applied to the artwork: distress, grain, fade and
/// halftone. Each is gated by its recipe value (0 = skip) and seeded from the
/// recipe seed so results are reproducible. Ripple/displacement (which needs the
/// fragment shader) is handled by a separate shader stage.
class EffectsStage extends RenderStage {
  const EffectsStage();

  @override
  String get id => 'effects';

  @override
  Future<void> apply(DesignRecipe recipe, RenderContext ctx) async {
    final fx = recipe.effects;
    if (fx == null || fx.isIdentity || ctx.artwork == null) return;

    final rng = DeterministicRng(recipe.seed).stream('effects');
    final seed = rng.nextInt(1 << 30);

    // Geometric displacement first (before texture/colour treatments).
    if (fx.shatter > 0) {
      await _shatter(ctx, seed, fx.shatter, fx.shatterSpikes);
    }
    if (fx.rippleAmp > 0) {
      await _ripple(ctx, fx.rippleAmp, fx.rippleFreq);
    }
    if (fx.tieDye > 0) {
      await _tieDye(ctx, seed, fx.tieDye);
    }
    if (fx.halftone > 0) {
      await _halftone(ctx, fx.halftone, fx.halftoneScale, fx.halftoneAngle);
    }
    if (fx.newsprint > 0) {
      await _newsprint(ctx, fx.newsprint);
    }
    if (fx.riso > 0) {
      await _riso(ctx, seed, fx.riso);
    }
    if (fx.sunFaded > 0) {
      await _sunFaded(ctx, fx.sunFaded);
    }
    if (fx.photocopy > 0) {
      await _photocopy(ctx, seed, fx.photocopy);
    }
    if (fx.distress > 0) {
      await _distress(ctx, seed, fx.distress);
    }
    if (fx.grain > 0) {
      await _grain(ctx, seed, fx.grain);
    }
    if (fx.fade > 0) {
      await _fade(ctx, fx.fade);
    }
  }

  /// Film grain: a noise texture blended `softLight`, restricted to artwork alpha.
  Future<void> _grain(RenderContext ctx, int seed, double amount) async {
    final noise = await EffectTextures.grain(ctx.width, ctx.height, seed);
    await ctx.transformArtwork((canvas, src) {
      canvas.drawImage(src, ui.Offset.zero, ui.Paint());
      canvas.saveLayer(
          ctx.fullRect,
          ui.Paint()
            ..blendMode = ui.BlendMode.softLight
            ..color = ui.Color.fromRGBO(0, 0, 0, amount.clamp(0.0, 1.0)));
      canvas.drawImage(noise, ui.Offset.zero, ui.Paint());
      // Restrict grain to where the artwork exists.
      canvas.drawImage(
          src, ui.Offset.zero, ui.Paint()..blendMode = ui.BlendMode.dstIn);
      canvas.restore();
    });
  }

  /// Distress: erode speckles out of the artwork (`dstOut`).
  Future<void> _distress(RenderContext ctx, int seed, double amount) async {
    final mask = await EffectTextures.speckle(ctx.width, ctx.height, seed, amount);
    await ctx.transformArtwork((canvas, src) {
      canvas.drawImage(src, ui.Offset.zero, ui.Paint());
      canvas.drawImage(
          mask, ui.Offset.zero, ui.Paint()..blendMode = ui.BlendMode.dstOut);
    });
  }

  /// Fade: wash the artwork toward light + lower its opacity.
  Future<void> _fade(RenderContext ctx, double amount) async {
    final a = amount.clamp(0.0, 1.0);
    await ctx.transformArtwork((canvas, src) {
      // Reduced contrast: lerp channels toward mid-grey, then lower alpha.
      final k = 1 - a * 0.45;
      final add = (a * 0.35 * 255);
      final cf = ui.ColorFilter.matrix(<double>[
        k, 0, 0, 0, add,
        0, k, 0, 0, add,
        0, 0, k, 0, add,
        0, 0, 0, 1 - a * 0.25, 0,
      ]);
      canvas.drawImage(src, ui.Offset.zero, ui.Paint()..colorFilter = cf);
    });
  }

  /// Sun-faded: desaturate toward luminance, warm the highlights and lift the
  /// blacks — a washed-out, left-in-the-window look. Pure colour grade.
  Future<void> _sunFaded(RenderContext ctx, double amount) async {
    final a = amount.clamp(0.0, 1.0);
    const lr = 0.299, lg = 0.587, lb = 0.114;
    final d = a * 0.5; // desaturation
    double m(double base, double lc) => base * (1 - d) + lc * d;
    final lift = a * 0.12 * 255;
    final warmR = a * 0.10 * 255;
    final coolB = -a * 0.06 * 255;
    await ctx.transformArtwork((canvas, src) {
      final cf = ui.ColorFilter.matrix(<double>[
        m(1, lr), m(0, lg), m(0, lb), 0, lift + warmR,
        m(0, lr), m(1, lg), m(0, lb), 0, lift,
        m(0, lr), m(0, lg), m(1, lb), 0, lift + coolB,
        0, 0, 0, 1, 0,
      ]);
      canvas.drawImage(src, ui.Offset.zero, ui.Paint()..colorFilter = cf);
    });
  }

  /// Photocopy: desaturate to grey, crush to a steep high-contrast near
  /// black-and-white, then erode a little toner speckle out.
  Future<void> _photocopy(RenderContext ctx, int seed, double amount) async {
    final a = amount.clamp(0.0, 1.0);
    const lr = 0.299, lg = 0.587, lb = 0.114;
    final k = 1 + a * 6; // contrast slope around mid-grey
    final off = (1 - k) * 0.5 * 255;
    await ctx.transformArtwork((canvas, src) {
      final cf = ui.ColorFilter.matrix(<double>[
        lr * k, lg * k, lb * k, 0, off,
        lr * k, lg * k, lb * k, 0, off,
        lr * k, lg * k, lb * k, 0, off,
        0, 0, 0, 1, 0,
      ]);
      canvas.drawImage(src, ui.Offset.zero, ui.Paint()..colorFilter = cf);
    });
    final mask =
        await EffectTextures.speckle(ctx.width, ctx.height, seed ^ 0x50, a * 0.3);
    await ctx.transformArtwork((canvas, src) {
      canvas.drawImage(src, ui.Offset.zero, ui.Paint());
      canvas.drawImage(
          mask, ui.Offset.zero, ui.Paint()..blendMode = ui.BlendMode.dstOut);
    });
  }

  /// Newsprint: monochrome the artwork, re-screen it as a coarse dot grid
  /// (reusing the halftone screen) and warm it toward newsprint paper.
  Future<void> _newsprint(RenderContext ctx, double amount) async {
    final a = amount.clamp(0.0, 1.0);
    const lr = 0.299, lg = 0.587, lb = 0.114;
    await ctx.transformArtwork((canvas, src) {
      final cf = ui.ColorFilter.matrix(<double>[
        lr, lg, lb, 0, 0,
        lr, lg, lb, 0, 0,
        lr, lg, lb, 0, 0,
        0, 0, 0, 1, 0,
      ]);
      canvas.drawImage(src, ui.Offset.zero, ui.Paint()..colorFilter = cf);
    });
    await _halftone(ctx, a, 0.5, 15); // coarse, angled screen
    await ctx.transformArtwork((canvas, src) {
      final t = a;
      final cf = ui.ColorFilter.matrix(<double>[
        1, 0, 0, 0, 8 * t,
        0, 1, 0, 0, 4 * t,
        0, 0, 1, 0, -6 * t,
        0, 0, 0, 1, 0,
      ]);
      canvas.drawImage(src, ui.Offset.zero, ui.Paint()..colorFilter = cf);
    });
  }

  /// Riso: two misregistered duotone ink passes (pink + blue), each mapping
  /// artwork luminance to that ink over paper-white, offset in opposite
  /// directions and multiply-blended, then grained. The classic risograph look.
  Future<void> _riso(RenderContext ctx, int seed, double amount) async {
    final a = amount.clamp(0.0, 1.0);
    final off = 2 + a * 4;

    // out = ink + ((255-ink)/255)*luminance → white where light, ink where dark.
    ui.ColorFilter ink(int r, int g, int b) {
      const lr = 0.299, lg = 0.587, lb = 0.114;
      final kr = (255 - r) / 255, kg = (255 - g) / 255, kb = (255 - b) / 255;
      return ui.ColorFilter.matrix(<double>[
        kr * lr, kr * lg, kr * lb, 0, r.toDouble(),
        kg * lr, kg * lg, kg * lb, 0, g.toDouble(),
        kb * lr, kb * lg, kb * lb, 0, b.toDouble(),
        0, 0, 0, 1, 0,
      ]);
    }

    await ctx.transformArtwork((canvas, src) {
      canvas.saveLayer(
          ctx.fullRect, ui.Paint()..color = ui.Color.fromRGBO(0, 0, 0, a));
      // Pink ink, shifted one way.
      canvas.drawImage(
          src,
          ui.Offset(-off, 0),
          ui.Paint()
            ..colorFilter = ink(0xEC, 0x40, 0x89)
            ..blendMode = ui.BlendMode.multiply);
      // Blue ink, shifted the other.
      canvas.drawImage(
          src,
          ui.Offset(off, off * 0.5),
          ui.Paint()
            ..colorFilter = ink(0x24, 0x51, 0xB5)
            ..blendMode = ui.BlendMode.multiply);
      // Keep the wash inside the artwork silhouette, then blend over the base.
      canvas.drawImage(
          src, ui.Offset.zero, ui.Paint()..blendMode = ui.BlendMode.dstIn);
      canvas.restore();
    });

    final noise = await EffectTextures.grain(ctx.width, ctx.height, seed ^ 0x21);
    await ctx.transformArtwork((canvas, src) {
      canvas.drawImage(src, ui.Offset.zero, ui.Paint());
      canvas.saveLayer(
          ctx.fullRect,
          ui.Paint()
            ..blendMode = ui.BlendMode.softLight
            ..color = ui.Color.fromRGBO(0, 0, 0, a * 0.5));
      canvas.drawImage(noise, ui.Offset.zero, ui.Paint());
      canvas.drawImage(
          src, ui.Offset.zero, ui.Paint()..blendMode = ui.BlendMode.dstIn);
      canvas.restore();
    });
  }

  /// Tie-dye: a psychedelic concentric-rainbow colour field, drawn as nested
  /// off-centre rings (the classic "bullseye" bleed with a swirl wobble) and
  /// blended `overlay` over the artwork so the flag's structure shows through the
  /// colour. Restricted to artwork alpha. Deterministic from [seed].
  Future<void> _tieDye(RenderContext ctx, int seed, double amount) async {
    final w = ctx.width.toDouble();
    final h = ctx.height.toDouble();
    final rng = DeterministicRng(seed).stream('tiedye');

    // Ring geometry: cover the diagonal so corners are filled.
    final cx = w * (0.42 + rng.nextDouble() * 0.16);
    final cy = h * (0.42 + rng.nextDouble() * 0.16);
    final maxR = math.sqrt(w * w + h * h);
    final step = (math.min(w, h) / 14).clamp(6.0, 60.0);
    final hue0 = rng.nextDouble() * 360;
    final hueStep = 14.0 + rng.nextDouble() * 14.0; // colour bands per ring
    final wobble = step * (0.7 + rng.nextDouble() * 0.8); // swirl offset radius
    final wobbleTurn = 0.5 + rng.nextDouble() * 0.6; // radians per ring
    final sat = 0.85 + rng.nextDouble() * 0.15;

    final field = await ctx.rasterise((canvas) {
      final ringCount = (maxR / step).ceil() + 1;
      final paint = ui.Paint()..isAntiAlias = true;
      // Largest ring first; each subsequent (smaller) circle paints over it.
      for (var i = ringCount; i >= 0; i--) {
        final r = i * step + (rng.nextDouble() - 0.5) * step * 0.35;
        if (r <= 0) continue;
        final ang = i * wobbleTurn;
        final ox = cx + math.cos(ang) * wobble * (i / ringCount);
        final oy = cy + math.sin(ang) * wobble * (i / ringCount);
        final hue = (hue0 + i * hueStep) % 360;
        paint.color = _hsv(hue, sat, 0.96);
        canvas.drawCircle(ui.Offset(ox, oy), r, paint);
      }
    });

    await ctx.transformArtwork((canvas, src) {
      canvas.drawImage(src, ui.Offset.zero, ui.Paint());
      canvas.saveLayer(
          ctx.fullRect,
          ui.Paint()
            ..blendMode = ui.BlendMode.overlay
            ..color = ui.Color.fromRGBO(0, 0, 0, amount.clamp(0.0, 1.0)));
      canvas.drawImage(field, ui.Offset.zero, ui.Paint());
      // Restrict the wash to where the artwork exists.
      canvas.drawImage(
          src, ui.Offset.zero, ui.Paint()..blendMode = ui.BlendMode.dstIn);
      canvas.restore();
    });
  }

  /// HSV→RGB (h in degrees, s/v in 0..1) → opaque [ui.Color]. Local so the
  /// render layer needn't depend on flutter/painting's HSVColor.
  ui.Color _hsv(double h, double s, double v) {
    final c = v * s;
    final hh = (h % 360) / 60.0;
    final x = c * (1 - (hh % 2 - 1).abs());
    final m = v - c;
    double r = 0, g = 0, b = 0;
    if (hh < 1) {
      r = c; g = x;
    } else if (hh < 2) {
      r = x; g = c;
    } else if (hh < 3) {
      g = c; b = x;
    } else if (hh < 4) {
      g = x; b = c;
    } else if (hh < 5) {
      r = x; b = c;
    } else {
      r = c; b = x;
    }
    return ui.Color.fromARGB(
      255,
      ((r + m) * 255).round().clamp(0, 255),
      ((g + m) * 255).round().clamp(0, 255),
      ((b + m) * 255).round().clamp(0, 255),
    );
  }

  /// Shatter / explosion: an inverse **polar warp** that blows the artwork into
  /// sharp zigzag shards radiating from a centre. For each destination pixel we
  /// sample the source at a radius modulated by a triangle wave of the angle
  /// (plus a little per-arm jitter), so alternating angular wedges push in/out —
  /// giving radial shards and a spiky, torn silhouette where shards fling off
  /// the canvas. Deterministic from [seed]. This is the signature "extreme" look.
  Future<void> _shatter(
      RenderContext ctx, int seed, double amount, double spikesKnob) async {
    final src = ctx.artwork!;
    final bytes = await src.toByteData();
    if (bytes == null) return;
    final data = bytes.buffer.asUint8List();
    final w = ctx.width, h = ctx.height;
    final rng = DeterministicRng(seed).stream('shatter');
    final amp = amount.clamp(0.0, 1.0);
    final spikes = (14 + spikesKnob.clamp(0.0, 1.0) * 26).round().clamp(6, 48);
    // Centre near the middle, nudged for asymmetry.
    final cx = w * (0.5 + (rng.nextDouble() - 0.5) * 0.14);
    final cy = h * (0.5 + (rng.nextDouble() - 0.5) * 0.14);
    final phase = rng.nextDouble() * 2 * math.pi;
    // Small per-arm radius jitter so shards aren't perfectly regular.
    final jitter = <double>[for (var i = 0; i < spikes; i++) rng.nextRange(-0.12, 0.12)];

    final out = Uint8List(w * h * 4);
    const twoPi = 2 * math.pi;
    for (var y = 0; y < h; y++) {
      final dy = y - cy;
      for (var x = 0; x < w; x++) {
        final dx = x - cx;
        final r = math.sqrt(dx * dx + dy * dy);
        final ang = math.atan2(dy, dx) + phase;
        // Triangle wave over [spikes] arms → sharp zigzag (−1..1).
        final t = (ang / twoPi * spikes) % spikes;
        final tf = t - t.floorToDouble();
        final tri = (tf < 0.5 ? tf * 2 : (1 - tf) * 2) * 2 - 1;
        final arm = jitter[t.floor() % spikes];
        // Inverse warp: displace the sampled radius along the same angle. Kept
        // moderate so shards stay part of the flag body (jagged zigzag bands +
        // a spiky silhouette) rather than flying off into thin rays.
        final srcR = r * (1 + amp * (0.30 * tri + 0.10 * arm));
        final a = ang - phase;
        final sx = cx + srcR * math.cos(a);
        final sy = cy + srcR * math.sin(a);
        final di = (y * w + x) * 4;
        if (sx < 0 || sx >= w || sy < 0 || sy >= h) {
          out[di] = 0; out[di + 1] = 0; out[di + 2] = 0; out[di + 3] = 0;
          continue;
        }
        final si = (sy.toInt() * w + sx.toInt()) * 4;
        out[di] = data[si];
        out[di + 1] = data[si + 1];
        out[di + 2] = data[si + 2];
        out[di + 3] = data[si + 3];
      }
    }

    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(out, w, h, ui.PixelFormat.rgba8888, completer.complete);
    ctx.artwork = await completer.future;
  }

  /// Ripple / displacement: shift horizontal strips of the artwork by a sine
  /// wave, giving a wavy fabric-in-motion look. CPU (per-strip `drawImageRect`)
  /// so it's deterministic and headless; the fragment-shader path can supersede
  /// it later for smoother per-pixel warp.
  Future<void> _ripple(RenderContext ctx, double amp, double freq) async {
    final w = ctx.width.toDouble();
    final h = ctx.height.toDouble();
    const strips = 120;
    final stripH = h / strips;
    final ampPx = amp.clamp(0.0, 1.0) * w * 0.09;
    await ctx.transformArtwork((canvas, src) {
      for (var i = 0; i < strips; i++) {
        final y = i * stripH;
        final dx = ampPx * math.sin(2 * math.pi * freq * (y / h));
        final srcRect = ui.Rect.fromLTWH(0, y, w, stripH + 1);
        final dstRect = ui.Rect.fromLTWH(dx, y, w, stripH + 1);
        canvas.drawImageRect(src, srcRect, dstRect, ui.Paint());
      }
    });
  }

  /// Halftone: re-screen the artwork as a rotated grid of coloured dots — the
  /// classic pop-art / screen-print look. Follows real print-halftone theory
  /// (angled dot screen, dot AREA proportional to ink coverage, paper showing
  /// in the gaps) rather than a naive darkness screen:
  ///  * the grid is **rotated** by [angleDeg] (a real screen is angled ~15°);
  ///  * each dot samples the **average colour of its cell** — averaging only the
  ///    OPAQUE samples so dots on the artwork edge take the artwork's colour, not
  ///    a muddy grey mixed with the transparent background;
  ///  * dot SIZE follows **ink demand = darkness + saturation** (not pure
  ///    luminance) so vivid *bright* colours (yellow!) still print big dots
  ///    instead of vanishing; only true white / near-transparent leaves a gap.
  ///    Area ∝ coverage (radius ∝ √coverage), and at full coverage the radius
  ///    reaches the cell's half-diagonal so solid fields print solid;
  ///  * a mild contrast curve separates mid-tones so the screen reads cleanly;
  ///  * the gaps between dots are left transparent — that IS the "paper" (the
  ///    garment shows through), exactly like a real screen print.
  ///
  /// Partial [amount] (<1) is NOT a translucent overlay on the solid artwork
  /// (which would hide interior dots and leave only an edge fringe). Instead the
  /// screen re-covers the WHOLE artwork at every strength: lowering [amount]
  /// grows each dot's coverage toward solid, so the dot texture stays visible
  /// everywhere and smoothly fills back to the un-screened artwork as amount→0.
  Future<void> _halftone(
      RenderContext ctx, double amount, double scale, double angleDeg) async {
    final src = ctx.artwork!;
    final bytes = await src.toByteData();
    if (bytes == null) return;
    final data = bytes.buffer.asUint8List();
    final w = ctx.width, h = ctx.height;
    final pitch = (w / (8 + scale * 3)).clamp(3.0, 40.0);
    final rad = angleDeg * math.pi / 180;
    final cos = math.cos(rad), sin = math.sin(rad);
    final amt = amount.clamp(0.0, 1.0);

    // Average an (up to) 3×3 cluster of samples around a cell centre.
    // Average only the OPAQUE samples in the cell, so dots straddling the
    // artwork edge take the artwork's colour (not a grey mix with the
    // transparent background). Returns a=0 when the cell is mostly empty.
    ({int r, int g, int b, int a}) sampleCell(double cx, double cy) {
      var sr = 0, sg = 0, sb = 0, opaque = 0, total = 0;
      final step = (pitch / 3).clamp(1.0, 8.0);
      for (var oy = -1; oy <= 1; oy++) {
        for (var ox = -1; ox <= 1; ox++) {
          final px = (cx + ox * step).round().clamp(0, w - 1);
          final py = (cy + oy * step).round().clamp(0, h - 1);
          final i = (py * w + px) * 4;
          total++;
          if (data[i + 3] < 40) continue;
          sr += data[i]; sg += data[i + 1]; sb += data[i + 2]; opaque++;
        }
      }
      if (opaque == 0) return (r: 0, g: 0, b: 0, a: 0);
      // Fade the dot out only when the cell is mostly transparent (soft edge).
      final a = opaque >= (total + 1) ~/ 2 ? 255 : (255 * opaque ~/ total);
      return (r: sr ~/ opaque, g: sg ~/ opaque, b: sb ~/ opaque, a: a);
    }

    // Max radius reaches the cell's half-diagonal, so a full-coverage cell's dot
    // covers its whole cell (incl. corners) and neighbours merge into a solid.
    final maxRadius = pitch * 0.72;

    ctx.artwork = await ctx.rasterise((canvas) {
      final paint = ui.Paint()..isAntiAlias = true;
      // Walk the grid in rotated (u,v) space so the screen sits at [angleDeg].
      // Project the four image corners to bound the iteration.
      double u(double x, double y) => x * cos + y * sin;
      double v(double x, double y) => -x * sin + y * cos;
      final us = [u(0, 0), u(w * 1.0, 0), u(0, h * 1.0), u(w * 1.0, h * 1.0)];
      final vs = [v(0, 0), v(w * 1.0, 0), v(0, h * 1.0), v(w * 1.0, h * 1.0)];
      final iMin = (us.reduce(math.min) / pitch).floor() - 1;
      final iMax = (us.reduce(math.max) / pitch).ceil() + 1;
      final jMin = (vs.reduce(math.min) / pitch).floor() - 1;
      final jMax = (vs.reduce(math.max) / pitch).ceil() + 1;
      for (var i = iMin; i <= iMax; i++) {
        for (var j = jMin; j <= jMax; j++) {
          final uu = i * pitch, vv = j * pitch;
          // Rotate back to image space.
          final cx = uu * cos - vv * sin, cy = uu * sin + vv * cos;
          if (cx < 0 || cx >= w || cy < 0 || cy >= h) continue;
          final c = sampleCell(cx, cy);
          if (c.a < 20) continue;
          final r = c.r, g = c.g, b = c.b;
          final maxc = math.max(r, math.max(g, b));
          final minc = math.min(r, math.min(g, b));
          final lum = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0;
          final sat = maxc <= 0 ? 0.0 : (maxc - minc) / maxc;
          // Ink demand: dark colours AND vivid (saturated) colours print big
          // dots; only near-white/desaturated-light areas leave gaps.
          var coverage = ((1 - lum) * 0.8 + sat * 0.55).clamp(0.0, 1.0);
          // Mild contrast curve: push mid-tones apart so the screen reads
          // cleanly (dark cells nearly solid, light cells crisp small dots).
          coverage = _contrast(coverage, 1.25);
          // Partial strength re-screens the WHOLE area: shrink the amount of
          // "paper" (1-coverage) so lower amounts grow the dots back toward a
          // solid fill of the original artwork. At amount==1 → true tonal dots;
          // at amount→0 → coverage→1 everywhere → the un-screened artwork.
          final eff = 1.0 - amt * (1.0 - coverage);
          final radius = maxRadius * math.sqrt(eff);
          if (radius < 0.35) continue;
          paint.color = ui.Color.fromARGB(c.a, r, g, b);
          canvas.drawCircle(ui.Offset(cx, cy), radius, paint);
        }
      }
    });
  }

  /// Contrast curve around 0.5 with strength [k] (k>1 steepens). Keeps 0→0 and
  /// 1→1, pushing mid-tones toward the extremes for a punchier dot screen.
  double _contrast(double x, double k) {
    final t = (x.clamp(0.0, 1.0) - 0.5) * k + 0.5;
    return t.clamp(0.0, 1.0);
  }
}
