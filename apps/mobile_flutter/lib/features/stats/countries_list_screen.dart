import 'package:flutter/material.dart';
import 'package:shared_models/shared_models.dart';

import '../../core/country_names.dart';
import '../map/country_detail_sheet.dart';

/// Full-screen list of all visited countries.
///
/// Navigated to from the Stats screen "Countries" tile. Countries are sorted
/// alphabetically by display name. Tapping any row opens [CountryDetailSheet]
/// as a modal bottom sheet (read-only — no add action).
class CountriesListScreen extends StatelessWidget {
  const CountriesListScreen({super.key, required this.visits});

  final List<EffectiveVisitedCountry> visits;

  @override
  Widget build(BuildContext context) {
    final sorted = [...visits]
      ..sort((a, b) {
        final na = kCountryNames[a.countryCode] ?? a.countryCode;
        final nb = kCountryNames[b.countryCode] ?? b.countryCode;
        return na.compareTo(nb);
      });

    final count = visits.length;
    final title = '$count ${count == 1 ? 'country' : 'countries'} visited';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView.builder(
        itemCount: sorted.length,
        itemBuilder: (context, i) {
          final visit = sorted[i];
          final name = kCountryNames[visit.countryCode] ?? visit.countryCode;
          final flag = _flagEmoji(visit.countryCode);
          final subtitle = visit.firstSeen != null
              ? 'Since ${visit.firstSeen!.year}'
              : visit.countryCode;

          return ListTile(
            leading: Text(flag, style: const TextStyle(fontSize: 28)),
            title: Text(name),
            subtitle: Text(subtitle),
            onTap: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (_) => CountryDetailSheet(
                isoCode: visit.countryCode,
                visit: visit,
              ),
            ),
          );
        },
      ),
    );
  }

  /// Converts an ISO 3166-1 alpha-2 code to its flag emoji.
  static String _flagEmoji(String code) {
    final a = 0x1F1E6 + code.codeUnitAt(0) - 0x41; // 0x41 = 'A'
    final b = 0x1F1E6 + code.codeUnitAt(1) - 0x41;
    return String.fromCharCode(a) + String.fromCharCode(b);
  }
}
