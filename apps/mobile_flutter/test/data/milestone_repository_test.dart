import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobile_flutter/data/milestone_repository.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('MilestoneRepository', () {
    test('getShownThresholds returns empty set when key is absent', () async {
      final repo = MilestoneRepository();
      expect(await repo.getShownThresholds(), isEmpty);
    });

    test('markShown then getShownThresholds returns that threshold', () async {
      final repo = MilestoneRepository();
      await repo.markShown(10);
      expect(await repo.getShownThresholds(), {10});
    });

    test('multiple markShown calls accumulate correctly', () async {
      final repo = MilestoneRepository();
      await repo.markShown(5);
      await repo.markShown(10);
      await repo.markShown(25);
      expect(await repo.getShownThresholds(), {5, 10, 25});
    });

    test('markShown is idempotent for the same threshold', () async {
      final repo = MilestoneRepository();
      await repo.markShown(10);
      await repo.markShown(10);
      expect(await repo.getShownThresholds(), {10});
    });
  });
}
