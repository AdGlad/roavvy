// T5 — MerchExclusiveDesign unit + widget tests (M144)
//
// Covers:
//   1. CountryCountCondition.isSatisfied() — true when count meets target
//   2. CountryCountCondition.isSatisfied() — false when count below target
//   3. remaining() — correct countdown
//   4. MerchLockedDesignCard shows lock + progress when locked
//   5. MerchLockedDesignCard shows "Unlocked for you" badge when unlocked

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_models/shared_models.dart';

import 'package:mobile_flutter/features/merch/merch_exclusive_design.dart';
import 'package:mobile_flutter/features/merch/merch_option_list_widgets.dart';

// ── Fixtures ──────────────────────────────────────────────────────────────────

const _design50 = MerchExclusiveDesign(
  id: 'half_the_world',
  label: 'Half the World',
  description: 'Visit 50 countries',
  unlockCondition: CountryCountCondition(50),
  template: CardTemplateType.passport,
  emoji: '🌍',
);

const _ctx40 = MerchUnlockContext(countryCount: 40, continentCount: 4);
const _ctx50 = MerchUnlockContext(countryCount: 50, continentCount: 5);

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

// ── Unit tests ────────────────────────────────────────────────────────────────

void main() {
  group('CountryCountCondition', () {
    test('isSatisfied returns true when count meets target', () {
      const cond = CountryCountCondition(50);
      expect(cond.isSatisfied(_ctx50), isTrue);
    });

    test('isSatisfied returns false when count below target', () {
      const cond = CountryCountCondition(50);
      expect(cond.isSatisfied(_ctx40), isFalse);
    });

    test('remaining() returns correct countdown', () {
      const cond = CountryCountCondition(50);
      expect(cond.remaining(_ctx40), equals(10));
    });

    test('remaining() returns 0 when already unlocked', () {
      const cond = CountryCountCondition(50);
      expect(cond.remaining(_ctx50), equals(0));
    });
  });

  // ── Widget tests ──────────────────────────────────────────────────────────

  group('MerchLockedDesignCard', () {
    testWidgets('shows lock icon and progress when locked', (tester) async {
      await tester.pumpWidget(
        _wrap(
          MerchLockedDesignCard(
            design: _design50,
            ctx: _ctx40,
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.textContaining('10 more to unlock'), findsOneWidget);
      expect(find.text('✦ Unlocked for you'), findsNothing);
    });

    testWidgets('shows unlocked badge when condition satisfied', (tester) async {
      await tester.pumpWidget(
        _wrap(
          MerchLockedDesignCard(
            design: _design50,
            ctx: _ctx50,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('✦ Unlocked for you'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });
  });
}
