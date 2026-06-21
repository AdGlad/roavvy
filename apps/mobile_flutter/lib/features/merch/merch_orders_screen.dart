import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import 'local_mockup_preview_screen.dart';
import 'merch_preset.dart';
import 'merch_template_ranker.dart';

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
    this.selectedCountryCodes = const [],
    this.thumbnailUrl,
  });

  final String configId;
  final String productName;
  final int countryCount;
  final DateTime createdAt;

  /// Raw status string from Firestore (e.g. 'cart_created', 'ordered').
  final String status;

  /// Country codes from the original order — used for "Design again" (M120).
  final List<String> selectedCountryCodes;

  /// Front mockup URL — shown as thumbnail in the collection card (M141).
  final String? thumbnailUrl;

  factory MerchOrderSummary.fromDoc(String id, Map<String, dynamic> data) {
    // Use stored design title if available; fall back to product type name.
    final variantId = data['variantId'] as String? ?? '';
    final productName = data['title'] as String? ??
        data['designTitle'] as String? ??
        (variantId.contains('Poster') ? 'Travel Poster' : 'Travel T-shirt');

    final codesRaw = data['selectedCountryCodes'];
    final codes = codesRaw is List ? codesRaw.cast<String>() : <String>[];
    final countryCount = codes.length;

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
      selectedCountryCodes: codes,
      thumbnailUrl: data['frontMockupUrl'] as String?,
    );
  }
}

// ── Provider ───────────────────────────────────────────────────────────────────

/// Reads up to 20 merch configs for the current user from Firestore (ADR-075).
///
/// Returns an empty list for anonymous or unauthenticated users.
final merchOrdersProvider = FutureProvider<List<MerchOrderSummary>>((
  ref,
) async {
  final userAsync = ref.watch(authStateProvider);
  final user = userAsync.valueOrNull;
  if (user == null) return const [];

  final snapshot =
      await FirebaseFirestore.instance
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
        appBar: AppBar(title: const Text('Order History')),
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

    return Scaffold(
      appBar: AppBar(title: const Text('Order History')),
      body: const MerchOrdersBody(),
    );
  }
}

/// Body-only orders widget — embeddable in tab views (e.g. MerchShopScreen).
class MerchOrdersBody extends ConsumerWidget {
  const MerchOrdersBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(authStateProvider);
    final user = userAsync.valueOrNull;

    if (user == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Sign in to view your orders.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final ordersAsync = ref.watch(merchOrdersProvider);

    return ordersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Could not load orders: $e')),
      data: (orders) {
        if (orders.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'Your travel collection is empty.\n\nEvery shirt you order appears '
                'here as a permanent record of your adventures.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 16),
          itemCount: orders.length,
          itemBuilder: (context, i) => _OrderCard(order: orders[i]),
        );
      },
    );
  }
}

class _OrderCard extends ConsumerWidget {
  const _OrderCard({required this.order});

  final MerchOrderSummary order;

  static String _fmt(DateTime dt) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${dt.day} ${months[dt.month]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final date = _fmt(order.createdAt);
    final n = order.countryCount;
    final noun = n == 1 ? 'country' : 'countries';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => _OrderDetailScreen(order: order),
          ),
        ),
        child: Row(
          children: [
            _OrderThumbnail(url: order.thumbnailUrl),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.productName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$n $noun · $date',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _StatusBadge(status: order.status),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(Icons.chevron_right),
            ),
          ],
        ),
      ),
    );
  }

}

// ── Order detail screen ────────────────────────────────────────────────────────

class _OrderDetailScreen extends ConsumerWidget {
  const _OrderDetailScreen({required this.order});

  final MerchOrderSummary order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final n = order.countryCount;
    final noun = n == 1 ? 'country' : 'countries';
    final canDesignAgain = order.selectedCountryCodes.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: Text(order.productName)),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Full-size mockup with pinch-to-zoom
                  if (order.thumbnailUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: AspectRatio(
                        aspectRatio: 3 / 4,
                        child: InteractiveViewer(
                          panEnabled: false,
                          minScale: 1.0,
                          maxScale: 4.0,
                          child: Image.network(
                            order.thumbnailUrl!,
                            fit: BoxFit.contain,
                            loadingBuilder: (_, child, p) => p == null
                                ? child
                                : const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                            errorBuilder: (_, __, ___) => Container(
                              color: theme.colorScheme.surfaceContainerHighest,
                              child: Icon(
                                Icons.dry_cleaning_outlined,
                                size: 80,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
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
                      child: Icon(
                        Icons.dry_cleaning_outlined,
                        size: 64,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  const SizedBox(height: 20),
                  // Order details
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
                          _DetailRow(
                            label: 'Status',
                            trailing: _StatusBadge(status: order.status),
                          ),
                          const SizedBox(height: 8),
                          _DetailRow(
                            label: 'Ordered',
                            value: _formatDate(order.createdAt),
                          ),
                          const SizedBox(height: 8),
                          _DetailRow(
                            label: 'Countries',
                            value: '$n $noun',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (canDesignAgain)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => _designAgain(context, ref),
                    child: const Text('Design again with these countries'),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _designAgain(BuildContext context, WidgetRef ref) async {
    final selectedCodes = order.selectedCountryCodes;
    if (selectedCodes.isEmpty) return;

    final visits = await ref.read(effectiveVisitsProvider.future);
    final trips = await ref.read(tripListProvider.future);
    final allCodes = visits.map((v) => v.countryCode).toList();

    if (!context.mounted) return;

    final ranks = MerchTemplateRanker.rankFor(codeCount: selectedCodes.length);
    final template = ranks
        .firstWhere((r) => !r.exclude, orElse: () => ranks.first)
        .template;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LocalMockupPreviewScreen(
          selectedCodes: selectedCodes,
          allCodes: allCodes,
          trips: trips,
          initialTemplate: template,
          initialPreset: MerchPreset(
            id: 'design_again',
            label: 'My Design',
            config: MerchPresetConfig(
              layout: template,
              source: MerchCountrySource.allTime,
              jitter: 0.4,
              density: MerchDensity.balanced,
              stampMode: MerchStampMode.entryExit,
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${dt.day} ${months[dt.month]} ${dt.year}';
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, this.value, this.trailing});

  final String label;
  final String? value;
  final Widget? trailing;

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
        trailing ??
            Text(
              value ?? '',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
      ],
    );
  }
}

class _OrderThumbnail extends StatelessWidget {
  const _OrderThumbnail({this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    const size = 80.0;
    final theme = Theme.of(context);
    final u = url;
    if (u != null && u.isNotEmpty) {
      return SizedBox(
        width: size,
        height: size,
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
    color: theme.colorScheme.surfaceContainerHighest,
    child: Icon(
      Icons.dry_cleaning_outlined,
      color: theme.colorScheme.onSurfaceVariant,
      size: 28,
    ),
  );
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
