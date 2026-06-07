import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/db/roavvy_database.dart';
import 'widgets/achievement_gallery.dart';
import 'widgets/daily_challenge_card.dart';
import 'widgets/merch_moments_section.dart';
import 'widgets/next_achievements_carousel.dart';
import 'widgets/stats_grid.dart';
import 'widgets/travel_progress_hero.dart';

/// Gamified travel stats and achievement dashboard (M97 + M147).
///
/// Sections:
/// 1. Travel Progress Hero — animated donut, persona, ranking, motivation
/// 2. Coloured Stats Grid — Countries/Continents/Trips/UNESCO animated cards
/// 3. Daily Challenge Card — streak, best, solve rate, avg clues
/// 4. Next Achievements — horizontal carousel of nearest unmet achievements
/// 5. Achievement Gallery — tabbed with rarity badges and "N more to go"
/// 6. Merch Moments — recently unlocked achievement merch suggestions
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
    final tripCountAsync = ref.watch(tripCountProvider);
    final continentCountAsync = ref.watch(continentCountProvider);
    final thisYearCountAsync = ref.watch(thisYearCountryCountProvider);
    final heritageCount =
        ref.watch(visitedHeritageProvider).valueOrNull?.length ?? 0;
    final challengeAggregate =
        ref.watch(challengeAggregateProvider).valueOrNull;

    final countryCount = visitsAsync.valueOrNull?.length ?? 0;
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
            const SliverAppBar(
              title: Text('Stats'),
              floating: true,
              snap: true,
            ),

            // ── Travel Progress Hero ──────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                child: TravelProgressHero(
                  countryCount: countryCount,
                  unlockedIds: unlockedIds,
                  continentCount: continentCount,
                  tripCount: tripCount,
                  heritageCount: heritageCount,
                ),
              ),
            ),

            // ── Coloured animated stats grid ──────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: StatsGrid(
                  countryCount: countryCount,
                  continentCount: continentCount,
                  tripCount: tripCount,
                  heritageCount: heritageCount,
                  visits: visits,
                ),
              ),
            ),

            // ── Daily Challenge card ──────────────────────────────────────
            if (challengeAggregate != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: DailyChallengeCard(aggregate: challengeAggregate),
                ),
              ),

            // ── Next Achievements Carousel ────────────────────────────────
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

            // ── Achievement Gallery ───────────────────────────────────────
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

            // ── Merch Moments ─────────────────────────────────────────────
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
