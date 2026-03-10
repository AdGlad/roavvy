import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/visits/visit_store.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // Use the in-memory SharedPreferences implementation for all tests.
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final t0 = DateTime.utc(2025, 1, 1);
  final t1 = DateTime.utc(2025, 6, 15);

  CountryVisit autoVisit(String code) => CountryVisit(
        countryCode: code,
        source: VisitSource.auto,
        updatedAt: t0,
      );

  CountryVisit manualTombstone(String code) => CountryVisit(
        countryCode: code,
        source: VisitSource.manual,
        isDeleted: true,
        updatedAt: t1,
      );

  group('VisitStore', () {
    test('load returns empty list when nothing saved', () async {
      final visits = await VisitStore.load();
      expect(visits, isEmpty);
    });

    test('save then load round-trips a single visit', () async {
      final v = autoVisit('GB');
      await VisitStore.save([v]);
      final loaded = await VisitStore.load();
      expect(loaded, [v]);
    });

    test('save then load round-trips multiple visits', () async {
      final visits = [autoVisit('GB'), autoVisit('JP'), autoVisit('US')];
      await VisitStore.save(visits);
      final loaded = await VisitStore.load();
      expect(loaded.map((v) => v.countryCode).toSet(), {'GB', 'JP', 'US'});
    });

    test('manual tombstone survives round-trip', () async {
      final tombstone = manualTombstone('GB');
      await VisitStore.save([tombstone]);
      final loaded = await VisitStore.load();
      expect(loaded.single.isDeleted, isTrue);
      expect(loaded.single.source, VisitSource.manual);
      expect(loaded.single.countryCode, 'GB');
    });

    test('save overwrites previous data', () async {
      await VisitStore.save([autoVisit('GB')]);
      await VisitStore.save([autoVisit('JP')]);
      final loaded = await VisitStore.load();
      expect(loaded.length, 1);
      expect(loaded.single.countryCode, 'JP');
    });

    test('clear removes all saved visits', () async {
      await VisitStore.save([autoVisit('GB'), autoVisit('JP')]);
      await VisitStore.clear();
      final loaded = await VisitStore.load();
      expect(loaded, isEmpty);
    });

    test('saved visits feed into effectiveVisits correctly', () async {
      final visits = [autoVisit('GB'), autoVisit('JP'), manualTombstone('US')];
      await VisitStore.save(visits);
      final loaded = await VisitStore.load();
      final effective = effectiveVisits(loaded);
      // US tombstone suppresses US; GB and JP are active.
      expect(effective.map((v) => v.countryCode).toSet(), {'GB', 'JP'});
    });

    test('manual tombstone persisted across save/load suppresses auto on next merge', () async {
      // Simulate: user removed GB in review, then a new scan detects GB again.
      final tombstone = manualTombstone('GB');
      await VisitStore.save([tombstone]);

      final saved = await VisitStore.load();
      final fromScan = [autoVisit('GB'), autoVisit('JP')]; // GB re-detected
      final merged = [...fromScan, ...saved];
      final effective = effectiveVisits(merged);

      expect(effective.map((v) => v.countryCode).toSet(), {'JP'});
      expect(effective.any((v) => v.countryCode == 'GB'), isFalse);
    });
  });
}
