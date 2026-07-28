// M202 — AI design critic: flag-gating, timeout, error, and thumbnail-only
// payload behaviour. The critic must NEVER throw and must return the input
// unchanged whenever it cannot improve it, so the heuristic result always wins.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/cards/flag_grid_layout_engine.dart';
import 'package:mobile_flutter/features/merch/design_engine/ai_critic.dart';
import 'package:mobile_flutter/features/merch/design_engine/design_engine_contracts.dart';
import 'package:mobile_flutter/features/merch/design_engine/design_params.dart';
import 'package:mobile_flutter/features/merch/design_engine/optimization_loop.dart';
import 'package:mobile_flutter/features/merch/merch_preset.dart';
import 'package:mobile_flutter/features/merch/product_mockup_specs.dart';
import 'package:shared_models/shared_models.dart';

DesignCandidate _candidate(
  String colour, {
  required double aesthetic,
  Uint8List? thumb,
}) {
  final params = DesignParams(
    template: CardTemplateType.grid,
    source: MerchCountrySource.allTime,
    countryCodes: const ['FR', 'DE'],
    shirtColour: colour,
  );
  return DesignCandidate(
    params: params,
    score: DesignScore(printable: true, aesthetic: aesthetic, profileFit: 0.5),
    thumbnail: thumb ?? Uint8List.fromList([1, 2, 3, 4]),
  );
}

void main() {
  group('AiCritic', () {
    final finalists = [
      _candidate('Black', aesthetic: 0.6),
      _candidate('White', aesthetic: 0.5),
      _candidate('Blue', aesthetic: 0.4),
    ];

    test('flag OFF → returns the input unchanged, caller never invoked', () async {
      var called = false;
      final critic = AiCritic(
        isEnabled: () => false,
        caller: (designs, timeout) async {
          called = true;
          return const [];
        },
      );
      final out = await critic.refine(finalists, timeout: const Duration(seconds: 2));
      expect(identical(out, finalists), isTrue);
      expect(called, isFalse);
      expect(critic.isEnabled, isFalse);
    });

    test('timeout → returns the input unchanged, never throws', () async {
      final critic = AiCritic(
        isEnabled: () => true,
        caller: (designs, timeout) =>
            // Never completes within the caller-supplied timeout.
            Future<List<Map<String, dynamic>>>.delayed(
                const Duration(seconds: 10), () => const []),
      );
      final out = await critic.refine(
        finalists,
        timeout: const Duration(milliseconds: 50),
      );
      expect(out, equals(finalists));
    });

    test('caller error → returns the input unchanged, never throws', () async {
      final critic = AiCritic(
        isEnabled: () => true,
        caller: (designs, timeout) async => throw Exception('network down'),
      );
      final out = await critic.refine(finalists, timeout: const Duration(seconds: 1));
      expect(out, equals(finalists));
    });

    test('zero remaining budget → no-op passthrough', () async {
      var called = false;
      final critic = AiCritic(
        isEnabled: () => true,
        caller: (designs, timeout) async {
          called = true;
          return const [];
        },
      );
      final out = await critic.refine(finalists, timeout: Duration.zero);
      expect(out, equals(finalists));
      expect(called, isFalse);
    });

    test('sends thumbnails (base64) + genome metadata only — no photos', () async {
      late List<Map<String, dynamic>> sent;
      final critic = AiCritic(
        isEnabled: () => true,
        caller: (designs, timeout) async {
          sent = designs;
          return const [];
        },
      );
      await critic.refine(finalists, timeout: const Duration(seconds: 1));

      expect(sent, hasLength(3));
      final first = sent.first;
      expect(first.keys, containsAll(<String>[
        'paramsHash',
        'thumbnailBase64',
        'template',
        'countryCount',
        'shirtColour',
      ]));
      // Data policy: never a photo / GPS / asset field.
      expect(first.containsKey('photo'), isFalse);
      expect(first.containsKey('latitude'), isFalse);
      expect(first.containsKey('assetId'), isFalse);
      // The thumbnail is the decoded design bytes, base64-encoded.
      expect(first['thumbnailBase64'], base64Encode(Uint8List.fromList([1, 2, 3, 4])));
      expect(first['countryCount'], 2);
    });

    test('a verdict re-ranks the finalists best-first', () async {
      final critic = AiCritic(
        isEnabled: () => true,
        // Give the last (heuristically-weakest) design the top aesthetic score.
        caller: (designs, timeout) async => [
          {'index': 0, 'aestheticScore': 0.1, 'hints': <String>[]},
          {'index': 1, 'aestheticScore': 0.2, 'hints': <String>[]},
          {'index': 2, 'aestheticScore': 1.0, 'hints': <String>[]},
        ],
      );
      final out = await critic.refine(finalists, timeout: const Duration(seconds: 1));
      expect(out.first.params.shirtColour, 'Blue'); // was last, now first
      expect(out, hasLength(3));
    });

    test('candidates without thumbnails are skipped (passthrough if none)', () async {
      var called = false;
      final noThumbs = [
        _candidate('Black', aesthetic: 0.6, thumb: Uint8List(0)),
      ];
      final critic = AiCritic(
        isEnabled: () => true,
        caller: (designs, timeout) async {
          called = true;
          return const [];
        },
      );
      final out = await critic.refine(noThumbs, timeout: const Duration(seconds: 1));
      expect(out, equals(noThumbs));
      expect(called, isFalse);
    });
  });
}
