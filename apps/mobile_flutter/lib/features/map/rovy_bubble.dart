import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── Domain model ──────────────────────────────────────────────────────────────

/// The contextual trigger that caused a Rovy message to appear (ADR-071).
enum RovyTrigger {
  newCountry,
  regionOneAway,
  milestone,
  postShare,
  caughtUp,
}

/// A short message shown in the Rovy avatar bubble (ADR-071).
class RovyMessage {
  const RovyMessage({
    required this.text,
    required this.trigger,
    this.emoji,
  });

  final String text;
  final RovyTrigger trigger;
  final String? emoji;
}

// ── Provider (ADR-071) ────────────────────────────────────────────────────────

/// Holds the currently displayed [RovyMessage], or null when no bubble is
/// shown.  Co-located with [RovyBubble] to avoid polluting `providers.dart`.
///
/// Setting state to a new [RovyMessage] replaces any current message.
/// Setting to null dismisses the bubble.
final rovyMessageProvider = StateProvider<RovyMessage?>((_) => null);

// ── RovyBubble ────────────────────────────────────────────────────────────────

/// Floating Rovy avatar bubble shown at the bottom-right of the map.
///
/// Watches [rovyMessageProvider]; shows a speech bubble with [RovyMessage.text]
/// when a message is present.  Supports:
/// - Auto-dismiss after 4 seconds (ADR-071)
/// - Tap-to-dismiss
/// - [AnimatedSwitcher] scale-in entrance
///
/// Hidden (zero size) when no message is active.
class RovyBubble extends ConsumerStatefulWidget {
  const RovyBubble({super.key});

  @override
  ConsumerState<RovyBubble> createState() => _RovyBubbleState();
}

class _RovyBubbleState extends ConsumerState<RovyBubble> {
  Timer? _dismissTimer;

  static const _autoDismiss = Duration(seconds: 4);

  @override
  void initState() {
    super.initState();
    // If the provider already has a message when this widget mounts (e.g.
    // in tests that override the initial value), start the auto-dismiss timer.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ref.read(rovyMessageProvider) != null) {
        _startTimer();
      }
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _dismissTimer?.cancel();
    _dismissTimer = Timer(_autoDismiss, () {
      if (mounted) {
        ref.read(rovyMessageProvider.notifier).state = null;
      }
    });
  }

  void _dismiss() {
    _dismissTimer?.cancel();
    ref.read(rovyMessageProvider.notifier).state = null;
  }

  @override
  Widget build(BuildContext context) {
    final message = ref.watch(rovyMessageProvider);

    // Start / restart the auto-dismiss timer whenever a new message arrives.
    ref.listen<RovyMessage?>(rovyMessageProvider, (_, next) {
      if (next != null) _startTimer();
    });

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (child, animation) {
        return ScaleTransition(scale: animation, child: child);
      },
      child: message == null
          ? const SizedBox.shrink(key: ValueKey('hidden'))
          : GestureDetector(
              key: ValueKey(message.text),
              onTap: _dismiss,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Speech bubble (extends left of avatar)
                  Flexible(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 180),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                          bottomLeft: Radius.circular(16),
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 6,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Text(
                        message.emoji != null
                            ? '${message.emoji} ${message.text}'
                            : message.text,
                        style: const TextStyle(
                            fontSize: 13, color: Colors.black87),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Rovy avatar — 48 px circle, amber border, "R" placeholder (ADR-071)
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFFFB300),
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'R',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
