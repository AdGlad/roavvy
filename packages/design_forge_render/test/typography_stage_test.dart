import 'dart:io';
import 'dart:ui' as ui;

import 'package:design_forge/design_forge.dart';
import 'package:design_forge_render/design_forge_render.dart';
import 'package:design_forge_render/src/stages/typography_stage.dart';
import 'package:flutter_test/flutter_test.dart';

final String _flagDir =
    Directory('../../apps/mobile_flutter/assets/flags/svg').absolute.path;
SvgFlagResolver _resolver() =>
    SvgFlagResolver((code) => File('$_flagDir/$code.svg').readAsString());

const _bg = ui.Color(0xFFF2F2F2);

DesignRecipe _base({Typography? typography}) => DesignRecipe(
      seed: 21,
      content: const RecipeContent(
        flags: [FlagRef('us')],
        meta: {'title': 'Japan Trip'},
      ),
      composition: const Composition(family: DesignFamily.singleHero),
      typography: typography,
    );

/// Count of pixels that differ between two images inside a vertical band
/// [y0..y1) (fractions of height).
Future<int> _bandDiff(ui.Image a, ui.Image b, double y0, double y1) async {
  final da = (await a.toByteData())!.buffer.asUint8List();
  final db = (await b.toByteData())!.buffer.asUint8List();
  final w = a.width, h = a.height;
  final r0 = (h * y0).floor(), r1 = (h * y1).ceil();
  var n = 0;
  for (var y = r0; y < r1; y++) {
    for (var x = 0; x < w; x++) {
      final i = (y * w + x) * 4;
      if (da[i] != db[i] || da[i + 1] != db[i + 1] || da[i + 2] != db[i + 2]) {
        n++;
      }
    }
  }
  return n;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TypographyStage.transformCase', () {
    test('applies upper / lower / title / asIs', () {
      expect(TypographyStage.transformCase('japan trip', TextCase.upper),
          'JAPAN TRIP');
      expect(TypographyStage.transformCase('Japan TRIP', TextCase.lower),
          'japan trip');
      expect(TypographyStage.transformCase('japan trip', TextCase.title),
          'Japan Trip');
      expect(TypographyStage.transformCase('jApAn TRIP', TextCase.asIs),
          'jApAn TRIP');
    });

    test('title case preserves inter-word spacing', () {
      expect(TypographyStage.transformCase('a  b', TextCase.title), 'A  B');
    });
  });

  group('TypographyStage render', () {
    testWidgets('title + placement:top draws a non-blank overlay in the band',
        (tester) async {
      await tester.runAsync(() async {
        final r = CanvasRenderer(assets: _resolver());
        final baseline = await r.render(
            _base(), RenderTarget.preview(size: 256, background: _bg));
        final withTitle = await r.render(
            _base(
                typography: const Typography(
                    placement: TextPlacement.top, textCase: TextCase.upper)),
            RenderTarget.preview(size: 256, background: _bg));

        // Overlay must change the image overall...
        expect(withTitle.imageHash, isNot(baseline.imageHash),
            reason: 'a title overlay must alter the output');
        // ...specifically in the TOP band where it is placed...
        final topDiff =
            await _bandDiff(baseline.image, withTitle.image, 0.04, 0.24);
        expect(topDiff, greaterThan(50),
            reason: 'the top band must contain the rendered title');
        // ...and leave the bottom band untouched.
        final bottomDiff =
            await _bandDiff(baseline.image, withTitle.image, 0.5, 1.0);
        expect(bottomDiff, 0,
            reason: 'top placement must not touch the bottom of the frame');
      });
    });

    testWidgets('placement:bottom draws in the bottom band, not the top',
        (tester) async {
      await tester.runAsync(() async {
        final r = CanvasRenderer(assets: _resolver());
        final baseline = await r.render(
            _base(), RenderTarget.preview(size: 256, background: _bg));
        final withTitle = await r.render(
            _base(typography: const Typography(placement: TextPlacement.bottom)),
            RenderTarget.preview(size: 256, background: _bg));
        final bottomDiff =
            await _bandDiff(baseline.image, withTitle.image, 0.76, 0.96);
        final topDiff =
            await _bandDiff(baseline.image, withTitle.image, 0.0, 0.2);
        expect(bottomDiff, greaterThan(50),
            reason: 'the bottom band must contain the rendered title');
        expect(topDiff, 0,
            reason: 'bottom placement must not touch the top of the frame');
      });
    });

    testWidgets('placement:none is byte-identical to no typography',
        (tester) async {
      await tester.runAsync(() async {
        final r = CanvasRenderer(assets: _resolver());
        final baseline = await r.render(
            _base(), RenderTarget.preview(size: 256, background: _bg));
        final none = await r.render(
            _base(typography: const Typography(placement: TextPlacement.none)),
            RenderTarget.preview(size: 256, background: _bg));
        expect(none.imageHash, baseline.imageHash);
      });
    });

    testWidgets('typography with no meta title → no overlay', (tester) async {
      await tester.runAsync(() async {
        final r = CanvasRenderer(assets: _resolver());
        // No 'title' key in meta.
        const content = RecipeContent(flags: [FlagRef('us')]);
        const family = Composition(family: DesignFamily.singleHero);
        final noTypo = await r.render(
            const DesignRecipe(seed: 21, content: content, composition: family),
            RenderTarget.preview(size: 256, background: _bg));
        final typoNoTitle = await r.render(
            const DesignRecipe(
                seed: 21,
                content: content,
                composition: family,
                typography: Typography(placement: TextPlacement.top)),
            RenderTarget.preview(size: 256, background: _bg));
        expect(typoNoTitle.imageHash, noTypo.imageHash,
            reason: 'typography with no meta title must draw nothing');
      });
    });
  });
}
