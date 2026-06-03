import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import 'merch_cart_item.dart';
import 'merch_cart_repository.dart';
import 'merch_cart_screen.dart';
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
                icon: Icon(Icons.shopping_bag_outlined),
                text: 'Orders',
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
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Could not load cart: $e')),
      data: (items) {
        if (items.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'Your cart is empty.\n\nHead to the map, pick your countries, '
                'and design your first personalised t-shirt.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder:
              (context, i) => _ShopCartItemTile(item: items[i], uid: uid),
        );
      },
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
