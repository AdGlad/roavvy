import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';

/// Top strip on [MapScreen] showing the user's current XP level and progress.
///
/// Listens to [xpNotifierProvider] and flashes "+N XP" for 1500 ms whenever
/// XP is earned. Height is fixed at 44pt.
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

  @override
  Widget build(BuildContext context) {
    final xp = ref.watch(xpNotifierProvider);

    return SafeArea(
      bottom: false,
      child: SizedBox(
        height: 44,
        child: Material(
          color: Colors.black54,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                // Level badge
                Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFB300),
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
                // Level label
                Text(
                  xp.levelLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                // Progress bar
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: xp.progressFraction,
                      backgroundColor: Colors.white24,
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFCA28)),
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
