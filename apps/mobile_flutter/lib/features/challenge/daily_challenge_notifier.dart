import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_models/shared_models.dart';

import '../../data/daily_challenge_repository.dart';
import 'guess_normalizer.dart';

// ── State ─────────────────────────────────────────────────────────────────────

/// Loaded state for the Daily Heritage Challenge screen.
class DailyChallengeState {
  const DailyChallengeState({
    required this.challenge,
    required this.progress,
    required this.site,
    this.submitting = false,
  });

  /// The server-side clues document from Firestore (M133).
  final DailyChallenge challenge;

  /// Local progress for today (clues revealed, guesses, solved state).
  final DailyChallengeProgress progress;

  /// The resolved [WorldHeritageSite] for today's challenge.
  final WorldHeritageSite site;

  /// True while a guess is being persisted. Prevents double-submit.
  final bool submitting;

  DailyChallengeState copyWith({
    DailyChallengeProgress? progress,
    bool? submitting,
  }) {
    return DailyChallengeState(
      challenge: challenge,
      progress: progress ?? this.progress,
      site: site,
      submitting: submitting ?? this.submitting,
    );
  }
}

// ── Notifier ──────────────────────────────────────────────────────────────────

/// Drives the [DailyChallengeScreen]. Initial state is provided by the
/// provider after composing the three async dependencies (challenge,
/// progress, sites). Mutations persist via [DailyChallengeRepository].
class DailyChallengeNotifier
    extends StateNotifier<AsyncValue<DailyChallengeState>> {
  DailyChallengeNotifier({
    required AsyncValue<DailyChallengeState> initial,
    required DailyChallengeRepository repo,
  })  : _repo = repo,
        super(initial);

  final DailyChallengeRepository _repo;

  /// Updates state when the underlying async providers change (e.g. loading →
  /// data). Called from the provider when `initial` changes.
  void update(AsyncValue<DailyChallengeState> next) {
    // Don't regress data → loading (happens when provider rebuilds).
    if (state is AsyncData && next is AsyncLoading) return;
    state = next;
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  /// Reveals the next clue. No-op if already at clue 5 or solved.
  Future<void> revealNextClue() async {
    final current = state.valueOrNull;
    if (current == null || current.progress.solved) return;
    if (current.progress.cluesRevealed >= 5) return;

    final updated =
        current.progress.copyWith(cluesRevealed: current.progress.cluesRevealed + 1);
    state = AsyncValue.data(current.copyWith(progress: updated));
    await _repo.save(updated);
  }

  /// Submits [input] as a guess. Returns true if correct.
  ///
  /// No-op if solved or already submitting.
  Future<bool> submitGuess(String input) async {
    final current = state.valueOrNull;
    if (current == null || current.progress.solved || current.submitting) {
      return false;
    }

    state = AsyncValue.data(current.copyWith(submitting: true));

    final isCorrect = guessMatches(input, current.site.name);

    final DailyChallengeProgress updated;
    if (isCorrect) {
      updated = current.progress.copyWith(
        solved: true,
        solvedAtClue: current.progress.cluesRevealed,
      );
    } else {
      updated = current.progress.copyWith(
        guesses: [...current.progress.guesses, input.trim()],
      );
    }

    await _repo.save(updated);
    if (mounted) {
      state = AsyncValue.data(current.copyWith(
        progress: updated,
        submitting: false,
      ));
    }
    return isCorrect;
  }
}

// ── Helper: build initial state from resolved deps ────────────────────────────

/// Constructs a [DailyChallengeState] from the three resolved async values.
///
/// Throws [StateError] if the site referenced by [challenge.siteId] is not
/// present in [allSites] (indicates a data integrity issue).
DailyChallengeState buildInitialChallengeState({
  required DailyChallenge challenge,
  required DailyChallengeProgress? savedProgress,
  required List<WorldHeritageSite> allSites,
}) {
  final site = allSites.where((s) => s.siteId == challenge.siteId).firstOrNull;
  if (site == null) {
    throw StateError('WHS site ${challenge.siteId} not found in bundled dataset');
  }
  final today = DateFormat('yyyy-MM-dd').format(DateTime.now().toUtc());
  final progress = savedProgress ??
      DailyChallengeProgress(
        date: today,
        siteId: challenge.siteId,
        cluesRevealed: 1,
        guesses: const [],
        solved: false,
      );
  return DailyChallengeState(challenge: challenge, progress: progress, site: site);
}
