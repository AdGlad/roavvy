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
        shape: StampShape.circular,
        color: StampColor.blue,
        rotation: 0,
        center: Offset.zero,
        isEntry: true,
      );
      expect(stamp.dateLabel, '12 JAN 2023');
    });

    test('isEntry=true produces ENTRY label', () {
      final trip = _trip(
        countryCode: 'FR',
        startedOn: DateTime(2022, 6, 1),
        endedOn: DateTime(2022, 6, 10),
      );
      final stamp = StampData.fromTrip(
        trip,
        shape: StampShape.rectangular,
        color: StampColor.red,
        rotation: 0.1,
        center: const Offset(100, 100),
        isEntry: true,
      );
      expect(stamp.entryLabel, 'ENTRY');
      expect(stamp.countryCode, 'FR');
    });

    test('isEntry=false produces EXIT label', () {
      final trip = _trip(
        countryCode: 'DE',
        startedOn: DateTime(2021, 3, 15),
        endedOn: DateTime(2021, 3, 22),
      );
      final stamp = StampData.fromTrip(
        trip,
        shape: StampShape.oval,
        color: StampColor.green,
        rotation: -0.1,
        center: const Offset(50, 50),
        isEntry: false,
      );
      expect(stamp.entryLabel, 'EXIT');
    });
  });

  group('StampData.fromCode', () {
    test('produces null dateLabel', () {
      final stamp = StampData.fromCode(
        'US',
        shape: StampShape.doubleRing,
        color: StampColor.black,
        rotation: 0,
        center: Offset.zero,
      );
      expect(stamp.dateLabel, isNull);
    });

    test('produces ENTRY label', () {
      final stamp = StampData.fromCode(
        'GB',
        shape: StampShape.circular,
        color: StampColor.purple,
        rotation: 0,
        center: Offset.zero,
      );
      expect(stamp.entryLabel, 'ENTRY');
      expect(stamp.countryCode, 'GB');
    });

    test('default scale is 1.0', () {
      final stamp = StampData.fromCode(
        'IT',
        shape: StampShape.rectangular,
        color: StampColor.blue,
        rotation: 0,
        center: Offset.zero,
      );
      expect(stamp.scale, 1.0);
    });
  });

  group('StampColor', () {
    test('each color has a distinct Color value', () {
      final colors = StampColor.values.map((c) => c.color).toSet();
      expect(colors.length, StampColor.values.length);
    });
  });

  group('StampShape', () {
    test('has exactly 4 values', () {
      expect(StampShape.values.length, 4);
    });
  });
}
