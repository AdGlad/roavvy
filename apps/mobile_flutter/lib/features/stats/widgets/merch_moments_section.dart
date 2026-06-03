import 'package:flutter/material.dart';
import 'package:shared_models/shared_models.dart';

import '../../merch/achievement_merch_option_screen.dart';

/// Merch Moments section — up to 3 most recently unlocked merch-eligible
/// achievements with a product suggestion CTA (M97, ADR-148).
///
/// Returns [SizedBox.shrink] when no merch-eligible achievements are unlocked.
class MerchMomentsSection extends StatelessWidget {
  const MerchMomentsSection({super.key, required this.unlockedById});

  final Map<String, DateTime> unlockedById;

  @override
  Widget build(BuildContext context) {
    final eligible =
        kAchievements
            .where((a) => a.merch != null && unlockedById.containsKey(a.id))
            .toList()
          ..sort((a, b) => unlockedById[b.id]!.compareTo(unlockedById[a.id]!));

    if (eligible.isEmpty) return const SizedBox.shrink();

    final display = eligible.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            'Merch Moments',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        ...display.map(
          (a) =>
              _MerchMomentTile(achievement: a, unlockedAt: unlockedById[a.id]!),
        ),
      ],
    );
  }
}

class _MerchMomentTile extends StatelessWidget {
  const _MerchMomentTile({required this.achievement, required this.unlockedAt});

  final Achievement achievement;
  final DateTime unlockedAt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.emoji_events_outlined, color: Colors.amber[700], size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You unlocked ${achievement.title}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Create a ${_productLabel(achievement.merch!)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonal(
            onPressed:
                () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder:
                        (_) => AchievementMerchOptionScreen(
                          achievement: achievement,
                        ),
                  ),
                ),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: theme.textTheme.labelSmall,
            ),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  String _productLabel(MerchTriggerType type) => switch (type) {
    MerchTriggerType.flagGrid => 'Flag Grid Tee',
    MerchTriggerType.passportStamp => 'Passport Stamp Tee',
    MerchTriggerType.timeline => 'Travel Timeline Tee',
    MerchTriggerType.country => 'Country Tee',
    MerchTriggerType.milestone => 'Milestone Tee',
  };
}
