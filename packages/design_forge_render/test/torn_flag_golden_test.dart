import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:design_forge/design_forge.dart';
import 'package:design_forge_render/design_forge_render.dart';
import 'package:flutter_test/flutter_test.dart';

/// Visual regression goldens for the `portrait_torn_flag` recipe: every
/// committed preset (design_studio/recipes/portrait_torn_flag) rendered through
/// the full pipeline with the real flag SVGs, at a fixed 640×800 transparent
/// artwork size.
///
/// Approve a deliberate visual change with:
///   flutter test --update-goldens test/torn_flag_golden_test.dart
/// then review the PNGs under test/goldens/portrait_torn_flag/ before committing.
///
/// Goldens are exact-pixel on the machine that produced them (macOS); the
/// pure-Dart torn geometry is bit-stable everywhere, but the flag SVG raster
/// comes from the platform rasteriser.
final _flagDir =
    Directory('../../apps/mobile_flutter/assets/flags/svg').absolute.path;
final _presetDir =
    Directory('../../design_studio/recipes/portrait_torn_flag').absolute;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final presets = _presetDir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.preset.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  test('there are committed presets to guard', () {
    expect(presets, isNotEmpty);
  });

  // Cut lines come from each flag's own lengthwise stripes: a flag without
  // any is never torn into strips.
  testWidgets('real flags: stripes found where they exist, none invented',
      (tester) async {
    const expected = {
      'official/us': 12, // 13 stripes
      'us': 12, // 4:3 artwork, larger canton
      'gr': 8, // 9 stripes
      'de': 2, // horizontal tricolour
      'sc': 0, // diagonal rays
      'fr': 0, // vertical tricolour (bands run across the portrait flag)
      'jp': 0, // disc
      'br': 0, // emblem
    };
    final found = <String, int>{};
    await tester.runAsync(() async {
      final resolver =
          SvgFlagResolver((c) => File('$_flagDir/$c.svg').readAsString());
      for (final code in expected.keys) {
        final img = await resolver.resolveFlag(code, width: 1900, height: 1000);
        final bytes = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
        found[code] = TornStripsRaster.lengthwiseBoundaries(
                bytes!.buffer.asUint8List(), img.width, img.height)
            .length;
      }
    });
    expect(found, expected);
  });

  for (final file in presets) {
    final stem = file.uri.pathSegments.last.replaceAll('.preset.json', '');
    testWidgets('golden: $stem', (tester) async {
      final preset = TornFlagPreset.fromJson(
          (jsonDecode(file.readAsStringSync()) as Map).cast<String, Object?>());
      late ui.Image image;
      await tester.runAsync(() async {
        final renderer = CanvasRenderer(
            assets: SvgFlagResolver(
                (c) => File('$_flagDir/$c.svg').readAsString()));
        final result = await renderer.render(
          preset.recipe,
          const RenderTarget(
              width: 640,
              height: 800,
              quality: RenderQuality.print,
              paintBackground: false),
        );
        image = result.image;
      });
      await expectLater(
          image, matchesGoldenFile('goldens/portrait_torn_flag/$stem.png'));
    });
  }
}
