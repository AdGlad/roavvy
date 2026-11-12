import 'dart:convert';
import 'dart:io';

import 'package:design_forge/design_forge.dart';
import 'package:design_forge_render/design_forge_render.dart';
import 'package:design_studio/design_studio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/studio_v2/host/bundle_asset_resolver.dart';

/// `portrait_torn_flag` parity: a preset approved in the macOS Design Lab must
/// render identically in Roavvy.
///
/// Each committed preset (design_studio/recipes/portrait_torn_flag) is loaded
/// with the same `TornFlagPreset` decoder the Lab uses and rendered through
/// the app's own print-file path — `RenderService.renderArtwork` over the
/// on-device bundle resolver ([createBundleAssetResolver]). The result must
/// match, pixel for pixel:
///   * the same preset rendered from the repo-disk flag files (the Lab's
///     resolver), and
///   * the engine's committed golden for that preset.
///
/// Never run this file with --update-goldens: the goldens belong to
/// packages/design_forge_render (update them there, after visual review).
final _presetDir = Directory('../../design_studio/recipes/portrait_torn_flag');
const _goldenDir =
    '../../../../../packages/design_forge_render/test/goldens/portrait_torn_flag';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final presets = _presetDir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.preset.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  test('the Lab presets are visible to the app', () {
    expect(presets, isNotEmpty);
  });

  for (final file in presets) {
    final stem = file.uri.pathSegments.last.replaceAll('.preset.json', '');

    testWidgets('$stem renders identically in Roavvy and the Lab',
        (tester) async {
      final preset = TornFlagPreset.fromJson(
          (jsonDecode(file.readAsStringSync()) as Map).cast<String, Object?>());
      expect(preset.recipeIdMatchesFile, isTrue);

      late RenderResult app, lab;
      await tester.runAsync(() async {
        app = await RenderService(createBundleAssetResolver())
            .renderArtwork(preset.recipe, longSide: 800);
        lab = await RenderService(SvgFlagResolver(
                (c) => File('assets/flags/svg/$c.svg').readAsString()))
            .renderArtwork(preset.recipe, longSide: 800);
      });

      expect(app.image.width, 640);
      expect(app.image.height, 800);
      expect(app.imageHash, lab.imageHash,
          reason: 'bundle-resolved and disk-resolved renders differ');
      await expectLater(
          app.image, matchesGoldenFile('$_goldenDir/$stem.png'));
    });
  }
}
