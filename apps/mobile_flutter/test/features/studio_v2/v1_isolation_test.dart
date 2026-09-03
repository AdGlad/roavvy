import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// M1 — V2 isolation guard. The V2 feature must NOT depend on the V1 merch/cards
/// flow, the macOS Lab, or the repo filesystem. This keeps V1 frozen and lets us
/// build/ship/fall-back V2 independently. (A structural test — no app boot.)
void main() {
  test('features/studio_v2 imports nothing from V1 / Lab / dart:io', () {
    final dir = Directory('lib/features/studio_v2');
    expect(dir.existsSync(), isTrue, reason: 'V2 feature dir must exist');

    final forbidden = <String, String>{
      "features/merch": 'V1 merch flow',
      "features/cards": 'V1 cards flow',
      "package:design_lab": 'macOS Lab host',
      "flag_source": "Lab's repo-disk FlagSource",
      "dart:io": 'no repo/OS filesystem on device',
    };

    final offenders = <String>[];
    for (final f in dir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      final src = f.readAsStringSync();
      for (final entry in forbidden.entries) {
        if (src.contains("import '") && src.contains(entry.key) ||
            src.contains('import "') && src.contains(entry.key)) {
          // Only flag when it appears on an import line.
          for (final line in src.split('\n')) {
            final l = line.trimLeft();
            if (l.startsWith('import') && l.contains(entry.key)) {
              offenders.add('${f.path}: ${entry.value} ($l)');
            }
          }
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'V2 must stay isolated:\n${offenders.join('\n')}',
    );
  });
}
