import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../stats/countries_list_screen.dart';

/// A slim stats bar overlaid at the bottom of the map.
///
/// Watches [filteredEffectiveVisitsProvider] for the country count (so it
/// respects the year filter) and [tripCountProvider] for the trip count.
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

        final bottomInset = MediaQuery.paddingOf(context).bottom;
        final stripTheme = Theme.of(context);
        final stripIsDark = stripTheme.brightness == Brightness.dark;
        return Container(
          color:
              stripIsDark
                  ? const Color(0xFF0D2137).withValues(alpha: 0.88)
                  : stripTheme.colorScheme.surface.withValues(alpha: 0.96),
          padding: EdgeInsets.fromLTRB(16, 8, 16, 8 + bottomInset),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _Stat(
                label: 'Countries',
                value: countryCount.toString(),
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
              _Stat(label: 'First visit', value: earliest),
              _Stat(label: 'Latest visit', value: latest),
              _Stat(label: 'Trips', value: tripCount.toString()),
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
    final cs = Theme.of(context).colorScheme;
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            color: cs.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: cs.onSurface.withValues(alpha: 0.70), fontSize: 11),
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
          color: cs.onSurface.withValues(alpha: 0.08),
        ),
        child: content,
      ),
    );
  }
}
