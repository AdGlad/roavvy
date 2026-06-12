import 'dart:developer' as developer;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/notification_service.dart';
import '../../core/providers.dart';
import '../../data/db/roavvy_database.dart';
import 'widgets/achievement_gallery.dart';
import 'widgets/achievement_timeline.dart';
import 'widgets/daily_challenge_card.dart';
import 'widgets/merch_moments_section.dart';
import 'widgets/next_achievements_carousel.dart';
import 'widgets/deepest_region_card.dart';
import 'widgets/rarest_visits_card.dart';
import 'widgets/stats_grid.dart';
import 'widgets/travel_heatmap_card.dart';
import 'widgets/travel_progress_hero.dart';
import 'widgets/year_in_review_card.dart';

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

class _StatsScreenState extends ConsumerState<StatsScreen>
    with SingleTickerProviderStateMixin {
  late final Future<List<UnlockedAchievementRow>> _achievementsFuture;
  late final AnimationController _staggerCtrl;
  final _celebrationPlayer = AudioPlayer();

  // One interval per section — staggered entry over 1.4s total.
  static const _dur = Duration(milliseconds: 1400);

  late final Animation<double> _heroAnim;
  late final Animation<double> _gridAnim;
  late final Animation<double> _heatmapAnim;
  late final Animation<double> _challengeAnim;
  late final Animation<double> _yearAnim;
  late final Animation<double> _carouselAnim;
  late final Animation<double> _rarestAnim;
  late final Animation<double> _deepestAnim;
  late final Animation<double> _timelineAnim;
  late final Animation<double> _galleryAnim;
  late final Animation<double> _merchAnim;

  @override
  void initState() {
    super.initState();
    _achievementsFuture = ref.read(achievementRepositoryProvider).loadAllRows();
    _staggerCtrl = AnimationController(vsync: this, duration: _dur);

    // Play celebration sound when achievements load (fire-and-forget).
    _achievementsFuture.then((rows) {
      if (!mounted || rows.isEmpty) return;
      _celebrationPlayer
          .play(AssetSource('audio/celebration.mp3'))
          .catchError((e) => developer.log('Stats: celebration sound failed: $e'));
    });

    Animation<double> interval(double start, double end) =>
        CurvedAnimation(
          parent: _staggerCtrl,
          curve: Interval(start, end, curve: Curves.easeOut),
        );

    _heroAnim = interval(0.00, 0.30);
    _gridAnim = interval(0.10, 0.40);
    _heatmapAnim = interval(0.15, 0.45);
    _challengeAnim = interval(0.20, 0.50);
    _yearAnim = interval(0.25, 0.55);
    _carouselAnim = interval(0.30, 0.60);
    _rarestAnim = interval(0.35, 0.65);
    _deepestAnim = interval(0.38, 0.68);
    _timelineAnim = interval(0.42, 0.72);
    _galleryAnim = interval(0.50, 0.80);
    _merchAnim = interval(0.60, 1.00);

    _staggerCtrl.forward();
  }

  @override
  void dispose() {
    _staggerCtrl.dispose();
    _celebrationPlayer.dispose();
    super.dispose();
  }

  Widget _stagger(Animation<double> anim, Widget child) {
    return FadeTransition(
      opacity: anim,
      child: AnimatedBuilder(
        animation: anim,
        builder: (_, c) => Transform.translate(
          offset: Offset(0, 20 * (1 - anim.value)),
          child: c,
        ),
        child: child,
      ),
    );
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

    // Schedule a streak-at-risk reminder at 8pm today (no-op if already past).
    if (challengeAggregate != null && challengeAggregate.currentStreak > 0) {
      NotificationService.instance.scheduleStreakReminder(
        currentStreak: challengeAggregate.currentStreak,
      );
    }

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
              child: _stagger(
                _heroAnim,
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                  child: TravelProgressHero(
                    countryCount: countryCount,
                    unlockedIds: unlockedIds,
                    continentCount: continentCount,
                    tripCount: tripCount,
                    heritageCount: heritageCount,
                    visits: visits,
                  ),
                ),
              ),
            ),

            // ── Coloured animated stats grid ──────────────────────────────
            SliverToBoxAdapter(
              child: _stagger(
                _gridAnim,
                Padding(
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
            ),

            // ── Travel History Heatmap ────────────────────────────────────
            if (visits != null && visits.isNotEmpty)
              SliverToBoxAdapter(
                child: _stagger(
                  _heatmapAnim,
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    child: TravelHeatmapCard(visits: visits),
                  ),
                ),
              ),

            // ── Daily Challenge card ──────────────────────────────────────
            if (challengeAggregate != null)
              SliverToBoxAdapter(
                child: _stagger(
                  _challengeAnim,
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: DailyChallengeCard(aggregate: challengeAggregate),
                  ),
                ),
              ),

            // ── Year in Review ────────────────────────────────────────────
            if (thisYearCount > 0)
              SliverToBoxAdapter(
                child: _stagger(
                  _yearAnim,
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: YearInReviewCard(thisYearCount: thisYearCount),
                  ),
                ),
              ),

            // ── Next Achievements Carousel ────────────────────────────────
            SliverToBoxAdapter(
              child: _stagger(
                _carouselAnim,
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: NextAchievementsCarousel(
                    countryCount: countryCount,
                    continentCount: continentCount,
                    tripCount: tripCount,
                    thisYearCount: thisYearCount,
                    heritageCount: heritageCount,
                    unlockedIds: unlockedIds,
                  ),
                ),
              ),
            ),

            // ── Rarest Visits Badge ───────────────────────────────────────
            SliverToBoxAdapter(
              child: _stagger(
                _rarestAnim,
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  child: RarestVisitsCard(visits: visits),
                ),
              ),
            ),

            // ── Deepest Region Callout ────────────────────────────────────
            SliverToBoxAdapter(
              child: _stagger(
                _deepestAnim,
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  child: DeepestRegionCard(visits: visits),
                ),
              ),
            ),

            // ── Achievement Timeline ──────────────────────────────────────
            SliverToBoxAdapter(
              child: _stagger(
                _timelineAnim,
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: AchievementTimeline(
                    countryCount: countryCount,
                    unlockedIds: unlockedIds,
                  ),
                ),
              ),
            ),

            // ── Achievement Gallery ───────────────────────────────────────
            SliverToBoxAdapter(
              child: _stagger(
                _galleryAnim,
                Padding(
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
            ),

            // ── Merch Moments ─────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _stagger(
                _merchAnim,
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: MerchMomentsSection(unlockedById: unlockedById),
                ),
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
