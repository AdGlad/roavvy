import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:shared_models/shared_models.dart';

import '../../../core/theme/roavvy_colours.dart';
import '../../merch/achievement_merch_option_screen.dart';

/// Gamified hero card for the Stats screen (M97, ADR-148).
///
/// Shows a PieChart donut ring with visited vs remaining countries,
/// the user's tier badge (highest unlocked country achievement), and
/// a "Create your travel tee" CTA.
class TravelProgressHero extends StatelessWidget {
  const TravelProgressHero({
    super.key,
    required this.countryCount,
    required this.unlockedIds,
  });

  final int countryCount;

  /// Set of currently unlocked achievement IDs. Used to derive the tier label.
  final Set<String> unlockedIds;

  static const int _totalCountries = 195;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tier = _tierLabel(unlockedIds);
    final remaining = (_totalCountries - countryCount).clamp(0, _totalCountries);
    final fraction = countryCount / _totalCountries;

    final gold = theme.colorScheme.primary;
    final surface = theme.colorScheme.surfaceContainerHighest;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            SizedBox(
              height: 200,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      startDegreeOffset: -90,
                      sectionsSpace: 0,
                      centerSpaceRadius: 72,
                      sections: [
                        PieChartSectionData(
                          value: countryCount.toDouble().clamp(1, _totalCountries.toDouble()),
                          color: gold,
                          radius: 20,
                          showTitle: false,
                        ),
                        PieChartSectionData(
                          value: remaining.toDouble().clamp(1, _totalCountries.toDouble()),
                          color: surface,
                          radius: 16,
                          showTitle: false,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$countryCount',
                        style: theme.textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        'countries',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (tier != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: RoavvyColours.roavvyGold.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: RoavvyColours.roavvyGold),
                ),
                child: Text(
                  tier,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: RoavvyColours.roavvyGold,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            const SizedBox(height: 4),
            Text(
              '$countryCount / $_totalCountries countries visited  '
              '(${(fraction * 100).toStringAsFixed(1)}%)',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                final achievement = _topAchievement(unlockedIds);
                if (achievement == null) return;
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        AchievementMerchOptionScreen(achievement: achievement),
                  ),
                );
              },
              child: const Text('Create your travel tee'),
            ),
          ],
        ),
      ),
      ),
    );
  }

  /// Returns the title of the highest unlocked country achievement, or null.
  String? _tierLabel(Set<String> unlockedIds) =>
      _topAchievement(unlockedIds)?.title;

  /// Returns the highest unlocked country-count achievement, or null.
  Achievement? _topAchievement(Set<String> unlockedIds) {
    const order = [
      'countries_195',
      'countries_150',
      'countries_125',
      'countries_100',
      'countries_75',
      'countries_50',
      'countries_40',
      'countries_30',
      'countries_25',
      'countries_20',
      'countries_15',
      'countries_10',
      'countries_5',
      'countries_3',
      'countries_1',
    ];
    for (final id in order) {
      if (unlockedIds.contains(id)) {
        return kAchievements.firstWhere((a) => a.id == id);
      }
    }
    return null;
  }
}
