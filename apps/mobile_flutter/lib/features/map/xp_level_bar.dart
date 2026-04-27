import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../xp/xp_event.dart';

/// Top strip on [MapScreen] showing the user's current XP level and progress.
///
/// Listens to [xpNotifierProvider] and flashes "+N XP" for 1500 ms whenever
/// XP is earned. Height is fixed at 44pt.
///
/// Tapping the level badge or label opens [_XpProgressionSheet] (M86).
class XpLevelBar extends ConsumerStatefulWidget {
  const XpLevelBar({super.key});

  @override
  ConsumerState<XpLevelBar> createState() => _XpLevelBarState();
}

class _XpLevelBarState extends ConsumerState<XpLevelBar> {
  StreamSubscription<int>? _earnedSub;
  String? _flashLabel;
  Timer? _flashTimer;

  @override
  void initState() {
    super.initState();
    _earnedSub = ref.read(xpNotifierProvider.notifier).xpEarned.listen(_onXpEarned);
  }

  @override
  void dispose() {
    _earnedSub?.cancel();
    _flashTimer?.cancel();
    super.dispose();
  }

  void _onXpEarned(int amount) {
    _flashTimer?.cancel();
    if (mounted) {
      setState(() => _flashLabel = '+$amount XP');
      _flashTimer = Timer(const Duration(milliseconds: 1500), () {
        if (mounted) setState(() => _flashLabel = null);
      });
    }
  }

  void _showProgression(BuildContext context, XpState xp) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _XpProgressionSheet(xp: xp),
    );
  }

  @override
  Widget build(BuildContext context) {
    final xp = ref.watch(xpNotifierProvider);

    return SafeArea(
      bottom: false,
      child: SizedBox(
        height: 44,
        child: Material(
          color: const Color(0xFF0D2137).withValues(alpha: 0.88), // ADR-080
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                // Level badge + label — tappable to show progression sheet.
                GestureDetector(
                  onTap: () => _showProgression(context, xp),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFD700),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${xp.level}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        xp.levelLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Progress bar
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: xp.progressFraction,
                      backgroundColor: const Color(0xFF1E3A5F),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
                      minHeight: 6,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Next level label or +XP flash
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _flashLabel != null
                      ? Text(
                          _flashLabel!,
                          key: ValueKey(_flashLabel),
                          style: const TextStyle(
                            color: Color(0xFFFFCA28),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : xp.xpToNextLevel > 0
                          ? Text(
                              'L${xp.level + 1}',
                              key: const ValueKey('next'),
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                            )
                          : const Text(
                              'MAX',
                              key: ValueKey('max'),
                              style: TextStyle(
                                color: Color(0xFFFFB300),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── XP Progression Sheet ───────────────────────────────────────────────────────

/// Bottom sheet showing all 8 XP levels, the user's current level highlighted,
/// XP thresholds, and how many XP remain to the next level.
class _XpProgressionSheet extends StatelessWidget {
  const _XpProgressionSheet({required this.xp});

  final XpState xp;

  static const _levelEmojis = [
    '✈️', '🧭', '🗺️', '🌍', '🏕️', '⚓', '🚀', '👑',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0D2137),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Traveller Levels',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (xp.xpToNextLevel > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${xp.xpToNextLevel} XP to next level',
                    style: const TextStyle(color: Color(0xFFFFD700), fontSize: 13),
                  ),
                ),
              const SizedBox(height: 16),
              for (int i = 0; i < kLevelLabels.length; i++)
                _LevelRow(
                  level: i + 1,
                  label: kLevelLabels[i],
                  emoji: _levelEmojis[i],
                  xpRequired: kXpThresholds[i],
                  isCurrent: xp.level == i + 1,
                  isUnlocked: xp.level > i + 1,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LevelRow extends StatelessWidget {
  const _LevelRow({
    required this.level,
    required this.label,
    required this.emoji,
    required this.xpRequired,
    required this.isCurrent,
    required this.isUnlocked,
  });

  final int level;
  final String label;
  final String emoji;
  final int xpRequired;
  final bool isCurrent;
  final bool isUnlocked;

  @override
  Widget build(BuildContext context) {
    final highlight = isCurrent;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: highlight
            ? const Color(0xFFFFD700).withValues(alpha: 0.15)
            : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: highlight
            ? Border.all(color: const Color(0xFFFFD700), width: 1)
            : null,
      ),
      child: Row(
        children: [
          // Level badge
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: isUnlocked || isCurrent
                  ? const Color(0xFFFFD700)
                  : Colors.white12,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '$level',
              style: TextStyle(
                color: isUnlocked || isCurrent ? Colors.white : Colors.white38,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: isCurrent
                    ? const Color(0xFFFFD700)
                    : isUnlocked
                        ? Colors.white
                        : Colors.white38,
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ),
          Text(
            xpRequired == 0 ? 'Start' : '$xpRequired XP',
            style: TextStyle(
              color: isUnlocked || isCurrent ? Colors.white54 : Colors.white24,
              fontSize: 11,
            ),
          ),
          if (isCurrent) ...[
            const SizedBox(width: 6),
            const Text('◀', style: TextStyle(color: Color(0xFFFFD700), fontSize: 10)),
          ],
        ],
      ),
    );
  }
}
