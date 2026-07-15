import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_models/shared_models.dart';

import '../../core/country_names.dart';
import '../../core/providers.dart';
import 'country_scene_icons.dart';
import 'timeline_painter.dart';

// ── Layout constants ──────────────────────────────────────────────────────────

const _kNodeRadius = 32.0;
const _kAchievementRadius = 38.0;
const _kNodeSpacing = 118.0;
const _kTopPadding = 56.0;
const _kBottomPadding = 96.0;

final _kMonthYear = DateFormat('MMM yyyy');

// ── Data model ────────────────────────────────────────────────────────────────

sealed class _TimelineItem {}

final class _TripItem extends _TimelineItem {
  _TripItem({
    required this.trip,
    required this.isFirstVisit,
    required this.runningUniqueCount,
  });

  final TripRecord trip;
  final bool isFirstVisit;
  final int runningUniqueCount;
}

final class _AchievementItem extends _TimelineItem {
  _AchievementItem(this.achievement);
  final Achievement achievement;
}

// ── Provider ──────────────────────────────────────────────────────────────────

/// Builds the interleaved list of trips + country-count achievement milestones,
/// newest item first (top of screen).
List<_TimelineItem> _buildTimeline(
  List<TripRecord> trips,
  Set<String> unlockedIds,
) {
  // Work chronologically (oldest first) to track running unique-country count.
  final sorted = [...trips]..sort((a, b) => a.startedOn.compareTo(b.startedOn));

  final seen = <String>{};
  final chronological = <_TimelineItem>[];

  // Country achievements sorted by threshold ascending.
  final countryAchievements =
      kAchievements
          .where(
            (a) =>
                a.category == AchievementCategory.countries &&
                unlockedIds.contains(a.id),
          )
          .toList()
        ..sort((a, b) => a.progressTarget.compareTo(b.progressTarget));

  int nextAchIdx = 0;

  for (final trip in sorted) {
    final cc = trip.countryCode.toUpperCase();
    final isFirst = !seen.contains(cc);
    if (isFirst) seen.add(cc);
    final runningCount = seen.length;

    chronological.add(
      _TripItem(
        trip: trip,
        isFirstVisit: isFirst,
        runningUniqueCount: runningCount,
      ),
    );

    // Flush any achievement milestones just crossed.
    while (nextAchIdx < countryAchievements.length &&
        runningCount >= countryAchievements[nextAchIdx].progressTarget) {
      chronological.add(_AchievementItem(countryAchievements[nextAchIdx]));
      nextAchIdx++;
    }
  }

  // Newest at top.
  return chronological.reversed.toList();
}

// ── Screen ────────────────────────────────────────────────────────────────────

class TravelTimelineScreen extends ConsumerWidget {
  const TravelTimelineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripsAsync = ref.watch(tripListProvider);
    final achievementsAsync = ref.watch(unlockedAchievementIdsProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Journey'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: tripsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load trips: $e')),
        data: (trips) {
          if (trips.isEmpty) {
            return const _EmptyTimeline();
          }
          final unlockedIds = achievementsAsync.valueOrNull ?? {};
          final items = _buildTimeline(trips, unlockedIds);
          return _TimelineBody(items: items);
        },
      ),
    );
  }
}

// ── Timeline body ─────────────────────────────────────────────────────────────

class _TimelineBody extends StatelessWidget {
  const _TimelineBody({required this.items});

  final List<_TimelineItem> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final positions = computeTimelinePositions(
          count: items.length,
          width: width,
          topPadding: _kTopPadding,
          nodeSpacing: _kNodeSpacing,
        );
        final totalHeight = timelineHeight(
          count: items.length,
          topPadding: _kTopPadding,
          nodeSpacing: _kNodeSpacing,
          bottomPadding: _kBottomPadding,
        );

        final cs = Theme.of(context).colorScheme;
        final pathColor = cs.primary.withValues(alpha: 0.35);
        final pathShadow = cs.primary.withValues(alpha: 0.12);

