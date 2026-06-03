import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_models/shared_models.dart';

import '../../../core/country_names.dart';
import '../../../core/providers.dart';
import '../../../core/theme/roavvy_colours.dart';
import '../../challenge/daily_challenge_stats.dart';
import '../../merch/achievement_merch_option_screen.dart';

/// Tabbed achievement gallery for the Stats screen (M97, ADR-148).
///
/// Tabs: Countries | Continents | Trips | UNESCO | All.
/// Unlocked rows: gold accent, trophy icon, unlock date, optional merch CTA.
/// Locked rows: dimmed, lock icon, LinearProgressIndicator.
class AchievementGallery extends ConsumerWidget {
  const AchievementGallery({
    super.key,
    required this.unlockedById,
    required this.countryCount,
    required this.continentCount,
    required this.tripCount,
    required this.thisYearCount,
    required this.heritageCount,
  });

  final Map<String, DateTime> unlockedById;
  final int countryCount;
  final int continentCount;
  final int tripCount;
  final int thisYearCount;
  final int heritageCount;

  int _currentProgress(Achievement a) => switch (a.category) {
    AchievementCategory.countries => countryCount,
    AchievementCategory.continents => continentCount,
    AchievementCategory.trips => tripCount,
    AchievementCategory.thisYear => thisYearCount,
    AchievementCategory.heritageSites => heritageCount,
  };

  List<Achievement> _forCategory(AchievementCategory cat) =>
      kAchievements.where((a) => a.category == cat).toList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final challengeAggregate =
        ref.watch(challengeAggregateProvider).valueOrNull;

