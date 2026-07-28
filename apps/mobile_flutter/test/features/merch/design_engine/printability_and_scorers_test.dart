// M198 — printability gate + analytic scorers.

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/cards/flag_grid_layout_engine.dart';
import 'package:mobile_flutter/features/merch/design_engine/analytic_scorers.dart';
import 'package:mobile_flutter/features/merch/design_engine/design_params.dart';
import 'package:mobile_flutter/features/merch/design_engine/printability.dart';
import 'package:mobile_flutter/features/merch/design_engine/scoring_engine.dart';
import 'package:mobile_flutter/features/merch/design_engine/travel_profile.dart';
import 'package:mobile_flutter/features/merch/design_engine/travel_profile_analyzer.dart';
import 'package:mobile_flutter/features/merch/merch_preset.dart';
import 'package:mobile_flutter/features/merch/product_mockup_specs.dart';
import 'package:shared_models/shared_models.dart';

TripRecord _trip(String code) => TripRecord(
      id: '$code-t',
      countryCode: code,
      startedOn: DateTime(2022, 1, 1),
      endedOn: DateTime(2022, 1, 10),
      photoCount: 12,
      isManual: false,
    );

/// A broad 8-country profile (grid ranks #1, globe-trotter loves all-time).
final TravelProfile _profile8 = TravelProfileAnalyzer.analyze(
  ['FR', 'DE', 'IT', 'JP', 'US', 'BR', 'AU', 'ZA'].map(_trip).toList(),
  now: DateTime(2026, 6, 1),
);

/// A synthetic large country set to stress the sub-pixel / min-feature gate.
List<String> _manyCodes(int n) => List.generate(
      n,
      (i) => String.fromCharCode(65 + i ~/ 26) + String.fromCharCode(65 + i % 26),
    );

const _goodGrid = DesignParams(
  template: CardTemplateType.grid,
  source: MerchCountrySource.allTime,
  countryCodes: ['FR', 'DE', 'IT', 'JP', 'US', 'BR', 'AU', 'ZA'],
  rowCount: 3,
);

