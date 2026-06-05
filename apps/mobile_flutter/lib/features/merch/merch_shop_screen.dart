import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import 'merch_cart_item.dart';
import 'merch_cart_item_card.dart';
import 'merch_cart_screen.dart';
import 'merch_design_entry_screen.dart';
import 'merch_orders_screen.dart';
import 'widgets/merch_collections_section.dart';
import 'widgets/merch_identity_header.dart';
import 'widgets/merch_ready_to_design_section.dart';

/// Shop screen — single-scroll personal discovery surface (M145, ADR-177).
///
/// Replaces the former Tab-based Cart/Orders layout with a unified scroll
/// that puts identity + discovery content first and keeps transactional
/// content (saved designs, recent orders) accessible below.
class MerchShopScreen extends ConsumerWidget {
  const MerchShopScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUidProvider);
    final cartAsync = ref.watch(merchCartProvider);
    final ordersAsync = ref.watch(merchOrdersProvider);

    final cartItems = cartAsync.valueOrNull ?? const [];
    final recentOrders = (ordersAsync.valueOrNull ?? const []).take(5).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Shop')),
      body: CustomScrollView(
        slivers: [
          // ── Identity header ──────────────────────────────────────────────
          const SliverToBoxAdapter(child: MerchIdentityHeader()),

          // ── Design entry banner (M140) ───────────────────────────────────
          const SliverToBoxAdapter(child: _DesignEntryBanner()),

          // ── Personalised recommendations ─────────────────────────────────
          const SliverToBoxAdapter(child: MerchReadyToDesignSection()),

          // ── Dynamic collections ───────────────────────────────────────────
          const SliverToBoxAdapter(child: MerchCollectionsSection()),

          // ── Saved designs (cart items) ────────────────────────────────────
          if (uid != null && cartItems.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: _SectionHeader(
                title: 'Saved Designs',
                icon: Icons.shopping_cart_outlined,
              ),
            ),
            SliverList.builder(
              itemCount: cartItems.length,
              itemBuilder:
                  (context, i) => MerchCartItemCard(
                    item: cartItems[i],
                    uid: uid,
                    onCheckout:
                        cartItems[i].status ==
                                    MerchCartItemStatus.mockupReady ||
                                cartItems[i].status ==
                                    MerchCartItemStatus.checkoutStarted
                            ? () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder:
                                    (_) => CartItemCheckoutScreen(
                                      item: cartItems[i],
                                    ),
                              ),
                            )
                            : null,
                  ),
            ),
          ],

          // ── Recent orders ─────────────────────────────────────────────────
          if (uid != null && recentOrders.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: _SectionHeader(
                title: 'My Collection',
                icon: Icons.collections_bookmark_outlined,
                action: recentOrders.length == 5
                    ? TextButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const MerchOrdersScreen(),
                          ),
                        ),
                        child: const Text('See all'),
                      )
                    : null,
              ),
            ),
            SliverList.builder(
              itemCount: recentOrders.length,
              itemBuilder: (context, i) => _OrderCard(order: recentOrders[i]),
            ),
          ],

          // ── Empty state when nothing in cart/orders ───────────────────────
          if (uid == null ||
              (cartItems.isEmpty && recentOrders.isEmpty))
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
                child: Text(
                  uid == null
                      ? 'Sign in to save designs and view your collection.'
                      : 'Start a design above — your saved designs and orders appear here.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.icon, this.action});

  final String title;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 8, 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.white54),
          const SizedBox(width: 6),
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          if (action != null) action!,
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

// ── Recent order card (compact) ───────────────────────────────────────────────

class _OrderCard extends ConsumerWidget {
  const _OrderCard({required this.order});

  final MerchOrderSummary order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: order.thumbnailUrl != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.network(
                  order.thumbnailUrl!,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported_outlined),
                ),
              )
            : const Icon(Icons.checkroom_outlined),
        title: Text(
          order.productName,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${order.countryCount} countries',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right, size: 18),
      ),
    );
  }
}
