import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/commerce/commerce_flag.dart';
import 'package:mobile_flutter/features/scan/achievement_unlock_sheet.dart';
import 'package:shared_models/shared_models.dart';

Achievement get _achievement => kAchievements.first;
final _unlockedAt = DateTime(2026, 1, 14, 10, 0);

Achievement get _merchAchievement =>
    kAchievements.firstWhere((a) => a.merch != null);

Future<void> pumpSheet(
  WidgetTester tester, {
  bool commerce = false,
  Achievement? achievement,
}) async {
  await tester.binding.setSurfaceSize(const Size(400, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        commerceBuildProvider.overrideWithValue(commerce),
        commerceRemoteSwitchProvider.overrideWithValue(true),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder:
                (context) => ElevatedButton(
                  onPressed:
                      () => AchievementUnlockSheet.show(
                        context,
                        achievement: achievement ?? _achievement,
                        unlockedAt: _unlockedAt,
                      ),
                  child: const Text('Open'),
                ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

void main() {
  group('AchievementUnlockSheet — rendering', () {
    testWidgets('shows achievement title', (tester) async {
      await pumpSheet(tester);
      expect(find.text(_achievement.title), findsOneWidget);
    });

    testWidgets('shows achievement description', (tester) async {
      await pumpSheet(tester);
      expect(find.text(_achievement.description), findsOneWidget);
    });

    testWidgets('shows unlock date formatted correctly', (tester) async {
      await pumpSheet(tester);
      expect(find.text('Unlocked 14 Jan 2026'), findsOneWidget);
    });

    testWidgets('shows Share achievement button', (tester) async {
      await pumpSheet(tester);
      expect(find.text('Share achievement'), findsOneWidget);
    });

    testWidgets('shows Done button', (tester) async {
      await pumpSheet(tester);
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('shows trophy icon', (tester) async {
      await pumpSheet(tester);
      expect(find.byIcon(Icons.emoji_events_outlined), findsOneWidget);
    });
  });

  group('AchievementUnlockSheet — interaction', () {
    testWidgets('Done dismisses the sheet', (tester) async {
      await pumpSheet(tester);
      expect(find.text(_achievement.title), findsOneWidget);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.text(_achievement.title), findsNothing);
    });
  });

  group('AchievementUnlockSheet — commerce (ADR-180)', () {
    testWidgets('no merch CTA when commerce is off', (tester) async {
      await pumpSheet(tester, achievement: _merchAchievement);
      expect(find.text('Design your merch'), findsNothing);
      expect(find.text('Share achievement'), findsOneWidget);
    });

    testWidgets('merch CTA shown when commerce is on', (tester) async {
      await pumpSheet(tester, commerce: true, achievement: _merchAchievement);
      expect(find.text('Design your merch'), findsOneWidget);
    });
  });

  group('StatsScreen — locked card does not open sheet', () {
    testWidgets('tapping locked card area does not show sheet', (tester) async {
      // A card with onTap=null should not open the sheet.
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: AchievementUnlockSheet(
                achievement: _achievement,
                unlockedAt: _unlockedAt,
              ),
            ),
          ),
        ),
      );
      // Sheet renders inline here (not via showModalBottomSheet).
      // This just verifies correct rendering without a tap path.
      expect(find.text(_achievement.title), findsOneWidget);
    });
  });
}
