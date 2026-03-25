import 'package:flutter/material.dart';

import '../cards/card_generator_screen.dart';

/// Emoji shown per level label on the level-up sheet.
const _kLevelEmoji = {
  'Traveller': '🌱',
  'Explorer': '🧭',
  'Navigator': '🗺️',
  'Globetrotter': '✈️',
  'Pathfinder': '🌍',
  'Voyager': '⚓',
  'Pioneer': '🔭',
  'Legend': '🏆',
};

/// Celebratory sheet shown when the user reaches a new XP level.
///
/// Shown from [ScanSummaryScreen] via [LevelUpSheet.show] when
/// `xpState.level > lastShownLevel` (ADR-094).
///
/// "Create a travel card" navigates to [CardGeneratorScreen].
/// "Later" dismisses without action.
class LevelUpSheet extends StatelessWidget {
  const LevelUpSheet({super.key, required this.levelLabel});

  final String levelLabel;

  /// Convenience method — shows this sheet via [showModalBottomSheet].
  static Future<void> show(
    BuildContext context, {
    required String levelLabel,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => LevelUpSheet(levelLabel: levelLabel),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final emoji = _kLevelEmoji[levelLabel] ?? '✈️';

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            Text(
              "You're now a $levelLabel!",
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'The world keeps opening up.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const CardGeneratorScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.style_outlined),
                label: const Text('Create a travel card'),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Later'),
            ),
          ],
        ),
      ),
    );
  }
}
