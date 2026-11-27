import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:design_forge/design_forge.dart';
import 'package:design_studio/design_studio.dart';

/// Disk side of the Signature Workbench (M191, ADR-181). Host-only (dart:io).
///
/// Layout, relative to the repo root:
///   packages/design_studio/assets/signature/index.json         (committed)
///   packages/design_studio/assets/signature/ID.pack.json     (committed)
///   design_studio/contact_sheets/signature/ID/LABEL/       (review sheets + QA reports)
///   packages/design_forge_render/test/goldens/signature/ID/  (goldens, via flutter test)
class SignatureIO {
  SignatureIO(this.repoRoot);

  /// From the Lab's flag directory (`<repo>/apps/mobile_flutter/assets/flags/svg`).
  factory SignatureIO.fromFlagDir(Directory flagDir) {
    var repo = flagDir;
    for (var i = 0; i < 5; i++) {
      repo = repo.parent;
    }
    return SignatureIO(repo);
  }

  final Directory repoRoot;

  Directory get packsDir => Directory(
      '${repoRoot.path}/packages/design_studio/${SignatureCatalog.packagePrefix}');

  File get indexFile => File('${packsDir.path}/${SignatureCatalog.indexFile}');

  File packFile(String id) =>
      File('${packsDir.path}/${SignatureCatalog.packFile(id)}');

  Directory get renderPackageDir =>
      Directory('${repoRoot.path}/packages/design_forge_render');

  Directory sheetDir(String id, String label) =>
      Directory('${repoRoot.path}/design_studio/contact_sheets/signature/$id/$label')
        ..createSync(recursive: true);

  /// Pack ids in feed order (from index.json).
  List<String> listIds() {
    if (!indexFile.existsSync()) return const [];
    final json = jsonDecode(indexFile.readAsStringSync()) as Map;
    return [for (final id in (json['packs'] as List)) id as String];
  }

  SignatureRecipe load(String id) =>
      SignaturePackCodec.decode(packFile(id).readAsStringSync());

  /// Writes [pack] in canonical form and makes sure the index lists it.
  File save(SignatureRecipe pack) {
    packsDir.createSync(recursive: true);
    final file = packFile(pack.id)
      ..writeAsStringSync(SignaturePackCodec.encode(pack));
    final ids = listIds();
    if (!ids.contains(pack.id)) {
      indexFile.writeAsStringSync(
          '${const JsonEncoder.withIndent('  ').convert({'packs': [...ids, pack.id]})}\n');
    }
    return file;
  }

  /// Writes a review sheet PNG and its QA report into [sheetDir].
  (File, File) writeReview(
    String id,
    String label, {
    required Uint8List sheetPng,
    required Map<String, Object?> report,
  }) {
    final dir = sheetDir(id, label);
    final png = File('${dir.path}/contact_sheet.png')..writeAsBytesSync(sheetPng);
    final json = File('${dir.path}/qa_report.json')
      ..writeAsStringSync(
          '${const JsonEncoder.withIndent('  ').convert(report)}\n');
    return (png, json);
  }

  /// The command that (re)writes this pack's goldens after approval.
  static const String goldenCommand =
      'flutter test --update-goldens test/signature_golden_test.dart';

  /// Runs [goldenCommand] in design_forge_render. Returns (exitCode, output).
  Future<(int, String)> updateGoldens() async {
    final r = await Process.run(
      'flutter',
      ['test', '--update-goldens', 'test/signature_golden_test.dart'],
      workingDirectory: renderPackageDir.path,
      runInShell: true,
    );
    return (r.exitCode, '${r.stdout}\n${r.stderr}');
  }

  static String timestamp([DateTime? at]) {
    final t = at ?? DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${t.year}${two(t.month)}${two(t.day)}-${two(t.hour)}${two(t.minute)}${two(t.second)}';
  }
}
