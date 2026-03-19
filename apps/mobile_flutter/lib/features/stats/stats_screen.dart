import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_models/shared_models.dart';

import '../../core/providers.dart';
import '../../data/db/roavvy_database.dart';
import '../scan/achievement_unlock_sheet.dart';

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _fmtUnlockDate(DateTime dt) {
  final m = _months[dt.month - 1];
  return 'Unlocked ${dt.day} $m ${dt.year}';
}

/// Travel stats and achievement gallery screen.
///
/// Entry point: Stats tab (index 2).
/// Watches three async providers for stats panel values — displays "—" as a
/// fallback while any value is still loading; no spinner (Design Principle 3).
/// Reads all [UnlockedAchievementRow]s via [achievementRepositoryProvider] for
/// the achievement gallery unlock dates (ADR-052, Decision 3).
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
    _achievementsFuture =
        ref.read(achievementRepositoryProvider).loadAllRows();
  }

  @override
  Widget build(BuildContext context) {
    final visitsAsync = ref.watch(effectiveVisitsProvider);
    final summaryAsync = ref.watch(travelSummaryProvider);
    final regionCountAsync = ref.watch(regionCountProvider);

    final countryCount =
        visitsAsync.whenOrNull(data: (v) => v.length.toString()) ?? '—';
    final regionCount =
        regionCountAsync.whenOrNull(data: (n) => n.toString()) ?? '—';
    final sinceYear = summaryAsync.whenOrNull(
          data: (s) => s.earliestVisit?.year.toString(),
        ) ??
        '—';

    return FutureBuilder<List<UnlockedAchievementRow>>(
      future: _achievementsFuture,
      builder: (context, snapshot) {
        final achievementRows = snapshot.data ?? const [];
        final unlockedById = {
          for (final r in achievementRows) r.achievementId: r.unlockedAt,
        };

        return CustomScrollView(
          slivers: [
            const SliverAppBar(
              title: Text('Stats'),
              floating: true,
              snap: true,
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _StatsPanel(
                  countryCount: countryCount,
                  regionCount: regionCount,
                  sinceYear: sinceYear,
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
                child: Text(
                  'Achievements',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            _AchievementGrid(unlockedById: unlockedById),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
          ],
        );
      },
    );
  }
}

// ── Stats panel ───────────────────────────────────────────────────────────────

class _StatsPanel extends StatelessWidget {
  const _StatsPanel({
    required this.countryCount,
    required this.regionCount,
    required this.sinceYear,
  });

  final String countryCount;
  final String regionCount;
  final String sinceYear;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Semantics(
            label: '$countryCount countries visited',
            excludeSemantics: true,
            child: _StatTile(value: countryCount, label: 'Countries'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Semantics(
            label: '$regionCount regions visited',
            excludeSemantics: true,
            child: _StatTile(value: regionCount, label: 'Regions'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Semantics(
            label: sinceYear == '—'
                ? 'No travel data yet'
                : 'Travelling since $sinceYear',
            excludeSemantics: true,
            child: _StatTile(value: sinceYear, label: 'Since'),
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: theme.textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Achievement gallery ───────────────────────────────────────────────────────

class _AchievementGrid extends StatelessWidget {
  const _AchievementGrid({required this.unlockedById});

  final Map<String, DateTime> unlockedById;

  @override
  Widget build(BuildContext context) {
    // Unlocked achievements sorted by unlock date descending, then locked.
    final unlocked = kAchievements
        .where((a) => unlockedById.containsKey(a.id))
        .toList()
      ..sort((a, b) => unlockedById[b.id]!.compareTo(unlockedById[a.id]!));

    final locked = kAchievements
        .where((a) => !unlockedById.containsKey(a.id))
        .toList();

    final items = [...unlocked, ...locked];

    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.1,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final achievement = items[index];
          final unlockDate = unlockedById[achievement.id];
          return Padding(
            padding: EdgeInsets.only(
              left: index.isEven ? 16 : 0,
              right: index.isOdd ? 16 : 0,
            ),
            child: _AchievementCard(
              achievement: achievement,
              unlockedAt: unlockDate,
              onTap: unlockDate == null
                  ? null
                  : () => AchievementUnlockSheet.show(
                        context,
                        achievement: achievement,
                        unlockedAt: unlockDate,
                      ),
            ),
          );
        },
        childCount: items.length,
      ),
    );
  }
}

class _AchievementCard extends StatelessWidget {
  const _AchievementCard({
    required this.achievement,
    required this.unlockedAt,
    this.onTap,
  });

  final Achievement achievement;
  final DateTime? unlockedAt;
  final VoidCallback? onTap;

  bool get isUnlocked => unlockedAt != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = theme.colorScheme.onSurfaceVariant;

    final semanticLabel = [
      achievement.title,
      achievement.description,
      isUnlocked
          ? _fmtUnlockDate(unlockedAt!)
          : 'Not yet unlocked',
    ].join('. ');

    final card = Container(
      decoration: BoxDecoration(
        color: isUnlocked
            ? const Color(0xFFFFF8E1) // amber/gold tint
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isUnlocked
                ? Icons.emoji_events_outlined
                : Icons.lock_outline,
            size: 28,
            color: isUnlocked ? Colors.amber[700] : secondary,
          ),
          const Spacer(),
          Text(
            achievement.title,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: isUnlocked ? null : secondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            achievement.description,
            style: theme.textTheme.bodySmall?.copyWith(color: secondary),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (isUnlocked) ...[
            const SizedBox(height: 4),
            Text(
              _fmtUnlockDate(unlockedAt!),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ],
      ),
    );

    final cardWithOpacity =
        isUnlocked ? card : Opacity(opacity: 0.55, child: card);

    return Semantics(
      label: semanticLabel,
      child: onTap == null
          ? cardWithOpacity
          : GestureDetector(
              onTap: onTap,
              child: cardWithOpacity,
            ),
    );
  }
}
