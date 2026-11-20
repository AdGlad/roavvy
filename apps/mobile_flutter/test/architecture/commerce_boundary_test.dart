import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// ADR-180 / M186: every route into commerce goes through
/// `features/commerce_entry/`, so one switch hides all of it.
///
/// Fails if a library outside the commerce feature folders imports a commerce
/// screen, sheet or entry widget directly. Add new commerce CTAs through
/// `CommerceEntry` / `CommerceGate` instead.
void main() {
  const lib = 'lib';

  // Folders that ARE commerce, plus the seam itself.
  bool isCommerceOwner(String rel) =>
      rel.startsWith('features/merch/') ||
      RegExp(r'^features/studio_v2[a-z_]*/').hasMatch(rel) ||
      rel.startsWith('features/commerce_entry/');

  // Dev-only entrypoints that boot commerce tools directly.
  const devEntrypoints = {'main_studio_v2.dart', 'main_mockup_lab.dart'};

  // Free features that happen to live in features/merch/.
  const freeInMerch = {
    'features/merch/travel_story_screen.dart', // the year/scan story
  };

  bool isCommerceRoute(String rel) {
    final inCommerce =
        rel.startsWith('features/merch/') ||
        RegExp(r'^features/studio_v2[a-z_]*/').hasMatch(rel);
    if (!inCommerce || freeInMerch.contains(rel)) return false;
    return RegExp(r'_(screen|sheet|entry)\.dart$').hasMatch(rel);
  }

  final importRe = RegExp(r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''');

  test('only commerce_entry imports commerce screens', () {
    final violations = <String>[];
    final files = Directory(lib)
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));

    for (final file in files) {
      final rel = file.path.replaceAll(r'\', '/').substring('$lib/'.length);
      if (isCommerceOwner(rel) || devEntrypoints.contains(rel)) continue;

      for (final line in file.readAsLinesSync()) {
        final m = importRe.firstMatch(line);
        if (m == null) continue;
        final uri = m.group(1)!;
        String? target;
        if (uri.startsWith('package:mobile_flutter/')) {
          target = uri.substring('package:mobile_flutter/'.length);
        } else if (!uri.contains(':')) {
          target = Uri.parse('file:///$rel').resolve(uri).path.substring(1);
        }
        if (target != null && isCommerceRoute(target)) {
          violations.add('$rel → $target');
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'Commerce screens must be opened through '
          'features/commerce_entry/commerce_entry.dart (ADR-180).',
    );
  });

  test('commerce Cloud Functions are only called from commerce code', () {
    // M187: a commerce-off session must make no commerce network calls, so
    // the callables must stay behind the screens CommerceEntry gates.
    final callable = RegExp(
      r'''httpsCallable\(\s*['"](createMerchCart|getMerchPrices)['"]''',
    );
    final violations = <String>[];
    for (final file
        in Directory(lib).listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      final rel = file.path.replaceAll(r'\', '/').substring('$lib/'.length);
      if (isCommerceOwner(rel)) continue;
      if (callable.hasMatch(file.readAsStringSync())) violations.add(rel);
    }
    expect(violations, isEmpty);
  });

  test('the rule catches a direct import (self-check)', () {
    expect(isCommerceRoute('features/merch/merch_orders_screen.dart'), isTrue);
    expect(
      isCommerceRoute('features/studio_v2_commerce/studio_v2_entry.dart'),
      isTrue,
    );
    expect(isCommerceRoute('features/merch/travel_story_screen.dart'), isFalse);
    expect(isCommerceRoute('features/merch/merch_preset.dart'), isFalse);
  });
}
