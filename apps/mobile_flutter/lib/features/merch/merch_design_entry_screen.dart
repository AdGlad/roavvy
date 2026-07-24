import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_models/shared_models.dart';

import '../../core/country_names.dart';
import '../../core/providers.dart';
import 'merch_template_ranker.dart';
import 'shop_collection_option_screen.dart';

// ── Filter chip enum ──────────────────────────────────────────────────────────

enum MerchDesignFilterChip { all, thisYear, europe, asia, americas, custom }

// ── Screen ────────────────────────────────────────────────────────────────────

/// Country selection screen reached from the Shop tab "Design a shirt" CTA.
///
/// Lets the user choose which countries to design for using quick chip filters,
/// then proceeds to [LocalMockupPreviewScreen]. Entry point: ADR-174 (M140).
class MerchDesignEntryScreen extends ConsumerStatefulWidget {
  const MerchDesignEntryScreen({super.key});

  @override
  ConsumerState<MerchDesignEntryScreen> createState() =>
      _MerchDesignEntryScreenState();
}

class _MerchDesignEntryScreenState
    extends ConsumerState<MerchDesignEntryScreen> {
  MerchDesignFilterChip _chip = MerchDesignFilterChip.all;
  Set<String> _selectedCodes = {};
  bool _initialised = false;

  Set<String> _applyFilter(
    List<EffectiveVisitedCountry> visits,
    MerchDesignFilterChip chip,
  ) {
    switch (chip) {
      case MerchDesignFilterChip.all:
        return visits.map((v) => v.countryCode).toSet();
      case MerchDesignFilterChip.thisYear:
        final year = DateTime.now().year;
        return visits
            .where((v) => v.firstSeen?.year == year)
            .map((v) => v.countryCode)
            .toSet();
      case MerchDesignFilterChip.europe:
        return visits
            .where((v) => kCountryContinent[v.countryCode] == 'Europe')
            .map((v) => v.countryCode)
            .toSet();
      case MerchDesignFilterChip.asia:
        return visits
            .where((v) => kCountryContinent[v.countryCode] == 'Asia')
            .map((v) => v.countryCode)
            .toSet();
      case MerchDesignFilterChip.americas:
        return visits
            .where((v) {
              final c = kCountryContinent[v.countryCode];
              return c == 'North America' || c == 'South America';
            })
            .map((v) => v.countryCode)
            .toSet();
      case MerchDesignFilterChip.custom:
        return _selectedCodes;
    }
  }

  void _selectChip(
    MerchDesignFilterChip chip,
    List<EffectiveVisitedCountry> visits,
  ) {
    setState(() {
      // Tapping "All countries" again while it's already the active filter
      // toggles the whole list off, rather than re-selecting the same set —
      // the quickest way to clear a selection and start picking manually.
      if (chip == MerchDesignFilterChip.all &&
          _chip == MerchDesignFilterChip.all) {
        _chip = MerchDesignFilterChip.custom;
        _selectedCodes = {};
        return;
      }
      _chip = chip;
      if (chip != MerchDesignFilterChip.custom) {
        _selectedCodes = _applyFilter(visits, chip);
      }
    });
  }

  bool _chipHasVisits(
    MerchDesignFilterChip chip,
    List<EffectiveVisitedCountry> visits,
  ) {
    switch (chip) {
      case MerchDesignFilterChip.all:
        return visits.isNotEmpty;
      case MerchDesignFilterChip.thisYear:
        final year = DateTime.now().year;
        return visits.any((v) => v.firstSeen?.year == year);
      case MerchDesignFilterChip.europe:
        return visits.any(
          (v) => kCountryContinent[v.countryCode] == 'Europe',
        );
      case MerchDesignFilterChip.asia:
        return visits.any(
          (v) => kCountryContinent[v.countryCode] == 'Asia',
        );
      case MerchDesignFilterChip.americas:
        return visits.any((v) {
          final c = kCountryContinent[v.countryCode];
          return c == 'North America' || c == 'South America';
        });
      case MerchDesignFilterChip.custom:
        return true;
    }
  }

  void _toggleCountry(String code) {
    setState(() {
      _chip = MerchDesignFilterChip.custom;
      if (_selectedCodes.contains(code)) {
        _selectedCodes = {..._selectedCodes}..remove(code);
      } else {
        _selectedCodes = {..._selectedCodes, code};
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final visitsAsync = ref.watch(effectiveVisitsProvider);
    final tripsAsync = ref.watch(tripListProvider);

    final deTheme = Theme.of(context);
    final deCs = deTheme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Design a shirt'),
        elevation: 0,
      ),
      body: visitsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Could not load visits: $e'),
        ),
        data: (visits) {
          // Initialise selection on first data load.
          if (!_initialised) {
            _selectedCodes = visits.map((v) => v.countryCode).toSet();
            _initialised = true;
          }

          final sortedVisits = [...visits]..sort(
            (a, b) =>
                (kCountryNames[a.countryCode] ?? a.countryCode).compareTo(
                  kCountryNames[b.countryCode] ?? b.countryCode,
                ),
          );

          final chips = [
            (MerchDesignFilterChip.all, 'All countries'),
            (MerchDesignFilterChip.thisYear, 'This year'),
            (MerchDesignFilterChip.europe, 'Europe'),
            (MerchDesignFilterChip.asia, 'Asia'),
            (MerchDesignFilterChip.americas, 'Americas'),
            (MerchDesignFilterChip.custom, 'Custom'),
          ];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero stat
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Text(
                  '${visits.length} ${visits.length == 1 ? "country" : "countries"} in your collection',
                  style: TextStyle(color: deCs.onSurface.withValues(alpha: 0.54), fontSize: 13),
                ),
              ),

              // Chip row
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    for (final (chip, label) in chips)
                      if (_chipHasVisits(chip, visits))
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(label),
                            selected: _chip == chip,
                            onSelected: (_) => _selectChip(chip, visits),
                            selectedColor: const Color(
                              0xFFF2C94C,
                            ).withValues(alpha: 0.25),
                            checkmarkColor: const Color(0xFFF2C94C),
                            labelStyle: TextStyle(
                              color:
                                  _chip == chip
                                      ? const Color(0xFFF2C94C)
                                      : deCs.onSurface.withValues(alpha: 0.54),
                              fontSize: 12,
                            ),
                            side: BorderSide(
                              color:
                                  _chip == chip
                                      ? const Color(0xFFF2C94C).withValues(alpha: 0.6)
                                      : deCs.onSurface.withValues(alpha: 0.12),
                            ),
                          ),
                        ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // Country list
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: sortedVisits.length,
                  itemBuilder: (ctx, i) {
                    final code = sortedVisits[i].countryCode;
                    final name = kCountryNames[code] ?? code;
                    final isSelected = _selectedCodes.contains(code);
                    return CheckboxListTile(
                      title: Text(name, style: const TextStyle(fontSize: 14)),
                      value: isSelected,
                      activeColor: const Color(0xFFF2C94C),
                      checkColor: Colors.black,
                      onChanged: (_) => _toggleCountry(code),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: FilledButton(
            onPressed:
                _selectedCodes.isEmpty
                    ? null
                    : () {
                      final trips = tripsAsync.valueOrNull ?? const [];
                      final allCodes =
                          visitsAsync.valueOrNull
                              ?.map((v) => v.countryCode)
                              .toList() ??
                          const [];
                      final codes = _selectedCodes.toList();
                      final ranks = MerchTemplateRanker.rankFor(
                        codeCount: codes.length,
                      );
                      final template = ranks
                          .firstWhere(
                            (r) => !r.exclude,
                            orElse: () => ranks.first,
                          )
                          .template;
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder:
                              (_) => ShopCollectionOptionScreen(
                                label: 'My Design',
                                codes: codes,
                                allCodes: allCodes,
                                trips: trips,
                                featuredTemplate: template,
                              ),
                        ),
                      );
                    },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFF2C94C),
              foregroundColor: Colors.black,
            ),
            child: Text(
              'Design with ${_selectedCodes.length} '
              '${_selectedCodes.length == 1 ? "country" : "countries"} →',
            ),
          ),
        ),
      ),
    );
  }
}
