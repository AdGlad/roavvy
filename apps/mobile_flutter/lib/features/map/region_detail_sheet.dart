import 'package:flutter/material.dart';
import 'package:shared_models/shared_models.dart';

import '../../core/country_names.dart';
import 'region_progress_notifier.dart';

// ── Region emoji flags ────────────────────────────────────────────────────────

const _kRegionEmoji = <Region, String>{
  Region.europe: '🌍',
  Region.asia: '🌏',
  Region.africa: '🌍',
  Region.northAmerica: '🌎',
  Region.southAmerica: '🌎',
  Region.oceania: '🌏',
};

// ── Public API ────────────────────────────────────────────────────────────────

/// Opens a bottom sheet showing region completion progress (ADR-072).
///
/// Lists countries in [data.region] split into visited and unvisited sections.
/// [visits] is the current effective visited country list — used to determine
/// which countries in the region have been visited.
void showRegionDetailSheet(
  BuildContext context,
  RegionProgressData data,
  List<EffectiveVisitedCountry> visits,
) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _RegionDetailSheetContent(data: data, visits: visits),
  );
}

// ── Sheet content ─────────────────────────────────────────────────────────────

class _RegionDetailSheetContent extends StatelessWidget {
  const _RegionDetailSheetContent({
    required this.data,
    required this.visits,
  });

  final RegionProgressData data;
  final List<EffectiveVisitedCountry> visits;

  @override
  Widget build(BuildContext context) {
    final visitedCodes = {for (final v in visits) v.countryCode};

    // Collect all countries in this region from kCountryContinent.
    final allInRegion = <String>[];
    for (final entry in kCountryContinent.entries) {
      final r = Region.fromContinentString(entry.value);
      if (r == data.region) {
        allInRegion.add(entry.key);
      }
    }
    allInRegion.sort();

    final visitedInRegion =
        allInRegion.where((c) => visitedCodes.contains(c)).toList();
    final unvisitedInRegion =
        allInRegion.where((c) => !visitedCodes.contains(c)).toList();

    final emoji = _kRegionEmoji[data.region] ?? '🌍';
    final remaining = data.remaining;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      builder: (context, scrollController) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 28)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data.region.displayName,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          '${data.visitedCount} of ${data.totalCount} countries',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // "One more" callout
            if (!data.isComplete && remaining > 0) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFB300).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFFFB300),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.flag_outlined,
                          color: Color(0xFFFF8F00), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          remaining == 1
                              ? 'Just 1 more country to complete ${data.region.displayName}!'
                              : 'You need $remaining more to complete ${data.region.displayName}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFFFF8F00),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            // Country lists
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  if (visitedInRegion.isNotEmpty) ...[
                    _SectionHeader(
                      label: 'Visited (${visitedInRegion.length})',
                      color: const Color(0xFF388E3C),
                    ),
                    const SizedBox(height: 4),
                    ...visitedInRegion.map((code) => _CountryTile(
                          code: code,
                          visited: true,
                        )),
                    const SizedBox(height: 16),
                  ],
                  if (unvisitedInRegion.isNotEmpty) ...[
                    _SectionHeader(
                      label: 'Not yet visited (${unvisitedInRegion.length})',
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(height: 4),
                    ...unvisitedInRegion.map((code) => _CountryTile(
                          code: code,
                          visited: false,
                        )),
                    const SizedBox(height: 24),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _CountryTile extends StatelessWidget {
  const _CountryTile({required this.code, required this.visited});

  final String code;
  final bool visited;

  @override
  Widget build(BuildContext context) {
    final name = kCountryNames[code] ?? code;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            visited ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 16,
            color: visited ? const Color(0xFF388E3C) : Colors.grey.shade400,
          ),
          const SizedBox(width: 8),
          Text(
            name,
            style: TextStyle(
              fontSize: 14,
              color: visited ? Colors.black87 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
