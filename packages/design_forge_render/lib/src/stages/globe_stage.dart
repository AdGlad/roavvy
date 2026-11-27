import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:design_forge/design_forge.dart';

import '../geometry/globe_raster.dart';
import 'render_stage.dart';

/// Wraps the flag onto a ball when the recipe asks for it
/// ([DesignRecipe.globe]); a no-op otherwise. Runs right after composition
/// (which covers the frame with the flag under a clip) and before the clip,
/// so the ball's radius is the clip's: half the frame's short side × the
/// clip scale. Sparkle stars are drawn over the ball afterwards.
class GlobeStage extends RenderStage {
  const GlobeStage();

  @override
  String get id => 'globe';

  @override
  Future<void> apply(DesignRecipe recipe, RenderContext ctx) async {
    final g = recipe.globe;
    final art = ctx.artwork;
    if (g == null || art == null) return;
    final w = art.width, h = art.height;
    final cx = w / 2, cy = h / 2;
    final r = math.min(w, h) / 2 * (recipe.clip?.scale ?? 0.92);
    final data = await art.toByteData(format: ui.ImageByteFormat.rawRgba);
    final bytes = data!.buffer.asUint8List();
    final out = await Isolate.run(() => GlobeRaster.paint(bytes, w, h, g, cx, cy, r));
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(out, w, h, ui.PixelFormat.rgba8888, completer.complete);
    final ball = await completer.future;
    if (g.sparkles <= 0) {
      ctx.artwork = ball;
      return;
    }
    // Faint sparkle stars over the sphere (inside the rim).
    final rs = r * (1 - g.rim.clamp(0.0, 0.3));
    final rng = DeterministicRng(recipe.seed).stream('globe:sparkles');
    final count = (g.sparkles.clamp(0.0, 1.0) * 30).round();
    ctx.artwork = await ctx.rasterise((canvas) {
      canvas.drawImage(ball, ui.Offset.zero, ui.Paint());
      canvas.save();
      canvas.clipPath(ui.Path()
        ..addOval(ui.Rect.fromCircle(center: ui.Offset(cx, cy), radius: rs)));
      for (var k = 0; k < count; k++) {
        final ang = rng.nextDouble() * math.pi * 2;
        final dist = math.sqrt(rng.nextDouble()) * rs * 0.95;
        final size = r * (0.035 + 0.075 * math.pow(rng.nextDouble(), 1.6));
        final alpha = 0.12 + 0.2 * rng.nextDouble();
        canvas.drawPath(
          _star(cx + math.cos(ang) * dist, cy + math.sin(ang) * dist, size,
              rng.nextDouble() * math.pi),
          ui.Paint()..color = ui.Color.fromRGBO(255, 255, 255, alpha),
        );
      }
      canvas.restore();
    });
  }

  static ui.Path _star(double x, double y, double r, double rot) {
    final p = ui.Path();
    for (var k = 0; k < 10; k++) {
      final rad = k.isEven ? r : r * 0.42;
      final a = rot - math.pi / 2 + k * math.pi / 5;
      final px = x + math.cos(a) * rad, py = y + math.sin(a) * rad;
      if (k == 0) {
        p.moveTo(px, py);
      } else {
        p.lineTo(px, py);
      }
    }
    return p..close();
  }
}