    return DefaultTabController(
      length: 5,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Text(
              'Achievements',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Countries'),
              Tab(text: 'Continents'),
              Tab(text: 'Trips'),
              Tab(text: 'UNESCO'),
              Tab(text: 'All'),
            ],
          ),
          SizedBox(
            height: 380,
            child: TabBarView(
              children: [
                _AchievementList(
                  achievements: _forCategory(AchievementCategory.countries),
                  unlockedById: unlockedById,
                  currentProgress: _currentProgress,
                ),
                _AchievementList(
                  achievements: _forCategory(AchievementCategory.continents),
                  unlockedById: unlockedById,
                  currentProgress: _currentProgress,
                ),
                _AchievementList(
                  achievements: _forCategory(AchievementCategory.trips),
                  unlockedById: unlockedById,
                  currentProgress: _currentProgress,
                ),
                _UnescoTab(
                  heritageCount: heritageCount,
                  unlockedById: unlockedById,
                  currentProgress: _currentProgress,
                  challengeAggregate: challengeAggregate,
                ),
                _AchievementList(
                  achievements: kAchievements,
                  unlockedById: unlockedById,
                  currentProgress: _currentProgress,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── UNESCO tab ────────────────────────────────────────────────────────────────

class _UnescoTab extends ConsumerWidget {
  const _UnescoTab({
    required this.heritageCount,
    required this.unlockedById,
    required this.currentProgress,
    required this.challengeAggregate,
  });

  final int heritageCount;
  final Map<String, DateTime> unlockedById;
  final int Function(Achievement) currentProgress;
  final ChallengeAggregate? challengeAggregate;

  void _showContributingSites(
    BuildContext context,
    Achievement a,
    List<VisitedHeritageSite> allVisited,
  ) {
    // Sort by firstSeen so the user sees the chronological journey.
    final sorted = [...allVisited]..sort((x, y) {
      return x.firstSeen.compareTo(y.firstSeen);
    });
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _HeritageContributorsSheet(achievement: a, sites: sorted),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final visitedSites =
        ref.watch(visitedHeritageProvider).valueOrNull ?? const [];
    final whsAchievements =
        kAchievements
            .where((a) => a.category == AchievementCategory.heritageSites)
            .toList();
    final agg = challengeAggregate;

    return ListView(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      children: [
        // ── Challenge stats card ──────────────────────────────────────────
        if (agg != null) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              'Daily Challenge',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _ChallengeStatCell(
                    label: 'Streak',
                    value:
                        agg.currentStreak == 0 ? '—' : '${agg.currentStreak}',
                    icon: Icons.local_fire_department,
                    iconColor:
                        agg.currentStreak >= 2
                            ? Colors.orange
                            : theme.colorScheme.onSurfaceVariant,
                  ),
                  _ChallengeStatCell(
                    label: 'Best',
                    value: agg.bestStreak == 0 ? '—' : '${agg.bestStreak}',
                    icon: Icons.emoji_events_outlined,
                    iconColor: RoavvyColours.roavvyGold,
                  ),
                  _ChallengeStatCell(
                    label: 'Solved',
                    value:
                        agg.totalPlayed == 0
                            ? '—'
                            : '${(agg.totalSolved / agg.totalPlayed * 100).round()}%',
                    icon: Icons.check_circle_outline,
                    iconColor: Colors.green,
                  ),
                  _ChallengeStatCell(
                    label: 'Avg clues',
                    value:
                        agg.totalSolved == 0
                            ? '—'
                            : agg.avgClues.toStringAsFixed(1),
                    icon: Icons.lightbulb_outline,
                    iconColor: Colors.amber,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // ── Heritage site achievements ────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Text(
            'Heritage Sites  ·  $heritageCount visited',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        for (final a in whsAchievements)
          _AchievementRow(
            achievement: a,
            unlockDate: unlockedById[a.id],
            current: currentProgress(a),
            onTap:
                unlockedById.containsKey(a.id) && visitedSites.isNotEmpty
                    ? () => _showContributingSites(context, a, visitedSites)
                    : null,
          ),
      ],
    );
  }
}

class _ChallengeStatCell extends StatelessWidget {
  const _ChallengeStatCell({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _AchievementList extends StatelessWidget {
  const _AchievementList({
    required this.achievements,
    required this.unlockedById,
    required this.currentProgress,
  });

  final List<Achievement> achievements;
  final Map<String, DateTime> unlockedById;
  final int Function(Achievement) currentProgress;

  @override
  Widget build(BuildContext context) {
    final unlocked =
        achievements.where((a) => unlockedById.containsKey(a.id)).toList()
          ..sort((a, b) => unlockedById[b.id]!.compareTo(unlockedById[a.id]!));
    final locked =
        achievements.where((a) => !unlockedById.containsKey(a.id)).toList();
    final items = [...unlocked, ...locked];

    return ListView.builder(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final a = items[index];
        final unlockDate = unlockedById[a.id];
        return _AchievementRow(
          achievement: a,
          unlockDate: unlockDate,
          current: currentProgress(a),
        );
      },
    );
  }
}

class _AchievementRow extends StatelessWidget {
  const _AchievementRow({
    required this.achievement,
    required this.unlockDate,
    required this.current,
    this.onTap,
  });

  final Achievement achievement;
  final DateTime? unlockDate;
  final int current;
  final VoidCallback? onTap;

  bool get isUnlocked => unlockDate != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Opacity(
      opacity: isUnlocked ? 1.0 : 0.55,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color:
                isUnlocked
                    ? RoavvyColours.roavvyGold.withOpacity(0.12)
                    : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
            border:
                isUnlocked
                    ? const Border(
                      left: BorderSide(
                        color: RoavvyColours.roavvyGold,
                        width: 3,
                      ),
                    )
                    : null,
            boxShadow:
                isUnlocked
                    ? [
                      BoxShadow(
                        color: RoavvyColours.roavvyGold.withOpacity(0.35),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ]
                    : null,
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isUnlocked
                          ? Icons.emoji_events_outlined
                          : Icons.lock_outline,
                      size: 20,
                      color:
                          isUnlocked
                              ? RoavvyColours.roavvyGold
                              : theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        achievement.title,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color:
                              isUnlocked
                                  ? null
                                  : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    if (isUnlocked && achievement.merch != null)
                      _MerchChip(achievement: achievement),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  achievement.description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (isUnlocked)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Text(
                          _fmtDate(unlockDate!),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        if (onTap != null) ...[
                          const Spacer(),
                          Text(
                            'See sites →',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  )
                else ...[
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: (current / achievement.progressTarget).clamp(
                      0.0,
                      1.0,
                    ),
                    minHeight: 4,
                    borderRadius: BorderRadius.circular(2),
                    backgroundColor: theme.colorScheme.outline.withValues(
                      alpha: 0.2,
                    ),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$current / ${achievement.progressTarget}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _fmtDate(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return 'Unlocked ${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }
}

// ── Heritage contributors sheet ───────────────────────────────────────────────

/// Bottom sheet listing the visited heritage sites that earned a [Achievement].
class _HeritageContributorsSheet extends StatelessWidget {
  const _HeritageContributorsSheet({
    required this.achievement,
    required this.sites,
  });

  final Achievement achievement;
  final List<VisitedHeritageSite> sites;

  static String _flag(String iso) {
    if (iso.length != 2) return '';
    const base = 0x1F1E6;
    return String.fromCharCode(base + iso.codeUnitAt(0) - 65) +
        String.fromCharCode(base + iso.codeUnitAt(1) - 65);
  }

  static String _fmtDate(DateTime dt) {
    const m = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${m[dt.month - 1]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Only the sites that contributed to this specific achievement tier count.
    // All visited sites count — cap list at achievement target for display.
    final display = sites.take(achievement.progressTarget).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.4,
      maxChildSize: 0.85,
      builder:
          (ctx, scrollCtrl) => Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Header
                Row(
                  children: [
                    const Icon(
                      Icons.emoji_events_outlined,
                      color: RoavvyColours.roavvyGold,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        achievement.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${sites.length} heritage site${sites.length == 1 ? '' : 's'} visited',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 8),
                // Site list
                for (final site in display)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _flag(site.countryCode),
                          style: const TextStyle(fontSize: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                site.name,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${kCountryNames[site.countryCode] ?? site.countryCode} · '
                                'First visited ${_fmtDate(site.firstSeen)}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                if (sites.length > achievement.progressTarget) ...[
                  const Divider(height: 24),
                  Text(
                    '+ ${sites.length - achievement.progressTarget} more visited site'
                    '${(sites.length - achievement.progressTarget) == 1 ? '' : 's'}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
    );
  }
}

class _MerchChip extends StatelessWidget {
  const _MerchChip({required this.achievement});

  final Achievement achievement;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed:
          () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder:
                  (_) => AchievementMerchOptionScreen(achievement: achievement),
            ),
          ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: Theme.of(context).textTheme.labelSmall,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: const BorderSide(color: RoavvyColours.roavvyCoral),
      ),
      child: const Text('Make tee'),
    );
  }
}
