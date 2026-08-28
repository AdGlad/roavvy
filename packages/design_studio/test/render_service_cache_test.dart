import 'dart:ui' as ui;

import 'package:design_forge/design_forge.dart';
import 'package:design_forge_render/design_forge_render.dart';
import 'package:design_studio/design_studio.dart';
import 'package:flutter_test/flutter_test.dart';

/// [RenderService] cache is **bounded** — the guard against the Studio V2
/// high-memory runaway (a live Fine-Tune slider drag mints a distinct recipe,
/// and a full-resolution render, on every tick). Over a long session the cache
/// must not grow without limit. This exercises the real renderer with a trivial
/// 1×1 asset resolver so many distinct recipes actually rasterise and populate
/// the cache.
class _TinyResolver implements AssetResolver {
  ui.Image? _px;

  Future<ui.Image> _onePx() async {
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder);
    return _px ??= await recorder.endRecording().toImage(1, 1);
  }

  @override
  Future<ui.Image> resolveFlag(String code,
          {required int width, required int height}) =>
      _onePx();
  @override
  Future<ui.Image?> resolveClipMask(ClipShape shape, String? code,
          {required int width, required int height}) async =>
      _onePx();
  @override
  Future<ui.Image?> resolvePassportCollage(List<PassportStampRef> stamps,
          {required int width,
          required int height,
          int seed = 0,
          double scatter = 0.5,
          double stampScale = 1.0,
          PassportInk ink = PassportInk.flag}) async =>
      _onePx();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('imageFor never grows the cache past maxCacheEntries', () async {
    final service = RenderService(_TinyResolver());
    final generator =
        LabShowcaseGenerator(silhouettesByShape: const {}, countryNames: const {});
    const context =
        DesignContext(flagCodes: ['us', 'fr', 'jp'], scopeKey: 'test:cache');

    // Render many DISTINCT recipes (different seeds → different recipeIds),
    // far more than the cap, at a small long-side to keep rasterisation cheap.
    final n = RenderService.maxCacheEntries * 2;
    final seen = <String>{};
    for (var i = 0; i < n; i++) {
      final recipe = generator.generate(context, seed: 1000 + i, count: 1).first;
      seen.add('${recipe.recipeId}@16');
      await service.imageFor(recipe, 16);
      expect(service.cacheSize, lessThanOrEqualTo(RenderService.maxCacheEntries),
          reason: 'cache exceeded its bound mid-session');
    }

    // Enough distinct recipes were produced to force eviction, and the cache
    // settled exactly at the cap.
    expect(seen.length, greaterThan(RenderService.maxCacheEntries));
    expect(service.cacheSize, RenderService.maxCacheEntries);
  });

  test('a cache hit is served without a new render and is LRU-touched',
      () async {
    final service = RenderService(_TinyResolver());
    final generator =
        LabShowcaseGenerator(silhouettesByShape: const {}, countryNames: const {});
    const context =
        DesignContext(flagCodes: ['us'], scopeKey: 'test:hit');
    final recipe = generator.generate(context, seed: 7, count: 1).first;

    final a = await service.imageFor(recipe, 16);
    final b = await service.imageFor(recipe, 16); // same key → cache hit
    expect(identical(a, b), isTrue);
    expect(service.cacheSize, 1);
  });
}
