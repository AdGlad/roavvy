import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_models/shared_models.dart';

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _fmtDate(DateTime dt) =>
    '${dt.day} ${_months[dt.month - 1]} ${dt.year}';

/// Shows detail for an achievement — unlocked or locked.
///
/// Opened from [ScanSummaryScreen] achievement chips (first-unlock context)
/// or from [StatsScreen] gallery (review context, unlocked or locked).
///
/// When [unlockedAt] is null the sheet shows the locked state: lock icon,
/// description (requirements), and "Not yet unlocked". When non-null it shows
/// the unlocked state with trophy icon, unlock date, and a share button.
///
/// All data is passed as constructor parameters — no loading state needed.
/// ADR-054.
class AchievementUnlockSheet extends StatelessWidget {
  const AchievementUnlockSheet({
    super.key,
    required this.achievement,
    this.unlockedAt,
  });

  final Achievement achievement;

  /// Null when showing a locked achievement.
  final DateTime? unlockedAt;

  bool get _isUnlocked => unlockedAt != null;

  /// Convenience method — shows this sheet via [showModalBottomSheet].
  ///
  /// Pass null for [unlockedAt] to show the locked state.
  static Future<void> show(
    BuildContext context, {
    required Achievement achievement,
    DateTime? unlockedAt,
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
    final secondary = theme.colorScheme.onSurfaceVariant;
    final dateStr = unlockedAt != null ? _fmtDate(unlockedAt!) : null;

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
                color: secondary.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            // Trophy or lock icon (decorative)
            ExcludeSemantics(
              child: Icon(
                _isUnlocked ? Icons.emoji_events_outlined : Icons.lock_outline,
                size: 56,
                color: _isUnlocked ? Colors.amber[700] : secondary,
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
              style: theme.textTheme.bodyMedium?.copyWith(color: secondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _isUnlocked ? 'Unlocked $dateStr' : 'Not yet unlocked',
              style: theme.textTheme.labelMedium?.copyWith(
                color: _isUnlocked ? theme.colorScheme.primary : secondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (_isUnlocked) ...[
              Semantics(
                label: 'Share ${achievement.title} achievement',
                child: FilledButton(
                  onPressed: () => _share(context, dateStr!),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                  ),
                  child: const Text('Share achievement'),
                ),
              ),
              const SizedBox(height: 8),
            ],
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

  void _share(BuildContext context, String dateStr) {
    final text =
        '${achievement.title} — ${achievement.description}. '
        'Unlocked on $dateStr. Discovered with Roavvy.';
    final box = context.findRenderObject() as RenderBox?;
    final origin = box != null
        ? box.localToGlobal(Offset.zero) & box.size
        : Rect.fromLTWH(0, 0, 1, 1);
    Share.share(text, sharePositionOrigin: origin);
  }
}
