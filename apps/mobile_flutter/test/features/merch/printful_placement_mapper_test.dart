// T2.1 — PrintfulPlacementMapper unit tests

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/merch/printful_placement_mapper.dart';

void main() {
  group('PrintfulPlacementMapper.mapFront', () {
    test('center maps to front', () {
      expect(PrintfulPlacementMapper.mapFront('center'), equals('front'));
    });

    test('left_chest maps to front_left', () {
      expect(
        PrintfulPlacementMapper.mapFront('left_chest'),
        equals('front_left'),
      );
    });

    test('right_chest maps to front_right', () {
      expect(
        PrintfulPlacementMapper.mapFront('right_chest'),
        equals('front_right'),
      );
    });

    test('none maps to front (blank shirt, no artwork)', () {
      expect(PrintfulPlacementMapper.mapFront('none'), equals('front'));
    });

    test('unknown position throws ArgumentError', () {
      expect(
        () => PrintfulPlacementMapper.mapFront('full_back'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('empty string throws ArgumentError', () {
      expect(
        () => PrintfulPlacementMapper.mapFront(''),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('all known front positions produce non-empty Printful value', () {
      for (final pos in ['center', 'left_chest', 'right_chest', 'none']) {
        final result = PrintfulPlacementMapper.mapFront(pos);
        expect(
          result,
          isNotEmpty,
          reason: 'mapFront($pos) returned empty string',
        );
      }
    });
  });

  group('PrintfulPlacementMapper.mapBack', () {
    test('center maps to back', () {
      expect(PrintfulPlacementMapper.mapBack('center'), equals('back'));
    });

    test('none maps to back (blank shirt back, no artwork)', () {
      expect(PrintfulPlacementMapper.mapBack('none'), equals('back'));
    });

    test('unknown position throws ArgumentError', () {
      expect(
        () => PrintfulPlacementMapper.mapBack('left_chest'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('empty string throws ArgumentError', () {
      expect(
        () => PrintfulPlacementMapper.mapBack(''),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('all known back positions produce non-empty Printful value', () {
      for (final pos in ['center', 'none']) {
        final result = PrintfulPlacementMapper.mapBack(pos);
        expect(
          result,
          isNotEmpty,
          reason: 'mapBack($pos) returned empty string',
        );
      }
    });
  });

  group('PrintfulPlacementMapper.sendsArtwork', () {
    test('center sends artwork', () {
      expect(PrintfulPlacementMapper.sendsArtwork('center'), isTrue);
    });

    test('left_chest sends artwork', () {
      expect(PrintfulPlacementMapper.sendsArtwork('left_chest'), isTrue);
    });

    test('right_chest sends artwork', () {
      expect(PrintfulPlacementMapper.sendsArtwork('right_chest'), isTrue);
    });

    test('none does not send artwork (blank product)', () {
      expect(PrintfulPlacementMapper.sendsArtwork('none'), isFalse);
    });
  });
}
