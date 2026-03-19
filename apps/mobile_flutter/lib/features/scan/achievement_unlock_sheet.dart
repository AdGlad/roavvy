import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_models/shared_models.dart';

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _fmtDate(DateTime dt) =>
    '${dt.day} ${_months[dt.month - 1]} ${dt.year}';

/// Shows detail for an unlocked achievement and offers a share action.
///
/// Opened from [ScanSummaryScreen] achievement chips (first-unlock context)
/// or from [StatsScreen] gallery (review context).
/// Locked achievements on [StatsScreen] must not open this sheet.
///
/// All data is passed as constructor parameters — no loading state needed
/// (sheet only opens with valid unlocked data). ADR-054.
class AchievementUnlockSheet extends StatelessWidget {
  const AchievementUnlockSheet({
    super.key,
    required this.achievement,
    required this.unlockedAt,
  });

  final Achievement achievement;
  final DateTime unlockedAt;

  /// Convenience method — shows this sheet via [showModalBottomSheet].
  static Future<void> show(
    BuildContext context, {
    required Achievement achievement,
    required DateTime unlockedAt,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: false,
      builder: (_) => AchievementUnlockSheet(
        achievement: achievement,
        unlockedAt: unlockedAt,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateStr = _fmtDate(unlockedAt);

    return Semantics(
      label: '${achievement.title} achievement',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            // Trophy icon (decorative)
            ExcludeSemantics(
              child: Icon(
                Icons.emoji_events_outlined,
                size: 56,
                color: Colors.amber[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              achievement.title,
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              achievement.description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Unlocked $dateStr',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Semantics(
              label: 'Share ${achievement.title} achievement',
              child: FilledButton(
                onPressed: () => _share(dateStr),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                ),
                child: const Text('Share achievement'),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
              ),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }

  void _share(String dateStr) {
    final text =
        '${achievement.title} — ${achievement.description}. '
        'Unlocked on $dateStr. Discovered with Roavvy.';
    Share.share(text);
  }
}
