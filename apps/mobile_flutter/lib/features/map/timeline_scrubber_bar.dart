import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';

/// A timeline scrubber bar overlaid at the bottom of the map, above [StatsStrip].
///
/// Visible only when [yearFilterProvider] is non-null. Allows the user to drag
/// through years to see which countries they had visited by that year. A clear
/// button resets the filter. (ADR-076)
class TimelineScrubberBar extends ConsumerWidget {
  const TimelineScrubberBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final yearFilter = ref.watch(yearFilterProvider);
    if (yearFilter == null) return const SizedBox.shrink();

    final earliestAsync = ref.watch(earliestVisitYearProvider);
    final now = DateTime.now().year;

    final earliestYear = earliestAsync.valueOrNull ?? now;
    final min = earliestYear.toDouble();
    final max = now.toDouble();

    // Clamp the current value to valid range.
    final currentValue = yearFilter.clamp(earliestYear, now).toDouble();
    final divisions = (max - min).round();

    return Card(
      margin: EdgeInsets.zero,
      color: Colors.amber.withAlpha(217), // ~85% opacity amber
      shape: const RoundedRectangleBorder(),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Showing countries visited by $yearFilter',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        ref.read(yearFilterProvider.notifier).state = null,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: const Text('Clear'),
                  ),
                ],
              ),
              if (divisions > 0)
                Slider(
                  min: min,
                  max: max,
                  divisions: divisions,
                  value: currentValue,
                  activeColor: Colors.black87,
                  inactiveColor: Colors.black26,
                  label: yearFilter.toString(),
                  onChanged: (value) {
                    ref.read(yearFilterProvider.notifier).state =
                        value.round();
                  },
                )
              else
                // Only one year available — show a disabled slider.
                Slider(
                  min: min,
                  max: max + 1, // avoid division by zero
                  value: currentValue,
                  onChanged: null,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
