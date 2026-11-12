import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:design_forge/design_forge.dart';

import '../geometry/torn_strips_raster.dart';
import 'render_stage.dart';

/// Composition for [DesignFamily.portraitTornFlag]: the recipe's first flag,
/// turned to portrait and torn into ragged strips by [TornStripsRaster].
///
/// The flag is rasterised by the asset resolver at exactly the rotated size
/// (so it is sampled 1:1, never resampled), then the strip geometry, distress
/// and ink colour are computed on the CPU — off the UI isolate — and decoded
/// back into the artwork layer.
class TornFlagLayout {
  const TornFlagLayout._();

  static bool handles(DesignFamily family) =>
      family == DesignFamily.portraitTornFlag;

  static Future<void> build(DesignRecipe recipe, RenderContext ctx) async {
    final flags = recipe.content.flags;
    if (flags.isEmpty) return;
    final params = recipe.tornStrips ?? const TornStrips();

    // Probe the flag's native aspect, then rasterise it so its WIDTH (its
    // hoist, across the portrait) is exactly the rotated flag's width — the
    // length is stretched by the rasteriser when flagAspect overrides it.
    // Alternative artwork (e.g. `official/us`, true 1.9:1 proportions) when the
    // recipe asks for it and the asset exists; else the standard flag.
    var code = flags.first.code;
    final variant = params.flagVariant;
    if (variant != null && variant.isNotEmpty) {
      try {
        await ctx.assets.resolveFlag('$variant/$code', width: 64, height: 64);
        code = '$variant/$code';
      } catch (_) {
        // No such artwork: keep the standard flag.
      }
    }
    final probe = await ctx.assets.resolveFlag(code, width: 512, height: 512);
    final native = probe.width / probe.height;
    final aspect = params.flagAspect > 0 ? params.flagAspect : native;
    final length =
        TornStripsRaster.flagLengthFor(ctx.width, ctx.height, aspect, params);
    final across = (length / aspect).round();
    final flag = await ctx.assets
        .resolveFlag(code, width: length * 8, height: across);
    final bytes = await flag.toByteData(format: ui.ImageByteFormat.rawRgba);
    final flagRgba = bytes!.buffer.asUint8List();

    final job = _Job(
      flagRgba: flagRgba,
      flagW: flag.width,
      flagH: flag.height,
      lengthPx: length,
      canvasW: ctx.width,
      canvasH: ctx.height,
      params: params,
      seed: recipe.seed,
    );
    final pixels = await Isolate.run(job.run);
    ctx.artwork = await _decode(pixels, ctx.width, ctx.height);
  }

  static Future<ui.Image> _decode(Uint8List rgba, int w, int h) {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
        rgba, w, h, ui.PixelFormat.rgba8888, completer.complete);
    return completer.future;
  }
}

/// The isolate payload: plain data only.
class _Job {
  const _Job({
    required this.flagRgba,
    required this.flagW,
    required this.flagH,
    required this.lengthPx,
    required this.canvasW,
    required this.canvasH,
    required this.params,
    required this.seed,
  });

  final Uint8List flagRgba;
  final int flagW, flagH, lengthPx, canvasW, canvasH;
  final TornStrips params;
  final int seed;

  Uint8List run() => const TornStripsRaster().render(
        flagRgba: flagRgba,
        flagW: flagW,
        flagH: flagH,
        lengthPx: lengthPx,
        canvasW: canvasW,
        canvasH: canvasH,
        params: params,
        seed: seed,
      );
}
