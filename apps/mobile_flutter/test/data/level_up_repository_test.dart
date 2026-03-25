import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobile_flutter/data/level_up_repository.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('LevelUpRepository', () {
    test('getLastShownLevel returns 1 when key is absent', () async {
      final repo = LevelUpRepository();
      expect(await repo.getLastShownLevel(), 1);
    });

    test('markShown persists level; getLastShownLevel returns it', () async {
      final repo = LevelUpRepository();
      await repo.markShown(3);
      expect(await repo.getLastShownLevel(), 3);
    });

    test('markShown is idempotent — calling twice leaves the latest value', () async {
      final repo = LevelUpRepository();
      await repo.markShown(2);
      await repo.markShown(2);
      expect(await repo.getLastShownLevel(), 2);
    });

    test('markShown with higher level overwrites lower', () async {
      final repo = LevelUpRepository();
      await repo.markShown(2);
      await repo.markShown(5);
      expect(await repo.getLastShownLevel(), 5);
    });

    test('two instances share the same SharedPreferences storage', () async {
      final repo1 = LevelUpRepository();
      final repo2 = LevelUpRepository();
      await repo1.markShown(4);
      expect(await repo2.getLastShownLevel(), 4);
    });
  });
}
