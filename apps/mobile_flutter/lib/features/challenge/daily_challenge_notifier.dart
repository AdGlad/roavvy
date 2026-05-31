import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_models/shared_models.dart';

import '../../data/daily_challenge_repository.dart';
import 'daily_challenge_service.dart';
import 'daily_challenge_stats.dart';
import 'guess_normalizer.dart';
import 'hot_cold_feedback.dart';

// ── Guess result ──────────────────────────────────────────────────────────────

/// Distance + directional feedback for a wrong guess. In-memory only.
class GuessResult {
  const GuessResult({
    required this.guess,
    required this.distanceKm,
    required this.direction,
    required this.hotColdLabel,
    required this.hotColdEmoji,
    required this.hotColdColor,
  });

  final String guess;
  final double distanceKm;

  /// Cardinal direction from guessed site to target, e.g. `'north-east'`.
  final String direction;
  final String hotColdLabel;
  final String hotColdEmoji;
  final Color hotColdColor;
}

// ── State ─────────────────────────────────────────────────────────────────────

/// Loaded state for the Daily Heritage Challenge screen.
class DailyChallengeState {
  const DailyChallengeState({
    required this.challenge,
    required this.progress,
    required this.site,
    this.submitting = false,
    this.lastGuessResult,
  });

  /// The server-side clues document from Firestore (M133).
  final DailyChallenge challenge;

  /// Local progress for today (clues revealed, guesses, solved state).
  final DailyChallengeProgress progress;

  /// The resolved [WorldHeritageSite] for today's challenge.
  final WorldHeritageSite site;

  /// True while a guess is being persisted. Prevents double-submit.
  final bool submitting;

  /// Hot/cold result from the most recent wrong guess. Null until first guess.
  final GuessResult? lastGuessResult;

  /// Maximum number of wrong guesses allowed before game ends.
  static const int maxGuesses = 5;

  DailyChallengeState copyWith({
    DailyChallengeProgress? progress,
    bool? submitting,
    GuessResult? lastGuessResult,
    bool clearLastGuessResult = false,
  }) {
    return DailyChallengeState(
      challenge: challenge,
      progress: progress ?? this.progress,
      site: site,
      submitting: submitting ?? this.submitting,
      lastGuessResult: clearLastGuessResult
          ? null
          : lastGuessResult ?? this.lastGuessResult,
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
    required List<WorldHeritageSite> allSites,
    required ChallengeStatsService statsService,
  })  : _repo = repo,
        _allSites = allSites,
        _stats = statsService,
        super(initial);

  final DailyChallengeRepository _repo;
  final List<WorldHeritageSite> _allSites;
  final ChallengeStatsService _stats;

