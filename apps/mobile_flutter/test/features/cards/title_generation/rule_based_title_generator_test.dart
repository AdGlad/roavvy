import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/cards/title_generation/rule_based_title_generator.dart';
import 'package:mobile_flutter/features/cards/title_generation/title_generation_models.dart';
import 'package:shared_models/shared_models.dart';

TitleGenerationRequest _req({required List<String> codes}) {
  return TitleGenerationRequest(
    countryCodes: codes,
    countryNames: codes,
    regionNames: const [],
    cardType: CardTemplateType.grid,
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
}
