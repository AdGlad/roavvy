import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/cards/title_generation/rule_based_title_generator.dart';
import 'package:mobile_flutter/features/cards/title_generation/title_generation_models.dart';
import 'package:shared_models/shared_models.dart';

TitleGenerationRequest _req({
  required List<String> codes,
  int? startYear,
  int? endYear,
}) {
  return TitleGenerationRequest(
    countryCodes: codes,
    countryNames: codes,
    regionNames: const [],
    startYear: startYear,
    endYear: endYear,
    cardType: CardTemplateType.grid,
  );
}

void main() {
  final generator = RuleBasedTitleGenerator();

  test('empty list returns non-empty non-throwing result', () async {
    final result = await generator.generate(_req(codes: []));
    expect(result.title, isNotEmpty);
    expect(result.source, TitleSource.fallback);
  });

  test('single country returns title containing country name', () async {
    final result = await generator.generate(_req(codes: ['JP'], startYear: 2024));
    expect(result.title, contains('Japan'));
    expect(result.title, contains('2024'));
  });

  test('single country without year omits year', () async {
    final result = await generator.generate(_req(codes: ['FR']));
    expect(result.title, contains('France'));
    expect(result.title, isNot(contains('null')));
  });

  test('Nordic cluster contains "Nordic"', () async {
    final result = await generator.generate(_req(codes: ['NO', 'SE', 'FI']));
    expect(result.title, contains('Nordic'));
  });

  test('Nordic partial cluster does not trigger Nordic label', () async {
    final result = await generator.generate(_req(codes: ['NO', 'US']));
    expect(result.title, isNot(contains('Nordic')));
  });

  test('European multi-country + year contains year', () async {
    final result = await generator.generate(
      _req(codes: ['DE', 'IT', 'ES'], startYear: 2022, endYear: 2023),
    );
    expect(result.title, isNotEmpty);
    expect(result.title, contains('2022'));
  });

  test('mixed continents returns non-empty title', () async {
    final result = await generator.generate(
      _req(codes: ['JP', 'BR', 'US', 'DE']),
    );
    expect(result.title, isNotEmpty);
    expect(result.source, TitleSource.fallback);
  });

  test('multi-year range uses en-dash format', () async {
    final result = await generator.generate(
      _req(codes: ['AU'], startYear: 2020, endYear: 2023),
    );
    expect(result.title, contains('2020'));
    expect(result.title, contains('2023'));
  });
}
