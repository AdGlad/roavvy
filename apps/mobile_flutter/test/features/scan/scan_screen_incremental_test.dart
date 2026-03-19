import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/data/db/roavvy_database.dart';
import 'package:mobile_flutter/data/visit_repository.dart';

VisitRepository _makeRepo() =>
    VisitRepository(RoavvyDatabase(NativeDatabase.memory()));

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  group('VisitRepository — lastScanAt', () {
    test('loadLastScanAt returns null when no scan has run', () async {
      final repo = _makeRepo();
      expect(await repo.loadLastScanAt(), isNull);
    });

    test('saveLastScanAt persists a UTC timestamp', () async {
      final repo = _makeRepo();
      final ts = DateTime.utc(2025, 6, 15, 10, 30);
      await repo.saveLastScanAt(ts);
      expect(await repo.loadLastScanAt(), ts);
    });

    test('saveLastScanAt converts local time to UTC', () async {
      final repo = _makeRepo();
      // Create a local-time DateTime with known UTC equivalent.
      final local = DateTime(2025, 6, 15, 10, 30).toLocal();
      await repo.saveLastScanAt(local);
      final loaded = await repo.loadLastScanAt();
      expect(loaded, local.toUtc());
    });

    test('saveLastScanAt overwrites the previous value', () async {
      final repo = _makeRepo();
      final t1 = DateTime.utc(2025, 1, 1);
      final t2 = DateTime.utc(2025, 6, 1);
      await repo.saveLastScanAt(t1);
      await repo.saveLastScanAt(t2);
      expect(await repo.loadLastScanAt(), t2);
    });

    test('clearLastScanAt resets to null', () async {
      final repo = _makeRepo();
      await repo.saveLastScanAt(DateTime.utc(2025, 1, 1));
      await repo.clearLastScanAt();
      expect(await repo.loadLastScanAt(), isNull);
    });

    test('clearAll also clears lastScanAt', () async {
      final repo = _makeRepo();
      await repo.saveLastScanAt(DateTime.utc(2025, 3, 1));
      await repo.clearAll();
      expect(await repo.loadLastScanAt(), isNull);
    });
  });
}
