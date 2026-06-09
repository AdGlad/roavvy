import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_models/shared_models.dart';

import '../../core/providers.dart';
import '../../core/theme/roavvy_colours.dart';
import 'local_mockup_preview_screen.dart';
import 'merch_context.dart';
import 'merch_preset.dart';
import 'merch_exclusive_design.dart';
import 'merch_option_list_widgets.dart';
import 'travel_identity.dart';

/// T-shirt option selection screen entered from an unlocked achievement.
///
/// Reads [effectiveVisitsProvider] and [tripListProvider] directly so the
/// caller only needs to pass [achievement]. Delegates all scope resolution
/// and option generation to [MerchContext.fromAchievement] (ADR-150), which
/// produces achievement-type-specific [MerchOptionListItem]s.
///
/// Converges on [LocalMockupPreviewScreen] → [MerchOrderConfirmationScreen]
/// → Shopify checkout — the same downstream pipeline as [PulseMerchOptionScreen].
class AchievementMerchOptionScreen extends ConsumerStatefulWidget {
  const AchievementMerchOptionScreen({super.key, required this.achievement});

  final Achievement achievement;

  @override
  ConsumerState<AchievementMerchOptionScreen> createState() =>
      _AchievementMerchOptionScreenState();
}

class _AchievementMerchOptionScreenState
    extends ConsumerState<AchievementMerchOptionScreen> {
  bool _showAll = false;

  static String _subtitle(Achievement achievement) {
    // Continent-explorer achievements.
    if (achievement.continentScope != null) {
      return 'Celebrating ${achievement.progressTarget} countries'
          ' in ${achievement.continentScope}';
    }
    // Region achievements.
    if (achievement.regionScope != null) {
      return 'Celebrating ${achievement.progressTarget} countries'
          ' in the ${subRegionDisplayName(achievement.regionScope!)}';
    }
    // Passport stamp milestones.
    if (achievement.category == AchievementCategory.trips &&
        achievement.merch == MerchTriggerType.passportStamp) {
      final stamps = achievement.progressTarget * 2;
      return 'Celebrating $stamps passport stamps';
    }
    return switch (achievement.category) {
      AchievementCategory.countries when achievement.progressTarget == 1 =>
        'Celebrating your first country',
      AchievementCategory.countries =>
        'Celebrating ${achievement.progressTarget} countries visited',
      AchievementCategory.continents =>
        'Celebrating ${achievement.progressTarget} continents explored',
      AchievementCategory.trips =>
        'Celebrating ${achievement.progressTarget} trips logged',
      AchievementCategory.thisYear =>
        'Celebrating ${achievement.progressTarget} countries'
            ' in ${DateTime.now().year}',
      AchievementCategory.heritageSites =>
        'Celebrating UNESCO World Heritage Sites visited',
    };
  }

  @override
  Widget build(BuildContext context) {
    final visitsAsync = ref.watch(effectiveVisitsProvider);
    final tripsAsync = ref.watch(tripListProvider);

    if (visitsAsync.isLoading || tripsAsync.isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Your travel shirt ideas'),
          elevation: 0,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (visitsAsync.hasError || tripsAsync.hasError) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Your travel shirt ideas'),
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Could not load travel data'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  ref.invalidate(effectiveVisitsProvider);
                  ref.invalidate(tripListProvider);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: RoavvyColours.roavvyCoral,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final allVisits = visitsAsync.value ?? const [];
    final allTrips = tripsAsync.value ?? const [];

    final merchCtx = MerchContext.fromAchievement(
      achievement: widget.achievement,
      allVisits: allVisits,
      allTrips: allTrips,
    );
    final allItems = merchCtx.buildItems();
    final allCodes = merchCtx.allCodes;
    final subtitle = _subtitle(widget.achievement);
    final identity = merchCtx.identity;

    final featured =
        allItems.whereType<MerchOptionFeaturedEntry>().firstOrNull;
    final alternatives = allItems
        .whereType<MerchOptionEntry>()
        .take(4)
        .map((e) => e.option)
        .toList();

    final amoCs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your travel shirt ideas'),
        elevation: 0,
      ),
      body: CustomScrollView(
        slivers: [
          // Header (identity or subtitle)
          SliverToBoxAdapter(
            child:
                identity != null
                    ? _CelebrationHeader(identity: identity, subtitle: subtitle)
                    : Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Text(
                        subtitle,
                        style: TextStyle(
                          color: amoCs.onSurface.withValues(alpha: 0.54),
                          fontSize: 13,
                        ),
                      ),
                    ),
          ),

          // Featured card
          if (featured != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: MerchOptionFeaturedCard(
                  option: featured.option,
                  allCodes: allCodes,
                ),
              ),
            ),

          // Alternatives strip
          if (alternatives.isNotEmpty) ...[
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(left: 16, bottom: 6),
                child: Text(
                  'OTHER STYLES',
                  style: TextStyle(
                    color: amoCs.onSurface.withValues(alpha: 0.38),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: MerchOptionAlternativesStrip(
                options: alternatives,
                allCodes: allCodes,
              ),
            ),
          ],

          // "See all styles" toggle
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: TextButton(
                onPressed:
                    _showAll ? null : () => setState(() => _showAll = true),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerLeft,
                ),
                child: Text(
                  _showAll ? 'All styles' : 'See all styles ›',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
          ),

          // Full list (shown when _showAll)
          if (_showAll) ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              sliver: SliverList.separated(
                itemCount: allItems.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) {
                  final item = allItems[i];
                  return switch (item) {
                    MerchOptionHeaderItem() =>
                      MerchOptionSectionHeader(item.label),
                    MerchOptionFeaturedEntry() => MerchOptionFeaturedCard(
                      option: item.option,
                      allCodes: allCodes,
                    ),
                    MerchOptionEntry() => MerchOptionCard(
                      option: item.option,
                      allCodes: allCodes,
                      index: i,
                    ),
                    MerchOptionCustomiseEntry() => MerchOptionCustomCard(
                      template: item.template,
                      label: item.label,
                    ),
                  };
                },
              ),
            ),
            SliverToBoxAdapter(
              child: _ExclusiveDesignsSectionAchievement(
                allVisits: allVisits,
                allTrips: allTrips,
              ),
            ),
          ] else
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }
}

