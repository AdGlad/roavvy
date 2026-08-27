import 'dart:io';
import 'dart:ui' as ui;

import 'package:design_forge/design_forge.dart';
import 'package:design_forge_render/design_forge_render.dart';
import 'package:flutter_test/flutter_test.dart';

/// M5 — garment-aware colour: adaptive ink (text / typographic / solid stamp
/// ink) re-inks for garment contrast, while flag fills keep semantic colours.

final String _flagDir =
    Directory('../../apps/mobile_flutter/assets/flags/svg').absolute.path;

SvgFlagResolver _resolver() =>
    SvgFlagResolver((code) => File('$_flagDir/$code.svg').readAsString());

// A fixed, neutral background so the ONLY variable across a pair is the recipe's
// garmentColour — isolating what the colour stage does, not the flatten fill.
const ui.Color _fixedBg = ui.Color(0xFF808080);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('garment-aware colour', () {
    testWidgets('flag-only design is untouched by garmentColour', (tester) async {
      await tester.runAsync(() async {
        final r = CanvasRenderer(assets: _resolver());
        DesignRecipe flagOnly(String garment) => DesignRecipe(
              seed: 11,
              content: const RecipeContent(flags: [FlagRef('us')]),
              composition: const Composition(family: DesignFamily.singleHero),
              palette: Palette(
                strategy: ColourStrategy.garmentAware,
                garmentColour: garment,
              ),
            );
        final dark = await r.render(flagOnly('#111111'),
            RenderTarget.preview(size: 200, background: _fixedBg));
        final light = await r.render(flagOnly('#eeeeee'),
            RenderTarget.preview(size: 200, background: _fixedBg));
        expect(light.imageHash, dark.imageHash,
            reason: 'a flag fill must keep its semantic colours on any garment');
      });
    });

    testWidgets('text ink flips between dark and light garments', (tester) async {
      await tester.runAsync(() async {
        final r = CanvasRenderer(assets: _resolver());
        DesignRecipe text(String garment) => DesignRecipe(
              seed: 12,
              content: const RecipeContent(flags: [FlagRef('us')]),
              composition: const Composition(family: DesignFamily.typographic),
              clip: const Clip(shapeId: 'text', text: 'ROAM'),
              palette: Palette(
                strategy: ColourStrategy.garmentAware,
                garmentColour: garment,
              ),
            );
        final onDark = await r.render(text('#111111'),
            RenderTarget.preview(size: 200, background: _fixedBg));
        final onLight = await r.render(text('#eeeeee'),
            RenderTarget.preview(size: 200, background: _fixedBg));
        expect(onLight.imageHash, isNot(onDark.imageHash),
            reason: 'adaptive text ink must re-ink for contrast');
      });
    });

    testWidgets('solid passport-stamp ink flips between garments', (tester) async {
      await tester.runAsync(() async {
        final r = CanvasRenderer(assets: _resolver());
        DesignRecipe stamp(String garment) => DesignRecipe(
              seed: 13,
              content: const RecipeContent(flags: [FlagRef('us')]),
              composition: const Composition(family: DesignFamily.passportStamp),
              clip: const Clip(
                  shapeId: 'passportPage',
                  code: 'us|1 JAN 24|5 JAN 24',
                  ink: 'black'),
              palette: Palette(
                strategy: ColourStrategy.garmentAware,
                garmentColour: garment,
              ),
            );
        final onDark = await r.render(stamp('#111111'),
            RenderTarget.preview(size: 220, background: _fixedBg));
        final onLight = await r.render(stamp('#eeeeee'),
            RenderTarget.preview(size: 220, background: _fixedBg));
        expect(onLight.imageHash, isNot(onDark.imageHash),
            reason: 'solid stamp ink is adaptive and must re-ink for contrast');
      });
    });
  });
}
