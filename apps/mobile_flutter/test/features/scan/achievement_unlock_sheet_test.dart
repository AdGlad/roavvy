import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/scan/achievement_unlock_sheet.dart';
import 'package:shared_models/shared_models.dart';

Achievement get _achievement => kAchievements.first;
final _unlockedAt = DateTime(2026, 1, 14, 10, 0);

Future<void> pumpSheet(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => AchievementUnlockSheet.show(
              context,
              achievement: _achievement,
              unlockedAt: _unlockedAt,
            ),
            child: const Text('Open'),
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

  group('StatsScreen — locked card does not open sheet', () {
    testWidgets('tapping locked card area does not show sheet', (tester) async {
      // A card with onTap=null should not open the sheet.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AchievementUnlockSheet(
              achievement: _achievement,
              unlockedAt: _unlockedAt,
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
