import 'dart:convert';
import 'dart:io';

import 'package:design_forge/design_forge.dart';
import 'package:design_studio/design_studio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reads package files the way the Lab does (paths relative to this package).
Future<String> _disk(String key) async => File(key).readAsString();

void main() {
  test('bundled packs load and every lock still matches the engine', () async {
    final catalog = await SignatureCatalog.load(_disk,
        prefix: SignatureCatalog.packagePrefix, includeDrafts: true);
    expect(catalog.packs.map((p) => p.id), contains('torn_flag'));
    expect(catalog.verify(), isEmpty,
        reason: 'An engine change altered an approved design; review it in '
            'the Lab and re-approve the pack (ADR-181 §6).');
  });

  test('bundled packs are written in canonical form', () async {
    for (final f in Directory(SignatureCatalog.packagePrefix)
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.pack.json'))) {
      final text = f.readAsStringSync();
      expect(SignaturePackCodec.encode(SignaturePackCodec.decode(text)), text,
          reason: '${f.path} was hand-edited; re-save it from the Lab');
    }
  });

  test('torn_flag seed pack reproduces the US Classic preset',
      () async {
    final catalog = await SignatureCatalog.load(_disk,
        prefix: SignatureCatalog.packagePrefix, includeDrafts: true);
    final preset = jsonDecode(File(
            '../../design_studio/recipes/portrait_torn_flag/us-classic.preset.json')
        .readAsStringSync()) as Map;
    final stored = (preset['recipe'] as Map)['recipeId'];
    final pack = catalog.byId('torn_flag')!;
    expect(SignatureResolver.hero(pack, 'us').recipeId, stored);
    for (final cc in ['jp', 'sc', 'br', 'gb']) {
      expect(SignatureResolver.hero(pack, cc).content.flags.single.code, cc);
    }
  });

  test('drafts are dropped when drafts are not allowed (release)', () async {
    final catalog = await SignatureCatalog.load(_disk,
        prefix: SignatureCatalog.packagePrefix, includeDrafts: false);
    expect(catalog.packs.where((p) => !p.isApproved), isEmpty);
  });

  test('a pack whose id does not match its file name is refused', () async {
    final pack = File('${SignatureCatalog.packagePrefix}torn_flag.pack.json')
        .readAsStringSync();
    Future<String> loader(String key) async => key.endsWith('index.json')
        ? '{"packs": ["other"]}'
        : pack;
    expect(SignatureCatalog.load(loader, prefix: ''), throwsFormatException);
  });
}
