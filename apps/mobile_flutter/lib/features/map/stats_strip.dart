import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../stats/achievements_screen.dart';
import '../stats/countries_list_screen.dart';

/// A slim stats bar overlaid at the bottom of the map.
///
/// Watches [travelSummaryProvider] and renders:
/// - country count (tappable → CountriesListScreen)
/// - earliest → latest visit year
/// - achievements count (tappable → StatsScreen)
///
/// Renders nothing ([SizedBox.shrink]) while loading or on error.
class StatsStrip extends ConsumerWidget {
  const StatsStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(travelSummaryProvider);

    return summaryAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (summary) {
        final earliest = summary.earliestVisit?.year.toString() ?? '—';
        final latest = summary.latestVisit?.year.toString() ?? '—';

        final bottomInset = MediaQuery.paddingOf(context).bottom;
        return Container(
          color: const Color(0xFF0D2137).withValues(alpha: 0.88), // ADR-080
          padding: EdgeInsets.fromLTRB(16, 8, 16, 8 + bottomInset),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _Stat(
                label: 'Countries',
                value: summary.countryCount.toString(),
                onTap: () {
                  final visits = ref.read(effectiveVisitsProvider).valueOrNull ?? [];
                  Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => CountriesListScreen(visits: visits),
                  ));
                },
              ),
              _Stat(label: 'First visit', value: earliest),
              _Stat(label: 'Latest visit', value: latest),
              _Stat(
                label: 'Achievements',
                value: '🏆 ${summary.achievementCount}',
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => const AchievementsScreen(),
                )),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.onTap});

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
      ],
    );
    if (onTap == null) return content;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.white.withValues(alpha: 0.08),
        ),
        child: content,
      ),
    );
  }
}
