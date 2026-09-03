import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../merch/merch_orders_screen.dart' show MerchOrdersScreen;
import '../merch/merch_share_exporter.dart';

/// **After the purchase** — what happens once the order exists.
///
/// A shirt made out of somebody's travels is a brag, not a transaction, and
/// the minute after buying is when they most want to show it. Ending on a
/// confirmation with nowhere to go wastes that, and leaves the buyer with no
/// route to their own order.
///
/// So three things, in the order they are wanted: show it, track it, and the
/// reassurance that it is kept.
class AfterPurchaseSheet extends StatelessWidget {
  const AfterPurchaseSheet({super.key, required this.artworkBytes, this.title});

  /// The design as printed — what gets shared.
  final Uint8List artworkBytes;
  final String? title;

  static Future<void> show(
    BuildContext context, {
    required Uint8List artworkBytes,
    String? title,
  }) => showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFF1A1C21),
    showDragHandle: true,
    builder:
        (_) => AfterPurchaseSheet(artworkBytes: artworkBytes, title: title),
  );

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ON ITS WAY',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1.4,
              color: Colors.tealAccent,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title == null
                ? 'Your shirt is being made.'
                : '“$title” is being made.',
            style: const TextStyle(fontSize: 16, color: Colors.white),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const Key('v2-after-share'),
            onPressed: () => _share(context),
            icon: const Icon(Icons.ios_share_rounded, size: 18),
            label: const Text('Share your design'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.tealAccent,
              foregroundColor: Colors.black,
              minimumSize: const Size.fromHeight(46),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            key: const Key('v2-after-track'),
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const MerchOrdersScreen(),
                ),
              );
            },
            icon: const Icon(Icons.local_shipping_outlined, size: 18),
            label: const Text('Track your order'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white24),
              minimumSize: const Size.fromHeight(44),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Saved to Your designs — order it again any time without '
            'rebuilding it.',
            style: TextStyle(fontSize: 11, color: Colors.white38),
          ),
        ],
      ),
    ),
  );

  Future<void> _share(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    final origin =
        box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size; // iPad popover anchor
    final ok = await MerchShareExporter.share(
      artworkBytes,
      title: title ?? 'My Travel Design',
      shareText: 'My travel design, made with Roavvy 🌍',
      sharePositionOrigin: origin,
    );
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Couldn’t open the share sheet. Please try again.'),
        ),
      );
    }
  }
}
