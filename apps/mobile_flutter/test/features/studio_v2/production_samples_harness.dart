// M26 — the standalone production harness.
//
// Generates real, full-resolution print files from representative designs
// WITHOUT launching Roavvy: it drives the same StudioController and the same
// renderer the app does, over the real bundled assets, and writes the files out
// for someone to open and look at.
//
// It is skipped unless asked, because it writes to disk and takes minutes:
//
//   flutter test test/features/studio_v2/production_samples_harness.dart \
//     --dart-define=PRODUCTION_SAMPLES=/tmp/roavvy_print
//
// Each file is named for what it is testing, and the run prints a table of
// dimensions, physical size, transparency and render time.
import 'dart:io';

import 'package:flutter/services.dart' show FontLoader;

import 'package:design_forge/design_forge.dart';
import 'package:design_studio/design_studio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/studio_v2/host/bundle_asset_resolver.dart';
import 'package:mobile_flutter/features/studio_v2/host/passport_stamp_inventory.g.dart';
import 'package:mobile_flutter/features/studio_v2/host/silhouette_inventory.g.dart';
import 'package:mobile_flutter/features/studio_v2/studio_v2_app.dart';
import 'package:mobile_flutter/features/studio_v2_commerce/print_calibration.dart';
import 'package:mobile_flutter/features/studio_v2_commerce/production_print_specs.dart';

const String _outDir = String.fromEnvironment('PRODUCTION_SAMPLES');

/// A session over the real bundled art, so a sample looks like a shirt rather
/// than like a test fixture.
StudioController bundledStudio({int countries = 8}) {
  final trips = demoStudioContext.trips.take(countries).toList();
  final c = StudioController(
    generator: LabShowcaseGenerator(
      silhouettesByShape: {
        ClipShape.animalSilhouette:
            kStudioV2SilhouettesByKind['animal'] ?? const [],
        ClipShape.plantSilhouette:
            kStudioV2SilhouettesByKind['plant'] ?? const [],
        ClipShape.landmarkSilhouette:
            kStudioV2SilhouettesByKind['landmark'] ?? const [],
        ClipShape.passportStampOutline: kStudioV2PassportStampSlugs,
      },
      countryNames: const {},
    ),
    service: RenderService(createBundleAssetResolver()),
    designContext: DesignContext.fromTrips(
      trips,
      scopeKey: 'studio_v2:samples:$countries',
    ),
    initialSeed: 7,
  );
  return c;
}

int _subject(String label) =>
    StudioController.subjects.indexWhere((s) => s.$3 == label);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('production samples', (tester) async {
    final dir = Directory(_outDir);
    dir.createSync(recursive: true);

    // A calibration sheet exists to be read with a tape measure in hand, and a
    // test binary ships no real font — so lend it one from the host machine.
    // If none of these exist the sheets still work: every measurement on them
    // is drawn as geometry, and only the captions go blocky.
    for (final candidate in const [
      '/System/Library/Fonts/Supplemental/Arial.ttf',
      '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
    ]) {
      final f = File(candidate);
      if (!f.existsSync()) continue;
      final loader = FontLoader(PrintCalibration.labelFamily)
        ..addFont(Future.value(f.readAsBytesSync().buffer.asByteData()));
      await loader.load();
      break;
    }

    // (name, how to set the design up, how to set the front up)
    final cases = <(String, void Function(StudioController))>[
      ('flags-grid', (c) {
        c.selectSubject(_subject('Flags'));
        c.applyDetailChoice('grid');
      }),
      ('flags-clipped-heart', (c) {
        c.selectSubject(_subject('Flags'));
        c.applyDetailChoice('heart');
      }),
      ('passport', (c) => c.selectSubject(_subject('Passport'))),
      ('typography', (c) {
        c.selectSubject(_subject('Words'));
        c.commitTitle('EIGHT COUNTRIES');
      }),
      ('route', (c) => c.selectSubject(_subject('Route'))),
      ('print-treatment-retro', (c) {
        c.selectSubject(_subject('Flags'));
        final options = c.vibeStyleOptions();
        final retro = options.firstWhere(
          (o) => o.$1 == LabStyle.retro,
          orElse: () => options.first,
        );
        c.onStyleTap(retro.$1, retro.$2);
      }),
    ];

    final rows = <String>[];
    Future<void> emit(
      String name,
      StudioController c, {
      required FrontFit fit,
    }) async {
      c.setSide(true);
      c.setFrontFit(fit);
      c.setSide(false);
      final files = await renderPrintFiles(c);
      if (files.isEmpty) {
        rows.add('$name | (no print files)');
        return;
      }
      for (final f in files) {
        final path = '$_outDir/$name-${f.side.name}.${f.format.extension}';
        File(path).writeAsBytesSync(f.bytes);
        final (wIn, hIn) = f.physicalInches;
        rows.add(
          '${name.padRight(26)} ${f.side.name.padRight(5)} '
          '${f.widthPx}x${f.heightPx} '
          '${wIn.toStringAsFixed(0)}x${hIn.toStringAsFixed(0)}in '
          '@${f.dpi}dpi  '
          'alpha=${f.format == ProductionImageFormat.png} '
          '${(f.bytes.length / 1024).round()}KB '
          '${f.elapsed.inMilliseconds}ms  $path',
        );
      }
    }

    await tester.runAsync(() async {
      // M26.1 — the four calibration targets, first, because they are what a
      // physical sample is measured against.
      for (final sheet in await calibrationSheets()) {
        final path =
            '$_outDir/calibration-${sheet.placement.name}.'
            '${sheet.format.extension}';
        File(path).writeAsBytesSync(sheet.bytes);
        final (wIn, hIn) = sheet.physicalInches;
        rows.add(
          '${'calibration-${sheet.placement.name}'.padRight(26)} '
          '${sheet.side.name.padRight(5)} ${sheet.widthPx}x${sheet.heightPx} '
          '${wIn.toStringAsFixed(0)}x${hIn.toStringAsFixed(0)}in '
          '@${sheet.dpi}dpi  alpha=true '
          '${(sheet.bytes.length / 1024).round()}KB '
          '${sheet.elapsed.inMilliseconds}ms  $path',
        );
      }

      for (final (name, setUp) in cases) {
        final c = bundledStudio();
        setUp(c);
        await emit(name, c, fit: FrontFit.full);
        c.dispose();
      }

      // Front placements, on one design so they are comparable.
      for (final (label, fit) in [
        ('front-full', FrontFit.full),
        ('front-chest', FrontFit.chest),
        ('front-none', FrontFit.none),
      ]) {
        final c = bundledStudio();
        await emit(label, c, fit: fit);
        c.dispose();
      }

      // Country counts: one flag has nothing to arrange, many have too much.
      for (final n in [1, 2, 8]) {
        final c = bundledStudio(countries: n);
        await emit('countries-$n', c, fit: FrontFit.full);
        c.dispose();
      }
    });

    // ignore: avoid_print
    print('\n=== production samples → $_outDir ===\n${rows.join('\n')}\n');
    expect(dir.listSync().whereType<File>(), isNotEmpty);
  }, timeout: const Timeout(Duration(minutes: 20)), skip: _outDir.isEmpty);
}
