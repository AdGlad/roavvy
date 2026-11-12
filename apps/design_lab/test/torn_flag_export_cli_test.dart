import 'dart:io';

import 'package:design_forge/design_forge.dart';
import 'package:design_lab/flag_source.dart';
import 'package:design_lab/render_service.dart';
import 'package:design_lab/torn_flag/torn_flag_io.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Command-line export for the Torn Flag studio (no app window). Skipped unless
/// PRESET is set. From apps/design_lab:
///
///   PRESET=../../design_studio/recipes/portrait_torn_flag/us-classic.preset.json \
///     flutter test test/torn_flag_export_cli_test.dart
///
/// Optional: LONG_SIDE (default 4500), SEED (override the preset's seed),
/// SHEET_SEEDS (e.g. 6 → also a contact sheet of seeds seed..seed+5),
/// REFERENCE (path → also a reference-vs-generated comparison).
/// Output goes to design_studio/generated_batches/lab_export/torn_flag/.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final env = Platform.environment;
  final presetPath = env['PRESET'];

  testWidgets('export torn flag artwork', (tester) async {
    final source = FlagSource.locate()!;
    final service = RenderService(source.resolver());
    final io = TornFlagIO.fromFlagDir(source.dir);
    var preset = io.loadPreset(File(presetPath!));
    if (!preset.recipeIdMatchesFile) {
      // ignore: avoid_print
      print('WARNING: ${preset.name} was saved by a different engine version; '
          'the export may not match the earlier one.');
    }
    final seed = int.tryParse(env['SEED'] ?? '');
    if (seed != null) {
      preset = TornFlagPreset(
          name: preset.name,
          notes: preset.notes,
          recipe: preset.recipe.copyWith(seed: seed));
    }
    final longSide = int.tryParse(env['LONG_SIDE'] ?? '') ?? TornFlagIO.printLongSide;
    final sheetSeeds = int.tryParse(env['SHEET_SEEDS'] ?? '') ?? 0;
    final reference = env['REFERENCE'];

    await tester.runAsync(() async {
      // The test runner draws text in a placeholder font; give the contact
      // sheet labels a real one.
      const arial = '/System/Library/Fonts/Supplemental/Arial.ttf';
      if (File(arial).existsSync()) {
        final bytes = File(arial).readAsBytesSync();
        await (FontLoader('LabLabel')
              ..addFont(Future.value(ByteData.sublistView(bytes))))
            .load();
      }
      final png = await io.exportArtwork(service, preset, longSide: longSide);
      // ignore: avoid_print
      print('artwork:    ${png.path}');
      if (sheetSeeds > 0) {
        final sheet = await io.exportContactSheet(
          service,
          [
            for (var i = 0; i < sheetSeeds; i++)
              TornFlagPreset(
                  name: preset.name,
                  recipe: preset.recipe.copyWith(seed: preset.recipe.seed + i)),
          ],
          title: preset.name,
          labelFontFamily: 'LabLabel',
        );
        // ignore: avoid_print
        print('contact:    ${sheet.path}');
      }
      if (reference != null) {
        final cmp =
            await io.exportComparison(service, preset, File(reference));
        // ignore: avoid_print
        print('comparison: ${cmp.path}');
      }
    });
  }, skip: presetPath == null);
}
