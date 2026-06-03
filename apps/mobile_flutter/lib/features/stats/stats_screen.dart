import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_models/shared_models.dart';

import '../../core/providers.dart';
import '../../data/db/roavvy_database.dart';
import 'countries_list_screen.dart';
import 'region_breakdown_sheet.dart';
import 'widgets/achievement_gallery.dart';
import 'widgets/merch_moments_section.dart';
import 'widgets/next_achievements_carousel.dart';
import 'widgets/travel_progress_hero.dart';

/// Gamified travel stats and achievement dashboard (M97, ADR-148).
///
/// Sections:
/// 1. Travel Progress Hero — PieChart donut + tier badge + merch CTA
/// 2. Next Achievements — horizontal carousel of nearest unmet achievements
/// 3. Stats Grid — countries / continents / regions / trips (2×2)
/// 4. Achievement Gallery — tabbed (Countries | Continents | Trips | All)
/// 5. Merch Moments — recently unlocked achievement merch suggestions
class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  late final Future<List<UnlockedAchievementRow>> _achievementsFuture;

  @override
  void initState() {
    super.initState();
    _achievementsFuture = ref.read(achievementRepositoryProvider).loadAllRows();
  }

  @override
  Widget build(BuildContext context) {
    final visitsAsync = ref.watch(effectiveVisitsProvider);
    final regionCountAsync = ref.watch(regionCountProvider);
    final tripCountAsync = ref.watch(tripCountProvider);
    final continentCountAsync = ref.watch(continentCountProvider);
    final thisYearCountAsync = ref.watch(thisYearCountryCountProvider);
    final heritageCount =
        ref.watch(visitedHeritageProvider).valueOrNull?.length ?? 0;

    final countryCount = visitsAsync.valueOrNull?.length ?? 0;
    final regionCount = regionCountAsync.valueOrNull ?? 0;
    final tripCount = tripCountAsync.valueOrNull ?? 0;
    final continentCount = continentCountAsync.valueOrNull ?? 0;
    final thisYearCount = thisYearCountAsync.valueOrNull ?? 0;
    final visits = visitsAsync.valueOrNull;

    return FutureBuilder<List<UnlockedAchievementRow>>(
      future: _achievementsFuture,
      builder: (context, snapshot) {
        final achievementRows = snapshot.data ?? const [];
        final unlockedById = {
          for (final r in achievementRows) r.achievementId: r.unlockedAt,
        };
        final unlockedIds = unlockedById.keys.toSet();

        return CustomScrollView(
          slivers: [
            SliverAppBar(
              title: const Text('Stats'),
              floating: true,
              snap: true,
            ),

            // ── Travel Progress Hero ────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                child: TravelProgressHero(
                  countryCount: countryCount,
                  unlockedIds: unlockedIds,
                ),
              ),
            ),

            // ── Next Achievements Carousel ──────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: NextAchievementsCarousel(
                  countryCount: countryCount,
                  continentCount: continentCount,
                  tripCount: tripCount,
                  thisYearCount: thisYearCount,
                  unlockedIds: unlockedIds,
                ),
              ),
            ),

            // ── Stats Grid ─────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                child: _StatsGrid(
                  countryCount: countryCount,
                  continentCount: continentCount,
                  regionCount: regionCount,
                  tripCount: tripCount,
                  visits: visits,
                  regionCountStr:
                      regionCountAsync.valueOrNull?.toString() ?? '—',
                ),
              ),
            ),

            // ── Achievement Gallery ─────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: AchievementGallery(
                  unlockedById: unlockedById,
                  countryCount: countryCount,
                  continentCount: continentCount,
                  tripCount: tripCount,
                  thisYearCount: thisYearCount,
                  heritageCount: heritageCount,
                ),
              ),
            ),

            // ── Merch Moments ───────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: MerchMomentsSection(unlockedById: unlockedById),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Stats Grid ────────────────────────────────────────────────────────────────

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({
    required this.countryCount,
    required this.continentCount,
    required this.regionCount,
    required this.tripCount,
    required this.visits,
    required this.regionCountStr,
  });

  final int countryCount;
  final int continentCount;
  final int regionCount;
  final int tripCount;
  final List<EffectiveVisitedCountry>? visits;
  final String regionCountStr;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.0,
      children: [
        _StatCard(
          value: countryCount == 0 ? '—' : '$countryCount',
          label: 'Countries',
          suffix: '/ 195',
          onTap:
              (visits != null && visits!.isNotEmpty)
                  ? () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => CountriesListScreen(visits: visits!),
                    ),
                  )
                  : null,
        ),
        _StatCard(
          value: continentCount == 0 ? '—' : '$continentCount',
          label: 'Continents',
          suffix: '/ 6',
        ),
        _StatCard(
          value: regionCount == 0 ? '—' : '$regionCount',
          label: 'Regions',
          onTap:
              regionCount > 0 ? () => RegionBreakdownSheet.show(context) : null,
        ),
        _StatCard(value: tripCount == 0 ? '—' : '$tripCount', label: 'Trips'),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.label,
    this.suffix,
    this.onTap,
  });

  final String value;
  final String label;
  final String? suffix;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final card = Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (suffix != null) ...[
                const SizedBox(width: 4),
                Text(
                  suffix!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
          Row(
            children: [
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 2),
                Icon(
                  Icons.chevron_right,
                  size: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ],
          ),
        ],
      ),
    );
    if (onTap == null) return card;
    return GestureDetector(onTap: onTap, child: card);
  }
}

// ── Standalone Achievements screen ────────────────────────────────────────────

/// Full-screen achievement gallery. Pushed from the map stats strip (M86).
///
/// Wraps [AchievementGallery] in a proper [Scaffold] so it renders correctly
/// when navigated to outside the Stats tab context.
class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  @override
  Widget build(BuildContext context) {
    return const _AchievementsScreenBody();
  }
}

class _AchievementsScreenBody extends ConsumerStatefulWidget {
  const _AchievementsScreenBody();

  @override
  ConsumerState<_AchievementsScreenBody> createState() =>
      _AchievementsScreenBodyState();
}

class _AchievementsScreenBodyState
    extends ConsumerState<_AchievementsScreenBody> {
  late final Future<List<UnlockedAchievementRow>> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(achievementRepositoryProvider).loadAllRows();
  }

  @override
  Widget build(BuildContext context) {
    final continentCount = ref.watch(continentCountProvider).valueOrNull ?? 0;
    final tripCount = ref.watch(tripCountProvider).valueOrNull ?? 0;
    final thisYearCount =
        ref.watch(thisYearCountryCountProvider).valueOrNull ?? 0;
    final countryCount =
        ref.watch(effectiveVisitsProvider).valueOrNull?.length ?? 0;
    final heritageCount =
        ref.watch(visitedHeritageProvider).valueOrNull?.length ?? 0;

    return Scaffold(
      body: FutureBuilder<List<UnlockedAchievementRow>>(
        future: _future,
        builder: (context, snapshot) {
          final rows = snapshot.data ?? const [];
          final unlockedById = {
            for (final r in rows) r.achievementId: r.unlockedAt,
          };
          return CustomScrollView(
            slivers: [
              const SliverAppBar(
                title: Text('Achievements'),
                floating: true,
                snap: true,
              ),
              SliverToBoxAdapter(
                child: AchievementGallery(
                  unlockedById: unlockedById,
                  countryCount: countryCount,
                  continentCount: continentCount,
                  tripCount: tripCount,
                  thisYearCount: thisYearCount,
                  heritageCount: heritageCount,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
            ],
          );
        },
      ),
    );
  }
}
