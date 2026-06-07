import 'package:flutter/material.dart';
import 'package:shared_models/shared_models.dart';

import '../../../core/theme/roavvy_colours.dart';
import '../../merch/achievement_merch_option_screen.dart';

/// Merch Moments section — up to 5 most recently unlocked merch-eligible
/// achievements with an emotional gradient CTA (M97, ADR-148, M147).
///
/// Returns [SizedBox.shrink] when no merch-eligible achievements are unlocked.
class MerchMomentsSection extends StatelessWidget {
  const MerchMomentsSection({super.key, required this.unlockedById});

  final Map<String, DateTime> unlockedById;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final eligible =
        kAchievements
            .where((a) => a.merch != null && unlockedById.containsKey(a.id))
            .toList()
          ..sort((a, b) => unlockedById[b.id]!.compareTo(unlockedById[a.id]!));

    if (eligible.isEmpty) return const SizedBox.shrink();

    final display = eligible.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Row(
            children: [
              Icon(
                Icons.dry_cleaning_outlined,
                size: 17,
                color: RoavvyColours.roavvyGold,
              ),
              const SizedBox(width: 6),
              Text(
                'Wear your achievements',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        ...display.map(
          (a) => _MerchMomentTile(
            achievement: a,
            unlockedAt: unlockedById[a.id]!,
          ),
        ),
      ],
    );
  }
}

class _MerchMomentTile extends StatelessWidget {
  const _MerchMomentTile({required this.achievement, required this.unlockedAt});

  final Achievement achievement;
  final DateTime unlockedAt;

  static String _monthYear(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            RoavvyColours.roavvyGold.withValues(alpha: 0.15),
            const Color(0xFFF57F17).withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: RoavvyColours.roavvyGold.withValues(alpha: 0.3),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: [
          // ── Gold trophy icon ──────────────────────────────────
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: RoavvyColours.roavvyGold.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.emoji_events,
              color: RoavvyColours.roavvyGold,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          // ── Text ─────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  achievement.title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Unlocked ${_monthYear(unlockedAt)}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // ── CTA button ────────────────────────────────────────
          FilledButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    AchievementMerchOptionScreen(achievement: achievement),
              ),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: RoavvyColours.roavvyGold,
              foregroundColor: Colors.black87,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(_ctaLabel(achievement.merch!)),
          ),
        ],
      ),
    );
  }

  String _ctaLabel(MerchTriggerType type) => switch (type) {
    MerchTriggerType.flagGrid => 'Flag Tee',
    MerchTriggerType.passportStamp => 'Stamp Tee',
    MerchTriggerType.timeline => 'Timeline Tee',
    MerchTriggerType.country => 'Country Tee',
    MerchTriggerType.milestone => 'Milestone Tee',
  };
}
