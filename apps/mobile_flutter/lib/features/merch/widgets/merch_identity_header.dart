import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers.dart';
import '../travel_identity.dart';

/// Compact header shown at the top of the Shop tab (M145, ADR-177).
///
/// Displays the user's resolved [TravelIdentity] emoji + name, plus live
/// travel stats (country count · continent count · since [year]).
class MerchIdentityHeader extends ConsumerWidget {
  const MerchIdentityHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visitsAsync = ref.watch(effectiveVisitsProvider);
    final continentCountAsync = ref.watch(continentCountProvider);
    final tripsAsync = ref.watch(tripListProvider);
    final earliestYearAsync = ref.watch(earliestVisitYearProvider);

    final visits = visitsAsync.valueOrNull ?? const [];
    final continentCount = continentCountAsync.valueOrNull ?? 0;
    final trips = tripsAsync.valueOrNull ?? const [];
    final earliestYear = earliestYearAsync.valueOrNull;

    final codes = visits.map((v) => v.countryCode).toList();
    final identity = TravelIdentityInfo.forContext(
      codes: codes,
      tripCount: trips.length,
      stampCount: trips.length * 2,
    );

    final isLoading =
        visitsAsync.isLoading ||
        continentCountAsync.isLoading ||
        tripsAsync.isLoading;

    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF0E1A2B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: isLoading
            ? const _ShimmerRow()
            : Row(
                children: [
                  Text(
                    identity.emoji,
                    style: const TextStyle(fontSize: 28),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        identity.displayName,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: const Color(0xFFFFD700),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _statsLabel(
                          countryCount: visits.length,
                          continentCount: continentCount,
                          since: earliestYear,
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white54,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  String _statsLabel({
    required int countryCount,
    required int continentCount,
    int? since,
  }) {
    final parts = <String>[
      '$countryCount ${countryCount == 1 ? "country" : "countries"}',
      if (continentCount > 0)
        '$continentCount ${continentCount == 1 ? "continent" : "continents"}',
      if (since != null) 'since $since',
    ];
    return parts.join(' · ');
  }
}

class _ShimmerRow extends StatelessWidget {
  const _ShimmerRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: Colors.white12,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 100,
              height: 12,
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 160,
              height: 10,
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
