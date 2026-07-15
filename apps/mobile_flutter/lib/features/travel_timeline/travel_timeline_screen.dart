import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:shared_models/shared_models.dart';

import '../../core/country_names.dart';
import '../../core/providers.dart';
import 'country_scene_icons.dart';
import 'timeline_painter.dart';

// ── Layout constants ──────────────────────────────────────────────────────────

const _kNodeRadiusFirst = 34.0;   // first-visit trip node
const _kNodeRadiusRepeat = 28.0;  // repeat-visit trip node
const _kAchievementRadius = 38.0;
const _kNodeSpacing = 130.0;
const _kTopPadding = 56.0;
const _kBottomPadding = 96.0;

// Keep a single shared radius for the painter's path routing.
const _kNodeRadius = _kNodeRadiusFirst;

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
    final scene = countrySceneIcon(cc);
    final date = _kMonthYear.format(trip.startedOn);

    final radius = isFirstVisit ? _kNodeRadiusFirst : _kNodeRadiusRepeat;
    final flagW = isFirstVisit ? 36.0 : 28.0;
    final flagH = isFirstVisit ? 24.0 : 18.0;

    final isLeft = center.dx < canvasWidth * 0.5;
    final labelLeft = isLeft ? center.dx + radius + 10 : null;
    final labelRight = !isLeft ? canvasWidth - center.dx + radius + 10 : null;
    final labelWidth = (canvasWidth * 0.30).clamp(80.0, 130.0);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Premium node circle with gradient fill + SVG flag
        Positioned(
          left: center.dx - radius,
          top: center.dy - radius,
          child: _PremiumNodeCircle(
            radius: radius,
            isFirstVisit: isFirstVisit,
            child: ClipOval(
              child: SvgPicture.asset(
                'assets/flags/svg/${cc.toLowerCase()}.svg',
                width: flagW,
                height: flagH,
                fit: BoxFit.cover,
                placeholderBuilder:
                    (_) => Text(
                      flagEmoji(cc),
                      style: TextStyle(fontSize: isFirstVisit ? 22 : 16),
                    ),
              ),
            ),
          ),
        ),
        // Scene badge — bottom-left of node
        Positioned(
          left: center.dx - radius + 2,
          top: center.dy + radius - 18,
          child: _SceneBadge(scene: scene),
        ),
        // First-visit gold star — top-right of node
        if (isFirstVisit)
          Positioned(
            left: center.dx + radius - 14,
            top: center.dy - radius - 2,
            child: const _FirstVisitBadge(),
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
    final labelLeft = isLeft ? center.dx + _kAchievementRadius + 10 : null;
    final labelRight =
        !isLeft ? canvasWidth - center.dx + _kAchievementRadius + 10 : null;
    final labelWidth = (canvasWidth * 0.30).clamp(80.0, 130.0);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Achievement circle with glow
        Positioned(
          left: center.dx - _kAchievementRadius,
          top: center.dy - _kAchievementRadius,
          child: _AchievementCircle(
            radius: _kAchievementRadius,
            child: Text(emoji, style: const TextStyle(fontSize: 28)),
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

// ── Premium node circle (trip) ────────────────────────────────────────────────

class _PremiumNodeCircle extends StatelessWidget {
  const _PremiumNodeCircle({
    required this.radius,
    required this.isFirstVisit,
    required this.child,
  });

  final double radius;
  final bool isFirstVisit;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final diameter = radius * 2;
    final borderColor = isFirstVisit ? cs.primary : cs.outline;
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient:
            isFirstVisit
                ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    cs.primaryContainer,
                    cs.primary.withValues(alpha: 0.25),
                  ],
                )
                : null,
        color: isFirstVisit ? null : cs.surfaceContainerHighest,
        border: Border.all(
          color: borderColor,
          width: isFirstVisit ? 2.5 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: borderColor.withValues(alpha: isFirstVisit ? 0.35 : 0.15),
            blurRadius: isFirstVisit ? 12 : 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}

// ── Achievement circle ────────────────────────────────────────────────────────

class _AchievementCircle extends StatelessWidget {
  const _AchievementCircle({required this.radius, required this.child});

  final double radius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final diameter = radius * 2;
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [cs.secondaryContainer, cs.tertiaryContainer],
        ),
        border: Border.all(color: cs.secondary, width: 3),
        boxShadow: [
          BoxShadow(
            color: cs.secondary.withValues(alpha: 0.40),
            blurRadius: 20,
            spreadRadius: 2,
            offset: Offset.zero,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}

// ── Scene badge ───────────────────────────────────────────────────────────────

class _SceneBadge extends StatelessWidget {
  const _SceneBadge({required this.scene});
  final String scene;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: cs.surface,
        border: Border.all(color: cs.outline.withValues(alpha: 0.4), width: 1),
      ),
      alignment: Alignment.center,
      child: Text(scene, style: const TextStyle(fontSize: 10)),
    );
  }
}

// ── First-visit badge ─────────────────────────────────────────────────────────

class _FirstVisitBadge extends StatelessWidget {
  const _FirstVisitBadge();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: cs.secondary,
        boxShadow: [
          BoxShadow(
            color: cs.secondary.withValues(alpha: 0.5),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: const Text('⭐', style: TextStyle(fontSize: 9)),
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
