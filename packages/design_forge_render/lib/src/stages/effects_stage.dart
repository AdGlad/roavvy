import 'dart:math' as math;
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
    if (fx.rippleAmp > 0) {
      await _ripple(ctx, fx.rippleAmp, fx.rippleFreq);
    }
    if (fx.tieDye > 0) {
      await _tieDye(ctx, seed, fx.tieDye);
    }
    if (fx.halftone > 0) {
      await _halftone(ctx, fx.halftone, fx.halftoneScale);
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

  /// Halftone: replace the artwork with a dot screen whose dot size tracks local
  /// darkness. A recognisable print-halftone; dot pitch from [scale].
  Future<void> _halftone(RenderContext ctx, double amount, double scale) async {
    final src = ctx.artwork!;
    final bytes = await src.toByteData();
    if (bytes == null) return;
    final data = bytes.buffer.asUint8List();
    final w = ctx.width, h = ctx.height;
    final pitch = (w / (8 + scale * 3)).clamp(3.0, 40.0);

    ctx.artwork = await ctx.rasterise((canvas) {
      final paint = ui.Paint()..isAntiAlias = true;
      for (var cy = pitch / 2; cy < h; cy += pitch) {
        for (var cx = pitch / 2; cx < w; cx += pitch) {
          final px = cx.floor().clamp(0, w - 1);
          final py = cy.floor().clamp(0, h - 1);
          final i = (py * w + px) * 4;
          final alpha = data[i + 3];
          if (alpha < 20) continue;
          final r = data[i], g = data[i + 1], b = data[i + 2];
          final lum = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0;
          // Darker → bigger dot.
          final coverage = (1 - lum);
          final radius = (pitch * 0.62) * math.sqrt(coverage.clamp(0.0, 1.0));
          if (radius < 0.4) continue;
          paint.color = ui.Color.fromARGB(alpha, r, g, b);
          canvas.drawCircle(ui.Offset(cx, cy), radius, paint);
        }
      }
    });

    // Blend the halftone back over the original by [amount] (1 = full halftone).
    if (amount < 1.0) {
      final dots = ctx.artwork!;
      ctx.artwork = await ctx.rasterise((canvas) {
        canvas.drawImage(src, ui.Offset.zero, ui.Paint());
        canvas.drawImage(dots, ui.Offset.zero,
            ui.Paint()..color = ui.Color.fromRGBO(0, 0, 0, amount.clamp(0.0, 1.0)));
      });
    }
  }
}
