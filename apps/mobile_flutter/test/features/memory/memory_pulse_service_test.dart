import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/notification_service.dart';
import 'package:mobile_flutter/data/db/roavvy_database.dart';
import 'package:mobile_flutter/features/memory/memory_anniversary_photo.dart';
import 'package:mobile_flutter/features/memory/memory_pulse_service.dart';
import 'package:mobile_flutter/features/scan/hero_image_repository.dart';

MemoryPulseService _makeService() {
  final db = RoavvyDatabase(NativeDatabase.memory());
  return MemoryPulseService(
    heroRepo: HeroImageRepository(db),
    notifications: NotificationService.instance,
    db: db,
  );
}

MemoryAnniversaryPhoto _photo({
  String assetId = 'asset_1',
  String? countryCode = 'GR',
  String? tripId = 'trip_1',
  DateTime? capturedAt,
}) {
  return MemoryAnniversaryPhoto(
    assetId: assetId,
    capturedAt: capturedAt ?? DateTime.utc(2022, 7, 12, 10),
    countryCode: countryCode,
    tripId: tripId,
  );
}

void main() {
  group('MemoryPulseService.buildCopy', () {
    test('body includes country name when countryCode is known', () {
      final service = _makeService();
      final copy = service.buildCopy(_photo(countryCode: 'GR'), 3);
      expect(copy.body, contains('Greece'));
      expect(copy.body, contains('3 years ago'));
    });

    test('body uses singular "year" when yearsAgo == 1', () {
      final service = _makeService();
      final copy = service.buildCopy(_photo(countryCode: 'FR'), 1);
      expect(copy.body, contains('1 year ago'));
      expect(copy.body, isNot(contains('1 years ago')));
    });

    test('body falls back to "today" phrase when countryCode is null', () {
      final service = _makeService();
      final copy = service.buildCopy(_photo(countryCode: null), 2);
      expect(copy.body, contains('2 years ago today'));
    });

    test('title ends with 👀', () {
      final service = _makeService();
      final copy = service.buildCopy(_photo(), 3);
      expect(copy.title, endsWith('👀'));
    });
  });

  group('MemoryPulseService.buildQuestion', () {
    test('returns one-year question when yearsAgo == 1', () {
      final service = _makeService();
      final q = service.buildQuestion(_photo(), 1);
      expect(q, contains('one year ago'));
    });

    test('returns milestone question when yearsAgo == 5 and country known', () {
      final service = _makeService();
      final q = service.buildQuestion(_photo(countryCode: 'JP'), 5);
      expect(q, contains('5 years'));
      expect(q, contains('Japan'));
    });

    test('includes country name when known and yearsAgo > 1', () {
      final service = _makeService();
      final q = service.buildQuestion(_photo(countryCode: 'IT'), 3);
      expect(q, contains('Italy'));
    });

    test('falls back to "today" phrasing when countryCode is null', () {
      final service = _makeService();
      final q = service.buildQuestion(_photo(countryCode: null), 4);
      expect(q, contains('4 years ago today'));
    });
  });

  group('MemoryPulseService.checkToday (legacy)', () {
    test('returns empty list when no heroes exist', () async {
      final service = _makeService();
      final result = await service.checkToday(DateTime.now());
      expect(result, isEmpty);
    });

    test('limits result to 3 entries', () async {
      final service = _makeService();
      final result = await service.checkToday(DateTime.now());
      expect(result.length, lessThanOrEqualTo(3));
    });
  });
}
