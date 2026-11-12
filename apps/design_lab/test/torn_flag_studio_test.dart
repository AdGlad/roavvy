import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:design_forge/design_forge.dart';
import 'package:design_lab/flag_source.dart';
import 'package:design_lab/render_service.dart';
import 'package:design_lab/torn_flag/torn_flag_io.dart';
import 'package:design_lab/torn_flag/torn_flag_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Torn Flag studio's disk workflow (presets, exports, contact sheets,
/// comparison) and screen, run headlessly against a throwaway repo root.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late TornFlagIO io;
  late RenderService service;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('torn_flag_studio');
    io = TornFlagIO(tmp);
    service = RenderService(FlagSource.locate()!.resolver());
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  TornFlagPreset preset({int seed = 5}) => TornFlagPreset(
        name: 'Test Preset',
        recipe: portraitTornFlagRecipe(
            flagCode: 'us', seed: seed, params: const TornStrips(gap: 0.25)),
      );

  test('slug', () {
    expect(TornFlagIO.slug('US — Classic!'), 'us-classic');
    expect(TornFlagIO.slug('  '), 'preset');
  });

  test('presets save and reload to the same recipe', () {
    final file = io.savePreset(preset());
    expect(file.path, endsWith('portrait_torn_flag/test-preset.preset.json'));
    expect(io.listPresets().map((f) => f.path), [file.path]);
    final back = io.loadPreset(file);
    expect(back.name, 'Test Preset');
    expect(back.recipe.recipeId, preset().recipe.recipeId);
    expect(back.recipeIdMatchesFile, isTrue);
  });

  testWidgets('export writes a transparent PNG and a reproducible sidecar',
      (tester) async {
    await tester.runAsync(() async {
      final png = await io.exportArtwork(service, preset(), longSide: 500);
      expect(png.existsSync(), isTrue);
      final sidecar = File(png.path.replaceAll('.png', '.json'));
      final json =
          (jsonDecode(sidecar.readAsStringSync()) as Map).cast<String, Object?>();
      expect((json['render'] as Map)['width'], 400);
      expect((json['render'] as Map)['height'], 500);
      expect((json['render'] as Map)['background'], 'transparent');

      // The sidecar alone reproduces the exact image.
      final again = TornFlagPreset.fromJson(
          (json['preset'] as Map).cast<String, Object?>());
      final rerun = await service.renderArtwork(again.recipe, longSide: 500);
      expect(rerun.imageHash, json['imageHash']);

      // Transparent corner.
      final codec = await ui.instantiateImageCodec(png.readAsBytesSync());
      final img = (await codec.getNextFrame()).image;
      final px = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
      expect(px!.getUint8(3), 0);
    });
  });

  testWidgets('contact sheet and comparison export', (tester) async {
    await tester.runAsync(() async {
      final sheet = await io.exportContactSheet(
        service,
        [for (var s = 1; s <= 4; s++) preset(seed: s)],
        title: 'seeds',
        cellLongSide: 300,
        columns: 2,
      );
      expect(sheet.existsSync(), isTrue);
      final cells = (jsonDecode(File(sheet.path.replaceAll('.png', '.json'))
              .readAsStringSync()) as Map)['cells'] as List;
      expect(cells, hasLength(4));

      // Use a rendered PNG as a stand-in reference image.
      final ref = await io.exportArtwork(service, preset(), longSide: 300);
      final cmp = await io.exportComparison(service, preset(), ref, height: 300);
      expect(cmp.existsSync(), isTrue);
    });
  });

  testWidgets('the screen renders a preview and reacts to a seed change',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    io.savePreset(preset(seed: 9));

    await tester.pumpWidget(MaterialApp(
      home: TornFlagScreen(service: service, io: io, codes: const ['us', 'sc']),
    ));
    // Wait for the debounced render and the isolate (slow under a loaded
    // parallel test run), up to 30s.
    for (var i = 0; i < 600 && find.byType(RawImage).evaluate().isEmpty; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
    expect(find.text('Torn Flag · Test Preset'), findsOneWidget);
    expect(find.byType(RawImage), findsWidgets);
    expect(find.text('9'), findsOneWidget); // seed field from the preset

    await tester.tap(find.byTooltip('Next seed'));
    await tester.pump();
    expect(find.text('10'), findsOneWidget);
  });
}
