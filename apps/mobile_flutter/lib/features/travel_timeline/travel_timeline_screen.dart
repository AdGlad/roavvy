import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:shared_models/shared_models.dart';

import '../../core/continent_emoji.dart';
import '../../core/country_names.dart';
import '../../core/providers.dart';
import 'country_scene_icons.dart';
import 'journey_share_exporter.dart';
import 'timeline_painter.dart';
import 'trip_detail_sheet.dart';

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

final class _YearHeaderItem extends _TimelineItem {
  _YearHeaderItem({
    required this.year,
    required this.countryCount,
    required this.continentCount,
  });

  final int year;
  final int countryCount;
  final int continentCount;
}

// ── Provider ──────────────────────────────────────────────────────────────────

/// Builds the interleaved list of year headers + trips + achievement milestones,
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

  // Precompute per-year stats for headers.
  final yearCountries = <int, Set<String>>{};
  final yearContinents = <int, Set<String>>{};
  for (final trip in sorted) {
    final y = trip.startedOn.year;
    final cc = trip.countryCode.toUpperCase();
    (yearCountries[y] ??= {}).add(cc);
    (yearContinents[y] ??= {}).add(kCountryContinent[cc] ?? 'Other');
  }

  int nextAchIdx = 0;
  int? lastYear;

  for (final trip in sorted) {
    final cc = trip.countryCode.toUpperCase();
    final year = trip.startedOn.year;

    // Inject a year header whenever the year changes.
    if (year != lastYear) {
      chronological.add(
        _YearHeaderItem(
          year: year,
          countryCount: yearCountries[year]?.length ?? 0,
          continentCount: yearContinents[year]?.length ?? 0,
        ),
      );
      lastYear = year;
    }

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

// ── Stats DTO ─────────────────────────────────────────────────────────────────

class _TimelineStats {
  const _TimelineStats({
    required this.countryCount,
    required this.visitedContinents,
    required this.sinceYear,
  });

  final int countryCount;
  final Set<String> visitedContinents;
  final int sinceYear;
}

_TimelineStats _computeStats(List<TripRecord> trips) {
  final countries = <String>{};
  final continents = <String>{};
  int earliest = DateTime.now().year;
  for (final t in trips) {
    final cc = t.countryCode.toUpperCase();
    countries.add(cc);
    final c = kCountryContinent[cc];
    if (c != null) continents.add(c);
    if (t.startedOn.year < earliest) earliest = t.startedOn.year;
  }
  return _TimelineStats(
    countryCount: countries.length,
    visitedContinents: continents,
    sinceYear: earliest,
  );
}

// ── Filter helpers ────────────────────────────────────────────────────────────

bool _matchesContinent(String countryCode, String? activeContinent) {
  if (activeContinent == null) return true;
  final continent = kCountryContinent[countryCode.toUpperCase()];
  if (activeContinent == 'Americas') {
    return continent == 'North America' || continent == 'South America';
  }
  return continent == activeContinent;
}

List<_TimelineItem> _filterItems(
  List<_TimelineItem> items,
  String? activeContinent,
  bool firstVisitOnly,
) {
  if (activeContinent == null && !firstVisitOnly) return items;
  return items.where((item) {
    if (item is _TripItem) {
      final cc = item.trip.countryCode.toUpperCase();
      if (!_matchesContinent(cc, activeContinent)) return false;
      if (firstVisitOnly && !item.isFirstVisit) return false;
      return true;
    }
    return true;
  }).toList();
}

// ── Screen ────────────────────────────────────────────────────────────────────

class TravelTimelineScreen extends ConsumerStatefulWidget {
  const TravelTimelineScreen({super.key});

  @override
  ConsumerState<TravelTimelineScreen> createState() =>
      _TravelTimelineScreenState();
}

class _TravelTimelineScreenState extends ConsumerState<TravelTimelineScreen> {
  String? _activeContinent;
  bool _firstVisitOnly = false;
  late final ScrollController _scrollCtrl;

  @override
  void initState() {
    super.initState();
    _scrollCtrl = ScrollController();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          final stats = _computeStats(trips);
          final unlockedIds = achievementsAsync.valueOrNull ?? {};
          final items = _buildTimeline(trips, unlockedIds);
          final filteredItems = _filterItems(
            items,
            _activeContinent,
            _firstVisitOnly,
          );
          return Column(
            children: [
              _TimelineStatsHeader(stats: stats, trips: trips),
              const Divider(height: 1, thickness: 1),
              _FilterBar(
                activeContinent: _activeContinent,
                firstVisitOnly: _firstVisitOnly,
                onContinentChanged: (c) =>
                    setState(() => _activeContinent = c),
                onFirstVisitOnlyChanged: (v) =>
                    setState(() => _firstVisitOnly = v),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final headerIndices = {
                      for (int i = 0; i < filteredItems.length; i++)
                        if (filteredItems[i] is _YearHeaderItem) i,
                    };
                    final positions = computeTimelinePositions(
                      count: filteredItems.length,
                      width: width,
                      topPadding: _kTopPadding,
                      nodeSpacing: _kNodeSpacing,
                      headerIndices: headerIndices,
                    );
                    final yearOffsets = <int, double>{};
                    for (int i = 0; i < filteredItems.length; i++) {
                      final item = filteredItems[i];
                      if (item is _YearHeaderItem) {
                        yearOffsets[item.year] =
                            positions[i].dy - _kTopPadding;
                      }
                    }
                    return Stack(
                      children: [
                        _TimelineBody(
                          items: filteredItems,
                          scrollController: _scrollCtrl,
                        ),
                        if (yearOffsets.length >= 3)
                          Positioned(
                            right: 4,
                            top: 0,
                            bottom: 0,
                            child: _YearJumpIndex(
                              yearOffsets: yearOffsets,
                              scrollController: _scrollCtrl,
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Stats header ──────────────────────────────────────────────────────────────

const _kAllContinents = [
  'Europe',
  'Asia',
  'North America',
  'South America',
  'Africa',
  'Oceania',
];

class _TimelineStatsHeader extends StatefulWidget {
  const _TimelineStatsHeader({required this.stats, required this.trips});

  final _TimelineStats stats;
  final List<TripRecord> trips;

  @override
  State<_TimelineStatsHeader> createState() => _TimelineStatsHeaderState();
}

class _TimelineStatsHeaderState extends State<_TimelineStatsHeader> {
  bool _isSharing = false;

  Future<void> _share() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);
    try {
      await JourneyShareExporter.export(
        context: context,
        countryCount: widget.stats.countryCount,
        continentCount: widget.stats.visitedContinents.length,
        sinceYear: widget.stats.sinceYear,
        trips: widget.trips,
      );
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Stat chips row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _StatChip(
                label: '${widget.stats.countryCount} countries',
                icon: '🌍',
              ),
              _StatChip(
                label: '${widget.stats.visitedContinents.length} continents',
                icon: '🗺️',
              ),
              _StatChip(
                label: 'Since ${widget.stats.sinceYear}',
                icon: '📅',
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Continent dot strip
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final continent in _kAllContinents) ...[
                _ContinentDot(
                  continent: continent,
                  visited: widget.stats.visitedContinents.contains(continent),
                ),
                if (continent != _kAllContinents.last) const SizedBox(width: 8),
              ],
            ],
          ),
          const SizedBox(height: 12),
          // Share CTA
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isSharing ? null : _share,
              icon: _isSharing
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: cs.primary,
                      ),
                    )
                  : const Icon(Icons.share_outlined, size: 16),
              label: Text(_isSharing ? 'Sharing…' : 'Share your journey'),
              style: OutlinedButton.styleFrom(
                foregroundColor: cs.primary,
                side: BorderSide(color: cs.primary.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(vertical: 10),
                textStyle: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.icon});

  final String label;
  final String icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContinentDot extends StatelessWidget {
  const _ContinentDot({required this.continent, required this.visited});

  final String continent;
  final bool visited;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final emoji = kContinentEmoji[continent] ?? '🌐';
    return Tooltip(
      message: continent,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: visited ? 28 : 18,
        height: visited ? 28 : 18,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: visited ? cs.primaryContainer : cs.surfaceContainerHighest,
          border: Border.all(
            color: visited ? cs.primary : cs.outline.withValues(alpha: 0.3),
            width: visited ? 2 : 1,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          emoji,
          style: TextStyle(fontSize: visited ? 14 : 10),
        ),
      ),
    );
  }
}

// ── Filter bar ────────────────────────────────────────────────────────────────

const _kContinentLabels = [
  'Europe',
  'Asia',
  'Americas',
  'Africa',
  'Oceania',
];

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.activeContinent,
    required this.firstVisitOnly,
    required this.onContinentChanged,
    required this.onFirstVisitOnlyChanged,
  });

  final String? activeContinent;
  final bool firstVisitOnly;
  final ValueChanged<String?> onContinentChanged;
  final ValueChanged<bool> onFirstVisitOnlyChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: [
          _buildContinentChip(context, cs, null),
          for (final label in _kContinentLabels) ...[
            const SizedBox(width: 6),
            _buildContinentChip(context, cs, label),
          ],
          const SizedBox(width: 6),
          FilterChip(
            label: const Text('★ First visits'),
            selected: firstVisitOnly,
            onSelected: onFirstVisitOnlyChanged,
            selectedColor: cs.primaryContainer,
            labelStyle: TextStyle(
              color: firstVisitOnly ? cs.onPrimaryContainer : cs.onSurface,
              fontSize: 12,
            ),
            backgroundColor: cs.surfaceContainerHighest,
            side: BorderSide.none,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildContinentChip(
    BuildContext context,
    ColorScheme cs,
    String? label,
  ) {
    final isActive = activeContinent == label;
    return FilterChip(
      label: Text(label ?? 'All'),
      selected: isActive,
      onSelected: (_) => onContinentChanged(isActive ? null : label),
      selectedColor: cs.primaryContainer,
      labelStyle: TextStyle(
        color: isActive ? cs.onPrimaryContainer : cs.onSurface,
        fontSize: 12,
      ),
      backgroundColor: cs.surfaceContainerHighest,
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      visualDensity: VisualDensity.compact,
    );
  }
}

// ── Year jump index ───────────────────────────────────────────────────────────

class _YearJumpIndex extends StatelessWidget {
  const _YearJumpIndex({
    required this.yearOffsets,
    required this.scrollController,
  });

  final Map<int, double> yearOffsets;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final sortedYears = yearOffsets.keys.toList()..sort();
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final year in sortedYears)
          GestureDetector(
            onTap: () => scrollController.animateTo(
              yearOffsets[year]!,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                year.toString(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.5),
                  fontSize: 9,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Timeline body ─────────────────────────────────────────────────────────────

class _TimelineBody extends StatefulWidget {
  const _TimelineBody({required this.items, required this.scrollController});

  final List<_TimelineItem> items;
  final ScrollController scrollController;

  @override
  State<_TimelineBody> createState() => _TimelineBodyState();
}

class _TimelineBodyState extends State<_TimelineBody>
    with TickerProviderStateMixin {
  // Only animate on the very first build — skip on scroll restore.
  static bool _hasAnimated = false;

  late final AnimationController _pathCtrl;
  late final AnimationController _staggerCtrl;
  late final Animation<double> _pathAnim;

  @override
  void initState() {
    super.initState();
    final staggerMs =
        (widget.items.length * 40).clamp(1, 800);

    _pathCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _staggerCtrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: staggerMs),
    );
    _pathAnim = CurvedAnimation(parent: _pathCtrl, curve: Curves.easeInOut);

    if (!_hasAnimated) {
      _pathCtrl.forward();
      _staggerCtrl.forward();
      _hasAnimated = true;
    } else {
      _pathCtrl.value = 1.0;
      _staggerCtrl.value = 1.0;
    }
  }

  @override
  void dispose() {
    _pathCtrl.dispose();
    _staggerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_pathAnim, _staggerCtrl]),
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final headerIndices = {
              for (int i = 0; i < widget.items.length; i++)
                if (widget.items[i] is _YearHeaderItem) i,
            };
            final positions = computeTimelinePositions(
              count: widget.items.length,
              width: width,
              topPadding: _kTopPadding,
              nodeSpacing: _kNodeSpacing,
              headerIndices: headerIndices,
            );
            final totalHeight = timelineHeight(
              count: widget.items.length,
              topPadding: _kTopPadding,
              nodeSpacing: _kNodeSpacing,
              bottomPadding: _kBottomPadding,
            );

            final cs = Theme.of(context).colorScheme;
            final pathShadow = cs.primary.withValues(alpha: 0.12);
            final staggerMs =
                (widget.items.length * 40).clamp(1, 800).toDouble();

            return SingleChildScrollView(
              controller: widget.scrollController,
              child: SizedBox(
                width: width,
                height: totalHeight,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Snake path (draws on via pathProgress)
                    Positioned.fill(
                      child: CustomPaint(
                        painter: TimelinePainter(
                          positions: positions,
                          nodeRadius: _kNodeRadius,
                          pathColor: cs.primary,
                          pathShadowColor: pathShadow,
                          pathProgress: _pathAnim.value,
                        ),
                      ),
                    ),
                    // Nodes with staggered entry
                    for (int i = 0; i < widget.items.length; i++) ...[
                      () {
                        final delayFraction =
                            (i * 40.0 / staggerMs).clamp(0.0, 1.0);
                        final endFraction =
                            (delayFraction + 0.3).clamp(0.0, 1.0);
                        final nodeProgress = Interval(
                          delayFraction,
                          endFraction,
                          curve: Curves.easeOut,
                        ).transform(_staggerCtrl.value);
                        return _PositionedNode(
                          item: widget.items[i],
                          center: positions[i],
                          width: width,
                          nodeProgress: nodeProgress,
                        );
                      }(),
                    ],
                  ],
                ),
              ),
            );
          },
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
    this.nodeProgress = 1.0,
  });

  final _TimelineItem item;
  final Offset center;
  final double width;
  final double nodeProgress;

  @override
  Widget build(BuildContext context) {
    final child = switch (item) {
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
      _YearHeaderItem(:final year, :final countryCount, :final continentCount) =>
        _YearHeaderNode(
          year: year,
          countryCount: countryCount,
          continentCount: continentCount,
          center: center,
        ),
    };
    if (nodeProgress >= 1.0) return child;
    return Opacity(
      opacity: nodeProgress,
      child: Transform.scale(
        scale: 0.6 + 0.4 * nodeProgress,
        origin: center,
        child: child,
      ),
    );
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

    return GestureDetector(
      onTap: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => TripDetailSheet(trip: trip, isFirstVisit: isFirstVisit),
      ),
      child: Stack(
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
      ),
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

    return GestureDetector(
      onTap: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => AchievementDetailSheet(achievement: achievement),
      ),
      child: Stack(
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
      ),
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

// ── Year header node ──────────────────────────────────────────────────────────

class _YearHeaderNode extends StatelessWidget {
  const _YearHeaderNode({
    required this.year,
    required this.countryCount,
    required this.continentCount,
    required this.center,
  });

  final int year;
  final int countryCount;
  final int continentCount;
  final Offset center;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final parts = <String>[
      '$year',
      '$countryCount ${countryCount == 1 ? 'country' : 'countries'}',
      if (continentCount > 1) '$continentCount continents',
    ];
    return Positioned(
      left: 0,
      right: 0,
      top: center.dy - 22,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: cs.secondaryContainer.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: cs.secondary.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Text(
            parts.join('  ·  '),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: cs.onSecondaryContainer,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
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
