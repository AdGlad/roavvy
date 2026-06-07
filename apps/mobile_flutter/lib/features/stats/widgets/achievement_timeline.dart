import 'package:flutter/material.dart';
import 'package:shared_models/shared_models.dart';

import '../../../core/theme/roavvy_colours.dart';

/// Horizontal milestone journey for country achievements (M147).
///
/// Shows 8 key country milestones connected by a line. Unlocked nodes are
/// gold with a checkmark. The next milestone pulses with a blue ring.
/// Future nodes are grey. Horizontally scrollable.
class AchievementTimeline extends StatelessWidget {
  const AchievementTimeline({
    super.key,
    required this.countryCount,
    required this.unlockedIds,
  });

  final int countryCount;
  final Set<String> unlockedIds;

  // Key milestones to show on the timeline.
  static const _milestoneIds = [
    'countries_1',
    'countries_5',
    'countries_10',
    'countries_25',
    'countries_50',
    'countries_100',
    'countries_150',
    'countries_195',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Resolve achievements — skip any not found (defensive).
    final milestones = _milestoneIds
        .map(
          (id) =>
              kAchievements.where((a) => a.id == id).firstOrNull,
        )
        .whereType<Achievement>()
        .toList();

    if (milestones.isEmpty) return const SizedBox.shrink();

    // Find index of the first locked milestone (the "next" node).
    final nextIndex = milestones.indexWhere(
      (a) => !unlockedIds.contains(a.id),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Row(
            children: [
              Icon(
                Icons.route_outlined,
                size: 17,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                'Your Journey',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '$countryCount countries',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 100,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            scrollDirection: Axis.horizontal,
            itemCount: milestones.length,
            itemBuilder: (context, index) {
              final a = milestones[index];
              final isUnlocked = unlockedIds.contains(a.id);
              final isNext = index == nextIndex;
              final isLast = index == milestones.length - 1;

              return _TimelineNode(
                achievement: a,
                isUnlocked: isUnlocked,
                isNext: isNext,
                showConnector: !isLast,
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Timeline node ─────────────────────────────────────────────────────────────

class _TimelineNode extends StatefulWidget {
  const _TimelineNode({
    required this.achievement,
    required this.isUnlocked,
    required this.isNext,
    required this.showConnector,
  });

  final Achievement achievement;
  final bool isUnlocked;
  final bool isNext;
  final bool showConnector;

  @override
  State<_TimelineNode> createState() => _TimelineNodeState();
}

class _TimelineNodeState extends State<_TimelineNode>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _pulseAnim = Tween<double>(
      begin: 1.0,
      end: 1.4,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    if (widget.isNext) {
      _pulseCtrl.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  static String _shortTitle(Achievement a) {
    // Truncate long titles for the compact node label.
    final t = a.title;
    if (t.length <= 10) return t;
    return '${t.substring(0, 9)}…';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final nodeColor = widget.isUnlocked
        ? RoavvyColours.roavvyGold
        : widget.isNext
            ? theme.colorScheme.primary
            : theme.colorScheme.outline.withValues(alpha: 0.4);

    final connector = widget.showConnector
        ? Container(
            width: 32,
            height: 2,
            margin: const EdgeInsets.only(bottom: 28),
            color: widget.isUnlocked
                ? RoavvyColours.roavvyGold.withValues(alpha: 0.5)
                : theme.colorScheme.outline.withValues(alpha: 0.2),
          )
        : null;

    final nodeWidget = widget.isNext
        ? AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, child) => Transform.scale(
              scale: _pulseAnim.value,
              child: child,
            ),
            child: _NodeCircle(color: nodeColor, isUnlocked: false),
          )
        : _NodeCircle(color: nodeColor, isUnlocked: widget.isUnlocked);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 4),
            nodeWidget,
            const SizedBox(height: 6),
            SizedBox(
              width: 56,
              child: Text(
                _shortTitle(widget.achievement),
                textAlign: TextAlign.center,
                maxLines: 2,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: widget.isNext || widget.isUnlocked
                      ? FontWeight.w600
                      : FontWeight.normal,
                  color: widget.isUnlocked
                      ? RoavvyColours.roavvyGold
                      : widget.isNext
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.6),
                  height: 1.2,
                ),
              ),
            ),
            if (widget.isUnlocked || widget.isNext)
              Text(
                '${widget.achievement.progressTarget}',
                style: TextStyle(
                  fontSize: 9,
                  color: widget.isUnlocked
                      ? RoavvyColours.roavvyGold.withValues(alpha: 0.7)
                      : theme.colorScheme.primary.withValues(alpha: 0.7),
                ),
              ),
          ],
        ),
        if (connector != null) ...[
          const SizedBox(width: 0),
          Padding(
            padding: const EdgeInsets.only(top: 15),
            child: connector,
          ),
        ],
      ],
    );
  }
}

class _NodeCircle extends StatelessWidget {
  const _NodeCircle({required this.color, required this.isUnlocked});

  final Color color;
  final bool isUnlocked;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isUnlocked ? color : Colors.transparent,
        border: isUnlocked ? null : Border.all(color: color, width: 2),
        boxShadow: isUnlocked
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: isUnlocked
          ? const Icon(Icons.check, size: 14, color: Colors.black87)
          : null,
    );
  }
}