        return SingleChildScrollView(
          child: SizedBox(
            width: width,
            height: totalHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Snake path
                Positioned.fill(
                  child: CustomPaint(
                    painter: TimelinePainter(
                      positions: positions,
                      nodeRadius: _kNodeRadius,
                      pathColor: pathColor,
                      pathShadowColor: pathShadow,
                    ),
                  ),
                ),
                // Nodes
                for (int i = 0; i < items.length; i++)
                  _PositionedNode(
                    item: items[i],
                    center: positions[i],
                    width: width,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Positioned node ───────────────────────────────────────────────────────────

class _PositionedNode extends StatelessWidget {
  const _PositionedNode({
    required this.item,
    required this.center,
    required this.width,
  });

  final _TimelineItem item;
  final Offset center;
  final double width;

  @override
  Widget build(BuildContext context) {
    return switch (item) {
      _TripItem(:final trip, :final isFirstVisit) => _TripNode(
        trip: trip,
        isFirstVisit: isFirstVisit,
        center: center,
        canvasWidth: width,
      ),
      _AchievementItem(:final achievement) => _AchievementNode(
        achievement: achievement,
        center: center,
        canvasWidth: width,
      ),
    };
  }
}

// ── Trip node ─────────────────────────────────────────────────────────────────

class _TripNode extends StatelessWidget {
  const _TripNode({
    required this.trip,
    required this.isFirstVisit,
    required this.center,
    required this.canvasWidth,
  });

  final TripRecord trip;
  final bool isFirstVisit;
  final Offset center;
  final double canvasWidth;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cc = trip.countryCode.toUpperCase();
    final countryName = kCountryNames[cc] ?? cc;
    final flag = flagEmoji(cc);
    final scene = countrySceneIcon(cc);
    final date = _kMonthYear.format(trip.startedOn);

    // Label on the opposite side from the node.
    // Threshold 0.5 cleanly separates left-column (≤0.26w) from center/right (≥0.50w).
    final isLeft = center.dx < canvasWidth * 0.5;
    final labelLeft = isLeft ? center.dx + _kNodeRadius + 8 : null;
    final labelRight =
        !isLeft ? canvasWidth - center.dx + _kNodeRadius + 8 : null;
    // Reserve up to 30% of canvas width for labels, clamped to a readable range.
    final labelWidth = (canvasWidth * 0.30).clamp(80.0, 130.0);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Node circle
        Positioned(
          left: center.dx - _kNodeRadius,
          top: center.dy - _kNodeRadius,
          child: _NodeCircle(
            radius: _kNodeRadius,
            color:
                isFirstVisit
                    ? cs.primaryContainer
                    : cs.surfaceContainerHighest,
            borderColor: isFirstVisit ? cs.primary : cs.outline,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(flag, style: const TextStyle(fontSize: 22)),
                Text(scene, style: const TextStyle(fontSize: 11)),
              ],
            ),
          ),
        ),
        // Country label
        Positioned(
          left: labelLeft,
          right: labelRight,
          top: center.dy - 22,
          width: labelWidth,
          child: Column(
            crossAxisAlignment:
                isLeft ? CrossAxisAlignment.start : CrossAxisAlignment.end,
            children: [
              Text(
                countryName,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: cs.onSurface,
                  fontWeight:
                      isFirstVisit ? FontWeight.w700 : FontWeight.normal,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                date,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.55),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Achievement node ──────────────────────────────────────────────────────────

class _AchievementNode extends StatelessWidget {
  const _AchievementNode({
    required this.achievement,
    required this.center,
    required this.canvasWidth,
  });

  final Achievement achievement;
  final Offset center;
  final double canvasWidth;

  static const _kEmojis = {
    1: '🌱',
    3: '⭐',
    5: '🎯',
    10: '🥈',
    15: '🥇',
    20: '🏆',
    25: '🌍',
    30: '🌎',
    40: '🌏',
    50: '💎',
    75: '👑',
    100: '🏅',
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final emoji = _kEmojis[achievement.progressTarget] ?? '🏆';
    final isLeft = center.dx < canvasWidth * 0.5;
    final labelLeft = isLeft ? center.dx + _kAchievementRadius + 8 : null;
    final labelRight =
        !isLeft ? canvasWidth - center.dx + _kAchievementRadius + 8 : null;
    final labelWidth = (canvasWidth * 0.30).clamp(80.0, 130.0);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Achievement circle — slightly larger and gold-tinted
        Positioned(
          left: center.dx - _kAchievementRadius,
          top: center.dy - _kAchievementRadius,
          child: _NodeCircle(
            radius: _kAchievementRadius,
            color: cs.secondaryContainer,
            borderColor: cs.secondary,
            borderWidth: 3,
            child: Text(emoji, style: const TextStyle(fontSize: 26)),
          ),
        ),
        // Label
        Positioned(
          left: labelLeft,
          right: labelRight,
          top: center.dy - 24,
          width: labelWidth,
          child: Column(
            crossAxisAlignment:
                isLeft ? CrossAxisAlignment.start : CrossAxisAlignment.end,
            children: [
              Text(
                achievement.title,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: cs.secondary,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '${achievement.progressTarget} countries',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.55),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Shared node circle ────────────────────────────────────────────────────────

class _NodeCircle extends StatelessWidget {
  const _NodeCircle({
    required this.radius,
    required this.color,
    required this.borderColor,
    required this.child,
    this.borderWidth = 2.5,
  });

  final double radius;
  final Color color;
  final Color borderColor;
  final Widget child;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    final diameter = radius * 2;
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: [
          BoxShadow(
            color: borderColor.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyTimeline extends StatelessWidget {
  const _EmptyTimeline();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('✈️', style: const TextStyle(fontSize: 56)),
          const SizedBox(height: 16),
          Text(
            'Your journey map starts here',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: cs.onSurface),
          ),
          const SizedBox(height: 8),
          Text(
            'Scan your photos to trace every\ncountry you\'ve visited.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}
