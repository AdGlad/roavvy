import 'dart:ui' as ui;

import 'package:design_forge/design_forge.dart';
import 'package:design_forge_render/design_forge_render.dart';
import 'package:flutter_test/flutter_test.dart';

/// A Passport design must render as passport stamps even when the host has no
/// stamp artwork for the selected countries. This resolver supplies flags (so
/// there IS artwork to degrade into) but no stamps at all — the exact shape of
/// the mobile bug. The [ClipStage] must then fall back to built-in stamp
/// geometry rather than leaving the flag composition untouched.
class _FlagsOnlyResolver implements AssetResolver {
  @override
  Future<ui.Image> resolveFlag(String code,
      {required int width, required int height}) {
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawRect(
      ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      ui.Paint()..color = const ui.Color(0xFFCC2244),
    );
    return recorder.endRecording().toImage(width, height);
  }

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const content = RecipeContent(
    flags: [FlagRef('au'), FlagRef('fr')],
    source: 'test:passport',
  );

  DesignRecipe recipe(Clip? clip) => DesignRecipe(
        seed: 3,
        content: content,
        composition: const Composition(family: DesignFamily.grid),
        clip: clip,
      );

  Future<String> render(WidgetTester tester, Clip? clip) async {
    late String hash;
    await tester.runAsync(() async {
      final renderer = CanvasRenderer(assets: _FlagsOnlyResolver());
      hash =
          (await renderer.render(recipe(clip), RenderTarget.preview(size: 220)))
              .imageHash;
    });
    return hash;
  }

  testWidgets('a passport page with no stamp artwork still renders stamps',
      (tester) async {
    final page = await render(
        tester,
        const Clip(
          shapeId: 'passportPage',
          code: 'au|12 MAR 24|28 MAR 24;fr|04 JUN 25|11 JUN 25',
          scatter: 0.5,
        ));
    expect(page, isNot(await render(tester, null)),
        reason: 'the passport page rendered as a plain flag print');
  });

  testWidgets('the built-in passport fallback is deterministic',
      (tester) async {
    const clip = Clip(
      shapeId: 'passportPage',
      code: 'au|12 MAR 24|28 MAR 24;gb|02 SEP 25|18 SEP 25',
      scatter: 0.5,
    );
    expect(await render(tester, clip), await render(tester, clip));
  });

  testWidgets('entry and exit stamps render differently (arrival vs departure)',
      (tester) async {
    final entry = await render(
        tester,
        const Clip(
            shapeId: 'passportStampOutline', code: 'au_entry|12 MAR 24'));
    final exit = await render(tester,
        const Clip(shapeId: 'passportStampOutline', code: 'au_exit|28 MAR 24'));
    final flat = await render(tester, null);
    expect(entry, isNot(flat));
    expect(exit, isNot(flat));
    expect(entry, isNot(exit));
  });

  testWidgets('the trip date is stamped onto the artwork', (tester) async {
    // Same country, same layout — only the trip dates differ, so any change in
    // the output is the date being drawn on the stamps. (The test font renders
    // every glyph identically, so compare dated vs undated rather than two
    // different dates.)
    final dated = await render(tester,
        const Clip(shapeId: 'passportPage', code: 'au|12 MAR 24|28 MAR 24'));
    final undated =
        await render(tester, const Clip(shapeId: 'passportPage', code: 'au'));
    expect(dated, isNot(undated));
  });
}
