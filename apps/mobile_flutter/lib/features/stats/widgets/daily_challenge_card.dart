import 'package:flutter/material.dart';

import '../../challenge/daily_challenge_stats.dart';

/// Dedicated Daily Challenge statistics card for the Stats screen (M147).
///
/// Shows current streak (with heated flame at 7+ days), best streak,
/// solve rate, and average clues. Replaces the inline card previously
/// buried inside the UNESCO achievement tab.
class DailyChallengeCard extends StatelessWidget {
  const DailyChallengeCard({super.key, required this.aggregate});

  final ChallengeAggregate aggregate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final agg = aggregate;
    final isHot = agg.currentStreak >= 7;
    final isWarm = agg.currentStreak >= 3;
    final solveRate =
        agg.totalPlayed == 0 ? null : agg.totalSolved / agg.totalPlayed;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ───────────────────────────────────────────────────
          Row(
            children: [
              Icon(
                Icons.local_fire_department,
                size: 17,
                color: isHot ? Colors.deepOrange : Colors.orange,
              ),
              const SizedBox(width: 6),
              Text(
                'Daily Challenge',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (isWarm)
                _StreakBadge(streak: agg.currentStreak, isHot: isHot),
            ],
          ),
          const SizedBox(height: 10),

          // ── Stats card ───────────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: _ChallengeCell(
                    label: 'Streak',
                    value:
                        agg.currentStreak == 0 ? '—' : '${agg.currentStreak}',
                    icon: Icons.local_fire_department,
                    iconColor: isHot ? Colors.deepOrange : Colors.orange,
                  ),
                ),
                _VerticalDivider(),
                Expanded(
                  child: _ChallengeCell(
                    label: 'Best',
                    value: agg.bestStreak == 0 ? '—' : '${agg.bestStreak}',
                    icon: Icons.emoji_events_outlined,
                    iconColor: const Color(0xFFF2C94C),
                  ),
                ),
                _VerticalDivider(),
                Expanded(
                  child: _ChallengeCell(
                    label: 'Solved',
                    value:
                        solveRate == null
                            ? '—'
                            : '${(solveRate * 100).round()}%',
                    icon: Icons.check_circle_outline,
                    iconColor:
                        solveRate == 1.0 ? Colors.amber : Colors.green,
                  ),
                ),
                _VerticalDivider(),
                Expanded(
                  child: _ChallengeCell(
                    label: 'Avg clues',
                    value:
                        agg.totalSolved == 0
                            ? '—'
                            : agg.avgClues.toStringAsFixed(1),
                    icon: Icons.lightbulb_outline,
                    iconColor: Colors.amber,
                  ),
                ),
              ],
            ),
          ),

          // ── Motivation line ──────────────────────────────────────────────
          if (agg.currentStreak == 0 && agg.totalPlayed > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Play today to start a new streak!',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Streak badge ──────────────────────────────────────────────────────────────

class _StreakBadge extends StatelessWidget {
  const _StreakBadge({required this.streak, required this.isHot});

  final int streak;
  final bool isHot;

  @override
  Widget build(BuildContext context) {
    final color = isHot ? Colors.deepOrange : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        '$streak day streak',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// ── Cell ──────────────────────────────────────────────────────────────────────

class _ChallengeCell extends StatelessWidget {
  const _ChallengeCell({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: iconColor),
        const SizedBox(height: 5),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

// ── Divider ───────────────────────────────────────────────────────────────────

class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 40,
    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.18),
  );
}