void main() {
  group('PrintabilityGate — rejects bad, passes good', () {
    test('empty country set is rejected (GenomeValidity)', () {
      const p = DesignParams(
        template: CardTemplateType.grid,
        source: MerchCountrySource.allTime,
        countryCodes: [],
      );
      final r = const PrintabilityGate().firstViolation(p, _profile8);
      expect(r, isNotNull);
      expect(r, contains('GenomeValidity'));
    });

    test('a healthy grid design passes every constraint', () {
      expect(const PrintabilityGate().isPrintable(_goodGrid, _profile8), isTrue);
    });

    test('dark-on-black is rejected (injected dark ink), adaptive passes', () {
      // Inject a resolver that pins dark ink → invisible on a black shirt.
      final darkOnBlack = GarmentContrastConstraint(inkLuminance: (_) => 0.10);
      expect(darkOnBlack.violation(_goodGrid, _profile8), isNotNull);
      expect(
        darkOnBlack.violation(_goodGrid, _profile8),
        contains('contrast'),
      );
      // The default adaptive model contrasts on every supported garment.
      const adaptive = GarmentContrastConstraint();
      for (final colour in ['Black', 'White', 'Blue', 'Grey', 'Red']) {
        final p = _goodGrid.copyWith(shirtColour: colour);
        expect(adaptive.violation(p, _profile8), isNull, reason: colour);
      }
    });

    test('an unsupported shirt colour is rejected', () {
      final p = _goodGrid.copyWith(shirtColour: 'Charcoal');
      final r = const GarmentContrastConstraint().violation(p, _profile8);
      expect(r, isNotNull);
      expect(r, contains('unsupported'));
    });

    test('over-dense sub-pixel grid is rejected (MinFeatureSize)', () {
      final p = DesignParams(
        template: CardTemplateType.grid,
        source: MerchCountrySource.allTime,
        countryCodes: _manyCodes(200),
        gridLayoutMode: FlagGridLayoutMode.normalizedGrid,
        imageSize: ImageSize.small,
      );
      final r = const PrintabilityGate().firstViolation(p, _profile8);
      expect(r, isNotNull);
      expect(r, contains('MinFeatureSize'));
    });

    test('near-empty passport is rejected (CoverageBounds)', () {
      const p = DesignParams(
        template: CardTemplateType.passport,
        source: MerchCountrySource.singleCountry,
        countryCodes: ['JP'],
        stampMode: MerchStampMode.entryOnly,
        density: MerchDensity.sparse,
        imageSize: ImageSize.small,
      );
      final r = const PrintabilityGate().firstViolation(p, _profile8);
      expect(r, isNotNull);
      expect(r, contains('CoverageBounds'));
    });

    test('healthy grid coverage sits inside the band', () {
      final cov = estimateInkCoverage(_goodGrid);
      expect(cov, greaterThan(kMinCoverage));
      expect(cov, lessThan(kMaxCoverage));
    });
  });

  group('Analytic scorers — bounded + sensible', () {
    final samples = <DesignParams>[
      _goodGrid,
      _goodGrid.copyWith(gridLayoutMode: FlagGridLayoutMode.montage),
      _goodGrid.copyWith(template: CardTemplateType.passport),
      const DesignParams(
        template: CardTemplateType.grid,
        source: MerchCountrySource.singleCountry,
        countryCodes: ['AU'],
        clipShape: GridClipShape.countryOutline,
        clipCode: 'au',
        isPortrait: true,
      ),
    ];

    test('every scorer returns a value in [0, 1]', () {
      final scorers = [...kDefaultAnalyticScorers, kDefaultProfileScorer];
      for (final s in scorers) {
        for (final p in samples) {
          final v = s.score(p, _profile8);
          expect(v, inInclusiveRange(0.0, 1.0), reason: '${s.name} on $p');
        }
      }
    });

    test('a focal single-country outline beats a busy 8-flag grid on hierarchy',
        () {
      const focal = FocalHierarchyScorer();
      final outline = samples.last; // AU country outline
      expect(focal.score(outline, _profile8),
          greaterThan(focal.score(_goodGrid, _profile8)));
    });

    test('profile fit prefers the ranked template + matching source', () {
      const fit = ProfileFitScorer();
      final good = fit.score(_goodGrid, _profile8); // grid #1 + all-time
      final bad = fit.score(
        _goodGrid.copyWith(template: CardTemplateType.frontRibbon),
        _profile8,
      ); // frontRibbon excluded for this density
      expect(good, greaterThan(bad));
    });
  });

  group('analyticScore — composition', () {
    test('non-printable design scores a total of 0', () {
      const empty = DesignParams(
        template: CardTemplateType.grid,
        source: MerchCountrySource.allTime,
        countryCodes: [],
      );
      final s = analyticScore(empty, _profile8);
      expect(s.printable, isFalse);
      expect(s.total(), 0.0);
      expect(s.rejectionReason, isNotNull);
    });

    test('an obviously-good design outscores an obviously-bad one', () {
      final good = analyticScore(_goodGrid, _profile8);
      final bad = analyticScore(
        _goodGrid.copyWith(template: CardTemplateType.frontRibbon),
        _profile8,
      );
      expect(good.printable, isTrue);
      expect(bad.printable, isTrue);
      expect(good.total(), greaterThan(bad.total()));
    });

    test('printable design reports bounded aesthetic + profileFit', () {
      final s = analyticScore(_goodGrid, _profile8);
      expect(s.aesthetic, inInclusiveRange(0.0, 1.0));
      expect(s.profileFit, inInclusiveRange(0.0, 1.0));
      expect(s.printabilityMargin, inInclusiveRange(0.0, 1.0));
    });
  });
}
