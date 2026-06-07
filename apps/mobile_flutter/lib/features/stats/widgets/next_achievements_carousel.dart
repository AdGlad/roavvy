import 'package:flutter/material.dart';
import 'package:shared_models/shared_models.dart';

import '../../../core/theme/roavvy_colours.dart';

/// Category filter options for [NextAchievementsCarousel].
enum _AchievementFilter {
  all,
  countries,
  continents,
  trips,
  thisYear,
  heritage,
}

/// Horizontally scrollable carousel of ALL unmet achievements (M97, ADR-148).
///
/// Category filter tabs (All / Countries / Continents / Trips / This Year /
/// UNESCO) let the user browse every locked achievement and see exactly what
/// is required. Sorted by ascending remaining so closest appear first.
/// Cards ≤ 2 away show "SO CLOSE!" badge. Progress bars animate on render.
class NextAchievementsCarousel extends StatefulWidget {
  const NextAchievementsCarousel({
    super.key,
    required this.countryCount,
    required this.continentCount,
    required this.tripCount,
    required this.thisYearCount,
    required this.unlockedIds,
    this.heritageCount = 0,
  });

  final int countryCount;
  final int continentCount;
  final int tripCount;
  final int thisYearCount;
  final int heritageCount;
  final Set<String> unlockedIds;

  @override
  State<NextAchievementsCarousel> createState() =>
      _NextAchievementsCarouselState();
}

class _NextAchievementsCarouselState extends State<NextAchievementsCarousel> {
  _AchievementFilter _filter = _AchievementFilter.all;

  int _currentProgress(Achievement a) => switch (a.category) {
    AchievementCategory.countries => widget.countryCount,
    AchievementCategory.continents => widget.continentCount,
    AchievementCategory.trips => widget.tripCount,
    AchievementCategory.thisYear => widget.thisYearCount,
    AchievementCategory.heritageSites => widget.heritageCount,
  };

