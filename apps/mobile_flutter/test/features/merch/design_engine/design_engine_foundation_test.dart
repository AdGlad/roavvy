// M197 — AI design engine foundation: genome + travel profile analyzer.

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/cards/flag_grid_layout_engine.dart';
import 'package:mobile_flutter/features/merch/design_engine/design_params.dart';
import 'package:mobile_flutter/features/merch/design_engine/travel_profile.dart';
import 'package:mobile_flutter/features/merch/design_engine/travel_profile_analyzer.dart';
import 'package:mobile_flutter/features/merch/merch_preset.dart';
import 'package:mobile_flutter/features/merch/merch_template_ranker.dart';
import 'package:mobile_flutter/features/merch/product_mockup_specs.dart';
import 'package:shared_models/shared_models.dart';

TripRecord _trip(
  String code, {
  required DateTime start,
  required DateTime end,
  int photos = 10,
}) =>
    TripRecord(
      id: '$code-${start.toIso8601String()}',
      countryCode: code,
      startedOn: start,
      endedOn: end,
      photoCount: photos,
      isManual: false,
    );

void main() {
  group('DesignParams — genome', () {
    const base = DesignParams(
      template: CardTemplateType.grid,
      source: MerchCountrySource.allTime,
      countryCodes: ['FR', 'DE', 'IT'],
    );

    test('contentHash is stable and order-independent for codes', () {
      final a = base;
      final b = base.copyWith(countryCodes: ['IT', 'DE', 'FR']);
      expect(a.contentHash, b.contentHash);
      expect(a, b);
    });

    test('different genes → different hash', () {
      final a = base;
      final b = base.copyWith(shirtColour: 'White');
      expect(a.contentHash, isNot(b.contentHash));
    });

    test('toPresetConfig maps the shared genes', () {
      final cfg = base
          .copyWith(density: MerchDensity.dense, jitter: 0.4)
          .toPresetConfig();
      expect(cfg.layout, CardTemplateType.grid);
      expect(cfg.source, MerchCountrySource.allTime);
      expect(cfg.density, MerchDensity.dense);
      expect(cfg.jitter, 0.4);
    });

    test('normalize strips flag-grid genes from a non-grid template', () {
      final p = base.copyWith(
        template: CardTemplateType.passport,
        gridLayoutMode: FlagGridLayoutMode.montage,
        clipShape: GridClipShape.circle,
      );
      expect(p.isValid, isFalse);
      final n = p.normalize();
      expect(n.gridLayoutMode, FlagGridLayoutMode.packedRow);
      expect(n.clipShape, GridClipShape.none);
      expect(n.isValid, isTrue);
    });

    test('normalize removes a single-country clip on a multi-country set', () {
      final p = base.copyWith(
        clipShape: GridClipShape.countryOutline,
        clipCode: 'fr',
      );
      expect(p.isValid, isFalse); // 3 countries
      expect(p.normalize().clipShape, GridClipShape.none);
    });

    test('a single-country outline clip is valid', () {
      const p = DesignParams(
        template: CardTemplateType.grid,
        source: MerchCountrySource.singleCountry,
        countryCodes: ['AU'],
        clipShape: GridClipShape.countryOutline,
        clipCode: 'au',
      );
      expect(p.isValid, isTrue);
      expect(p.normalize(), p);
    });

    test('outline clip without a clipCode is coerced to none', () {
      const p = DesignParams(
        template: CardTemplateType.grid,
        source: MerchCountrySource.singleCountry,
        countryCodes: ['AU'],
        clipShape: GridClipShape.animalSilhouette,
      );
      expect(p.isValid, isFalse);
      expect(p.normalize().clipShape, GridClipShape.none);
    });

    test('imageSize default is medium', () {
      expect(base.imageSize, ImageSize.medium);
    });
  });

  group('TravelProfileAnalyzer', () {
    final now = DateTime(2026, 6, 1);
    DateTime d(int y, [int m = 1]) => DateTime(y, m, 1);

    test('empty history → empty profile', () {
      final p = TravelProfileAnalyzer.analyze(const [], now: now);
      expect(p.isEmpty, isTrue);
      expect(p.candidateSets, isEmpty);
    });

    test('single country → soloDeepDive + all-time set', () {
      final p = TravelProfileAnalyzer.analyze(
        [_trip('JP', start: d(2025), end: d(2025, 2))],
        now: now,
      );
      expect(p.countryCount, 1);
      expect(p.persona, TravelPersona.soloDeepDive);
      expect(p.density, MerchDensityClass.solo);
      expect(p.candidateSets.first.source, MerchCountrySource.allTime);
    });

    test('all-time set is always present and complete', () {
      final p = TravelProfileAnalyzer.analyze(
        [
          _trip('FR', start: d(2020), end: d(2020, 2)),
          _trip('DE', start: d(2021), end: d(2021, 2)),
          _trip('IT', start: d(2022), end: d(2022, 2)),
        ],
        now: now,
      );
      final allTime =
          p.candidateSets.firstWhere((s) => s.source == MerchCountrySource.allTime);
      expect(allTime.codes.toSet(), {'FR', 'DE', 'IT'});
    });

    test('signature country is the one with the most photos', () {
      final p = TravelProfileAnalyzer.analyze(
        [
          _trip('FR', start: d(2020), end: d(2020, 2), photos: 5),
          _trip('JP', start: d(2021), end: d(2021, 2), photos: 200),
          _trip('DE', start: d(2022), end: d(2022, 2), photos: 10),
        ],
        now: now,
      );
      expect(p.signatureCountries.first, 'JP');
    });

    test('recent-heavy small history → recentAdventurer', () {
      final p = TravelProfileAnalyzer.analyze(
        [
          _trip('TH', start: d(2026, 3), end: d(2026, 4), photos: 100),
          _trip('VN', start: d(2026, 4), end: d(2026, 5), photos: 100),
        ],
        now: now,
      );
      expect(p.isRecencyHeavy, isTrue);
      expect(p.persona, TravelPersona.recentAdventurer);
    });

    test('broad history → globeTrotter', () {
      final trips = <TripRecord>[];
      for (var i = 0; i < 26; i++) {
        final code = String.fromCharCodes([65 + (i ~/ 26), 65 + (i % 26)]);
        trips.add(_trip(code, start: d(2010 + i % 15), end: d(2010 + i % 15, 2)));
      }
      final p = TravelProfileAnalyzer.analyze(trips, now: now);
      expect(p.countryCount, greaterThanOrEqualTo(25));
      expect(p.persona, TravelPersona.globeTrotter);
    });

    test('this-year set appears when distinct from all-time', () {
      final p = TravelProfileAnalyzer.analyze(
        [
          _trip('FR', start: d(2019), end: d(2019, 2)),
          _trip('DE', start: d(2020), end: d(2020, 2)),
          _trip('JP', start: d(2026, 3), end: d(2026, 4)),
        ],
        now: now,
      );
      final thisYear =
          p.candidateSets.where((s) => s.source == MerchCountrySource.thisYear);
      expect(thisYear, isNotEmpty);
      expect(thisYear.first.codes, ['JP']);
    });
  });
}
