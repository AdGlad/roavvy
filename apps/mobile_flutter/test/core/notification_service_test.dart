import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/notification_service.dart';

void main() {
  // NotificationService.instance is a singleton. Tests that need a clean state
  // must avoid relying on _initialized order. All tests here exercise the
  // observable Dart-side contract only — no platform channel calls are made.

  group('NotificationService — guard: no-op before init', () {
    test('scheduleNudge completes without error when not initialized',
        () async {
      // _initialized starts false on the first use of the singleton.
      // Subsequent tests may have called init(), so we cannot guarantee state —
      // but the method must never throw regardless.
      await expectLater(
        NotificationService.instance.scheduleNudge(),
        completes,
      );
    });

    test('scheduleAchievementUnlock completes without error when not initialized',
        () async {
      await expectLater(
        NotificationService.instance.scheduleAchievementUnlock(
          title: 'Test',
          body: 'Test body',
        ),
        completes,
      );
    });

    test('requestPermission returns false when not initialized', () async {
      // Before init(), the iOS plugin impl is null → returns false.
      final result = await NotificationService.instance.requestPermission();
      // On Dart VM there is no iOS plugin — always false.
      expect(result, isFalse);
    });
  });

  group('NotificationService — pendingTabIndex ValueNotifier', () {
    test('starts as null', () {
      expect(NotificationService.instance.pendingTabIndex.value, isNull);
    });

    test('can be set and fires listeners', () {
      int? received;
      void listener() {
        received = NotificationService.instance.pendingTabIndex.value;
      }

      NotificationService.instance.pendingTabIndex.addListener(listener);
      NotificationService.instance.pendingTabIndex.value = 2;
      expect(received, 2);

      // Clean up.
      NotificationService.instance.pendingTabIndex.removeListener(listener);
      NotificationService.instance.pendingTabIndex.value = null;
    });

    test('resetting to null fires listener', () {
      int? received = 99;
      void listener() {
        received = NotificationService.instance.pendingTabIndex.value;
      }

      NotificationService.instance.pendingTabIndex.value = 3;
      NotificationService.instance.pendingTabIndex.addListener(listener);
      NotificationService.instance.pendingTabIndex.value = null;
      expect(received, isNull);

      NotificationService.instance.pendingTabIndex.removeListener(listener);
    });
  });
}
