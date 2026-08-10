import 'dart:ui' as ui;

import '../procedural/procedural_recipe.dart' show FlagCombination;

/// Abstraction over the GPU effect layer, so the rendering *technology* is
/// swappable behind one seam (see design_engine/docs/rendering-technology.md).
///
/// The default [SkiaEffectRenderer] runs Flutter fragment shaders on Impeller
/// (Metal on iOS, Vulkan/GLES on Android) — one code path, both platforms.
/// A native implementation (Core Image / AGSL) may be introduced later *behind
/// this same interface*, gated by measured benefit, always with the Skia path
/// as fallback. Every design is rendered through here at preview size (feed)
/// and print size (checkout), so preview == print.
abstract class EffectRenderer {
  /// Whether this renderer can run on the current device.
  bool get isAvailable;

  /// Merge [flagA] and [flagB] into a single `size`×`size` [ui.Image] using the
  /// GPU. Deterministic in its parameters (so the same recipe reproduces the
  /// same image). Caller owns the returned image (dispose when done).
  Future<ui.Image> blendFlags({
    required ui.Image flagA,
    required ui.Image flagB,
    required int size,
    double weightA,
    FlagCombination mode,
    double rippleAmp,
    double rippleFreq,
    int seed,
  });
}

/// Default cross-platform renderer: a single GLSL fragment shader compiled by
/// Impeller for every target. Load once with [load] (the program is reusable).
class SkiaEffectRenderer implements EffectRenderer {
  SkiaEffectRenderer._(this._program);

  final ui.FragmentProgram _program;

  static const String _assetKey = 'shaders/flag_blend.frag';

  /// Loads + compiles the shader program. Cheap to keep a single instance.
  static Future<SkiaEffectRenderer> load() async =>
      SkiaEffectRenderer._(await ui.FragmentProgram.fromAsset(_assetKey));

  @override
  bool get isAvailable => true; // Skia/Impeller is always present.

  @override
  Future<ui.Image> blendFlags({
    required ui.Image flagA,
    required ui.Image flagB,
    required int size,
    double weightA = 0.5,
    FlagCombination mode = FlagCombination.mix,
    double rippleAmp = 0.0,
    double rippleFreq = 3.0,
    int seed = 0,
  }) async {
    final shader = _program.fragmentShader();
    // Uniform indices must match the shader's declaration order.
    shader
      ..setFloat(0, size.toDouble()) // uSize.x
      ..setFloat(1, size.toDouble()) // uSize.y
      ..setFloat(2, weightA.clamp(0.0, 1.0))
      ..setFloat(3, mode.index.clamp(0, 3).toDouble())
      ..setFloat(4, rippleAmp)
      ..setFloat(5, rippleFreq)
      ..setFloat(6, (seed & 0xffff) / 65535.0)
      ..setImageSampler(0, flagA)
      ..setImageSampler(1, flagB);

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
      ui.Paint()..shader = shader,
    );
    final picture = recorder.endRecording();
    try {
      return await picture.toImage(size, size);
    } finally {
      picture.dispose();
    }
  }
}
