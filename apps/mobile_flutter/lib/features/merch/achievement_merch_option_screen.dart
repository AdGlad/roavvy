import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_models/shared_models.dart';

import '../../core/providers.dart';
import 'merch_context.dart';
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
class AchievementMerchOptionScreen extends ConsumerWidget {
  const AchievementMerchOptionScreen({
    super.key,
    required this.achievement,
  });

  final Achievement achievement;

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
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visitsAsync = ref.watch(effectiveVisitsProvider);
    final tripsAsync = ref.watch(tripListProvider);

    if (visitsAsync.isLoading || tripsAsync.isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF0D1B2A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0D1B2A),
          foregroundColor: Colors.white,
          title: const Text('Your travel shirt ideas'),
          elevation: 0,
        ),
        body: const Center(
          child: CircularProgressIndicator(color: Colors.white38),
        ),
      );
    }

    if (visitsAsync.hasError || tripsAsync.hasError) {
      return Scaffold(
        backgroundColor: const Color(0xFF0D1B2A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0D1B2A),
          foregroundColor: Colors.white,
          title: const Text('Your travel shirt ideas'),
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Could not load travel data',
                style: TextStyle(color: Colors.white54),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  ref.invalidate(effectiveVisitsProvider);
                  ref.invalidate(tripListProvider);
                },
                child: const Text(
                  'Retry',
                  style: TextStyle(color: Colors.amber),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final allVisits = visitsAsync.value ?? const [];
    final allTrips = tripsAsync.value ?? const [];

    final merchCtx = MerchContext.fromAchievement(
      achievement: achievement,
      allVisits: allVisits,
      allTrips: allTrips,
    );
    final items = merchCtx.buildItems();
    final allCodes = merchCtx.allCodes;
    final subtitle = _subtitle(achievement);

    final identity = merchCtx.identity;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1B2A),
        foregroundColor: Colors.white,
        title: const Text('Your travel shirt ideas'),
        elevation: 0,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (identity != null)
            _CelebrationHeader(identity: identity, subtitle: subtitle)
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Text(
                subtitle,
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final item = items[i];
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
  const _CelebrationHeader({
    required this.identity,
    required this.subtitle,
  });

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
            builder: (_, value, child) =>
                Transform.scale(scale: value, child: child),
            child: Text(
              identity.emoji,
              style: const TextStyle(fontSize: 36),
            ),
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
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  identity.tagline,
                  style: const TextStyle(
                    color: Colors.white38,
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
