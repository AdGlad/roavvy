// T4.7 — DailyChallengeScreen widget tests

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/providers.dart';
import 'package:mobile_flutter/data/daily_challenge_repository.dart';
import 'package:mobile_flutter/data/db/roavvy_database.dart';
import 'package:mobile_flutter/features/challenge/daily_challenge_notifier.dart';
import 'package:mobile_flutter/features/challenge/daily_challenge_screen.dart';
import 'package:mobile_flutter/features/challenge/daily_challenge_stats.dart';
import 'package:shared_models/shared_models.dart';

// ── Fixture helpers ────────────────────────────────────────────────────────────

const _challenge = DailyChallenge(
  siteId: '208',
  difficulty: 'medium',
  clues: [
    ChallengeClue(type: 'geography', text: 'Located in South Asia'),
    ChallengeClue(type: 'category', text: 'Cultural site'),
    ChallengeClue(type: 'historical', text: 'Built in the 17th century'),
    ChallengeClue(type: 'location', text: 'Agra, India'),
    ChallengeClue(type: 'direct', text: 'A mausoleum of white marble'),
  ],
);

const _site = WorldHeritageSite(
  siteId: '208',
  name: 'Taj Mahal',
  latitude: 27.175,
  longitude: 78.042,
  countryCode: 'IN',
  inscriptionYear: 1983,
  category: 'Cultural',
  region: 'Asia and the Pacific',
);

DailyChallengeProgress _progress({
  int cluesRevealed = 1,
  List<String> guesses = const [],
  bool solved = false,
  bool failed = false,
}) =>
    DailyChallengeProgress(
      date: '2026-06-03',
      siteId: '208',
      cluesRevealed: cluesRevealed,
      guesses: guesses,
      solved: solved,
      failed: failed,
    );

DailyChallengeState _state({
  int cluesRevealed = 1,
  List<String> guesses = const [],
  bool solved = false,
  bool failed = false,
}) =>
    DailyChallengeState(
      challenge: _challenge,
      progress: _progress(
        cluesRevealed: cluesRevealed,
        guesses: guesses,
        solved: solved,
        failed: failed,
      ),
      site: _site,
    );

/// Builds the screen with an injected AsyncValue state for the notifier.
Widget _pumpChallenge(
  WidgetTester tester,
  AsyncValue<DailyChallengeState> initialState,
) {
  final db = RoavvyDatabase(NativeDatabase.memory());
  final repo = DailyChallengeRepository(db);
  final statsService = ChallengeStatsService(db);

  return ProviderScope(
    overrides: [
      roavvyDatabaseProvider.overrideWithValue(db),
      dailyChallengeRepositoryProvider.overrideWithValue(repo),
      challengeStatsServiceProvider.overrideWithValue(statsService),
      allWhsSitesProvider.overrideWith((_) async => [_site]),
      dailyChallengeNotifierProvider.overrideWith(
        (ref) => DailyChallengeNotifier(
          initial: initialState,
          repo: repo,
          allSites: [_site],
          statsService: statsService,
        ),
      ),
    ],
    child: const MaterialApp(home: DailyChallengeScreen()),
  );
}

// ── Tests ──────────────────────────────────────────────────────────────────────

void main() {
  group('DailyChallengeScreen — loading state', () {
    testWidgets('shows CircularProgressIndicator while loading', (tester) async {
      await tester.pumpWidget(
        _pumpChallenge(tester, const AsyncValue.loading()),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.textContaining("Loading today's challenge"), findsOneWidget);
    });
  });

  group('DailyChallengeScreen — error state', () {
    testWidgets('shows Retry button on error', (tester) async {
      await tester.pumpWidget(
        _pumpChallenge(
          tester,
          AsyncValue.error('network error', StackTrace.empty),
        ),
      );
      await tester.pump();

      expect(find.text('Retry'), findsOneWidget);
    });
  });

  group('DailyChallengeScreen — data state', () {
    testWidgets('first clue is visible on load', (tester) async {
      await tester.pumpWidget(
        _pumpChallenge(tester, AsyncValue.data(_state(cluesRevealed: 1))),
      );
      await tester.pumpAndSettle();

      expect(find.text('Located in South Asia'), findsOneWidget);
    });

    testWidgets('only revealed clues are visible (cluesRevealed=2)', (tester) async {
      await tester.pumpWidget(
        _pumpChallenge(tester, AsyncValue.data(_state(cluesRevealed: 2))),
      );
      await tester.pumpAndSettle();

      expect(find.text('Located in South Asia'), findsOneWidget);
      expect(find.text('Cultural site'), findsOneWidget);
      // Clue 3 is not yet revealed
      expect(find.text('Built in the 17th century'), findsNothing);
    });

    testWidgets('guess input TextField is visible when game is active',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _pumpChallenge(tester, AsyncValue.data(_state())),
      );
      await tester.pumpAndSettle();

      // The autocomplete field view builder wraps a TextField
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('solved state shows ✅ result overlay', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _pumpChallenge(
          tester,
          AsyncValue.data(_state(solved: true, cluesRevealed: 3)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Solved'), findsAtLeastNWidgets(1));
    });

    testWidgets('failed state shows ❌ result overlay', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _pumpChallenge(
          tester,
          AsyncValue.data(_state(
            failed: true,
            guesses: ['Wrong 1', 'Wrong 2', 'Wrong 3', 'Wrong 4', 'Wrong 5'],
          )),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Better luck tomorrow'), findsOneWidget);
    });

    testWidgets('app bar shows "Daily Challenge" title', (tester) async {
      await tester.pumpWidget(
        _pumpChallenge(tester, AsyncValue.data(_state())),
      );
      await tester.pumpAndSettle();

      expect(find.text('Daily Challenge'), findsOneWidget);
    });
  });
}
