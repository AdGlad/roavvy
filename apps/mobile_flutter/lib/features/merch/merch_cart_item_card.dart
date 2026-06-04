import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'merch_cart_item.dart';
import 'merch_cart_repository.dart';

// ── Shared cart item card ──────────────────────────────────────────────────────

/// Visual gallery card for a saved merch design (M141).
///
/// Used by both [MerchShopScreen] (Cart tab) and [MerchCartScreen] (standalone).
/// Shows the front mockup image (200px), design title, options, status badge,
/// delete icon, and a "Checkout →" button when ready.
///
/// [onCheckout] is called when the user taps the card or the checkout button.
/// Pass `null` to disable checkout (e.g. while still generating).
/// [onDeleted] is called after a successful delete.
class MerchCartItemCard extends StatelessWidget {
  const MerchCartItemCard({
    super.key,
    required this.item,
    required this.uid,
    this.onCheckout,
    this.onDeleted,
  });

  final MerchCartItem item;
  final String uid;
  final VoidCallback? onCheckout;
  final VoidCallback? onDeleted;

  String _defaultTitle() {
    final n = item.selectedCountryCodes.length;
    return '${item.isTshirt ? 'T-shirt' : 'Poster'} · $n ${n == 1 ? 'country' : 'countries'}';
  }

  String _optionsLabel() {
    if (item.isTshirt) return '${item.colour} · ${item.size}';
    return item.size;
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
    onDeleted?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = item.title ?? _defaultTitle();

    final card = Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onCheckout,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Full-width mockup image
            _MockupImage(url: item.frontMockupUrl, title: title),

            // Info area
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _optionsLabel(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      MerchCartStatusBadge(status: item.status),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Remove',
                        onPressed: () => _confirmDelete(context),
                        iconSize: 20,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      if (onCheckout != null) ...[
                        const SizedBox(width: 12),
                        FilledButton.tonal(
                          onPressed: onCheckout,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'Checkout →',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      // Dismissible calls confirmDismiss; we handle delete ourselves and return
      // false so Dismissible never actually removes the item from the tree (the
      // stream-driven list will update automatically after Firestore deletes).
      confirmDismiss: (_) async {
        await _confirmDelete(context);
        return false;
      },
      child: card,
    );
  }
}

// ── Mockup image ───────────────────────────────────────────────────────────────

class _MockupImage extends StatelessWidget {
  const _MockupImage({this.url, required this.title});

  final String? url;
  final String title;

  @override
  Widget build(BuildContext context) {
    const height = 200.0;
    final theme = Theme.of(context);
    final u = url;
    if (u != null && u.isNotEmpty) {
      return Image.network(
        u,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(theme, height),
      );
    }
    return _placeholder(theme, height);
  }

  Widget _placeholder(ThemeData theme, double height) {
    return Container(
      height: height,
      width: double.infinity,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.dry_cleaning_outlined,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              title,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Status badge ───────────────────────────────────────────────────────────────

/// Shared status badge for [MerchCartItemStatus] — used by [MerchCartItemCard]
/// and any other widget needing the same enum-based colour mapping.
class MerchCartStatusBadge extends StatelessWidget {
  const MerchCartStatusBadge({super.key, required this.status});

  final MerchCartItemStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      MerchCartItemStatus.mockupGenerating => ('Generating…', Colors.orange),
      MerchCartItemStatus.mockupReady => (
        'Ready to checkout',
        const Color(0xFF2E7D32),
      ),
      MerchCartItemStatus.checkoutStarted => ('Checkout started', Colors.blue),
      MerchCartItemStatus.purchased => ('Purchased', Colors.green),
      MerchCartItemStatus.failed => ('Failed', Colors.red),
    };
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
}
