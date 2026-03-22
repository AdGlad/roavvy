import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';

// ── Data model ─────────────────────────────────────────────────────────────────

/// Summary of a single merch order read from Firestore (ADR-075).
///
/// Only app-layer fields — not shared across packages.
class MerchOrderSummary {
  const MerchOrderSummary({
    required this.configId,
    required this.productName,
    required this.countryCount,
    required this.createdAt,
    required this.status,
  });

  final String configId;
  final String productName;
  final int countryCount;
  final DateTime createdAt;

  /// Raw status string from Firestore (e.g. 'cart_created', 'ordered').
  final String status;

  factory MerchOrderSummary.fromDoc(
    String id,
    Map<String, dynamic> data,
  ) {
    // templateId is 'flag_grid_v1'; derive product name from variantId prefix.
    final variantId = data['variantId'] as String? ?? '';
    final productName =
        variantId.contains('Poster') ? 'Travel Poster' : 'Roavvy Test Tee';

    final codes = data['selectedCountryCodes'];
    final countryCount = codes is List ? codes.length : 0;

    DateTime createdAt;
    final ts = data['createdAt'];
    if (ts is Timestamp) {
      createdAt = ts.toDate();
    } else {
      createdAt = DateTime(2025);
    }

    return MerchOrderSummary(
      configId: id,
      productName: productName,
      countryCount: countryCount,
      createdAt: createdAt,
      status: data['status'] as String? ?? 'pending',
    );
  }
}

// ── Provider ───────────────────────────────────────────────────────────────────

/// Reads up to 20 merch configs for the current user from Firestore (ADR-075).
///
/// Returns an empty list for anonymous or unauthenticated users.
final merchOrdersProvider = FutureProvider<List<MerchOrderSummary>>((ref) async {
  final userAsync = ref.watch(authStateProvider);
  final user = userAsync.valueOrNull;
  if (user == null) return const [];

  final snapshot = await FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('merch_configs')
      .orderBy('createdAt', descending: true)
      .limit(20)
      .get();

  return snapshot.docs
      .map((doc) => MerchOrderSummary.fromDoc(doc.id, doc.data()))
      .toList();
});

// ── Screen ─────────────────────────────────────────────────────────────────────

/// Displays the user's past merch orders from Firestore.
///
/// Entry point: PrivacyAccountScreen → "My orders" tile.
class MerchOrdersScreen extends ConsumerWidget {
  const MerchOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(authStateProvider);
    final user = userAsync.valueOrNull;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My orders')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              'Sign in to view your orders.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final ordersAsync = ref.watch(merchOrdersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My orders')),
      body: ordersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load orders: $e')),
        data: (orders) {
          if (orders.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No orders yet. Head to the Shop to order your first '
                  'personalised item.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.separated(
            itemCount: orders.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) => _OrderTile(order: orders[i]),
          );
        },
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  const _OrderTile({required this.order});

  final MerchOrderSummary order;

  @override
  Widget build(BuildContext context) {
    final date = _formatDate(order.createdAt);
    final n = order.countryCount;
    final noun = n == 1 ? 'country' : 'countries';

    return ListTile(
      title: Text(order.productName),
      subtitle: Text('$n $noun · $date'),
      trailing: _StatusBadge(status: order.status),
    );
  }

  String _formatDate(DateTime dt) {
    final months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${dt.day} ${months[dt.month]} ${dt.year}';
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = _resolve(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
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

  static (String, Color) _resolve(String status) {
    if (status.endsWith('_error')) return ('Error', Colors.red);
    if (status == 'ordered' || status == 'print_file_submitted') {
      return ('Processing', const Color(0xFFFFB300));
    }
    return ('In progress', Colors.grey);
  }
}
