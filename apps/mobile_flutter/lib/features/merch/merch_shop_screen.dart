import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import 'merch_cart_item.dart';
import 'merch_cart_repository.dart';
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
              child: ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder:
                    (context, i) =>
                        _ShopCartItemTile(item: items[i], uid: uid),
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

// ── Cart item tile ────────────────────────────────────────────────────────────

class _ShopCartItemTile extends ConsumerWidget {
  const _ShopCartItemTile({required this.item, required this.uid});

  final MerchCartItem item;
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: _Thumbnail(url: item.frontMockupUrl),
      title: Text(
        item.title ?? _defaultTitle(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_optionsLabel()),
          const SizedBox(height: 4),
          _StatusBadge(status: item.status),
        ],
      ),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        tooltip: 'Remove',
        onPressed: () => _confirmDelete(context, ref),
      ),
      onTap:
          item.status == MerchCartItemStatus.mockupReady ||
                  item.status == MerchCartItemStatus.checkoutStarted
              ? () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => CartItemCheckoutScreen(item: item),
                ),
              )
              : null,
    );
  }

  String _defaultTitle() {
    final n = item.selectedCountryCodes.length;
    return '${item.isTshirt ? 'T-shirt' : 'Poster'} · $n ${n == 1 ? 'country' : 'countries'}';
  }

  String _optionsLabel() {
    if (item.isTshirt) return '${item.colour} · ${item.size}';
    return item.size;
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Remove design?'),
            content: const Text(
              'This will remove the saved design from your cart. '
              'You can always create a new one from the Shop.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Remove'),
              ),
            ],
          ),
    );
    if (confirmed != true) return;
    await MerchCartRepository(FirebaseFirestore.instance).delete(uid, item.id);
  }
}

// ── Thumbnail ─────────────────────────────────────────────────────────────────

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    const size = 56.0;
    final theme = Theme.of(context);
    final u = url;
    if (u != null && u.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.network(
          u,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _placeholder(theme, size),
        ),
      );
    }
    return _placeholder(theme, size);
  }

  Widget _placeholder(ThemeData theme, double size) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Icon(
      Icons.dry_cleaning_outlined,
      color: theme.colorScheme.onSurfaceVariant,
      size: 24,
    ),
  );
}

// ── Status badge ──────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final MerchCartItemStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = _resolve(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  static (String, Color) _resolve(
    MerchCartItemStatus status,
  ) => switch (status) {
    MerchCartItemStatus.mockupGenerating => ('Generating…', Colors.orange),
    MerchCartItemStatus.mockupReady => (
      'Ready to checkout',
      const Color(0xFF2E7D32),
    ),
    MerchCartItemStatus.checkoutStarted => ('Checkout started', Colors.blue),
    MerchCartItemStatus.purchased => ('Purchased', Colors.green),
    MerchCartItemStatus.failed => ('Failed', Colors.red),
  };
}
