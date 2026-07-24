import 'package:flutter/material.dart';
import 'package:shared_models/shared_models.dart';

import 'merch_option_list_widgets.dart';
import 'merch_template_ranker.dart';
import 'merch_title_wordbank.dart';
import 'pulse_merch_option.dart';

const _kLabelToContinent = {
  'Africa': 'africa',
  'Asia': 'asia',
  'Europe': 'europe',
  'North America': 'north_america',
  'Oceania': 'oceania',
  'South America': 'south_america',
};

/// Merch option carousel shown when tapping a recommendation or collection
/// in the Shop screen.
///
/// Builds one [PulseMerchOption] per eligible template for [codes].
/// The option matching [featuredTemplate] is placed first and badged
/// as "✦ Best Match", reflecting the choice the user made in the Shop.
class ShopCollectionOptionScreen extends StatelessWidget {
  const ShopCollectionOptionScreen({
    super.key,
    required this.label,
    required this.codes,
    required this.allCodes,
    required this.trips,
    required this.featuredTemplate,
  });

  final String label;
  final List<String> codes;
  final List<String> allCodes;
  final List<TripRecord> trips;
  final CardTemplateType featuredTemplate;

  List<PulseMerchOption> _buildOptions() {
    final ranks = MerchTemplateRanker.rankFor(codeCount: codes.length)
        .where((r) => !r.exclude)
        .toList();

    final continentKey = _kLabelToContinent[label];

    // "$label" is used verbatim as the design's on-shirt title text
    // (threaded through as titleOverride all the way to the printed mockup).
    // For collections with a meaningful label (Europe, 2026 Travels, an
    // achievement name) that reads fine, but "My Design" — the generic
    // label from the manual country picker — is a placeholder, not a
    // title. Swap it for the same wordbank-generated suggestion the
    // "New suggestion" button on the next screen offers, so the first
    // thing a player sees already reads like a real title.
    final options = ranks
        .map(
          (r) => PulseMerchOption(
            id: 'shop_${r.template.name}',
            title: label == 'My Design'
                ? MerchTitleWordbank.pickGeneric(codes.length, r.template.index)
                : '$label · ${r.label}',
            description: r.label,
            scope: PulseMerchScope.allTime,
            template: r.template,
            codes: codes,
            trips: trips,
            jitter: 0.4,
            stampSizeMultiplier: 1.0,
            continentKey: continentKey,
          ),
        )
        .toList();

    // Sort so featured template is first.
    final featuredIdx = options.indexWhere((o) => o.template == featuredTemplate);
    if (featuredIdx > 0) {
      final featured = options.removeAt(featuredIdx);
      options.insert(0, featured);
    }
    return options;
  }

  @override
  Widget build(BuildContext context) {
    final options = _buildOptions();
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(label), elevation: 0),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                '${codes.length} ${codes.length == 1 ? "country" : "countries"}'
                ' · Choose a design style',
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.54),
                  fontSize: 13,
                ),
              ),
            ),
          ),
          if (options.isNotEmpty)
            SliverToBoxAdapter(
              child: MerchDesignCarousel(
                options: options,
                allCodes: allCodes,
                featuredIndex: 0,
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }
}
