import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_models/shared_models.dart';

import '../../core/country_names.dart';
import '../../core/providers.dart';
import '../../core/region_names.dart';
import '../map/country_region_map_screen.dart';

/// Converts an ISO 3166-1 alpha-2 code to its flag emoji.
String _flag(String code) {
  if (code.length != 2) return '';
  const base = 0x1F1E6;
  return String.fromCharCode(base + code.codeUnitAt(0) - 65) +
      String.fromCharCode(base + code.codeUnitAt(1) - 65);
}

/// A draggable bottom sheet showing all detected regions grouped by country.
///
/// Opened from the Stats screen by tapping the "Regions" stat tile (ADR-082).
class RegionBreakdownSheet extends ConsumerWidget {
  const RegionBreakdownSheet({super.key});

  /// Convenience helper — opens this sheet as a modal bottom sheet.
  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => const RegionBreakdownSheet(),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                'Regions visited',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: _RegionList(scrollController: scrollController),
            ),
          ],
        );
      },
    );
  }
}

class _RegionList extends ConsumerWidget {
  const _RegionList({required this.scrollController});

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final secondary = theme.colorScheme.onSurfaceVariant;

    // Load all region visits asynchronously.
    return FutureBuilder<List<RegionVisit>>(
      future: ref.read(regionRepositoryProvider).loadAll(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        final allVisits = snapshot.data ?? const [];

        if (allVisits.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No regions detected yet.\nScan your photos to see a breakdown.',
                style: theme.textTheme.bodyMedium?.copyWith(color: secondary),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        // Group by country code, deduplicate region codes per country.
        final byCountry = <String, Set<String>>{};
        for (final v in allVisits) {
          byCountry.putIfAbsent(v.countryCode, () => {}).add(v.regionCode);
        }

        // Sort countries by display name.
        final sortedCountries = byCountry.keys.toList()
          ..sort((a, b) {
            final na = kCountryNames[a] ?? a;
            final nb = kCountryNames[b] ?? b;
            return na.compareTo(nb);
          });

        return ListView.builder(
          controller: scrollController,
          itemCount: sortedCountries.length,
          itemBuilder: (context, i) {
            final code = sortedCountries[i];
            final regionCodes = byCountry[code]!.toList()
              ..sort((a, b) {
                final na = kRegionNames[a] ?? a;
                final nb = kRegionNames[b] ?? b;
                return na.compareTo(nb);
              });
            final countryName = kCountryNames[code] ?? code;
            final flag = _flag(code);
            final regionWord =
                regionCodes.length == 1 ? 'region' : 'regions';

            return ExpansionTile(
              leading: Text(flag, style: const TextStyle(fontSize: 24)),
              title: Text(countryName,
                  style: theme.textTheme.bodyLarge
                      ?.copyWith(fontWeight: FontWeight.w600)),
              subtitle: Text(
                '${regionCodes.length} $regionWord',
                style: theme.textTheme.bodySmall?.copyWith(color: secondary),
              ),
              trailing: IconButton(
                icon: Icon(Icons.map_outlined,
                    size: 20, color: secondary),
                tooltip: 'View on map',
                onPressed: () {
                  final nav = Navigator.of(context);
                  nav.pop();
                  nav.push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          CountryRegionMapScreen(countryCode: code),
                    ),
                  );
                },
              ),
              children: regionCodes
                  .map(
                    (rc) => ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 32),
                      dense: true,
                      title: Text(
                        kRegionNames[rc] ?? rc,
                        style: theme.textTheme.bodyMedium,
                      ),
                      leading: const Icon(Icons.location_on_outlined, size: 16),
                    ),
                  )
                  .toList(),
            );
          },
        );
      },
    );
  }
}
