import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/cards/passport_stamp_model.dart';
import 'package:shared_models/shared_models.dart';

TripRecord _trip({
  required String countryCode,
  required DateTime startedOn,
  required DateTime endedOn,
}) =>
    TripRecord(
      id: '${countryCode}_${startedOn.toIso8601String()}',
      countryCode: countryCode,
      startedOn: startedOn,
      endedOn: endedOn,
      photoCount: 10,
      isManual: false,
    );

void main() {
  group('StampData.fromTrip', () {
    test('formats startedOn as DD MMM YYYY', () {
      final trip = _trip(
        countryCode: 'JP',
        startedOn: DateTime(2023, 1, 12),
        endedOn: DateTime(2023, 1, 20),
      );
      final stamp = StampData.fromTrip(
        trip,
        style: StampStyle.airportEntry,
        inkFamilyIndex: 0,
        ageEffect: StampAgeEffect.fresh,
        rotation: 0,
        center: Offset.zero,
        isEntry: true,
      );
      expect(stamp.dateLabel, '12 JAN 2023');
    });

    test('isEntry=true produces native arrival label', () {
      final trip = _trip(
        countryCode: 'FR',
        startedOn: DateTime(2022, 6, 1),
        endedOn: DateTime(2022, 6, 10),
      );
      final stamp = StampData.fromTrip(
        trip,
        style: StampStyle.landBorder,
        inkFamilyIndex: 1,
        ageEffect: StampAgeEffect.aged,
        rotation: 0.1,
        center: const Offset(100, 100),
        isEntry: true,
      );
      expect(stamp.entryLabel, 'ARRIVÉE'); // French native
      expect(stamp.isEntry, isTrue);
      expect(stamp.countryCode, 'FR');
    });

    test('isEntry=false produces native departure label', () {
      final trip = _trip(
        countryCode: 'DE',
        startedOn: DateTime(2021, 3, 15),
        endedOn: DateTime(2021, 3, 22),
      );
      final stamp = StampData.fromTrip(
        trip,
        style: StampStyle.modernSans,
        inkFamilyIndex: 2,
        ageEffect: StampAgeEffect.worn,
        rotation: -0.1,
        center: const Offset(50, 50),
        isEntry: false,
      );
      expect(stamp.entryLabel, 'AUSREISE'); // German native
      expect(stamp.isEntry, isFalse);
    });

    test('unknown country code falls back to DEPARTURE for exit', () {
      final trip = _trip(
        countryCode: 'XX',
        startedOn: DateTime(2023, 5, 1),
        endedOn: DateTime(2023, 5, 10),
      );
      final stamp = StampData.fromTrip(
        trip,
        style: StampStyle.transit,
        inkFamilyIndex: 0,
        ageEffect: StampAgeEffect.fresh,
        rotation: 0,
        center: Offset.zero,
        isEntry: false,
      );
      expect(stamp.entryLabel, 'DEPARTURE');
    });
  });

  group('StampData.fromCode', () {
    test('produces a deterministic non-null dateLabel', () {
      final stamp = StampData.fromCode(
        'US',
        style: StampStyle.transit,
        inkFamilyIndex: 3,
        ageEffect: StampAgeEffect.fresh,
        rotation: 0,
        center: Offset.zero,
      );
      expect(stamp.dateLabel, isNotNull);
      // Same call produces same label
      final stamp2 = StampData.fromCode(
        'US',
        style: StampStyle.transit,
        inkFamilyIndex: 3,
        ageEffect: StampAgeEffect.fresh,
        rotation: 0,
        center: Offset.zero,
      );
      expect(stamp.dateLabel, stamp2.dateLabel);
    });

    test('produces native arrival label', () {
      final stamp = StampData.fromCode(
        'GB',
        style: StampStyle.vintage,
        inkFamilyIndex: 4,
        ageEffect: StampAgeEffect.fresh,
        rotation: 0,
        center: Offset.zero,
      );
      expect(stamp.entryLabel, 'ARRIVAL'); // English
      expect(stamp.isEntry, isTrue);
      expect(stamp.countryCode, 'GB');
    });

    test('default scale is 1.0', () {
      final stamp = StampData.fromCode(
        'IT',
        style: StampStyle.hexBadge,
        inkFamilyIndex: 0,
        ageEffect: StampAgeEffect.aged,
        rotation: 0,
        center: Offset.zero,
      );
      expect(stamp.scale, 1.0);
    });
  });

  group('StampStyle', () {
    test('has exactly 15 values', () {
      expect(StampStyle.values.length, 15);
    });

    test('contains all expected style names', () {
      expect(StampStyle.values, containsAll([
        StampStyle.airportEntry,
        StampStyle.airportExit,
        StampStyle.landBorder,
        StampStyle.visaApproval,
        StampStyle.transit,
        StampStyle.vintage,
        StampStyle.modernSans,
        StampStyle.triangle,
        StampStyle.hexBadge,
        StampStyle.dottedCircle,
        StampStyle.multiRing,
        StampStyle.blockText,
      ]));
    });
  });

  group('StampInkPalette', () {
    test('has 12 families', () {
      expect(StampInkPalette.familyCount, 12);
    });

    test('each family index returns a distinct colour', () {
      final colors = List.generate(12, StampInkPalette.colorForFamily).toSet();
      expect(colors.length, 12);
    });

    test('familyIndexForCode is deterministic', () {
      expect(
        StampInkPalette.familyIndexForCode('JP'),
        StampInkPalette.familyIndexForCode('JP'),
      );
    });

    test('familyIndexForCode is within valid range', () {
      for (final code in ['GB', 'US', 'FR', 'DE', 'JP', 'AU']) {
        final idx = StampInkPalette.familyIndexForCode(code);
        expect(idx, greaterThanOrEqualTo(0));
        expect(idx, lessThan(12));
      }
    });
  });

  group('StampAgeEffect', () {
    test('opacity values are correct', () {
      expect(StampAgeEffect.fresh.opacity, closeTo(0.90, 0.001));
      expect(StampAgeEffect.aged.opacity, closeTo(0.78, 0.001));
      expect(StampAgeEffect.worn.opacity, closeTo(0.62, 0.001));
      expect(StampAgeEffect.faded.opacity, closeTo(0.45, 0.001));
    });

    test('fromWeightedRandom boundaries', () {
      expect(StampAgeEffect.fromWeightedRandom(0.0), StampAgeEffect.fresh);
      expect(StampAgeEffect.fromWeightedRandom(0.59), StampAgeEffect.fresh);
      expect(StampAgeEffect.fromWeightedRandom(0.60), StampAgeEffect.aged);
      expect(StampAgeEffect.fromWeightedRandom(0.89), StampAgeEffect.aged);
      expect(StampAgeEffect.fromWeightedRandom(0.90), StampAgeEffect.worn);
      expect(StampAgeEffect.fromWeightedRandom(0.97), StampAgeEffect.worn);
      expect(StampAgeEffect.fromWeightedRandom(0.98), StampAgeEffect.faded);
      expect(StampAgeEffect.fromWeightedRandom(0.999), StampAgeEffect.faded);
    });

    test('shiftsToFaded for worn and faded only', () {
      expect(StampAgeEffect.worn.shiftsToFaded, isTrue);
      expect(StampAgeEffect.faded.shiftsToFaded, isTrue);
      expect(StampAgeEffect.fresh.shiftsToFaded, isFalse);
      expect(StampAgeEffect.aged.shiftsToFaded, isFalse);
    });
  });

  group('StampRenderConfig', () {
    test('defaults all effects enabled', () {
      const config = StampRenderConfig();
      expect(config.enableRareArtefacts, isTrue);
      expect(config.enableNoise, isTrue);
      expect(config.enableAging, isTrue);
    });

    test('clean config disables all effects', () {
      expect(StampRenderConfig.clean.enableRareArtefacts, isFalse);
      expect(StampRenderConfig.clean.enableNoise, isFalse);
      expect(StampRenderConfig.clean.enableAging, isFalse);
    });

    test('equality', () {
      expect(const StampRenderConfig(), const StampRenderConfig());
      expect(
        const StampRenderConfig(enableNoise: false),
        isNot(const StampRenderConfig()),
      );
    });
  });

  group('StampData.inkColor', () {
    test('worn/faded shifts toward fadedInk', () {
      final fresh = StampData.fromCode(
        'GB', style: StampStyle.transit, inkFamilyIndex: 0,
        ageEffect: StampAgeEffect.fresh, rotation: 0, center: Offset.zero,
      );
      final worn = StampData.fromCode(
        'GB', style: StampStyle.transit, inkFamilyIndex: 0,
        ageEffect: StampAgeEffect.worn, rotation: 0, center: Offset.zero,
      );
      // Worn colour should differ from fresh due to faded blend
      expect(fresh.inkColor, isNot(worn.inkColor));
    });
  });
}
