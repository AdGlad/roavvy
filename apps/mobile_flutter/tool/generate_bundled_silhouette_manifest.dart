// Dev script: regenerates lib/features/merch/bundled_silhouette_manifest.dart
// from the actual bundled files in assets/silhouettes/.
//
// Run from the app root (apps/mobile_flutter):
//   dart run tool/generate_bundled_silhouette_manifest.dart
//
// It scans `assets/silhouettes/*.svg`, parses each `{cc}_{slug}.svg` filename
// into an ISO-2 (uppercase) → slug entry, and rewrites the const map. Kept as a
// committed script so the manifest can be regenerated whenever silhouette art is
// added or removed, without hand-editing the generated file.
import 'dart:io';

const _assetDir = 'assets/silhouettes';
const _outPath = 'lib/features/merch/bundled_silhouette_manifest.dart';

void main() {
  final dir = Directory(_assetDir);
  if (!dir.existsSync()) {
    stderr.writeln('Asset dir not found: $_assetDir (run from apps/mobile_flutter)');
    exitCode = 1;
    return;
  }

  final entries = <String, String>{};
  for (final f in dir.listSync().whereType<File>()) {
    final name = f.uri.pathSegments.last;
    if (!name.endsWith('.svg')) continue;
    final base = name.substring(0, name.length - 4); // drop ".svg"
    final us = base.indexOf('_');
    if (us <= 0 || us == base.length - 1) continue;
    final cc = base.substring(0, us).toUpperCase();
    final slug = base.substring(us + 1);
    entries[cc] = slug;
  }

  final keys = entries.keys.toList()..sort();
  final b = StringBuffer()
    ..writeln('// GENERATED FILE — do not edit by hand.')
    ..writeln('//')
    ..writeln('// Regenerate with:')
    ..writeln('//   dart run tool/generate_bundled_silhouette_manifest.dart')
    ..writeln('//')
    ..writeln('// Maps each ISO-2 country code (UPPERCASE) to the slug of its ONE bundled')
    ..writeln('// national-silhouette asset at `assets/silhouettes/{cc}_{slug}.svg` (with a')
    ..writeln('// matching `.png`). The subject varies (animal, landmark, or plant) but every')
    ..writeln('// entry here is guaranteed to exist as a bundled asset, so it can be clipped')
    ..writeln('// 100% locally with no network — this is the offline-safe complement to')
    ..writeln("// [AnimalSilhouetteService]'s Firebase-Storage-backed silhouette set.")
    ..writeln('//')
    ..writeln('// The procedural design engine consults this map (synchronously, deterministically)')
    ..writeln('// to decide whether a single-country design may emit a national-silhouette clip.')
    ..writeln()
    ..writeln('/// ISO-2 (UPPERCASE) → bundled silhouette slug. Derived from the actual files in')
    ..writeln("/// `assets/silhouettes/`, NOT from `assets/symbols/animal_slugs.json` (whose")
    ..writeln('/// slugs do not reliably match the bundled filenames).')
    ..writeln('const Map<String, String> kBundledSilhouetteSlugs = {');
  for (final cc in keys) {
    b.writeln("  '$cc': '${entries[cc]}',");
  }
  b
    ..writeln('};')
    ..writeln()
    ..writeln('/// Runtime accessor over [kBundledSilhouetteSlugs]. Pure, synchronous, and')
    ..writeln('/// deterministic so the procedural generator can consult it inside a')
    ..writeln('/// seed-driven sampling loop without any async/network work.')
    ..writeln('class BundledSilhouetteManifest {')
    ..writeln('  const BundledSilhouetteManifest._();')
    ..writeln()
    ..writeln('  /// Asset directory holding the bundled silhouette SVG/PNG pairs.')
    ..writeln("  static const String assetDir = 'assets/silhouettes';")
    ..writeln()
    ..writeln('  /// Whether [countryCode] (any case) has a bundled national silhouette.')
    ..writeln('  static bool hasFor(String countryCode) =>')
    ..writeln('      kBundledSilhouetteSlugs.containsKey(countryCode.toUpperCase());')
    ..writeln()
    ..writeln('  /// The bundled silhouette slug for [countryCode], or null if none is bundled.')
    ..writeln('  static String? slugFor(String countryCode) =>')
    ..writeln('      kBundledSilhouetteSlugs[countryCode.toUpperCase()];')
    ..writeln()
    ..writeln('  /// Whether the composite (country, slug) names a bundled silhouette — i.e.')
    ..writeln('  /// the slug matches the one bundled asset for that country. Used by the local')
    ..writeln('  /// clip loader to decide bundled-vs-network without touching the filesystem.')
    ..writeln('  static bool isBundled(String countryCode, String slug) =>')
    ..writeln('      kBundledSilhouetteSlugs[countryCode.toUpperCase()] == slug;')
    ..writeln()
    ..writeln('  /// The bundled SVG asset path for [countryCode] + [slug], or null if that')
    ..writeln('  /// pair is not bundled. Filenames are lowercase `{cc}_{slug}.svg`.')
    ..writeln('  static String? assetPathFor(String countryCode, String slug) {')
    ..writeln('    if (!isBundled(countryCode, slug)) return null;')
    ..writeln("    return '\$assetDir/\${countryCode.toLowerCase()}_\$slug.svg';")
    ..writeln('  }')
    ..writeln()
    ..writeln('  /// How many countries have a bundled silhouette.')
    ..writeln('  static int get count => kBundledSilhouetteSlugs.length;')
    ..writeln('}');

  File(_outPath).writeAsStringSync(b.toString());
  stdout.writeln('Wrote ${entries.length} entries to $_outPath');
}
