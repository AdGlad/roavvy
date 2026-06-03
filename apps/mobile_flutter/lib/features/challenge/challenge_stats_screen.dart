import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';
import 'daily_challenge_stats.dart';

/// Full-screen modal showing the user's Daily Heritage Challenge statistics.
///
/// Displays streak, solve rate, averages, and a 30-day solve grid.
/// Opened from the result overlay "View Stats" button or long-press on the
/// challenge chip. Device-local data only (ADR-005).
class ChallengeStatsScreen extends ConsumerWidget {
  const ChallengeStatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aggregateAsync = ref.watch(challengeAggregateProvider);
    final last30Async = ref.watch(challengeLast30Provider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Stats'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: aggregateAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Could not load stats.')),
        data: (agg) => _StatsBody(aggregate: agg, last30Async: last30Async),
      ),
    );
  }
}

class _StatsBody extends StatelessWidget {
  const _StatsBody({required this.aggregate, required this.last30Async});

  final ChallengeAggregate aggregate;
  final AsyncValue<List<({String date, bool solved, int guessesUsed})>>
  last30Async;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (aggregate.totalPlayed == 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.emoji_events_outlined,
                size: 56,
                color: theme.colorScheme.outline,
              ),
              const SizedBox(height: 16),
              Text('No challenges yet', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                'Complete your first challenge to see your stats here.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final solvePercent =
        aggregate.totalPlayed > 0
            ? (aggregate.totalSolved / aggregate.totalPlayed * 100).round()
            : 0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      children: [
        // ── Streak row ────────────────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.local_fire_department_rounded,
                iconColor: const Color(0xFFFF6F00),
                label: 'Current Streak',
                value: '${aggregate.currentStreak}',
                unit: aggregate.currentStreak == 1 ? 'day' : 'days',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.emoji_events_rounded,
                iconColor: const Color(0xFFF9A825),
                label: 'Best Streak',
                value: '${aggregate.bestStreak}',
                unit: aggregate.bestStreak == 1 ? 'day' : 'days',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── Totals row ────────────────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.calendar_today_outlined,
                iconColor: theme.colorScheme.primary,
                label: 'Played',
                value: '${aggregate.totalPlayed}',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatCard(
                icon: Icons.check_circle_outline_rounded,
                iconColor: const Color(0xFF388E3C),
                label: 'Solved',
                value: '${aggregate.totalSolved}',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatCard(
                icon: Icons.percent_rounded,
                iconColor: const Color(0xFF1976D2),
                label: 'Win Rate',
                value: '$solvePercent%',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── Averages row ──────────────────────────────────────────────────
        if (aggregate.totalSolved > 0)
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.touch_app_outlined,
                  iconColor: const Color(0xFF26C6DA),
                  label: 'Avg Guesses',
                  value: aggregate.avgGuesses.toStringAsFixed(1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.visibility_outlined,
                  iconColor: const Color(0xFF9C27B0),
                  label: 'Avg Clues',
                  value: aggregate.avgClues.toStringAsFixed(1),
                ),
              ),
            ],
          ),

        const SizedBox(height: 24),

        // ── 30-day grid ───────────────────────────────────────────────────
        Text(
          'Last 30 Days',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        last30Async.when(
          loading:
              () => const SizedBox(
                height: 56,
                child: Center(child: CircularProgressIndicator()),
              ),
          error: (_, __) => const SizedBox.shrink(),
          data: (rows) => _SolveGrid(rows: rows),
        ),
      ],
    );
  }
}

// ── Stat card ─────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.unit,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (unit != null) ...[
                const SizedBox(width: 3),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    unit!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ],
          ),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ── 30-day solve grid ─────────────────────────────────────────────────────────

class _SolveGrid extends StatelessWidget {
  const _SolveGrid({required this.rows});

  final List<({String date, bool solved, int guessesUsed})> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Build a date → entry map for O(1) lookup.
    final byDate = {for (final r in rows) r.date: r};

    // Generate the last 30 calendar days (today first = index 0).
    final today = DateTime.now().toUtc();
    final dates = List.generate(30, (i) {
      final d = today.subtract(Duration(days: i));
      return DateFormat('yyyy-MM-dd').format(d);
    });

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children:
          dates.map((date) {
            final entry = byDate[date];
            final Color color;
            if (entry == null) {
              color = theme.colorScheme.surfaceContainerHighest;
            } else if (entry.solved) {
              color = const Color(0xFF388E3C);
            } else {
              color = const Color(0xFFD32F2F);
            }
            return Tooltip(
              message: _label(date, entry),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            );
          }).toList(),
    );
  }

  String _label(
    String date,
    ({String date, bool solved, int guessesUsed})? entry,
  ) {
    final d = DateTime.parse(date);
    final formatted = DateFormat('d MMM').format(d);
    if (entry == null) return '$formatted — not played';
    return entry.solved ? '$formatted — solved' : '$formatted — not solved';
  }
}
