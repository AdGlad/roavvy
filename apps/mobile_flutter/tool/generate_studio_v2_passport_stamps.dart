// Dev script: regenerates
//   lib/features/studio_v2/host/passport_stamp_inventory.g.dart
// from the bundled stamp manifest at assets/mobile_meta/stamp_manifest.json.
//
// Run from the app root (apps/mobile_flutter):
//   dart run tool/generate_studio_v2_passport_stamps.dart
//
// The app already bundles the real passport entry/exit stamp artwork
// (`assets/mobile_png/<base>.png` + `assets/mobile_meta/<base>.json`, indexed by
// `stamp_manifest.json` keys like `AU-entry`). Studio V2's generator needs that
// inventory SYNCHRONOUSLY at construction time — it is what makes the Passport
// direction's subjects available — so the slug list is baked into a generated
// Dart file, in the same spirit as `silhouette_inventory.g.dart`.
//
// Slugs use the `<cc>_<entry|exit>` convention the design_forge renderer expects
// (`AU-entry` → `au_entry`). `bundle_asset_resolver.dart` maps a slug back to
// the manifest key to load the artwork at render time.
import 'dart:convert';
import 'dart:io';

const _manifestPath = 'assets/mobile_meta/stamp_manifest.json';
const _outPath = 'lib/features/studio_v2/host/passport_stamp_inventory.g.dart';

void main() {
  final manifest = File(_manifestPath);
  if (!manifest.existsSync()) {
    stderr.writeln(
      'Manifest not found: $_manifestPath (run from apps/mobile_flutter)',
    );
    exitCode = 1;
    return;
  }

  final map =
      (jsonDecode(manifest.readAsStringSync()) as Map).cast<String, dynamic>();
  final slugs = <String>{};
  for (final key in map.keys) {
    final i = key.lastIndexOf('-');
    if (i <= 0) continue;
    final cc = key.substring(0, i).toLowerCase();
    final dir = key.substring(i + 1).toLowerCase();
    if (dir != 'entry' && dir != 'exit') continue;
    // Only real ISO-2 country codes; the renderer derives the flag from the cc.
    if (cc.length != 2) continue;
    slugs.add('${cc}_$dir');
  }
  final sorted = slugs.toList()..sort();

  final b =
      StringBuffer()
        ..writeln('// GENERATED FILE — do not edit by hand.')
        ..writeln('//')
        ..writeln('// Regenerate with:')
        ..writeln('//   dart run tool/generate_studio_v2_passport_stamps.dart')
        ..writeln('//')
        ..writeln(
          '// The Studio V2 passport-stamp inventory: every bundled real',
        )
        ..writeln(
          '// entry/exit stamp, as `<cc>_<entry|exit>` slugs, derived from',
        )
        ..writeln(
          '// `assets/mobile_meta/stamp_manifest.json`. Feeds the generator so the',
        )
        ..writeln(
          '// Passport direction has available subjects on device; the artwork itself',
        )
        ..writeln('// is loaded through `bundle_asset_resolver.dart`.')
        ..writeln('')
        ..writeln(
          '/// Bundled passport-stamp slugs (`au_entry`, `au_exit`, …), sorted.',
        )
        ..writeln('const List<String> kStudioV2PassportStampSlugs = [');
  for (final s in sorted) {
    b.writeln("  '$s',");
  }
  b.writeln('];');

  File(_outPath).writeAsStringSync(b.toString());
  stdout.writeln('Wrote $_outPath (${sorted.length} stamp slugs).');
}
