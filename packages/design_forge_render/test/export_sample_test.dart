import 'dart:io';

import 'package:design_forge/design_forge.dart';
import 'package:design_forge_render/design_forge_render.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

// Throwaway visual-check harness: writes one PNG per capability so a human can
// eyeball the pipeline. Skipped unless EXPORT_SAMPLES=1.
void main() {
  final out = Platform.environment['OUT'] ?? '/tmp/design_forge_samples';
  final enabled = Platform.environment['EXPORT_SAMPLES'] == '1';

  TestWidgetsFlutterBinding.ensureInitialized();

  final flagDir =
      Directory('../../apps/mobile_flutter/assets/flags/svg').absolute.path;
  final resolver =
      SvgFlagResolver((code) => File('$flagDir/$code.svg').readAsString());

  DesignRecipe base({
    required List<FlagRef> flags,
    DesignFamily family = DesignFamily.singleHero,
    FlagCombination? combo,
    Clip? clip,
    EdgeTreatment? edge,
    Effects? fx,
    Palette? palette,
    int seed = 7,
  }) =>
      DesignRecipe(
        seed: seed,
        content: RecipeContent(flags: flags),
        composition: Composition(family: family),
        flagCombination: combo,
        clip: clip,
        edgeTreatment: edge,
        effects: fx,
        palette: palette,
      );

  final samples = <String, DesignRecipe>{
    'single_us': base(flags: [FlagRef('us')]),
    'combo_diagonal': base(
      flags: [FlagRef('us'), FlagRef('gb')],
      family: DesignFamily.duoBlend,
      combo: const FlagCombination(mode: FlagCombineMode.diagonalSplit),
    ),
    'combo_vertical': base(
      flags: [FlagRef('fr'), FlagRef('de')],
      family: DesignFamily.duoBlend,
      combo: const FlagCombination(mode: FlagCombineMode.vertical),
    ),
    'clip_heart': base(flags: [FlagRef('us')], clip: Clip.shape(ClipShape.heart)),
    'clip_circle': base(flags: [FlagRef('jp')], clip: Clip.shape(ClipShape.circle)),
    'torn_battleworn': base(
      flags: [FlagRef('us')],
      edge: const EdgeTreatment(style: TearStyle.battleWorn, edgeDamage: 0.85, asymmetry: 0.8),
    ),
    'torn_frayed': base(
      flags: [FlagRef('br')],
      edge: const EdgeTreatment(style: TearStyle.frayed, edgeDamage: 0.6, frayAmount: 0.9, asymmetry: 0.4),
    ),
    'fx_distress': base(flags: [FlagRef('us')], fx: const Effects(distress: 0.6)),
    'fx_grain': base(flags: [FlagRef('us')], fx: const Effects(grain: 0.7)),
    'fx_fade': base(flags: [FlagRef('us')], fx: const Effects(fade: 0.7)),
    'fx_halftone': base(flags: [FlagRef('us')], fx: const Effects(halftone: 1.0, halftoneScale: 5)),
    'fx_ripple': base(flags: [FlagRef('us')], fx: const Effects(rippleAmp: 0.6, rippleFreq: 5)),
    'colour_vintage': base(flags: [FlagRef('us')], palette: const Palette(vintageGrade: 0.85)),
    'colour_mono': base(flags: [FlagRef('us')], palette: const Palette(strategy: ColourStrategy.monochrome)),
    'torn_plus_vintage': base(
      flags: [FlagRef('us')],
      edge: const EdgeTreatment(style: TearStyle.ragged, edgeDamage: 0.7, asymmetry: 0.7),
      fx: const Effects(distress: 0.3, grain: 0.3),
      palette: const Palette(vintageGrade: 0.7),
    ),
  };

  testWidgets('export capability samples', (tester) async {
    Directory(out).createSync(recursive: true);
    final renderer = CanvasRenderer(assets: resolver);
    await tester.runAsync(() async {
      for (final entry in samples.entries) {
        final res = await renderer.render(
          entry.value,
          RenderTarget.preview(size: 384, background: const Color(0xFFF2F2F2)),
        );
        File('$out/${entry.key}.png').writeAsBytesSync(res.pngBytes);
      }
    });
    // ignore: avoid_print
    print('wrote ${samples.length} samples to $out');
  }, skip: !enabled);
}
