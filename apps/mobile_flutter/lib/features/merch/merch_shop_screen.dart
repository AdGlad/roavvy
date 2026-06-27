import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
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
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const MerchCartScreen(),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.receipt_long_outlined),
            tooltip: 'Order History',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const MerchOrdersScreen(),
              ),
            ),
          ),
        ],
      ),
      body: const CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _DesignEntryBanner()),
          SliverToBoxAdapter(child: MerchCollectionsSection()),
          SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
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
    final continentCount =
        ref.watch(continentCountProvider).valueOrNull ?? 0;
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
            onTap: () => Navigator.of(context).push(
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
