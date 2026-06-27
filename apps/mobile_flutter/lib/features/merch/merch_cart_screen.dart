import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/providers.dart';
import 'merch_cart_item.dart';
import 'merch_cart_item_card.dart';
import 'merch_cart_repository.dart';
import 'merch_order_confirmation_screen.dart';
import 'merch_post_purchase_screen.dart';
import 'merch_variant_lookup.dart';

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
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 16),
            itemCount: items.length,
            itemBuilder:
                (context, i) => MerchCartItemCard(
                  item: items[i],
                  uid: uid,
                  onCheckout:
                      items[i].status == MerchCartItemStatus.mockupReady ||
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
          );
        },
      ),
    );
  }
}

// ── Cart item checkout screen ─────────────────────────────────────────────────

/// Minimal screen that shows the saved cart item and launches checkout.
///
/// Reached by tapping a `mockupReady` cart item.
class CartItemCheckoutScreen extends ConsumerStatefulWidget {
  const CartItemCheckoutScreen({super.key, required this.item});

  final MerchCartItem item;

  @override
  ConsumerState<CartItemCheckoutScreen> createState() =>
      _CartItemCheckoutScreenState();
}

class _CartItemCheckoutScreenState extends ConsumerState<CartItemCheckoutScreen>
    with WidgetsBindingObserver {
  bool _confirmed = false;
  bool _checkoutStarted = false; // true once Proceed is tapped — locks the UI
  bool _checkoutLaunched = false;
  bool _pollingInProgress = false;

  static const int _pollIntervalSeconds = 5;
  static const int _pollMaxAttempts = 20; // 100 s total

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _checkoutLaunched &&
        !_pollingInProgress) {
      _pollingInProgress = true;
      _pollForPurchase();
    }
  }

  Future<void> _launchCheckout() async {
    final url = widget.item.checkoutUrl;
    if (url == null) return;
    // Lock the UI immediately — navigate away from review and block back nav
    // before opening the browser so the user cannot return and double-order.
    setState(() => _checkoutStarted = true);
    final base = Uri.parse(url);
    final uri = base.replace(
      queryParameters: {...base.queryParameters, 'return_to': 'roavvy://return'},
    );
    if (!mounted) return;
    final launched = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    if (!mounted) return;
    if (!launched) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open checkout')));
      setState(() => _checkoutStarted = false);
      return;
    }
    // inAppBrowserView returns immediately after presenting — app stays in
    // foreground so didChangeAppLifecycleState(resumed) never fires.
    // Start polling directly.
    setState(() => _checkoutLaunched = true);
    if (!_pollingInProgress) {
      _pollingInProgress = true;
      _pollForPurchase();
    }
  }

  Future<void> _pollForPurchase() async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) {
      _pollingInProgress = false;
      if (mounted) _showProcessingFallback();
      return;
    }

    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('cartItems')
        .doc(widget.item.id);

    for (int attempt = 0; attempt < _pollMaxAttempts; attempt++) {
      await Future<void>.delayed(
        const Duration(seconds: _pollIntervalSeconds),
      );
      if (!mounted) return;
      try {
        final snap = await docRef.get();
        if (snap.data()?['status'] == 'purchased') {
          _checkoutLaunched = false;
          _pollingInProgress = false;
          if (!mounted) return;
          final product = widget.item.isTshirt
              ? MerchProduct.tshirt
              : MerchProduct.poster;
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => MerchPostPurchaseScreen(
                product: product,
                countryCount: widget.item.selectedCountryCodes.length,
                frontMockupUrl: widget.item.frontMockupUrl,
                designTitle: widget.item.title,
              ),
            ),
          );
          return;
        }
      } catch (_) {
        // Network error mid-poll — continue.
      }
    }

    _checkoutLaunched = false;
    _pollingInProgress = false;
    if (mounted) _showProcessingFallback();
  }

  void _showProcessingFallback() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text("We're processing your order"),
        content: const Text(
          "If you completed payment, you'll receive a confirmation email "
          'shortly. Your order will appear in your order history once confirmed.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text('Back to map'),
          ),
        ],
      ),
    );
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

    if (_checkoutStarted) {
      return PopScope(
        canPop: false,
        child: Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_pollingInProgress) ...[
                      const CircularProgressIndicator(),
                      const SizedBox(height: 28),
                      Text(
                        'Checking your order…',
                        style: theme.textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "We'll take you to your order confirmation\nas soon as payment is confirmed.",
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ] else ...[
                      const CircularProgressIndicator(),
                      const SizedBox(height: 28),
                      Text(
                        'Opening checkout…',
                        style: theme.textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                    ],
                    if (_checkoutLaunched) ...[
                      const SizedBox(height: 32),
                      TextButton(
                        onPressed:
                            () => Navigator.of(
                              context,
                            ).popUntil((route) => route.isFirst),
                        child: const Text('Back to Roavvy'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

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
                  // Mockup preview — pinch to zoom up to 4×
                  if (item.frontMockupUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: AspectRatio(
                        aspectRatio: 3 / 4,
                        child: InteractiveViewer(
                          panEnabled: false,
                          minScale: 1.0,
                          maxScale: 4.0,
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
