import 'package:flutter/material.dart';
import 'package:shared_models/shared_models.dart';

import '../../../core/theme/roavvy_colours.dart';
import '../continent_explorer_screen.dart';

// Per-continent country totals (ISO 3166-1 alpha-2 set used by kCountryContinent).
const _kContinentTotals = <String, int>{
  'Africa': 54,
  'Asia': 48,
  'Europe': 44,
  'North America': 23,
  'South America': 12,
  'Oceania': 14,
};

/// Returns the continent with the highest completion fraction, or null when
/// the user has visited zero countries.
///
/// On a tie in fraction, prefers the continent with more absolute visits.
String? deepestContinent(
  Map<String, int> visitedPerContinent,
  Map<String, int> totals,
) {
  String? best;
  double bestFrac = -1;
  int bestAbs = -1;

  for (final entry in totals.entries) {
    final continent = entry.key;
    final total = entry.value;
    final visited = visitedPerContinent[continent] ?? 0;
    if (visited == 0) continue;
    final frac = visited / total;
    if (frac > bestFrac || (frac == bestFrac && visited > bestAbs)) {
      best = continent;
      bestFrac = frac;
      bestAbs = visited;
    }
  }
  return best;
}

/// Gradient callout card showing the continent the user has explored most
/// deeply (M151). Hidden when countryCount == 0.
///
/// Tapping "Explore [Continent]" navigates to [ContinentExplorerScreen].
class DeepestRegionCard extends StatelessWidget {
  const DeepestRegionCard({super.key, required this.visits});

  final List<EffectiveVisitedCountry>? visits;

  @override
  Widget build(BuildContext context) {
    final visitList = visits ?? [];
    if (visitList.isEmpty) return const SizedBox.shrink();

    // Count visits per continent.
    final visitedPerContinent = <String, int>{};
    for (final v in visitList) {
      final continent = kCountryContinent[v.countryCode];
      if (continent != null) {
        visitedPerContinent[continent] =
            (visitedPerContinent[continent] ?? 0) + 1;
      }
    }

    final continent = deepestContinent(visitedPerContinent, _kContinentTotals);
    if (continent == null) return const SizedBox.shrink();

    final visited = visitedPerContinent[continent]!;
    final total = _kContinentTotals[continent]!;
    final remaining = total - visited;
    final fraction = visited / total;
    final percent = (fraction * 100).round();

    final color =
        RoavvyColours.continentColors[continent] ?? const Color(0xFF3498DB);
    final emoji = RoavvyColours.continentEmoji[continent] ?? '🌍';

    return _DeepestRegionCardView(
      continent: continent,
      emoji: emoji,
      visited: visited,
      total: total,
      remaining: remaining,
      percent: percent,
      fraction: fraction,
      color: color,
    );
  }
}

class _DeepestRegionCardView extends StatelessWidget {
  const _DeepestRegionCardView({
    required this.continent,
    required this.emoji,
    required this.visited,
    required this.total,
    required this.remaining,
    required this.percent,
    required this.fraction,
    required this.color,
  });

  final String continent;
  final String emoji;
  final int visited;
  final int total;
  final int remaining;
  final int percent;
  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: isDark ? 0.25 : 0.15),
            color.withValues(alpha: isDark ? 0.10 : 0.05),
          ],
        ),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.45 : 0.30),
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      continent,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    Text(
                      'Your most explored continent',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Count + percent
          Text(
            '$visited / $total countries  ·  $percent%',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          // Animated progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: fraction),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOut,
              builder: (_, value, __) => LinearProgressIndicator(
                value: value,
                minHeight: 8,
                backgroundColor: color.withValues(alpha: 0.18),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Remaining callout
          if (remaining > 0)
            Text(
              remaining == 1
                  ? 'Just 1 more country to complete $continent!'
                  : '$remaining more to complete $continent',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          if (remaining == 0)
            Text(
              '$continent complete!',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          const SizedBox(height: 16),
          // CTA
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const ContinentExplorerScreen(),
              ),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: color.withValues(alpha: 0.18),
              foregroundColor: color,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: Text('Explore $continent'),
          ),
        ],
      ),
    );
  }
}
