// T2.2 — MerchTemplateRanker unit tests

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/merch/merch_template_ranker.dart';
import 'package:shared_models/shared_models.dart';

void main() {
  // ── densityFor ─────────────────────────────────────────────────────────────

  group('MerchTemplateRanker.densityFor', () {
    test('0 countries → solo', () {
      expect(MerchTemplateRanker.densityFor(0), MerchDensityClass.solo);
    });

    test('1 country → solo', () {
      expect(MerchTemplateRanker.densityFor(1), MerchDensityClass.solo);
    });

    test('2 countries → small', () {
      expect(MerchTemplateRanker.densityFor(2), MerchDensityClass.small);
    });

    test('5 countries → small (upper boundary)', () {
      expect(MerchTemplateRanker.densityFor(5), MerchDensityClass.small);
    });

    test('6 countries → medium (lower boundary)', () {
      expect(MerchTemplateRanker.densityFor(6), MerchDensityClass.medium);
    });

    test('15 countries → medium (upper boundary)', () {
      expect(MerchTemplateRanker.densityFor(15), MerchDensityClass.medium);
    });

    test('16 countries → large (lower boundary)', () {
      expect(MerchTemplateRanker.densityFor(16), MerchDensityClass.large);
    });

    test('50 countries → large (upper boundary)', () {
      expect(MerchTemplateRanker.densityFor(50), MerchDensityClass.large);
    });

    test('51 countries → massive (lower boundary)', () {
      expect(MerchTemplateRanker.densityFor(51), MerchDensityClass.massive);
    });

    test('100 countries → massive', () {
      expect(MerchTemplateRanker.densityFor(100), MerchDensityClass.massive);
    });
  });

  // ── densityForStamps ───────────────────────────────────────────────────────

  group('MerchTemplateRanker.densityForStamps', () {
    test('1 stamp → solo', () {
      expect(MerchTemplateRanker.densityForStamps(1), MerchDensityClass.solo);
    });

    test('2 stamps → solo (upper boundary)', () {
      expect(MerchTemplateRanker.densityForStamps(2), MerchDensityClass.solo);
    });

    test('3 stamps → small (lower boundary)', () {
      expect(MerchTemplateRanker.densityForStamps(3), MerchDensityClass.small);
    });

    test('8 stamps → small (upper boundary)', () {
      expect(MerchTemplateRanker.densityForStamps(8), MerchDensityClass.small);
    });

    test('9 stamps → medium (lower boundary)', () {
      expect(MerchTemplateRanker.densityForStamps(9), MerchDensityClass.medium);
    });

    test('24 stamps → medium (upper boundary)', () {
      expect(
        MerchTemplateRanker.densityForStamps(24),
        MerchDensityClass.medium,
      );
    });

    test('25 stamps → large (lower boundary)', () {
      expect(MerchTemplateRanker.densityForStamps(25), MerchDensityClass.large);
    });

    test('75 stamps → massive (lower boundary)', () {
      expect(
        MerchTemplateRanker.densityForStamps(75),
        MerchDensityClass.massive,
      );
    });
  });

  // ── rankFor — density-based (no achievement) ───────────────────────────────

  group('MerchTemplateRanker.rankFor — solo (1 country)', () {
    late List<MerchTemplateRank> ranks;

    setUp(() {
      ranks = MerchTemplateRanker.rankFor(codeCount: 1);
    });

    test('passport is ranked first (priority 1)', () {
      final passport = ranks.firstWhere(
        (r) => r.template == CardTemplateType.passport,
      );
      expect(passport.priority, equals(1));
      expect(passport.exclude, isFalse);
    });

    test('wordCloud is excluded for solo', () {
      final wc = ranks.firstWhere(
        (r) => r.template == CardTemplateType.wordCloud,
      );
      expect(wc.exclude, isTrue);
    });

    test('frontRibbon is excluded for solo', () {
      final ribbon = ranks.firstWhere(
        (r) => r.template == CardTemplateType.frontRibbon,
      );
      expect(ribbon.exclude, isTrue);
    });

    test('list is sorted by priority ascending', () {
      final priorities = ranks.map((r) => r.priority).toList();
      final sorted = [...priorities]..sort();
      expect(priorities, equals(sorted));
    });

    test('every CardTemplateType appears in result', () {
      final templates = ranks.map((r) => r.template).toSet();
      for (final t in CardTemplateType.values) {
        expect(templates, contains(t), reason: '${t.name} missing from ranks');
      }
    });
  });

  group('MerchTemplateRanker.rankFor — small (3 countries)', () {
    late List<MerchTemplateRank> ranks;

    setUp(() {
      ranks = MerchTemplateRanker.rankFor(codeCount: 3);
    });

    test('passport ranked above grid for small (priority 1 vs 2)', () {
      final passport = ranks.firstWhere(
        (r) => r.template == CardTemplateType.passport,
      );
      final grid = ranks.firstWhere((r) => r.template == CardTemplateType.grid);
      expect(passport.priority, lessThan(grid.priority));
    });

    test('frontRibbon is excluded', () {
      final ribbon = ranks.firstWhere(
        (r) => r.template == CardTemplateType.frontRibbon,
      );
      expect(ribbon.exclude, isTrue);
    });
  });

  group('MerchTemplateRanker.rankFor — large (16+ countries)', () {
    test('badge is excluded for 16 countries (large density)', () {
      final ranks = MerchTemplateRanker.rankFor(codeCount: 16);
      final badge = ranks.firstWhere(
        (r) => r.template == CardTemplateType.badge,
      );
      expect(badge.exclude, isTrue);
    });

    test('badge is excluded for 20 countries', () {
      final ranks = MerchTemplateRanker.rankFor(codeCount: 20);
      final badge = ranks.firstWhere(
        (r) => r.template == CardTemplateType.badge,
      );
      expect(badge.exclude, isTrue);
    });
  });

  // ── rankFor — achievement-scoped ───────────────────────────────────────────

  group('MerchTemplateRanker.rankFor — continent achievement', () {
    Achievement _continentAchievement(String continent) => Achievement(
      id: 'europe_10',
      title: 'Europe Explorer',
      description: '',
      category: AchievementCategory.countries,
      progressTarget: 10,
      continentScope: continent,
    );

    test('badge is ranked first for continent achievement (≤15 countries)', () {
      final ranks = MerchTemplateRanker.rankFor(
        achievement: _continentAchievement('Europe'),
        codeCount: 8,
      );
      final badge = ranks.firstWhere(
        (r) => r.template == CardTemplateType.badge,
      );
      expect(badge.priority, equals(1));
      expect(badge.exclude, isFalse);
    });

    test('badge is excluded for continent achievement with >15 countries', () {
      final ranks = MerchTemplateRanker.rankFor(
        achievement: _continentAchievement('Europe'),
        codeCount: 16,
      );
      final badge = ranks.firstWhere(
        (r) => r.template == CardTemplateType.badge,
      );
      expect(badge.exclude, isTrue);
    });

    test('frontRibbon is excluded for continent achievement', () {
      final ranks = MerchTemplateRanker.rankFor(
        achievement: _continentAchievement('Asia'),
        codeCount: 5,
      );
      final ribbon = ranks.firstWhere(
        (r) => r.template == CardTemplateType.frontRibbon,
      );
      expect(ribbon.exclude, isTrue);
    });
  });

  group('MerchTemplateRanker.rankFor — passport milestone achievement', () {
    final passportAchievement = Achievement(
      id: 'stamps_10',
      title: '10 Stamps',
      description: '',
      category: AchievementCategory.trips,
      progressTarget: 10,
      merch: MerchTriggerType.passportStamp,
    );

    test('passport ranked first', () {
      final ranks = MerchTemplateRanker.rankFor(
        achievement: passportAchievement,
        codeCount: 5,
      );
      final passport = ranks.firstWhere(
        (r) => r.template == CardTemplateType.passport,
      );
      expect(passport.priority, equals(1));
    });

    test('badge is excluded for passport milestone', () {
      final ranks = MerchTemplateRanker.rankFor(
        achievement: passportAchievement,
        codeCount: 5,
      );
      final badge = ranks.firstWhere(
        (r) => r.template == CardTemplateType.badge,
      );
      expect(badge.exclude, isTrue);
    });
  });

  group('MerchTemplateRanker.rankFor — thisYear achievement', () {
    final yearAchievement = Achievement(
      id: 'thisyear_5',
      title: '5 Countries This Year',
      description: '',
      category: AchievementCategory.thisYear,
      progressTarget: 5,
    );

    test('timeline ranked first for thisYear achievement', () {
      final ranks = MerchTemplateRanker.rankFor(
        achievement: yearAchievement,
        codeCount: 5,
      );
      final timeline = ranks.firstWhere(
        (r) => r.template == CardTemplateType.timeline,
      );
      expect(timeline.priority, equals(1));
    });

    test('badge is excluded for thisYear achievement', () {
      final ranks = MerchTemplateRanker.rankFor(
        achievement: yearAchievement,
        codeCount: 5,
      );
      final badge = ranks.firstWhere(
        (r) => r.template == CardTemplateType.badge,
      );
      expect(badge.exclude, isTrue);
    });
  });

  // ── maxForDensity ──────────────────────────────────────────────────────────

  group('MerchTemplateRanker.maxForDensity', () {
    test('solo → 4', () {
      expect(
        MerchTemplateRanker.maxForDensity(MerchDensityClass.solo),
        equals(4),
      );
    });

    test('small → 5', () {
      expect(
        MerchTemplateRanker.maxForDensity(MerchDensityClass.small),
        equals(5),
      );
    });

    test('medium → 6', () {
      expect(
        MerchTemplateRanker.maxForDensity(MerchDensityClass.medium),
        equals(6),
      );
    });

    test('large → 5', () {
      expect(
        MerchTemplateRanker.maxForDensity(MerchDensityClass.large),
        equals(5),
      );
    });

    test('massive → 4', () {
      expect(
        MerchTemplateRanker.maxForDensity(MerchDensityClass.massive),
        equals(4),
      );
    });
  });
}
