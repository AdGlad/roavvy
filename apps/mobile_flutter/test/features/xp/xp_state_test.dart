// T2.8 — XP level threshold and state computation unit tests
//
// Tests the pure xpStateFromTotal() function from xp_event.dart.
// Thresholds: [0, 100, 250, 500, 1000, 2000, 4000, 8000]
// Labels:     Traveller, Explorer, Navigator, Globetrotter,
//             Pathfinder, Voyager, Pioneer, Legend

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/xp/xp_event.dart';

void main() {
  // ── Level boundaries ───────────────────────────────────────────────────────

  group('xpStateFromTotal — level 1 (Traveller, 0–99 XP)', () {
    test('0 XP → level 1', () {
      expect(xpStateFromTotal(0).level, equals(1));
    });

    test('0 XP → labelː Traveller', () {
      expect(xpStateFromTotal(0).levelLabel, equals('Traveller'));
    });

    test('99 XP → level 1 (one below level 2 boundary)', () {
      expect(xpStateFromTotal(99).level, equals(1));
    });
  });

  group('xpStateFromTotal — level 2 (Explorer, 100–249 XP)', () {
    test('100 XP → level 2 (exactly at boundary)', () {
      expect(xpStateFromTotal(100).level, equals(2));
    });

    test('100 XP → label: Explorer', () {
      expect(xpStateFromTotal(100).levelLabel, equals('Explorer'));
    });

    test('249 XP → level 2 (one below level 3 boundary)', () {
      expect(xpStateFromTotal(249).level, equals(2));
    });
  });

  group('xpStateFromTotal — level 3 (Navigator, 250–499 XP)', () {
    test('250 XP → level 3 (exactly at boundary)', () {
      expect(xpStateFromTotal(250).level, equals(3));
    });

    test('250 XP → label: Navigator', () {
      expect(xpStateFromTotal(250).levelLabel, equals('Navigator'));
    });

    test('499 XP → level 3', () {
      expect(xpStateFromTotal(499).level, equals(3));
    });
  });

  group('xpStateFromTotal — level 4 (Globetrotter, 500–999 XP)', () {
    test('500 XP → level 4', () {
      expect(xpStateFromTotal(500).level, equals(4));
    });

    test('500 XP → label: Globetrotter', () {
      expect(xpStateFromTotal(500).levelLabel, equals('Globetrotter'));
    });

    test('999 XP → level 4', () {
      expect(xpStateFromTotal(999).level, equals(4));
    });
  });

  group('xpStateFromTotal — level 5 (Pathfinder, 1000–1999 XP)', () {
    test('1000 XP → level 5', () {
      expect(xpStateFromTotal(1000).level, equals(5));
    });

    test('1000 XP → label: Pathfinder', () {
      expect(xpStateFromTotal(1000).levelLabel, equals('Pathfinder'));
    });
  });

  group('xpStateFromTotal — level 6 (Voyager, 2000–3999 XP)', () {
    test('2000 XP → level 6', () {
      expect(xpStateFromTotal(2000).level, equals(6));
    });

    test('2000 XP → label: Voyager', () {
      expect(xpStateFromTotal(2000).levelLabel, equals('Voyager'));
    });
  });

  group('xpStateFromTotal — level 7 (Pioneer, 4000–7999 XP)', () {
    test('4000 XP → level 7', () {
      expect(xpStateFromTotal(4000).level, equals(7));
    });

    test('4000 XP → label: Pioneer', () {
      expect(xpStateFromTotal(4000).levelLabel, equals('Pioneer'));
    });
  });

  group('xpStateFromTotal — level 8 (Legend, 8000+ XP)', () {
    test('8000 XP → level 8 (max)', () {
      expect(xpStateFromTotal(8000).level, equals(8));
    });

    test('8000 XP → label: Legend', () {
      expect(xpStateFromTotal(8000).levelLabel, equals('Legend'));
    });

    test('10000 XP → level 8 (still max)', () {
      expect(xpStateFromTotal(10000).level, equals(8));
    });

    test('max level → xpToNextLevel is 0', () {
      expect(xpStateFromTotal(8000).xpToNextLevel, equals(0));
    });

    test('max level → progressFraction is 1.0', () {
      expect(xpStateFromTotal(8000).progressFraction, equals(1.0));
    });
  });

  // ── Progress fraction ──────────────────────────────────────────────────────

  group('xpStateFromTotal — progressFraction', () {
    test('0 XP → progressFraction is 0.0 (start of level 1)', () {
      expect(xpStateFromTotal(0).progressFraction, equals(0.0));
    });

    test('50 XP → progressFraction is 0.5 (midpoint of level 1: 0→100)', () {
      expect(xpStateFromTotal(50).progressFraction, closeTo(0.5, 0.001));
    });

    test('100 XP → progressFraction is 0.0 (start of level 2: 100→250)', () {
      expect(xpStateFromTotal(100).progressFraction, closeTo(0.0, 0.001));
    });

    test('175 XP → progressFraction is 0.5 (midpoint of level 2: 100→250)', () {
      expect(xpStateFromTotal(175).progressFraction, closeTo(0.5, 0.001));
    });

    test('progressFraction is always in [0.0, 1.0] for all levels', () {
      for (final xp in [0, 99, 100, 249, 250, 499, 500, 999, 1000, 7999, 8000, 10000]) {
        final frac = xpStateFromTotal(xp).progressFraction;
        expect(frac, inInclusiveRange(0.0, 1.0),
            reason: 'progressFraction out of range for XP=$xp');
      }
    });
  });

  // ── xpToNextLevel ──────────────────────────────────────────────────────────

  group('xpStateFromTotal — xpToNextLevel', () {
    test('0 XP → needs 100 more to reach level 2', () {
      expect(xpStateFromTotal(0).xpToNextLevel, equals(100));
    });

    test('100 XP → needs 150 more to reach level 3', () {
      expect(xpStateFromTotal(100).xpToNextLevel, equals(150));
    });

    test('7999 XP → needs 1 more to reach level 8', () {
      expect(xpStateFromTotal(7999).xpToNextLevel, equals(1));
    });
  });

  // ── kXpThresholds and kLevelLabels completeness ────────────────────────────

  group('kXpThresholds and kLevelLabels', () {
    test('thresholds and labels have equal length', () {
      expect(kXpThresholds.length, equals(kLevelLabels.length));
    });

    test('thresholds are strictly ascending', () {
      for (int i = 1; i < kXpThresholds.length; i++) {
        expect(kXpThresholds[i], greaterThan(kXpThresholds[i - 1]),
            reason: 'Threshold at index $i is not greater than index ${i - 1}');
      }
    });

    test('first threshold is 0 (start at level 1 with any XP)', () {
      expect(kXpThresholds.first, equals(0));
    });

    test('all level labels are non-empty strings', () {
      for (final label in kLevelLabels) {
        expect(label, isNotEmpty);
      }
    });
  });
}
