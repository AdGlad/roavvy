import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';

/// A slim stats bar overlaid at the bottom of the map.
///
/// Watches [travelSummaryProvider] and renders:
/// - country count
/// - earliest visit year → latest visit year (or "—" when absent)
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
              ),
              _Stat(label: 'First visit', value: earliest),
              _Stat(label: 'Latest visit', value: latest),
              _Stat(
                label: 'Achievements',
                value: '🏆 ${summary.achievementCount}',
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
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
  }
}
