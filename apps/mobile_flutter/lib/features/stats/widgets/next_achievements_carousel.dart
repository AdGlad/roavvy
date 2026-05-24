import 'package:flutter/material.dart';
import 'package:shared_models/shared_models.dart';

/// Horizontal carousel showing the 3 nearest unmet achievements (M97, ADR-148).
///
/// Sorted by ascending `(progressTarget - currentProgress)` so the
/// achievements closest to unlocking appear first.
class NextAchievementsCarousel extends StatelessWidget {
  const NextAchievementsCarousel({
    super.key,
    required this.countryCount,
    required this.continentCount,
    required this.tripCount,
    required this.thisYearCount,
    required this.unlockedIds,
  });

  final int countryCount;
  final int continentCount;
  final int tripCount;
  final int thisYearCount;
  final Set<String> unlockedIds;

  int _currentProgress(Achievement a) => switch (a.category) {
        AchievementCategory.countries => countryCount,
        AchievementCategory.continents => continentCount,
        AchievementCategory.trips => tripCount,
        AchievementCategory.thisYear => thisYearCount,
        AchievementCategory.heritageSites => 0, // M119: wired up in future polish
      };

  @override
  Widget build(BuildContext context) {
    final unmet = kAchievements
        .where((a) => !unlockedIds.contains(a.id))
        .map((a) => (a, a.progressTarget - _currentProgress(a)))
        .where((t) => t.$2 > 0)
        .toList()
      ..sort((a, b) => a.$2.compareTo(b.$2));

    final cards = unmet.take(3).toList();

    if (cards.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            'Next Achievements',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        SizedBox(
          height: 148,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: cards.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final (achievement, remaining) = cards[index];
              return _NextAchievementCard(
                achievement: achievement,
                current: _currentProgress(achievement),
                remaining: remaining,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _NextAchievementCard extends StatelessWidget {
  const _NextAchievementCard({
    required this.achievement,
    required this.current,
    required this.remaining,
  });

  final Achievement achievement;
  final int current;
  final int remaining;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = (current / achievement.progressTarget).clamp(0.0, 1.0);
    final unit = _unit(achievement.category);

    return Container(
      width: 200,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            achievement.title,
            style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            '${achievement.progressTarget} $unit',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
            backgroundColor: theme.colorScheme.outline.withValues(alpha: 0.2),
            valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
          ),
          const SizedBox(height: 6),
          Text(
            '$current / ${achievement.progressTarget}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          Text(
            '$remaining more to go',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.primary,
            ),
          ),
          if (achievement.merch != null) ...[
            const SizedBox(height: 4),
            Text(
              'Unlocks ${_merchLabel(achievement.merch!)}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  String _unit(AchievementCategory cat) => switch (cat) {
        AchievementCategory.countries => 'countries',
        AchievementCategory.continents => 'continents',
        AchievementCategory.trips => 'trips',
        AchievementCategory.thisYear => 'countries this year',
        AchievementCategory.heritageSites => 'heritage sites',
      };

  String _merchLabel(MerchTriggerType type) => switch (type) {
        MerchTriggerType.flagGrid => 'Flag Grid Tee',
        MerchTriggerType.passportStamp => 'Passport Stamp Tee',
        MerchTriggerType.timeline => 'Travel Timeline Tee',
        MerchTriggerType.country => 'Country Tee',
        MerchTriggerType.milestone => 'Milestone Tee',
      };
}
