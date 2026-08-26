import 'dart:io';
import 'dart:ui' as ui;

import 'package:design_forge/design_forge.dart';
import 'package:design_forge_render/design_forge_render.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records the stamp list handed to the passport collage so a test can assert
/// how `stampMode` filters it, without needing real stamp assets.
class _RecordingResolver extends SvgFlagResolver {
  _RecordingResolver(super.load);
  int lastCount = -1;
  @override
  Future<ui.Image?> resolvePassportCollage(
    List<PassportStampRef> stamps, {
    required int width,
    required int height,
    int seed = 0,
    double scatter = 0.5,
    double stampScale = 1.0,
    PassportInk ink = PassportInk.flag,
  }) async {
    lastCount = stamps.length;
    return null;
  }
}

/// Render consumption of the new recipe fields: copiesPerCountry (B3),
/// passport stampMode (B4), sizeClass + statementHero (B5).

final String _flagDir =
    Directory('../../apps/mobile_flutter/assets/flags/svg').absolute.path;

SvgFlagResolver _resolver() =>
    SvgFlagResolver((code) => File('$_flagDir/$code.svg').readAsString());

Future<String> _hash(DesignRecipe r) async {
  final res = await CanvasRenderer(assets: _resolver())
      .render(r, RenderTarget.preview(size: 220));
  return res.imageHash;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('copiesPerCountry (B3)', () {
    testWidgets('repeating one country into a grid changes the render',
        (tester) async {
      await tester.runAsync(() async {
        DesignRecipe recipe(int copies) => DesignRecipe(
              seed: 3,
              content: const RecipeContent(flags: [FlagRef('us')]),
              composition: Composition(
                family: DesignFamily.grid,
                copiesPerCountry: copies,
              ),
            );
        final one = await _hash(recipe(1));
        final many = await _hash(recipe(6));
        expect(many, isNot(one),
            reason: '6 copies must tile into a grid, not a single hero');
      });
    });
  });

  group('passport stampMode (B4)', () {
    testWidgets('entryOnly emits half the stamps of entryExit', (tester) async {
      await tester.runAsync(() async {
        Future<int> stampsFor(String? mode) async {
          final rec = _RecordingResolver(
              (code) => File('$_flagDir/$code.svg').readAsString());
          final recipe = DesignRecipe(
            seed: 4,
            content: const RecipeContent(flags: [FlagRef('us')]),
            composition: const Composition(family: DesignFamily.passportStamp),
            clip: Clip.shape(ClipShape.passportPage,
                code: 'us|2024-01|2024-02', stampMode: mode),
          );
          await CanvasRenderer(assets: rec)
              .render(recipe, RenderTarget.preview(size: 200));
          return rec.lastCount;
        }

        expect(await stampsFor('entryExit'), 2);
        expect(await stampsFor('entryOnly'), 1);
        expect(await stampsFor('exitOnly'), 1);
      });
    });
  });

  group('sizeClass (B5)', () {
    testWidgets('a smaller size shrinks the artwork on the garment',
        (tester) async {
      await tester.runAsync(() async {
        DesignRecipe recipe(SizeClass size) => DesignRecipe(
              seed: 5,
              content: const RecipeContent(flags: [FlagRef('us')]),
              composition:
                  Composition(family: DesignFamily.singleHero, sizeClass: size),
            );
        final large = await _hash(recipe(SizeClass.large));
        final small = await _hash(recipe(SizeClass.small));
        expect(small, isNot(large),
            reason: 'small must render the artwork at a smaller footprint');
      });
    });
  });
}
