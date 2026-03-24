import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_models/shared_models.dart';

import '../../core/country_names.dart';
import '../../core/providers.dart';
import 'merch_product_browser_screen.dart';

/// Screen 1 of the commerce flow: country selection.
///
/// Shows all of the user's effective visited countries as toggleable rows.
/// All countries are pre-selected on first open.
/// "Next →" is enabled only when ≥ 1 country is selected.
///
/// When [preSelectedCodes] is provided, only those codes start selected;
/// all other effective visits start deselected. (ADR-085)
class MerchCountrySelectionScreen extends ConsumerStatefulWidget {
  const MerchCountrySelectionScreen({super.key, this.preSelectedCodes});

  /// When non-null, only these ISO codes are initially selected.
  /// Codes not present in [effectiveVisitsProvider] are silently ignored.
  final List<String>? preSelectedCodes;

  @override
  ConsumerState<MerchCountrySelectionScreen> createState() =>
      _MerchCountrySelectionScreenState();
}

class _MerchCountrySelectionScreenState
    extends ConsumerState<MerchCountrySelectionScreen> {
  /// Codes that have been explicitly deselected by the user.
  /// Starts empty — all countries are selected by default.
  final Set<String> _deselected = {};

  /// True after [_deselected] has been seeded from [widget.preSelectedCodes].
  bool _initialized = false;

  static String _flagEmoji(String code) {
    final a = 0x1F1E6 + code.codeUnitAt(0) - 0x41;
    final b = 0x1F1E6 + code.codeUnitAt(1) - 0x41;
    return String.fromCharCode(a) + String.fromCharCode(b);
  }

  List<EffectiveVisitedCountry> _sorted(
      List<EffectiveVisitedCountry> visits) {
    final copy = [...visits];
    copy.sort((a, b) {
      final nameA = kCountryNames[a.countryCode] ?? a.countryCode;
      final nameB = kCountryNames[b.countryCode] ?? b.countryCode;
      return nameA.compareTo(nameB);
    });
    return copy;
  }

  @override
  Widget build(BuildContext context) {
    final visitsAsync = ref.watch(effectiveVisitsProvider);

    return visitsAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Shop')),
        body: Center(child: Text('Error: $e')),
      ),
      data: (visits) => _buildScreen(context, visits),
    );
  }

  Widget _buildScreen(
      BuildContext context, List<EffectiveVisitedCountry> visits) {
    if (visits.isEmpty) {
      return _EmptyState();
    }

    final sorted = _sorted(visits);

    // Seed _deselected from preSelectedCodes on first build after data loads.
    // (ADR-085: lazy init because visits are not available at construction time.)
    if (!_initialized && widget.preSelectedCodes != null) {
      final preSelected = widget.preSelectedCodes!.toSet();
      _deselected
        ..clear()
        ..addAll(sorted
            .map((v) => v.countryCode)
            .where((c) => !preSelected.contains(c)));
      _initialized = true;
    } else if (!_initialized) {
      _initialized = true;
    }
    final selectedCount = sorted.length - _deselected.length;

    return Scaffold(
      appBar: AppBar(
        title: Text('Your countries ($selectedCount selected)'),
        actions: [
          TextButton(
            onPressed: () => setState(() => _deselected.clear()),
            child: const Text('Select all'),
          ),
          TextButton(
            onPressed: () => setState(() {
              _deselected
                ..clear()
                ..addAll(sorted.map((v) => v.countryCode));
            }),
            child: const Text('Clear all'),
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: sorted.length,
        itemBuilder: (context, index) {
          final visit = sorted[index];
          final code = visit.countryCode;
          final name = kCountryNames[code] ?? code;
          final flag = _flagEmoji(code);
          final selected = !_deselected.contains(code);

          return CheckboxListTile(
            value: selected,
            onChanged: (_) => setState(() {
              if (selected) {
                _deselected.add(code);
              } else {
                _deselected.remove(code);
              }
            }),
            title: Text('$flag  $name'),
            controlAffinity: ListTileControlAffinity.trailing,
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: selectedCount == 0
                ? null
                : () {
                    final selected = sorted
                        .map((v) => v.countryCode)
                        .where((c) => !_deselected.contains(c))
                        .toList();
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            MerchProductBrowserScreen(selectedCodes: selected),
                      ),
                    );
                  },
            child: const Text('Choose a design →'),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Shop')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Scan your photos first to detect your visited countries — '
                'then come back here to put them on a t-shirt.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
