// T4 — Achievement merch CTA widget tests (M143)
//
// Covers:
//   1. AchievementUnlockSheet shows coral merch button when unlocked + merch != null
//   2. AchievementUnlockSheet hides merch button when unlocked but merch == null
//   3. AchievementUnlockSheet hides merch button when locked (merch != null but locked)
//   4. MerchMomentsSection shows action-oriented CTA label
//   5. MerchMomentsSection header is 'Design from your achievements'

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_models/shared_models.dart';

import 'package:mobile_flutter/features/scan/achievement_unlock_sheet.dart';
import 'package:mobile_flutter/features/stats/widgets/merch_moments_section.dart';

// ── Fixtures ──────────────────────────────────────────────────────────────────

final _achWithMerch = Achievement(
  id: 'countries_5', // must match an ID in kAchievements for MerchMomentsSection
  title: 'Globetrotter',
  description: 'Visit 10 countries',
  category: AchievementCategory.countries,
  progressTarget: 10,
  merch: MerchTriggerType.flagGrid,
);

final _achNoMerch = Achievement(
  id: 'test_no_merch',
  title: 'Explorer',
  description: 'Visit 5 countries',
  category: AchievementCategory.countries,
  progressTarget: 5,
);

final _unlockedAt = DateTime(2025, 6, 1);

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: child),
    );

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('AchievementUnlockSheet merch CTA', () {
    testWidgets(
        'shows "Design your merch" button when unlocked and merch != null',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          AchievementUnlockSheet(
            achievement: _achWithMerch,
            unlockedAt: _unlockedAt,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Design your merch'), findsOneWidget);
    });

    testWidgets('hides merch button when unlocked but merch == null',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          AchievementUnlockSheet(
            achievement: _achNoMerch,
            unlockedAt: _unlockedAt,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Design your merch'), findsNothing);
    });

    testWidgets('hides merch button when achievement is locked',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          AchievementUnlockSheet(
            achievement: _achWithMerch,
            // unlockedAt: null → locked state
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Design your merch'), findsNothing);
    });
  });

  group('MerchMomentsSection', () {
    testWidgets('header is "Wear your achievements"', (tester) async {
      final unlocked = {_achWithMerch.id: _unlockedAt};
      await tester.pumpWidget(
        _wrap(MerchMomentsSection(unlockedById: unlocked)),
      );
      await tester.pump();

      expect(find.text('Wear your achievements'), findsOneWidget);
    });

    testWidgets('shows action-oriented CTA label for flagGrid', (tester) async {
      final unlocked = {_achWithMerch.id: _unlockedAt};
      await tester.pumpWidget(
        _wrap(MerchMomentsSection(unlockedById: unlocked)),
      );
      await tester.pump();

      expect(find.text('Flag Tee'), findsOneWidget);
    });
  });
}
