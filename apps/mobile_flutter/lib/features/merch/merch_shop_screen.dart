import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../studio_v2_commerce/studio_v2_entry.dart';
import 'merch_cart_screen.dart';
import 'merch_design_entry_screen.dart';
import 'merch_orders_screen.dart';
import 'widgets/merch_collections_section.dart';

/// Shop screen — collections grid (M169).
///
/// Single focused purpose: show the user what they can design, grouped as
/// a 2-column grid of country-scope cards. The "Design a shirt from scratch"
/// banner at the top serves users who want to pick countries manually.
class MerchShopScreen extends ConsumerWidget {
  const MerchShopScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartCount = ref.watch(merchCartCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shop'),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: cartCount > 0,
              label: Text('$cartCount'),
              child: const Icon(Icons.shopping_bag_outlined),
            ),
            tooltip: 'Cart',
            onPressed:
                () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const MerchCartScreen(),
                  ),
                ),
          ),
          IconButton(
            icon: const Icon(Icons.receipt_long_outlined),
            tooltip: 'Order History',
            onPressed:
                () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const MerchOrdersScreen(),
                  ),
                ),
          ),
        ],
      ),
      body: const CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _DesignedForYouCard()),
          SliverToBoxAdapter(child: _DesignEntryBanner()),
          SliverToBoxAdapter(child: MerchCollectionsSection()),
          SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }
}

// ── Designed for You ─────────────────────────────────────────────────────────

/// The Studio's front door (M25.1).
///
/// Roavvy has already made the shirts; this says so. It is deliberately not an
/// invitation to configure something — the product principle is that Roavvy
/// creates first and the customer edits second, and the copy has to carry that
/// or the Studio reads as a tool rather than a gift.
///
/// Hidden entirely until there is travel to make designs from: an empty
/// promise is worse than no promise, and the banner below already serves
/// someone with nothing found yet.
class _DesignedForYouCard extends ConsumerWidget {
  const _DesignedForYouCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visits = ref.watch(effectiveVisitsProvider);
    final count = visits.valueOrNull?.length ?? 0;
    if (visits.isLoading || count == 0) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Material(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          key: const Key('shop-designed-for-you'),
          borderRadius: BorderRadius.circular(12),
          // Opened through the one bridge that knows both sides, so this gets
          // the real travel context, the cart, the live price and the signed-in
          // owner — the same Studio the dev entrypoints run, not a second one.
          onTap:
              () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const StudioV2Entry(embedded: true),
                ),
              ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.auto_awesome,
                    size: 22,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Designed for You',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Made from your $count '
                        '${count == 1 ? "country" : "countries"}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'See your designs',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Design entry banner ───────────────────────────────────────────────────────

/// Persistent "Design a shirt" CTA shown in the discovery scroll (M140).
///
/// Reads [effectiveVisitsProvider] and [continentCountProvider] to show live
/// stats. Tapping opens [MerchDesignEntryScreen].
class _DesignEntryBanner extends ConsumerWidget {
  const _DesignEntryBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countryCount =
        ref.watch(effectiveVisitsProvider).valueOrNull?.length ?? 0;
    final continentCount = ref.watch(continentCountProvider).valueOrNull ?? 0;
    final isLoading = ref.watch(effectiveVisitsProvider).isLoading;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF6B6B), Color(0xFFF2C94C)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap:
                () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const MerchDesignEntryScreen(),
                  ),
                ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isLoading)
                          Container(
                            width: 120,
                            height: 12,
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          )
                        else
                          Text(
                            '$countryCount '
                            '${countryCount == 1 ? "country" : "countries"}'
                            '${continentCount > 0 ? " · $continentCount ${continentCount == 1 ? "continent" : "continents"}" : ""}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        const SizedBox(height: 2),
                        const Text(
                          'Ready to design your next shirt?',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Text(
                    'Design a shirt →',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
