import 'dart:ui' as ui;

import 'package:design_forge/design_forge.dart';
import 'package:design_forge_render/design_forge_render.dart';
import 'package:design_studio/design_studio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/studio_v2/studio_v2_screen.dart';

/// Startup-runaway regression (M11). Proves the Studio V2 shell **settles** on
/// open and that idle rebuilds do NOT mint new recipes or trigger new render
/// work — the guard against the high-CPU/high-memory startup hang. It injects a
/// counting [RenderService] so every `imageFor` is observable without touching
/// the asset bundle, and a real [StudioController]/generator so the behaviour is
/// the production one.
class _NoopResolver implements AssetResolver {
  @override
  Future<ui.Image> resolveFlag(String code,
          {required int width, required int height}) =>
      throw UnimplementedError();
  @override
  Future<ui.Image?> resolveClipMask(ClipShape shape, String? code,
          {required int width, required int height}) async =>
      null;
  @override
  Future<ui.Image?> resolvePassportCollage(List<PassportStampRef> stamps,
          {required int width,
          required int height,
          int seed = 0,
          double scatter = 0.5,
          double stampScale = 1.0,
          PassportInk ink = PassportInk.flag}) async =>
      null;
}

/// A [RenderService] that never rasterises real assets: it counts every
/// `imageFor` call and the DISTINCT `recipeId@size` keys (what the real cache
/// would hold), returning a memoised 1×1 image so the preview resolves and the
/// tree can settle — exposing any idle render loop as a count that keeps rising.
class _CountingService extends RenderService {
  _CountingService() : super(_NoopResolver());

  int calls = 0;
  final Set<String> keys = {};
  ui.Image? _memo;

  @override
  Future<ui.Image> imageFor(DesignRecipe recipe, int longSide) async {
    calls++;
    keys.add('${recipe.recipeId}@$longSide');
    return _memo ??= await _onePx();
  }

  static Future<ui.Image> _onePx() {
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder);
    return recorder.endRecording().toImage(1, 1);
  }
}

StudioController _controller(_CountingService service) => StudioController(
      generator: LabShowcaseGenerator(
          silhouettesByShape: const {}, countryNames: const {}),
      service: service,
      designContext: const DesignContext(
          flagCodes: ['us', 'fr', 'jp'], scopeKey: 'test:idle'),
      initialSeed: 1,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<StudioController> pump(
    WidgetTester tester,
    _CountingService service,
  ) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final c = _controller(service);
    addTearDown(c.dispose);
    await tester.pumpWidget(MaterialApp(home: StudioV2Screen(controller: c)));
    return c;
  }

  testWidgets('the shell SETTLES on open (no startup runaway)', (tester) async {
    final service = _CountingService();
    await pump(tester, service);
    // A render loop would keep scheduling frames and time this out; a settled
    // shell completes it. The counting service resolves the preview immediately.
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
  });

  testWidgets('idle rebuilds mint no new recipe or render work', (tester) async {
    final service = _CountingService();
    final c = await pump(tester, service);
    await tester.pumpAndSettle(const Duration(milliseconds: 50));

    final idAtRest = c.current.recipeId;
    final callsAtRest = service.calls;
    final keysAtRest = service.keys.length;

    // Idle: pump many frames with NO user interaction.
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(c.current.recipeId, idAtRest, reason: 'recipe id drifted while idle');
    expect(service.calls, callsAtRest, reason: 'render calls grew while idle');
    expect(service.keys.length, keysAtRest,
        reason: 'distinct render keys (cache) grew while idle');
    // The Instant screen shows exactly one hero — one distinct render key.
    expect(keysAtRest, 1);
  });

  testWidgets('a pure stage change never re-renders the full-size hero',
      (tester) async {
    final service = _CountingService();
    final c = await pump(tester, service);
    await tester.pumpAndSettle(const Duration(milliseconds: 50));

    // The hero preview renders once, at its full 1024 long-side.
    final heroKey = '${c.current.recipeId}@1024';
    expect(service.keys, contains(heroKey));

    // Navigate across several stages. Workspaces may render their OWN on-demand
    // thumbnails (e.g. the Front mockup at 220px), but the persistent hero is
    // the same recipe, so it is served from cache — never rendered again.
    for (final stage in ['travels', 'front', 'fineTune', 'review']) {
      await tester.tap(find.byKey(Key('v2-stage-$stage')));
      await tester.pumpAndSettle(const Duration(milliseconds: 50));
    }

    // Exactly one full-size (@1024) hero render key ever exists.
    expect(service.keys.where((k) => k.endsWith('@1024')).length, 1,
        reason: 'the full-size hero was re-rendered by stage navigation');
  });
}