// ── Exclusive designs section ─────────────────────────────────────────────────

/// Shows near-miss locked designs and any already-unlocked exclusive designs
/// at the bottom of the expanded style list (M144).
class _ExclusiveDesignsSectionAchievement extends StatelessWidget {
  const _ExclusiveDesignsSectionAchievement({
    required this.allVisits,
    required this.allTrips,
  });

  final List<EffectiveVisitedCountry> allVisits;
  final List<TripRecord> allTrips;

  MerchUnlockContext _buildCtx() {
    final continentCount = allVisits
        .map((v) => kCountryContinent[v.countryCode])
        .whereType<String>()
        .toSet()
        .length;
    return MerchUnlockContext(
      countryCount: allVisits.length,
      continentCount: continentCount,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctx = _buildCtx();
    const nearMissThreshold = 15;

    final toShow = kMerchExclusiveDesigns.where((d) {
      if (d.isUnlocked(ctx)) return true;
      final rem = d.remaining(ctx);
      return rem > 0 && rem <= nearMissThreshold;
    }).toList();

    if (toShow.isEmpty) return const SizedBox(height: 40);

    final allCodes = allVisits.map((v) => v.countryCode).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(
            height: 1,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12),
          ),
          const SizedBox(height: 12),
          Text(
            'EXCLUSIVE DESIGNS',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          ...toShow.map(
            (d) => MerchLockedDesignCard(
              design: d,
              ctx: ctx,
              onUnlockedTap: d.isUnlocked(ctx)
                  ? () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder:
                              (_) => LocalMockupPreviewScreen(
                                selectedCodes: allCodes,
                                allCodes: allCodes,
                                trips: allTrips,
                                initialTemplate: d.template,
                                initialPreset: MerchPreset(
                                  id: 'exclusive_design',
                                  label: d.label,
                                  config: MerchPresetConfig(
                                    layout: d.template,
                                    source: MerchCountrySource.allTime,
                                    jitter: 0.4,
                                    density: MerchDensity.balanced,
                                    stampMode: MerchStampMode.entryExit,
                                  ),
                                ),
                              ),
                        ),
                      )
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// Animated header showing the resolved [TravelIdentityInfo] (ADR-155).
///
/// Displays the identity emoji with a scale-in animation, identity display
/// name in gold, and the identity tagline below the achievement subtitle.
class _CelebrationHeader extends StatelessWidget {
  const _CelebrationHeader({required this.identity, required this.subtitle});

  final TravelIdentityInfo identity;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.4, end: 1.0),
            duration: const Duration(milliseconds: 500),
            curve: Curves.elasticOut,
            builder:
                (_, value, child) =>
                    Transform.scale(scale: value, child: child),
            child: Text(identity.emoji, style: const TextStyle(fontSize: 36)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  identity.displayName,
                  style: const TextStyle(
                    color: Color(0xFFFFD700),
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
                    fontSize: 12,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  identity.tagline,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
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
