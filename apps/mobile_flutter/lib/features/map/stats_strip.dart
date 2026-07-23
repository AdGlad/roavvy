import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../stats/countries_list_screen.dart';

/// Compact travel stats rendered as a text overlay at the top-left of the
/// map area (countries / first visit / latest visit / trips), freeing the
/// vertical space the old bottom stats bar used to occupy.
///
/// Watches [filteredEffectiveVisitsProvider] for the country count (so it
/// respects the year filter) and [tripCountProvider] for the trip count.
/// The Countries row is tappable → [CountriesListScreen].
///
/// Renders nothing ([SizedBox.shrink]) while loading or on error.
class StatsStrip extends ConsumerWidget {
  const StatsStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(travelSummaryProvider);
    final countryCount =
        (ref.watch(filteredEffectiveVisitsProvider).valueOrNull ?? []).length;
    final tripCount = ref.watch(tripCountProvider).valueOrNull ?? 0;

    return summaryAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (summary) {
        final earliest = summary.earliestVisit?.year.toString() ?? '—';
        final latest = summary.latestVisit?.year.toString() ?? '—';

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StatRow(
              value: countryCount.toString(),
              label: 'Countries',
              onTap: () {
                final visits =
                    ref.read(effectiveVisitsProvider).valueOrNull ?? [];
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => CountriesListScreen(visits: visits),
                  ),
                );
              },
            ),
            _StatRow(value: earliest, label: 'First visit'),
            _StatRow(value: latest, label: 'Latest visit'),
            _StatRow(value: tripCount.toString(), label: 'Trips'),
          ],
        );
      },
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.value, required this.label, this.onTap});

  final String value;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0B2438);
    // Soft counter-shadow keeps the bare text legible over any map colour.
    final shadows = [
      Shadow(
        color: isDark ? Colors.black87 : Colors.white,
        blurRadius: 4,
      ),
    ];

    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            value,
            style: TextStyle(
              color: textColor,
              fontSize: 15,
              fontWeight: FontWeight.bold,
              shadows: shadows,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: textColor.withValues(alpha: 0.75),
              fontSize: 11,
              shadows: shadows,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return row;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: row,
    );
  }
}
