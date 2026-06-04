import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/providers.dart';
import 'merch_cart_item.dart';
import 'merch_cart_repository.dart';
import 'merch_order_confirmation_screen.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

/// Real-time stream of active (non-purchased) cart items for the current user (M120).
/// Uses a Firestore snapshot stream so the cart updates automatically when items
/// are added or updated (e.g. after createMerchCart completes).
final merchCartProvider = StreamProvider<List<MerchCartItem>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const <MerchCartItem>[]);
  return MerchCartRepository(FirebaseFirestore.instance).watchActive(uid);
});

/// Count of active cart items — used for the nav-bar badge (M120).
final merchCartCountProvider = Provider<int>((ref) {
  return ref.watch(merchCartProvider).valueOrNull?.length ?? 0;
});

// ── Screen ────────────────────────────────────────────────────────────────────

/// Displays in-progress and saved merch designs for the current user.
///
/// Entry points: profile screen tile, merch confirmation screen.
class MerchCartScreen extends ConsumerWidget {
  const MerchCartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUidProvider);

    if (uid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Your Cart')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              'Sign in to view your saved designs.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final cartAsync = ref.watch(merchCartProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Your Cart')),
      body: cartAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load cart: $e')),
        data: (items) {
          if (items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No designs saved yet.\n\nCreate your first shirt from an achievement '
                  'or a Memory Pulse — it takes less than a minute.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder:
                (context, i) => _CartItemTile(
                  item: items[i],
                  uid: uid,
                  onDeleted: () => ref.invalidate(merchCartProvider),
                ),
          );
        },
      ),
    );
  }
}

// ── Tile ──────────────────────────────────────────────────────────────────────

class _CartItemTile extends StatelessWidget {
  const _CartItemTile({
    required this.item,
    required this.uid,
    required this.onDeleted,
  });

  final MerchCartItem item;
  final String uid;
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: _Thumbnail(url: item.frontMockupUrl),
      title: Text(
        item.title ?? _defaultTitle(item),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_optionsLabel(item)),
          const SizedBox(height: 4),
          _StatusBadge(status: item.status),
        ],
      ),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        tooltip: 'Remove',
        onPressed: () => _confirmDelete(context),
      ),
      onTap:
          item.status == MerchCartItemStatus.mockupReady ||
                  item.status == MerchCartItemStatus.checkoutStarted
              ? () => _openCheckout(context)
              : null,
    );
  }

  String _defaultTitle(MerchCartItem item) {
    final n = item.selectedCountryCodes.length;
    return '${item.isTshirt ? 'T-shirt' : 'Poster'} · $n ${n == 1 ? 'country' : 'countries'}';
  }

  String _optionsLabel(MerchCartItem item) {
    if (item.isTshirt) {
      return '${item.colour} · ${item.size}';
    }
    return item.size;
  }

  void _openCheckout(BuildContext context) {
    final url = item.checkoutUrl;
    if (url == null) return;
    // Navigate to the confirmation screen for this cart item.
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CartItemCheckoutScreen(item: item),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
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
    onDeleted();
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

  Widget _placeholder(ThemeData theme, double size) {
    return Container(
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

// ── Cart item checkout screen ─────────────────────────────────────────────────

/// Minimal screen that shows the saved cart item and launches checkout.
///
/// Reached by tapping a `mockupReady` cart item.
class CartItemCheckoutScreen extends StatefulWidget {
  const CartItemCheckoutScreen({super.key, required this.item});

  final MerchCartItem item;

  @override
  State<CartItemCheckoutScreen> createState() => _CartItemCheckoutScreenState();
}

class _CartItemCheckoutScreenState extends State<CartItemCheckoutScreen> {
  bool _confirmed = false;

  Future<void> _launchCheckout() async {
    final url = widget.item.checkoutUrl;
    if (url == null) return;
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.inAppBrowserView)) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open checkout')));
    }
  }

  static String _positionLabel(String position) => switch (position) {
    'center' => 'Centre',
    'left_chest' => 'Left Chest',
    'right_chest' => 'Right Chest',
    _ => 'None',
  };

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Continue to Checkout')),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Mockup preview
                  if (item.frontMockupUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: AspectRatio(
                        aspectRatio: 3 / 4,
                        child: Image.network(
                          item.frontMockupUrl!,
                          fit: BoxFit.contain,
                          loadingBuilder:
                              (_, child, p) =>
                                  p == null
                                      ? child
                                      : const Center(
                                        child: CircularProgressIndicator(),
                                      ),
                        ),
                      ),
                    )
                  else
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.dry_cleaning_outlined,
                          size: 64,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  // Order summary
                  Card.outlined(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Order Details',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          if (item.isTshirt) ...[
                            _Row(label: 'Colour', value: item.colour),
                            const SizedBox(height: 8),
                            _Row(label: 'Size', value: item.size),
                            const SizedBox(height: 8),
                            _Row(
                              label: 'Front print',
                              value: _positionLabel(item.frontPosition),
                            ),
                            const SizedBox(height: 8),
                            _Row(
                              label: 'Back print',
                              value: _positionLabel(item.backPosition),
                            ),
                          ] else
                            _Row(label: 'Size', value: item.size),
                          const SizedBox(height: 8),
                          _Row(
                            label: 'Countries',
                            value: '${item.selectedCountryCodes.length}',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    value: _confirmed,
                    onChanged: (v) => setState(() => _confirmed = v ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text(
                      "I'm happy with my design and ready to order.",
                    ),
                  ),
                  const SizedBox(height: 16),
                  const MerchCustomProductWarning(),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Go Back'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _confirmed ? _launchCheckout : null,
                      child: const Text('Proceed to Checkout'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        SizedBox(
          width: 88,
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
