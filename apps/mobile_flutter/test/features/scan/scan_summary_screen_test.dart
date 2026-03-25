import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/providers.dart';
import 'package:mobile_flutter/features/scan/scan_summary_screen.dart';
import 'package:mobile_flutter/features/xp/xp_event.dart';
import 'package:mobile_flutter/features/xp/xp_notifier.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

EffectiveVisitedCountry _country(String code) => EffectiveVisitedCountry(
      countryCode: code,
      hasPhotoEvidence: true,
      photoCount: 1,
    );

/// Stub XpNotifier that never reads from the database.
/// Starts at XpState.zero (level 1 — Traveller) and ignores awards.
class _StubXpNotifier extends StateNotifier<XpState> implements XpNotifier {
  _StubXpNotifier() : super(XpState.zero);

  @override
  Stream<int> get xpEarned => const Stream.empty();

  @override
  Future<void> award(XpEvent event) async {}
}

Future<void> pumpSummary(
  WidgetTester tester, {
  List<EffectiveVisitedCountry> newCountries = const [],
  List<String> newAchievementIds = const [],
  List<String> newCodes = const [],
  VoidCallback? onDone,
  DateTime? lastScanAt,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        xpNotifierProvider.overrideWith((_) => _StubXpNotifier()),
      ],
      child: MaterialApp(
        home: ScanSummaryScreen(
          newCountries: newCountries,
          newAchievementIds: newAchievementIds,
          newCodes: newCodes,
          onDone: onDone ?? () {},
          lastScanAt: lastScanAt,
        ),
      ),
    ),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  group('ScanSummaryScreen — State A (new discoveries)', () {
    testWidgets('shows hero count for one new country', (tester) async {
      await pumpSummary(tester, newCountries: [_country('GB')]);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('new country discovered'), findsOneWidget);
    });

    testWidgets('shows hero count for multiple new countries', (tester) async {
      await pumpSummary(
          tester, newCountries: [_country('GB'), _country('JP'), _country('US')]);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('new countries discovered'), findsOneWidget);
    });

    testWidgets('shows country names in list', (tester) async {
      await pumpSummary(tester, newCountries: [_country('DE'), _country('FR')]);
      expect(find.textContaining('Germany'), findsOneWidget);
      expect(find.textContaining('France'), findsOneWidget);
    });

    testWidgets('shows continent badge for first country on a continent',
        (tester) async {
      // GB = Europe, JP = Asia — each first on their continent
      await pumpSummary(
          tester, newCountries: [_country('GB'), _country('JP')]);
      expect(find.textContaining('First country in Europe'), findsOneWidget);
      expect(find.textContaining('First country in Asia'), findsOneWidget);
    });

    testWidgets('does not show continent badge for second country on same continent',
        (tester) async {
      // FR and DE are both Europe — only one continent badge
      await pumpSummary(
          tester, newCountries: [_country('FR'), _country('DE')]);
      expect(find.textContaining('First country in Europe'), findsOneWidget);
    });

    testWidgets('shows Explore your map CTA', (tester) async {
      await pumpSummary(tester, newCountries: [_country('GB')]);
      expect(find.text('Explore your map'), findsOneWidget);
    });

    testWidgets('CTA calls onDone when newCodes is empty', (tester) async {
      bool called = false;
      await pumpSummary(
        tester,
        newCountries: [_country('GB')],
        newCodes: const [],
        onDone: () => called = true,
      );
      await tester.tap(find.text('Explore your map'));
      await tester.pump();
      expect(called, isTrue);
    });

    testWidgets('achievements section hidden when no achievements', (tester) async {
      await pumpSummary(tester, newCountries: [_country('GB')]);
      expect(find.text('Achievement unlocked'), findsNothing);
      expect(find.text('Achievements unlocked'), findsNothing);
    });

    testWidgets('shows achievement chip when achievement unlocked', (tester) async {
      final achievementId = kAchievements.first.id;
      await pumpSummary(
        tester,
        newCountries: [_country('GB')],
        newAchievementIds: [achievementId],
      );
      expect(find.text('Achievement unlocked'), findsOneWidget);
      expect(find.text(kAchievements.first.title), findsOneWidget);
    });

    testWidgets('shows plural header for multiple achievements', (tester) async {
      final ids = kAchievements.take(2).map((a) => a.id).toList();
      await pumpSummary(
        tester,
        newCountries: [_country('GB')],
        newAchievementIds: ids,
      );
      expect(find.text('Achievements unlocked'), findsOneWidget);
    });
  });

  group('ScanSummaryScreen — Task 52 animation (Task 52)', () {
    testWidgets('confetti widget absent in nothing-new variant', (tester) async {
      await pumpSummary(tester); // newCountries empty
      await tester.pumpAndSettle();
      expect(find.byType(ConfettiWidget), findsNothing);
    });

    testWidgets('confetti widget absent when disableAnimations is true',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: MaterialApp(
              home: ScanSummaryScreen(
                newCountries: [_country('GB')],
                newAchievementIds: const [],
                newCodes: const [],
                onDone: () {},
              ),
            ),
          ),
        ),
      );
      // initAnimations runs post-frame
      await tester.pump();
      expect(find.byType(ConfettiWidget), findsNothing);
    });

    testWidgets('confetti widget present when new countries exist', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: ScanSummaryScreen(
              newCountries: [_country('GB')],
              newAchievementIds: const [],
              newCodes: const [],
              onDone: () {},
            ),
          ),
        ),
      );
      // Post-frame callback runs after first pump
      await tester.pump();
      expect(find.byType(ConfettiWidget), findsOneWidget);
    });
  });

  group('ScanSummaryScreen — State B (nothing new)', () {
    testWidgets('shows All up to date title', (tester) async {
      await pumpSummary(tester);
      expect(find.text('All up to date'), findsOneWidget);
      expect(find.text('No new countries found this time.'), findsOneWidget);
    });

    testWidgets('shows last scan date when provided', (tester) async {
      await pumpSummary(
        tester,
        lastScanAt: DateTime(2026, 3, 15),
      );
      expect(find.text('Last scanned 15 Mar 2026'), findsOneWidget);
    });

    testWidgets('omits last scan line when lastScanAt is null', (tester) async {
      await pumpSummary(tester);
      expect(find.textContaining('Last scanned'), findsNothing);
    });

    testWidgets('shows Back to map CTA', (tester) async {
      await pumpSummary(tester);
      expect(find.text('Back to map'), findsOneWidget);
    });

    testWidgets('Back to map calls onDone', (tester) async {
      bool called = false;
      await pumpSummary(tester, onDone: () => called = true);
      await tester.tap(find.text('Back to map'));
      await tester.pumpAndSettle();
      expect(called, isTrue);
    });
  });

  group('ScanSummaryScreen — commerce entry point (M29)', () {
    testWidgets('shows Get a poster CTA in State A', (tester) async {
      await pumpSummary(
        tester,
        newCountries: [_country('GB')],
        newCodes: ['GB'],
      );
      expect(
        find.textContaining('Get a poster with your new discoveries'),
        findsOneWidget,
      );
    });

    testWidgets('Get a poster CTA not shown in State B', (tester) async {
      await pumpSummary(tester); // no new countries
      expect(
        find.textContaining('Get a poster with your new discoveries'),
        findsNothing,
      );
    });
  });
}
