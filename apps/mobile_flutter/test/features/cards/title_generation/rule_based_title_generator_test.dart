import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/cards/title_generation/rule_based_title_generator.dart';
import 'package:mobile_flutter/features/cards/title_generation/title_generation_models.dart';
import 'package:shared_models/shared_models.dart';

TitleGenerationRequest _req({
  required List<String> codes,
  List<HeroLabels>? heroLabels,
}) {
  return TitleGenerationRequest(
    countryCodes: codes,
    countryNames: codes,
    regionNames: const [],
    cardType: CardTemplateType.grid,
    heroLabels: heroLabels,
  );
}

void main() {
  // Fresh generator each test — uses a new Random so we don't rely on seeded
  // output order. Assertions use isIn(validOptions) instead of exact equality.
  RuleBasedTitleGenerator gen() => RuleBasedTitleGenerator();

  // ── Year-free guarantee ────────────────────────────────────────────────────

  test('no title contains a digit (year guard)', () async {
    final cases = [
      _req(codes: []),
      _req(codes: ['JP']),
      _req(codes: ['NO', 'SE', 'DK']),
      _req(codes: ['MV', 'SC']),
      _req(codes: ['FJ', 'WS']),
      _req(codes: ['FR', 'IT', 'ES']),
      _req(codes: ['JP', 'BR', 'US', 'DE']),
    ];
    for (final req in cases) {
      final result = await gen().generate(req);
      expect(result.title, isNot(matches(RegExp(r'\d'))),
          reason: 'Title "${result.title}" must not contain digits');
    }
  });

  // ── Empty / single country ─────────────────────────────────────────────────

  test('empty list returns a valid world-level title', () async {
    final result = await gen().generate(_req(codes: []));
    expect(result.title,
        isIn(['World Tour', 'Everywhere', 'Global Wander']));
    expect(result.source, TitleSource.fallback);
  });

  test('single country returns country name', () async {
    final result = await gen().generate(_req(codes: ['JP']));
    expect(result.title, 'Japan');
  });

  test('single country (FR) returns France', () async {
    final result = await gen().generate(_req(codes: ['FR']));
    expect(result.title, 'France');
  });

  // ── Sub-region clusters ────────────────────────────────────────────────────

  test('{NO, SE, DK} → one of the Nordic options', () async {
    final result = await gen().generate(_req(codes: ['NO', 'SE', 'DK']));
    expect(result.title,
        isIn(['Nordic Wander', 'Northern Lights', 'Fjord Life']));
  });

  test('{NO, SE, FI, IS, DK} → one of the Nordic options (full cluster)',
      () async {
    final result =
        await gen().generate(_req(codes: ['NO', 'SE', 'FI', 'IS', 'DK']));
    expect(result.title,
        isIn(['Nordic Wander', 'Northern Lights', 'Fjord Life']));
  });

  test('{MV, SC} → one of the Indian Ocean options', () async {
    final result = await gen().generate(_req(codes: ['MV', 'SC']));
    expect(result.title,
        isIn(['Indian Ocean', 'Turquoise Run', 'Island Escape']));
  });

  test('{FJ, WS} → one of the Pacific Islands options', () async {
    final result = await gen().generate(_req(codes: ['FJ', 'WS']));
    expect(result.title,
        isIn(['Pacific Islands', 'Island Life', 'Blue Horizon']));
  });

  test('{ES, PT} → one of the Iberian Road options', () async {
    final result = await gen().generate(_req(codes: ['ES', 'PT']));
    expect(result.title,
        isIn(['Iberian Road', 'Sun and Tapas', 'Atlantic Drive']));
  });

  test('{GB, IE} → one of the British Isles options', () async {
    final result = await gen().generate(_req(codes: ['GB', 'IE']));
    expect(result.title,
        isIn(['British Isles', 'Island Hopping', 'Tea and Moors']));
  });

  test('{EE, LV, LT} → one of the Baltic Loop options', () async {
    final result = await gen().generate(_req(codes: ['EE', 'LV', 'LT']));
    expect(result.title,
        isIn(['Baltic Loop', 'Baltic Run', 'Coast to Coast']));
  });

  test('{JP, KR} → one of the East Asia options', () async {
    final result = await gen().generate(_req(codes: ['JP', 'KR']));
    expect(result.title,
        isIn(['East Asia', 'Far East Fix', 'Neon and Temples']));
  });

  // ── Cluster mismatch falls through to continent ────────────────────────────

  test('Nordic partial cluster does not trigger Nordic options', () async {
    final result = await gen().generate(_req(codes: ['NO', 'US']));
    expect(result.title, isNot(anyOf('Nordic Wander', 'Northern Lights', 'Fjord Life')));
  });

  test('{DE, IT, ES, PL} → one of the Euro continent options', () async {
    // Not a subset of any sub-region cluster → falls through to Europe.
    final result =
        await gen().generate(_req(codes: ['DE', 'IT', 'ES', 'PL']));
    expect(result.title,
        isIn(['Euro Wander', 'Old World Run', 'Across Europe']));
  });

  // ── Continent fallback ─────────────────────────────────────────────────────

  test('mixed continents returns non-empty title', () async {
    final result =
        await gen().generate(_req(codes: ['JP', 'BR', 'US', 'DE']));
    expect(result.title, isNotEmpty);
    expect(result.source, TitleSource.fallback);
  });

  test('dominant Asia continent → one of the Asia options', () async {
    // 3 Asian, 1 European → Asia dominates
    final result =
        await gen().generate(_req(codes: ['IN', 'PK', 'BD', 'DE']));
    expect(result.title,
        isIn(['Asian Escape', 'East of Everything', 'Far East Road']));
  });

  test('dominant Europe continent → one of the Euro options', () async {
    final result = await gen()
        .generate(_req(codes: ['DE', 'IT', 'ES', 'PL', 'US']));
    expect(result.title,
        isIn(['Euro Wander', 'Old World Run', 'Across Europe']));
  });

  // ── Variety guarantee ──────────────────────────────────────────────────────

  test('repeated calls for the same input produce more than one distinct title',
      () async {
    // 20 calls should produce at least 2 distinct titles from the pool.
    final req = _req(codes: ['NO', 'SE', 'DK']);
    final titles = <String>{};
    for (var i = 0; i < 20; i++) {
      final r = await gen().generate(req);
      titles.add(r.title);
    }
    expect(titles.length, greaterThan(1),
        reason: 'Titles must vary across calls (at least 2 distinct values)');
  });

  // ── Multi-country does not return single-country name ─────────────────────

  test('multi-country result is not a single country name', () async {
    final codes = ['JP', 'KR', 'CN'];
    final result = await gen().generate(_req(codes: codes));
    // Should not be 'Japan', 'South Korea', 'China', 'JP', 'KR', 'CN'
    for (final c in codes) {
      expect(result.title, isNot(c));
    }
    expect(result.title, isNot('Japan'));
    expect(result.title, isNot('China'));
  });

  // ── HeroLabelAggregator ────────────────────────────────────────────────────

  group('HeroLabelAggregator', () {
    test('empty list returns null', () {
      expect(HeroLabelAggregator.aggregate([]), isNull);
    });

    test('uniform labels return the shared value', () {
      final labels = [
        const HeroLabels(primaryScene: 'beach', mood: ['sunset'], confidence: 0.9),
        const HeroLabels(primaryScene: 'beach', mood: ['sunset'], confidence: 0.8),
      ];
      final result = HeroLabelAggregator.aggregate(labels);
      expect(result, isNotNull);
      expect(result!.primaryScene, 'beach');
      expect(result.mood, 'sunset');
    });

    test('mixed scenes: most-frequent wins', () {
      final labels = [
        const HeroLabels(primaryScene: 'mountain', confidence: 0.9),
        const HeroLabels(primaryScene: 'mountain', confidence: 0.8),
        const HeroLabels(primaryScene: 'beach', confidence: 0.95),
      ];
      final result = HeroLabelAggregator.aggregate(labels);
      expect(result!.primaryScene, 'mountain');
    });

    test('all null scenes returns null primaryScene', () {
      final labels = [
        const HeroLabels(mood: ['sunset'], confidence: 0.7),
      ];
      final result = HeroLabelAggregator.aggregate(labels);
      expect(result!.primaryScene, isNull);
      expect(result.mood, 'sunset');
    });

    test('all empty fields returns null', () {
      final labels = [const HeroLabels(confidence: 0.0)];
      expect(HeroLabelAggregator.aggregate(labels), isNull);
    });
  });

  // ── Label-based title generation (M92) ────────────────────────────────────

  group('label-based titles', () {
    test('beach + sunset → one of the Aegean Sunset combo options', () async {
      final result = await gen().generate(_req(
        codes: ['GR'],
        heroLabels: [
          const HeroLabels(primaryScene: 'beach', mood: ['sunset'], confidence: 0.9),
        ],
      ));
      expect(result.title,
          isIn(['Aegean Sunset', 'Shore at Dusk', 'Golden Coastline']));
    });

    test('mountain + golden_hour → one of the Alpine Gold combo options',
        () async {
      final result = await gen().generate(_req(
        codes: ['CH'],
        heroLabels: [
          const HeroLabels(
              primaryScene: 'mountain', mood: ['golden_hour'], confidence: 0.85),
        ],
      ));
      expect(result.title,
          isIn(['Alpine Gold', 'Mountain at Dusk', 'Peaks at Sunset']));
    });

    test('mountain + hiking activity → one of the Trail Blazer options',
        () async {
      final result = await gen().generate(_req(
        codes: ['NO'],
        heroLabels: [
          const HeroLabels(
              primaryScene: 'mountain', activity: ['hiking'], confidence: 0.8),
        ],
      ));
      expect(result.title,
          isIn(['Trail Blazer', 'Into the Mountains', 'High Country']));
    });

    test('desert + roadtrip → one of the Desert Drive options', () async {
      final result = await gen().generate(_req(
        codes: ['MA'],
        heroLabels: [
          const HeroLabels(
              primaryScene: 'desert', activity: ['roadtrip'], confidence: 0.7),
        ],
      ));
      expect(result.title,
          isIn(['Desert Drive', 'Dust Road', 'Endless Miles']));
    });

    test('city scene only → one of the Urban Escape solo options', () async {
      final result = await gen().generate(_req(
        codes: ['DE'],
        heroLabels: [
          const HeroLabels(primaryScene: 'city', confidence: 0.6),
        ],
      ));
      expect(result.title,
          isIn(['Urban Escape', 'City Break', 'Streets and Stories']));
    });

    test('sunset mood only → one of the Golden Hour solo options', () async {
      final result = await gen().generate(_req(
        codes: ['GR'],
        heroLabels: [
          const HeroLabels(mood: ['sunset'], confidence: 0.5),
        ],
      ));
      expect(result.title,
          isIn(['Golden Hour', 'Last Light', 'Chasing Sunsets']));
    });

    test('label title fires before sub-region match', () async {
      // GR + CY is the Mediterranean sub-region, but beach+sunset labels
      // should take priority (ADR-137).
      final result = await gen().generate(_req(
        codes: ['GR', 'CY'],
        heroLabels: [
          const HeroLabels(
              primaryScene: 'beach', mood: ['sunset'], confidence: 0.9),
        ],
      ));
      expect(result.title,
          isIn(['Aegean Sunset', 'Shore at Dusk', 'Golden Coastline']));
      expect(result.title,
          isNot(anyOf('Mediterranean Escape', 'Blue Water Run', 'Island Life')));
    });

    test('label fires before single-country name', () async {
      // Single country + labels → label title, not country name.
      final result = await gen().generate(_req(
        codes: ['JP'],
        heroLabels: [
          const HeroLabels(primaryScene: 'city', mood: ['night'], confidence: 0.9),
        ],
      ));
      expect(result.title,
          isIn(['City After Dark', 'Neon Nights', 'Night in the City']));
      expect(result.title, isNot('Japan'));
    });

    test('no label match falls back to sub-region', () async {
      // Unusual scene not in any table (e.g. null primaryScene, no mood) →
      // geography fallback applies.
      final result = await gen().generate(_req(
        codes: ['NO', 'SE', 'DK'],
        heroLabels: [const HeroLabels(confidence: 0.0)],
      ));
      expect(result.title,
          isIn(['Nordic Wander', 'Northern Lights', 'Fjord Life']));
    });

    test('null heroLabels falls back to geography (no regression)', () async {
      final result = await gen().generate(_req(
        codes: ['NO', 'SE', 'DK'],
      ));
      expect(result.title,
          isIn(['Nordic Wander', 'Northern Lights', 'Fjord Life']));
    });

    test('label titles vary across repeated calls (shuffle)', () async {
      final req = _req(
        codes: ['GR'],
        heroLabels: [
          const HeroLabels(
              primaryScene: 'beach', mood: ['sunset'], confidence: 0.9),
        ],
      );
      final titles = <String>{};
      for (var i = 0; i < 20; i++) {
        titles.add((await gen().generate(req)).title);
      }
      expect(titles.length, greaterThan(1));
    });
  });
}
