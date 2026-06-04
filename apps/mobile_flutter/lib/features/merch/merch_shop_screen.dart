import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import 'merch_cart_item.dart';
import 'merch_cart_item_card.dart';
import 'merch_cart_screen.dart';
import 'merch_design_entry_screen.dart';
import 'merch_orders_screen.dart';

/// Shop screen combining Cart and Orders in two tabs.
///
/// Accessed via the Shop nav-bar tab (replaces the old Scan tab).
class MerchShopScreen extends ConsumerWidget {
  const MerchShopScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartCount = ref.watch(merchCartCountProvider);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Shop'),
          bottom: TabBar(
            tabs: [
              Tab(
                icon: Badge(
                  isLabelVisible: cartCount > 0,
                  child: const Icon(Icons.shopping_cart_outlined),
                ),
                text: 'Cart',
              ),
              const Tab(
                icon: Icon(Icons.collections_bookmark_outlined),
                text: 'My Collection',
              ),
            ],
          ),
        ),
        body: TabBarView(children: [_CartTabBody(), const MerchOrdersBody()]),
      ),
    );
  }
}

// ── Cart tab body ─────────────────────────────────────────────────────────────

class _CartTabBody extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUidProvider);

    if (uid == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Sign in to view your saved designs.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final cartAsync = ref.watch(merchCartProvider);

    return cartAsync.when(
      loading: () => Column(
        children: [
          const _DesignEntryBanner(),
          const Expanded(child: Center(child: CircularProgressIndicator())),
        ],
      ),
      error: (e, _) => Column(
        children: [
          const _DesignEntryBanner(),
          Expanded(child: Center(child: Text('Could not load cart: $e'))),
        ],
      ),
      data: (items) {
        if (items.isEmpty) {
          // Banner replaces empty-state text entirely.
          return const SingleChildScrollView(child: _DesignEntryBanner());
        }
        return Column(
          children: [
            const _DesignEntryBanner(),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 16),
                itemCount: items.length,
                itemBuilder:
                    (context, i) => MerchCartItemCard(
                      item: items[i],
                      uid: uid,
                      onCheckout:
                          items[i].status ==
                                      MerchCartItemStatus.mockupReady ||
                                  items[i].status ==
                                      MerchCartItemStatus.checkoutStarted
                              ? () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder:
                                      (_) => CartItemCheckoutScreen(
                                        item: items[i],
                                      ),
                                ),
                              )
                              : null,
                    ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Design entry banner ───────────────────────────────────────────────────────

/// Persistent "Design a shirt" CTA shown at the top of the Cart tab (M140).
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

