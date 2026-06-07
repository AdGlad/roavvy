import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:shared_models/shared_models.dart';

import '../../../core/theme/roavvy_colours.dart';
import '../../merch/achievement_merch_option_screen.dart';

/// Gamified hero card for the Stats screen (M97 + M147).
///
/// Shows an animated PieChart donut, travel persona, global ranking estimate,
/// dynamic motivational message, and a "Create your travel tee" CTA.
/// Dark-mode safe: uses theme.colorScheme.surface instead of Colors.white.
class TravelProgressHero extends StatefulWidget {
  const TravelProgressHero({
    super.key,
    required this.countryCount,
    required this.unlockedIds,
    this.continentCount = 0,
    this.tripCount = 0,
    this.heritageCount = 0,
  });

  final int countryCount;
  final Set<String> unlockedIds;
  final int continentCount;
  final int tripCount;
  final int heritageCount;

  @override
  State<TravelProgressHero> createState() => _TravelProgressHeroState();
}

class _TravelProgressHeroState extends State<TravelProgressHero>
    with SingleTickerProviderStateMixin {
  static const int _totalCountries = 195;

  late final AnimationController _ringCtrl;
  late final Animation<double> _ringAnim;

  @override
  void initState() {
    super.initState();
    _ringCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _ringAnim = CurvedAnimation(parent: _ringCtrl, curve: Curves.easeOutCubic);
    _ringCtrl.forward();
  }

  @override
  void dispose() {
    _ringCtrl.dispose();
    super.dispose();
  }

  // ── Persona ──────────────────────────────────────────────────────────────

  static String _persona(int n) {
    if (n >= 100) return 'World Conqueror';
    if (n >= 75) return 'Global Nomad';
    if (n >= 50) return 'World Explorer';
    if (n >= 30) return 'Globetrotter';
    if (n >= 15) return 'Seasoned Traveller';
    if (n >= 5) return 'Frequent Flyer';
    if (n >= 1) return 'Weekend Explorer';
    return 'Future Explorer';
  }

  static String? _ranking(int n) {
    if (n == 0) return null;
    if (n >= 150) return 'Top 0.2%';
    if (n >= 100) return 'Top 0.5%';
    if (n >= 75) return 'Top 1%';
    if (n >= 50) return 'Top 3%';
    if (n >= 30) return 'Top 7%';
    if (n >= 20) return 'Top 12%';
    if (n >= 10) return 'Top 25%';
    if (n >= 5) return 'Top 40%';
    return 'Top 60%';
  }

  // ── Motivational message ─────────────────────────────────────────────────

  String? _motivation() {
    Achievement? nearest;
    int nearestRemaining = 9999;
    for (final a in kAchievements) {
      if (widget.unlockedIds.contains(a.id)) continue;
      final current = _progressFor(a);
      final remaining = a.progressTarget - current;
      if (remaining > 0 && remaining < nearestRemaining) {
        nearestRemaining = remaining;
        nearest = a;
      }
    }
    if (nearest == null) {
      return 'Every achievement unlocked — you\'re unstoppable!';
    }
    final noun = switch (nearest.category) {
      AchievementCategory.countries => nearestRemaining == 1
          ? '1 more country'
          : '$nearestRemaining more countries',
      AchievementCategory.continents => nearestRemaining == 1
          ? '1 more continent'
          : '$nearestRemaining more continents',
      AchievementCategory.trips => nearestRemaining == 1
          ? '1 more trip'
          : '$nearestRemaining more trips',
      AchievementCategory.thisYear => nearestRemaining == 1
          ? '1 more country this year'
          : '$nearestRemaining more countries this year',
      AchievementCategory.heritageSites => nearestRemaining == 1
          ? '1 more UNESCO site'
          : '$nearestRemaining more UNESCO sites',
    };
    return '$noun to unlock "${nearest.title}"';
  }

  int _progressFor(Achievement a) => switch (a.category) {
    AchievementCategory.countries => widget.countryCount,
    AchievementCategory.continents => widget.continentCount,
    AchievementCategory.trips => widget.tripCount,
    AchievementCategory.thisYear => widget.countryCount,
    AchievementCategory.heritageSites => widget.heritageCount,
  };

  // ── Top achievement ──────────────────────────────────────────────────────

  Achievement? _topAchievement() {
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
      if (widget.unlockedIds.contains(id)) {
        return kAchievements.firstWhere((a) => a.id == id);
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = widget.countryCount;
    final fraction = count / _totalCountries;
    final persona = _persona(count);
    final ranking = _ranking(count);
    final motivation = _motivation();
    final topAchievement = _topAchievement();
    final tier = topAchievement?.title;
    final gold = RoavvyColours.roavvyGold;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: theme.shadowColor.withValues(alpha: 0.1),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            children: [
              // ── Animated donut ring ──────────────────────────────────────
              SizedBox(
                height: 190,
                child: AnimatedBuilder(
                  animation: _ringAnim,
                  builder: (_, __) {
                    final animated = count * _ringAnim.value;
                    final animRemaining =
                        (_totalCountries - animated).clamp(
                          0.0,
                          _totalCountries.toDouble(),
                        );
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        PieChart(
                          PieChartData(
                            startDegreeOffset: -90,
                            sectionsSpace: 0,
                            centerSpaceRadius: 70,
                            sections: [
                              PieChartSectionData(
                                value: animated.clamp(
                                  0.5,
                                  _totalCountries.toDouble(),
                                ),
                                color: gold,
                                radius: 22,
                                showTitle: false,
                              ),
                              PieChartSectionData(
                                value: animRemaining.clamp(
                                  0.5,
                                  _totalCountries.toDouble(),
                                ),
                                color:
                                    theme.colorScheme.surfaceContainerHighest,
                                radius: 16,
                                showTitle: false,
                              ),
                            ],
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: count.toDouble()),
                              duration: const Duration(milliseconds: 900),
                              curve: Curves.easeOut,
                              builder: (_, v, __) => Text(
                                '${v.round()}',
                                style: theme.textTheme.displaySmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Text(
                              count == 1 ? 'country' : 'countries',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),

              // ── Persona chip + tier badge ────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _Chip(
                    label: persona,
                    color: theme.colorScheme.primary,
                    bordered: false,
                  ),
                  if (tier != null && tier != persona) ...[
                    const SizedBox(width: 6),
                    _Chip(label: tier, color: gold, bordered: true),
                  ],
                ],
              ),

              const SizedBox(height: 6),

              // ── Progress line + ranking ──────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$count / $_totalCountries  ·  '
                    '${(fraction * 100).toStringAsFixed(1)}%',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (ranking != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.tertiary
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        ranking,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.tertiary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),

              // ── Motivational message ─────────────────────────────────────
              if (motivation != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 4),
                  child: Text(
                    motivation,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.65),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),

              const SizedBox(height: 14),

              // ── Merch CTA ────────────────────────────────────────────────
              FilledButton.icon(
                icon: const Icon(Icons.dry_cleaning_outlined, size: 16),
                label: const Text('Create your travel tee'),
                onPressed:
                    topAchievement == null
                        ? null
                        : () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder:
                                (_) => AchievementMerchOptionScreen(
                                  achievement: topAchievement,
                                ),
                          ),
                        ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 44),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Chip helper ───────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.color,
    required this.bordered,
  });

  final String label;
  final Color color;
  final bool bordered;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.13),
      borderRadius: BorderRadius.circular(20),
      border: bordered ? Border.all(color: color.withValues(alpha: 0.5)) : null,
    ),
    child: Text(
      label,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: color,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}
