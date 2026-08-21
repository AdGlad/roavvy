import 'dart:io';

import 'package:design_forge/design_forge.dart';
import 'package:design_lab/flag_source.dart';
import 'package:design_lab/render_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Visual verification of the fit/orientation/multi-flag fixes. Writes PNGs when
/// OUT is set.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('fit + orientation + multi-flag', (tester) async {
    final source = FlagSource.locate();
    expect(source, isNotNull);
    final service = RenderService(source!.resolver());

    DesignRecipe r({
      required List<String> flags,
      DesignFamily family = DesignFamily.singleHero,
      Clip? clip,
      FlagCombination? combo,
      EdgeTreatment? edge,
      Orientation orientation = Orientation.square,
    }) =>
        DesignRecipe(
          seed: 1,
          content: RecipeContent(flags: [for (final f in flags) FlagRef(f)]),
          composition: Composition(family: family, orientation: orientation),
          clip: clip,
          flagCombination: combo,
          edgeTreatment: edge,
        );

    final samples = <String, DesignRecipe>{
      'heart_full': r(flags: ['us'], clip: Clip.shape(ClipShape.heart)),
      'circle_full': r(flags: ['jp'], clip: Clip.shape(ClipShape.circle)),
      'grid_three': r(flags: ['us', 'gb', 'au'], family: DesignFamily.grid),
      'grid_three_heart': r(
          flags: ['us', 'gb', 'au'],
          family: DesignFamily.grid,
          clip: Clip.shape(ClipShape.heart)),
      'portrait': r(flags: ['fr'], orientation: Orientation.portrait),
      'landscape': r(flags: ['fr'], orientation: Orientation.landscape),
      // Torn edges following a silhouette outline (the reported case).
      'silhouette_torn': r(
        flags: ['sc'],
        clip: Clip.shape(ClipShape.plantSilhouette, code: 'sc_coco_de_mer'),
        edge: const EdgeTreatment(
            style: TearStyle.ragged, edgeDamage: 0.7, frayAmount: 0.6),
      ),
      'heart_torn': r(
        flags: ['us'],
        clip: Clip.shape(ClipShape.heart),
        edge: const EdgeTreatment(edgeDamage: 0.6),
      ),
    };

    final out = Platform.environment['OUT'];
    await tester.runAsync(() async {
      for (final e in samples.entries) {
        final img = await service.imageFor(e.value, 512);
        expect(img.width, greaterThan(0));
        if (out != null) {
          final res = await service.renderFull(e.value, 512);
          File('$out/fix_${e.key}.png').writeAsBytesSync(res.pngBytes);
        }
      }
    });
    if (out != null) {
      // ignore: avoid_print
      print('wrote fix samples to $out');
    }
  });
}
