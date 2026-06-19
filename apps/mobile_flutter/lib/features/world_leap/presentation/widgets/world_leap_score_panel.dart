// lib/features/world_leap/presentation/widgets/world_leap_score_panel.dart
//
// Animated slide-up score breakdown panel shown after each successful landing.

import 'package:flutter/material.dart';

import '../../domain/models/world_leap_launch.dart';
import '../../domain/models/world_leap_score_breakdown.dart';
import '../../world_leap_config.dart';

// ── Package-private data types (importable in tests) ─────────────────────────

class ScoreRowData {
  final String label;
  final int value;
  final bool isBonus;
  final bool isTotal;

  const ScoreRowData({
    required this.label,
    required this.value,
    this.isBonus = false,
    this.isTotal = false,
  });
}

/// Returns the score rows that should be displayed for [breakdown].
/// Package-private for testing.
List<ScoreRowData> buildScoreRows(
    WorldLeapScoreBreakdown breakdown, String toCountryName) {
  return [
    ScoreRowData(label: 'Base: $toCountryName', value: breakdown.baseCountry),
    ScoreRowData(label: 'Distance bonus', value: breakdown.distanceBonus),
    if (breakdown.hasLongShotBonus)
      ScoreRowData(
          label: 'Long-shot bonus!',
          value: breakdown.longShotBonus,
          isBonus: true),
    if (breakdown.hasHeritageBonus)
      ScoreRowData(
        label: breakdown.heritageSiteName != null
            ? '${breakdown.heritageSiteName} nearby'
            : 'Heritage bonus',
        value: breakdown.heritageBonus,
        isBonus: true,
      ),
    if (breakdown.hasContinentBonus)
      ScoreRowData(
        label: 'New continent!',
        value: breakdown.continentBonus,
        isBonus: true,
      ),
    if (breakdown.hasSpeedBonus)
      ScoreRowData(
        label: 'Speed bonus! ⚡',
        value: breakdown.speedBonus,
        isBonus: true,
      ),
    if (breakdown.hasComboBonus)
      ScoreRowData(
        label: 'Combo ×${breakdown.comboMultiplier.toStringAsFixed(1)} 🔥',
        value: breakdown.comboBonus,
        isBonus: true,
      ),
    ScoreRowData(label: 'TOTAL', value: breakdown.total, isTotal: true),
  ];
}

// ── Widget ────────────────────────────────────────────────────────────────────

class WorldLeapScorePanel extends StatefulWidget {
  final WorldLeapLaunch launch;

  /// Called when the player taps the panel or it auto-dismisses.
  final VoidCallback onDismiss;

  const WorldLeapScorePanel({
    super.key,
    required this.launch,
    required this.onDismiss,
  });

  @override
  State<WorldLeapScorePanel> createState() => _WorldLeapScorePanelState();
}

class _WorldLeapScorePanelState extends State<WorldLeapScorePanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    ));

    _animController.forward();

    Future.delayed(
      Duration(milliseconds: WorldLeapConfig.scorePanelDisplayDurationMs),
      () {
        if (mounted) widget.onDismiss();
      },
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final launch = widget.launch;
    final rows = buildScoreRows(launch.scoreBreakdown, launch.toCountryName);

    return Align(
      alignment: Alignment.bottomCenter,
      child: SlideTransition(
        position: _slideAnimation,
        child: GestureDetector(
          onTap: widget.onDismiss,
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Spacer(),
                    Text(
                      '\u{1F3AF} ${launch.toCountryName}!',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const Spacer(),
                    const Icon(Icons.touch_app, color: Colors.white38, size: 18),
                  ],
                ),
                const SizedBox(height: 6),
                // Star rating
                _StarRating(stars: launch.scoreBreakdown.stars),
                const SizedBox(height: 10),
                // Score rows with staggered fade-in
                ...rows.asMap().entries.map((entry) {
                  final index = entry.key;
                  final row = entry.value;
                  final delayMs = index * WorldLeapConfig.scorePanelRowStaggerMs;
                  return _StaggeredRow(
                    delayMs: delayMs,
                    child: _ScoreRow(
                      label: row.label,
                      value: row.value,
                      isTotal: row.isTotal,
                      color: row.isBonus
                          ? Colors.amber
                          : row.isTotal
                              ? Colors.white
                              : Colors.white70,
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Star rating ───────────────────────────────────────────────────────────────

class _StarRating extends StatelessWidget {
  final int stars; // 1–3

  const _StarRating({required this.stars});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        final filled = i < stars;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Icon(
            filled ? Icons.star_rounded : Icons.star_outline_rounded,
            color: filled ? Colors.amber : Colors.white24,
            size: 28,
          ),
        );
      }),
    );
  }
}

// ── Staggered row wrapper ─────────────────────────────────────────────────────

class _StaggeredRow extends StatefulWidget {
  final int delayMs;
  final Widget child;

  const _StaggeredRow({required this.delayMs, required this.child});

  @override
  State<_StaggeredRow> createState() => _StaggeredRowState();
}

class _StaggeredRowState extends State<_StaggeredRow> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: _visible ? 1.0 : 0.0,
      child: widget.child,
    );
  }
}

// ── Score row ─────────────────────────────────────────────────────────────────

class _ScoreRow extends StatelessWidget {
  final String label;
  final int value;
  final bool isTotal;
  final Color? color;

  const _ScoreRow({
    required this.label,
    required this.value,
    this.isTotal = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (isTotal) {
      return Column(
        children: [
          const Divider(color: Colors.white24, height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: color ?? Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                value.toString(),
                style: TextStyle(
                  color: color ?? Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: color ?? Colors.white70,
                fontWeight:
                    isTotal ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ),
          Text(
            '+$value',
            style: TextStyle(
              color: color ?? Colors.white70,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
