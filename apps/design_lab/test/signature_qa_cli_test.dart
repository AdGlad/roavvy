import 'dart:io';

import 'package:design_lab/flag_source.dart';
import 'package:design_lab/render_service.dart';
import 'package:design_lab/signature/signature_io.dart';
import 'package:design_lab/signature/signature_sweep.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Headless review export for a Signature Recipe (M191 T7): renders every
/// country's hero, runs the QA checks, and writes a contact sheet + QA report
/// — the same sweep the Lab's Signature Workbench runs. Skipped unless PACK is
/// set. From apps/design_lab:
///
///   PACK=torn_flag flutter test test/signature_qa_cli_test.dart
///
/// Optional: COUNTRIES=us,jp,br (default: every bundled flag), VARIATIONS=8
/// (also check variations 1..n), LABEL=… (output folder name).
/// Output: design_studio/contact_sheets/signature/PACK/LABEL/.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final env = Platform.environment;
  final packId = env['PACK'];

  testWidgets('signature review export', (tester) async {
    final source = FlagSource.locate()!;
    final io = SignatureIO.fromFlagDir(source.dir);
    final pack = io.load(packId!);
    final countries = env['COUNTRIES']?.split(',').map((s) => s.trim().toLowerCase()).toList() ??
        source.codes();
    final variations = int.tryParse(env['VARIATIONS'] ?? '') ?? 0;
    final label = env['LABEL'] ?? 'review-${SignatureIO.timestamp()}';
    // LONG_SIDE = preview size in px (default 375) for a closer look.
    final longSide =
        int.tryParse(env['LONG_SIDE'] ?? '') ?? SignatureSweep.defaultLongSide;
    final sweep =
        SignatureSweep(RenderService(source.resolver()), longSide: longSide);

    await tester.runAsync(() async {
      const arial = '/System/Library/Fonts/Supplemental/Arial.ttf';
      if (File(arial).existsSync()) {
        final bytes = File(arial).readAsBytesSync();
        await (FontLoader('LabLabel')
              ..addFont(Future.value(ByteData.sublistView(bytes))))
            .load();
      }
      final sw = Stopwatch()..start();
      final cells = await sweep
          .run(pack, countries, variations: variations, keepImages: false)
          .toList();
      // Heroes are re-rendered (cached) with images for the sheet only, so a
      // full variation sweep never holds thousands of images at once.
      final heroes = [
        for (final cc in countries) await sweep.cell(pack, cc, 0),
      ];
      final report = SignatureSweep.report(pack, cells, label: label, longSide: longSide);
      final sheet = await SignatureSweep.contactSheet(heroes,
          labelFontFamily: 'LabLabel', names: source.countryNames());
      final (png, json) =
          io.writeReview(pack.id, label, sheetPng: sheet, report: report);
      // ignore: avoid_print
      print('pack ${pack.id} v${pack.version} (${pack.status.name}): '
          '${countries.length} countries, $variations variations each, '
          '${sw.elapsed.inSeconds}s\n'
          'summary: ${report['summary']}\n'
          'blockers: ${(report['blockers'] as List).length}\n'
          'sheet:  ${png.path}\nreport: ${json.path}');
    });
  }, skip: packId == null, timeout: const Timeout(Duration(minutes: 60)));
}