  /// Updates state when the underlying async providers change (e.g. loading →
  /// data). Called from the provider when `initial` changes.
  void update(AsyncValue<DailyChallengeState> next) {
    // Don't regress data → loading (happens when provider rebuilds).
    if (state is AsyncData && next is AsyncLoading) return;
    state = next;
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  /// Immediately ends the game as failed — triggered by "Reveal Answer" button.
  Future<void> revealAnswer() async {
    final current = state.valueOrNull;
    if (current == null || current.progress.solved || current.progress.failed) {
      return;
    }
    final updated = current.progress.copyWith(failed: true);
    await _repo.save(updated);
    await _stats.record(
      date: updated.date,
      siteId: updated.siteId,
      solved: false,
      guessesUsed: updated.guesses.length,
      cluesUsed: updated.cluesRevealed,
    );
    if (mounted) {
      state = AsyncValue.data(current.copyWith(progress: updated, submitting: false));
    }
  }

  /// Reveals the next clue. No-op if already at clue 5 or solved/failed.
  Future<void> revealNextClue() async {
    final current = state.valueOrNull;
    if (current == null || current.progress.solved || current.progress.failed) {
      return;
    }
    if (current.progress.cluesRevealed >= 5) return;

    final updated =
        current.progress.copyWith(cluesRevealed: current.progress.cluesRevealed + 1);
    state = AsyncValue.data(current.copyWith(progress: updated));
    await _repo.save(updated);
  }

  /// Submits [input] (an official site name from autocomplete) as a guess.
  /// Returns true if correct.
  ///
  /// No-op if already solved, failed, or submitting.
  /// On the 5th wrong guess, sets `failed = true` and triggers the result overlay.
  Future<bool> submitGuess(String input) async {
    final current = state.valueOrNull;
    if (current == null ||
        current.progress.solved ||
        current.progress.failed ||
        current.submitting) {
      return false;
    }

    state = AsyncValue.data(current.copyWith(submitting: true));

    final isCorrect = guessMatches(input, current.site.name);

    if (isCorrect) {
      final updated = current.progress.copyWith(
        solved: true,
        solvedAtClue: current.progress.cluesRevealed,
      );
      await _repo.save(updated);
      await _stats.record(
        date: updated.date,
        siteId: updated.siteId,
        solved: true,
        guessesUsed: updated.guesses.length,
        cluesUsed: updated.cluesRevealed,
      );
      if (mounted) {
        state = AsyncValue.data(current.copyWith(
          progress: updated,
          submitting: false,
          clearLastGuessResult: true,
        ));
      }
      return true;
    }

    // Wrong guess — compute hot/cold feedback.
    final guessResult = _buildGuessResult(input, current.site);
    final newGuesses = [...current.progress.guesses, input.trim()];
    final exhausted = newGuesses.length >= DailyChallengeState.maxGuesses;
    final updated = current.progress.copyWith(
      guesses: newGuesses,
      failed: exhausted,
    );
    await _repo.save(updated);
    if (exhausted) {
      await _stats.record(
        date: updated.date,
        siteId: updated.siteId,
        solved: false,
        guessesUsed: updated.guesses.length,
        cluesUsed: updated.cluesRevealed,
      );
    }
    if (mounted) {
      state = AsyncValue.data(current.copyWith(
        progress: updated,
        submitting: false,
        lastGuessResult: guessResult,
      ));
    }
    return false;
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Builds a [GuessResult] by finding the guessed site in [_allSites] and
  /// computing distance + bearing to the challenge [target].
  GuessResult? _buildGuessResult(String input, WorldHeritageSite target) {
    final normalised = normalizeForGuess(input);
    final guessedSite = _allSites.firstWhere(
      (s) => normalizeForGuess(s.name) == normalised,
      orElse: () => _allSites.firstWhere(
        (s) => normalizeForGuess(s.name).contains(normalised) &&
            normalised.length >= 4,
        orElse: () => target, // fallback: use target (distance = 0)
      ),
    );
    final km = distanceKm(
      guessedSite.latitude, guessedSite.longitude,
      target.latitude, target.longitude,
    );
    final bearing = bearingDeg(
      guessedSite.latitude, guessedSite.longitude,
      target.latitude, target.longitude,
    );
    final direction = cardinalDirection(bearing);
    final rating = hotColdRating(km);
    return GuessResult(
      guess: input.trim(),
      distanceKm: km,
      direction: direction,
      hotColdLabel: rating.label,
      hotColdEmoji: rating.emoji,
      hotColdColor: rating.color,
    );
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
  final today = todayLocal();
  // Discard saved progress if the siteId changed (e.g. challenge was corrected
  // server-side). Using stale progress for a different site would show the
  // challenge as already solved / partially played when it is actually fresh.
  final validProgress = (savedProgress != null &&
          savedProgress.siteId == challenge.siteId)
      ? savedProgress
      : null;
  final progress = validProgress ??
      DailyChallengeProgress(
        date: today,
        siteId: challenge.siteId,
        cluesRevealed: 1,
        guesses: const [],
        solved: false,
      );
  return DailyChallengeState(challenge: challenge, progress: progress, site: site);
}