  bool _matchesFilter(Achievement a) => switch (_filter) {
    _AchievementFilter.all => true,
    _AchievementFilter.countries =>
      a.category == AchievementCategory.countries,
    _AchievementFilter.continents =>
      a.category == AchievementCategory.continents,
    _AchievementFilter.trips => a.category == AchievementCategory.trips,
    _AchievementFilter.thisYear => a.category == AchievementCategory.thisYear,
    _AchievementFilter.heritage =>
      a.category == AchievementCategory.heritageSites,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final allUnmet = kAchievements
        .where((a) => !widget.unlockedIds.contains(a.id))
        .map((a) => (a, a.progressTarget - _currentProgress(a)))
        .where((t) => t.$2 > 0)
        .toList()
      ..sort((a, b) => a.$2.compareTo(b.$2));

    if (allUnmet.isEmpty) return const SizedBox.shrink();

    final filtered =
        allUnmet.where((t) => _matchesFilter(t.$1)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ─────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Row(
            children: [
              Icon(
                Icons.bolt_outlined,
                size: 17,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                'To Unlock',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${filtered.length}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Category filter chips ───────────────────────────────────────
        SizedBox(
          height: 32,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            children: [
              _FilterChip(
                label: 'All',
                selected: _filter == _AchievementFilter.all,
                color: theme.colorScheme.primary,
                onTap: () => setState(
                  () => _filter = _AchievementFilter.all,
                ),
              ),
              const SizedBox(width: 6),
              _FilterChip(
                label: 'Countries',
                selected: _filter == _AchievementFilter.countries,
                color: const Color(0xFF2F80ED),
                onTap: () => setState(
                  () => _filter = _AchievementFilter.countries,
                ),
              ),
              const SizedBox(width: 6),
              _FilterChip(
                label: 'Continents',
                selected: _filter == _AchievementFilter.continents,
                color: const Color(0xFF27AE60),
                onTap: () => setState(
                  () => _filter = _AchievementFilter.continents,
                ),
              ),
              const SizedBox(width: 6),
              _FilterChip(
                label: 'Trips',
                selected: _filter == _AchievementFilter.trips,
                color: const Color(0xFF9B51E0),
                onTap: () => setState(
                  () => _filter = _AchievementFilter.trips,
                ),
              ),
              const SizedBox(width: 6),
              _FilterChip(
                label: 'This Year',
                selected: _filter == _AchievementFilter.thisYear,
                color: const Color(0xFF00ACC1),
                onTap: () => setState(
                  () => _filter = _AchievementFilter.thisYear,
                ),
              ),
              const SizedBox(width: 6),
              _FilterChip(
                label: 'UNESCO',
                selected: _filter == _AchievementFilter.heritage,
                color: RoavvyColours.roavvyGold,
                onTap: () => setState(
                  () => _filter = _AchievementFilter.heritage,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // ── Scrollable cards ────────────────────────────────────────────
        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              'All achievements in this category unlocked!',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          )
        else
          SizedBox(
            height: 168,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final (achievement, remaining) = filtered[index];
                return _NextAchievementCard(
                  achievement: achievement,
                  current: _currentProgress(achievement),
                  remaining: remaining,
                );
              },
            ),
          ),
      ],
    );
  }
}

// ── Filter chip ───────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color : color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? color : color.withValues(alpha: 0.30),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _NextAchievementCard extends StatelessWidget {
  const _NextAchievementCard({
    required this.achievement,
    required this.current,
    required this.remaining,
  });

  final Achievement achievement;
  final int current;
  final int remaining;

  static LinearGradient _gradient(AchievementCategory cat) => switch (cat) {
    AchievementCategory.countries => const LinearGradient(
      colors: [Color(0xFF1565C0), Color(0xFF2F80ED)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    AchievementCategory.continents => const LinearGradient(
      colors: [Color(0xFF1B5E20), Color(0xFF27AE60)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    AchievementCategory.trips => const LinearGradient(
      colors: [Color(0xFF4A148C), Color(0xFF9B51E0)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    AchievementCategory.thisYear => const LinearGradient(
      colors: [Color(0xFF006064), Color(0xFF00ACC1)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    AchievementCategory.heritageSites => LinearGradient(
      colors: [Color(0xFFF57F17), RoavvyColours.roavvyGold],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  };

  static IconData _icon(AchievementCategory cat) => switch (cat) {
    AchievementCategory.countries => Icons.public_outlined,
    AchievementCategory.continents => Icons.travel_explore_outlined,
    AchievementCategory.trips => Icons.flight_takeoff_outlined,
    AchievementCategory.thisYear => Icons.calendar_today_outlined,
    AchievementCategory.heritageSites => Icons.account_balance_outlined,
  };

  String _unit(AchievementCategory cat) => switch (cat) {
    AchievementCategory.countries => 'countries',
    AchievementCategory.continents => 'continents',
    AchievementCategory.trips => 'trips',
    AchievementCategory.thisYear => 'this year',
    AchievementCategory.heritageSites => 'heritage sites',
  };

  String _merchLabel(MerchTriggerType type) => switch (type) {
    MerchTriggerType.flagGrid => 'Flag Grid Tee',
    MerchTriggerType.passportStamp => 'Passport Stamp Tee',
    MerchTriggerType.timeline => 'Travel Timeline Tee',
    MerchTriggerType.country => 'Country Tee',
    MerchTriggerType.milestone => 'Milestone Tee',
  };

  @override
  Widget build(BuildContext context) {
    final progress = (current / achievement.progressTarget).clamp(0.0, 1.0);
    final gradient = _gradient(achievement.category);
    final accentColor = gradient.colors.last;
    final isSoClose = remaining <= 2;

    return Container(
      width: 210,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ───────────────────────────────────────────────
          Row(
            children: [
              Icon(_icon(achievement.category), size: 16, color: Colors.white70),
              const Spacer(),
              if (isSoClose)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'SO CLOSE!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // ── Title ────────────────────────────────────────────────
          Text(
            achievement.title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
              height: 1.2,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            '${achievement.progressTarget} ${_unit(achievement.category)}',
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
          const Spacer(),
          // ── Progress bar ─────────────────────────────────────────
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOut,
            builder: (_, v, __) => LinearProgressIndicator(
              value: v,
              minHeight: 5,
              borderRadius: BorderRadius.circular(3),
              backgroundColor: Colors.white.withValues(alpha: 0.25),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                '$current / ${achievement.progressTarget}',
                style: const TextStyle(color: Colors.white70, fontSize: 10),
              ),
              const Spacer(),
              Text(
                isSoClose
                    ? '$remaining to go!'
                    : '$remaining more to go',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (achievement.merch != null) ...[
            const SizedBox(height: 5),
            Text(
              'Unlocks ${_merchLabel(achievement.merch!)}',
              style: const TextStyle(color: Colors.white60, fontSize: 9),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
