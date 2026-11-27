import 'dart:io';
import 'dart:ui' as ui;

import 'package:design_forge/design_forge.dart';
import 'package:design_forge_render/design_forge_render.dart';
import 'package:flutter_test/flutter_test.dart';

/// Visual regression goldens for APPROVED Signature Recipe packs (ADR-181 §6):
/// every locked country's hero, rendered through the full pipeline with the
/// real flag SVGs at a fixed 640×800 transparent artwork size. Draft packs
/// have no goldens; they are still being tuned.
///
/// The Lab's Approve flow runs, from this package:
///   flutter test --update-goldens test/signature_golden_test.dart
/// Review the PNGs under test/goldens/signature/ before committing.
///
/// Exact-pixel on the machine that produced them (macOS): the flag SVG raster
/// comes from the platform rasteriser.
final _flagDir =
    Directory('../../apps/mobile_flutter/assets/flags/svg').absolute.path;
final _packDir = Directory('../design_studio/assets/signature').absolute;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final packs = [
    for (final f in _packDir.listSync().whereType<File>().toList()
      ..sort((a, b) => a.path.compareTo(b.path)))
      if (f.path.endsWith('.pack.json'))
        SignaturePackCodec.decode(f.readAsStringSync()),
  ];

  test('bundled packs are readable', () => expect(packs, isNotEmpty));

  for (final pack in packs.where((p) => p.isApproved)) {
    test('${pack.id}: approved pack has locks to guard', () {
      expect(pack.locks, isNotEmpty);
    });
    for (final cc in pack.locks.keys.toList()..sort()) {
      testWidgets('golden: ${pack.id}/$cc', (tester) async {
        final recipe = SignatureResolver.hero(pack, cc);
        expect(recipe.recipeId, pack.locks[cc],
            reason: 'Engine change altered an approved design');
        late ui.Image image;
        await tester.runAsync(() async {
          final renderer = CanvasRenderer(
              assets: SvgFlagResolver(
                  (c) => File('$_flagDir/$c.svg').readAsString()));
          image = (await renderer.render(
            recipe,
            const RenderTarget(
                width: 640,
                height: 800,
                quality: RenderQuality.print,
                paintBackground: false),
          ))
              .image;
        });
        await expectLater(
            image, matchesGoldenFile('goldens/signature/${pack.id}/$cc.png'));
      });
    }
  }
}
