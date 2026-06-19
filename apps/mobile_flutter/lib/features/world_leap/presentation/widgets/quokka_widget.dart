// lib/features/world_leap/presentation/widgets/quokka_widget.dart
//
// Quokka mascot animation widget for World Leap.
// Reacts to game state with bouncing, flying, celebrating, and sad animations.

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:mobile_flutter/features/world_leap/application/world_leap_controller.dart';
import 'package:mobile_flutter/features/world_leap/application/world_leap_state.dart';
import 'package:mobile_flutter/features/world_leap/world_leap_config.dart';

// ── Display mode ─────────────────────────────────────────────────────────────

/// Visual display mode for the quokka mascot.
/// Package-private for testing.
enum QuokkaDisplayMode { idle, bouncing, flying, celebrating, sad }

/// Returns the display mode for the quokka based on current game state.
/// Package-private for testing.
QuokkaDisplayMode quokkaDisplayMode(WorldLeapState state) => switch (state) {
      WorldLeapStateAiming() => QuokkaDisplayMode.bouncing,
      WorldLeapStateLaunching() => QuokkaDisplayMode.flying,
      WorldLeapStateLanded() => QuokkaDisplayMode.celebrating,
      WorldLeapStateComplete() => QuokkaDisplayMode.celebrating,
      WorldLeapStateFailed() => QuokkaDisplayMode.sad,
      _ => QuokkaDisplayMode.idle,
    };

// ── Widget ───────────────────────────────────────────────────────────────────

class QuokkaWidget extends StatefulWidget {
  final WorldLeapController controller;

  /// Size of the quokka image. Defaults to 120.
  final double size;

  const QuokkaWidget({
    super.key,
    required this.controller,
    this.size = 120.0,
  });

  @override
  State<QuokkaWidget> createState() => _QuokkaWidgetState();
}

class _QuokkaWidgetState extends State<QuokkaWidget>
    with TickerProviderStateMixin {
  // ── Animation controllers ─────────────────────────────────────────────────

  late final AnimationController _bounceController;
  late final AnimationController _celebrateController;
  late final AnimationController _sadController;

  // ── Animations ────────────────────────────────────────────────────────────

  late final Animation<double> _bounceAnim;
  late final Animation<double> _celebrateScaleAnim;
  late final Animation<double> _sadOffsetAnim;

  // ── Confetti ──────────────────────────────────────────────────────────────

  late final ConfettiController _confettiController;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _bounceAnim = Tween<double>(begin: 0, end: -8).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut),
    );

    _celebrateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _celebrateScaleAnim = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(
          parent: _celebrateController, curve: Curves.elasticOut),
    );

    _sadController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _sadOffsetAnim = Tween<double>(begin: 0, end: 16).animate(
      CurvedAnimation(parent: _sadController, curve: Curves.easeIn),
    );

    _confettiController =
        ConfettiController(duration: const Duration(seconds: 2));

    // Apply the current state immediately — the controller may already have
    // a non-idle state (e.g. if restored from a completed run) before this
    // widget mounts and adds its listener.
    _applyState(widget.controller.state);

    widget.controller.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onStateChanged);
    _bounceController.dispose();
    _celebrateController.dispose();
    _sadController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  // ── State listener ────────────────────────────────────────────────────────

  void _onStateChanged() => _applyState(widget.controller.state);

  void _applyState(WorldLeapState state) {
    switch (state) {
      case WorldLeapStateAiming():
        _bounceController.repeat(reverse: true);
        _celebrateController.reset();
        _sadController.reset();
      case WorldLeapStateLaunching():
        _bounceController.stop();
        _celebrateController.reset();
        _sadController.reset();
      case WorldLeapStateLanded():
        _bounceController.stop();
        _celebrateController.forward(from: 0);
        _confettiController.play();
      case WorldLeapStateFailed():
        _bounceController.stop();
        _sadController.forward(from: 0);
      case WorldLeapStateComplete():
        _bounceController.stop();
        _celebrateController.forward(from: 0);
        _confettiController.play();
      default:
        _bounceController.stop();
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Confetti above the quokka
        Positioned(
          top: 0,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            numberOfParticles: 20,
            gravity: 0.3,
            colors: const [
              Colors.yellow,
              Colors.green,
              Colors.blue,
              Colors.orange,
            ],
          ),
        ),
        AnimatedBuilder(
          animation: Listenable.merge([
            _bounceController,
            _celebrateController,
            _sadController,
          ]),
          builder: (context, child) {
            final bounceOffset = _bounceAnim.value;
            final scale = _celebrateScaleAnim.value;
            final sadOffset = _sadOffsetAnim.value;
            final totalOffset = bounceOffset + sadOffset;

            // Flip horizontally during Launching state to show quokka flying
            final isLaunching =
                widget.controller.state is WorldLeapStateLaunching;
            final isFailed =
                widget.controller.state is WorldLeapStateFailed;

            return Transform.translate(
              offset: Offset(0, totalOffset),
              child: Transform.scale(
                scale: scale,
                child: Opacity(
                  opacity: isFailed ? 0.6 : 1.0,
                  child: Transform.scale(
                    scaleX: isLaunching ? -1.0 : 1.0,
                    child: Image.asset(
                      WorldLeapConfig.quokkaAsset,
                      width: widget.size,
                      height: widget.size,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
