import 'package:flutter/material.dart';
import 'package:shared_models/shared_models.dart';

import '../../merch/merch_country_selection_screen.dart';

/// Tabbed achievement gallery for the Stats screen (M97, ADR-148).
///
/// Tabs: Countries | Continents | Trips | All.
/// Unlocked rows: gold accent, trophy icon, unlock date, optional merch CTA.
/// Locked rows: dimmed, lock icon, LinearProgressIndicator.
class AchievementGallery extends StatelessWidget {
  const AchievementGallery({
    super.key,
    required this.unlockedById,
    required this.countryCount,
    required this.continentCount,
    required this.tripCount,
    required this.thisYearCount,
  });

  final Map<String, DateTime> unlockedById;
  final int countryCount;
  final int continentCount;
  final int tripCount;
  final int thisYearCount;

  int _currentProgress(Achievement a) => switch (a.category) {
        AchievementCategory.countries => countryCount,
        AchievementCategory.continents => continentCount,
        AchievementCategory.trips => tripCount,
        AchievementCategory.thisYear => thisYearCount,
      };

  List<Achievement> _forCategory(AchievementCategory cat) =>
      kAchievements.where((a) => a.category == cat).toList();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Text(
              'Achievements',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Countries'),
              Tab(text: 'Continents'),
              Tab(text: 'Trips'),
              Tab(text: 'All'),
            ],
          ),
          SizedBox(
            height: 320,
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
    final unlocked = achievements
        .where((a) => unlockedById.containsKey(a.id))
        .toList()
      ..sort((a, b) => unlockedById[b.id]!.compareTo(unlockedById[a.id]!));
    final locked = achievements.where((a) => !unlockedById.containsKey(a.id)).toList();
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
  });

  final Achievement achievement;
  final DateTime? unlockDate;
  final int current;

  bool get isUnlocked => unlockDate != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Opacity(
      opacity: isUnlocked ? 1.0 : 0.55,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: isUnlocked ? const Color(0xFFFFF8E1) : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
          border: isUnlocked
              ? const Border(left: BorderSide(color: Color(0xFFFFB300), width: 3))
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
                    isUnlocked ? Icons.emoji_events_outlined : Icons.lock_outline,
                    size: 20,
                    color: isUnlocked ? Colors.amber[700] : theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      achievement.title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isUnlocked ? null : theme.colorScheme.onSurfaceVariant,
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
                  child: Text(
                    _fmtDate(unlockDate!),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                )
              else ...[
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: (current / achievement.progressTarget).clamp(0.0, 1.0),
                  minHeight: 4,
                  borderRadius: BorderRadius.circular(2),
                  backgroundColor: theme.colorScheme.outline.withValues(alpha: 0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
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
    );
  }

  String _fmtDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return 'Unlocked ${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }
}

class _MerchChip extends StatelessWidget {
  const _MerchChip({required this.achievement});

  final Achievement achievement;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const MerchCountrySelectionScreen(),
        ),
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: Theme.of(context).textTheme.labelSmall,
        side: BorderSide(color: Theme.of(context).colorScheme.primary),
      ),
      child: const Text('Make tee'),
    );
  }
}
