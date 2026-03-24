import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/milestone_repository.dart';

/// Badge emoji shown per threshold on the milestone card.
const _kThresholdBadge = {
  5: '🌍',
  10: '🗺️',
  25: '✈️',
  50: '🌐',
  100: '🏆',
};

/// Share text emoji shown per threshold.
const _kThresholdShareEmoji = {
  5: '🌍',
  10: '🗺️',
  25: '✈️',
  50: '🌐',
  100: '🏆',
};

/// Shows the [MilestoneCardSheet] for [threshold] as a modal bottom sheet.
///
/// Mirrors the [showRegionDetailSheet] pattern (ADR-069).
Future<void> showMilestoneCardSheet(
    BuildContext context, int threshold) {
  return showModalBottomSheet<void>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => MilestoneCardSheet(threshold: threshold),
  );
}

/// Celebrates reaching a country count milestone (5, 10, 25, 50, 100).
///
/// Shown once per threshold via [MilestoneRepository].
class MilestoneCardSheet extends StatelessWidget {
  const MilestoneCardSheet({super.key, required this.threshold});

  final int threshold;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final badge = _kThresholdBadge[threshold] ?? '🌍';
    final emoji = _kThresholdShareEmoji[threshold] ?? '🌍';
    final shareText = "I've visited $threshold countries with Roavvy! $emoji";

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(badge, style: const TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            Text(
              "You've visited $threshold countries!",
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'A new milestone for your travel story.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Builder(
              builder: (btnCtx) => FilledButton.icon(
                onPressed: () {
                  final box = btnCtx.findRenderObject() as RenderBox?;
                  final origin = box != null
                      ? box.localToGlobal(Offset.zero) & box.size
                      : Rect.fromLTWH(0, 0, 1, 1);
                  Share.share(shareText, sharePositionOrigin: origin);
                },
                icon: const Icon(Icons.share_outlined),
                label: const Text('Share'),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }
}


/// Computes the highest milestone threshold to show for [countryCount], given
/// thresholds already shown in [shownThresholds].
///
/// Returns null if no new milestone is due.
int? pendingMilestoneThreshold(int countryCount, Set<int> shownThresholds) {
  int? highest;
  for (final t in kMilestoneThresholds) {
    if (t <= countryCount && !shownThresholds.contains(t)) {
      if (highest == null || t > highest) highest = t;
    }
  }
  return highest;
}
