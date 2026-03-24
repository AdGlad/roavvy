import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import 'merch_product_browser_screen.dart';

/// Post-purchase celebration screen shown after the user returns from Shopify
/// checkout (ADR-074).
///
/// Optimistic — assumes purchase completed. Shopify sends the real confirmation
/// email; this screen is a celebration prompt. Blocks back navigation so the
/// user must tap "Back to my map" to return cleanly to the map.
class MerchPostPurchaseScreen extends StatefulWidget {
  const MerchPostPurchaseScreen({
    super.key,
    required this.product,
    required this.countryCount,
  });

  final MerchProduct product;
  final int countryCount;

  @override
  State<MerchPostPurchaseScreen> createState() =>
      _MerchPostPurchaseScreenState();
}

class _MerchPostPurchaseScreenState extends State<MerchPostPurchaseScreen> {
  late final ConfettiController _confetti;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 4));
    final reduceMotion = WidgetsBinding.instance.platformDispatcher.accessibilityFeatures
        .reduceMotion;
    if (!reduceMotion) {
      _confetti.play();
    }
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  void _shareOrder(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    final origin = box != null
        ? box.localToGlobal(Offset.zero) & box.size
        : Rect.fromLTWH(0, 0, 1, 1);
    Share.share(
      'Just ordered a ${widget.product.name} with all ${widget.countryCount} '
      "countries I've visited — made with Roavvy 🌍",
      sharePositionOrigin: origin,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final n = widget.countryCount;
    final noun = n == 1 ? 'country' : 'countries';

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Order placed'),
        ),
        body: Stack(
          alignment: Alignment.topCenter,
          children: [
            // Confetti burst from top centre
            ConfettiWidget(
              confettiController: _confetti,
              blastDirectionality: BlastDirectionality.explosive,
              emissionFrequency: 0.05,
              numberOfParticles: 20,
              gravity: 0.1,
              colors: const [
                Color(0xFFFFB300),
                Color(0xFF4CAF50),
                Color(0xFF2196F3),
                Color(0xFFE91E63),
              ],
            ),

            // Main content
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      '🎉',
                      style: TextStyle(fontSize: 72),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Your order is on its way!',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "You'll receive a confirmation email shortly.\n"
                      'Your ${widget.product.name} is being made with '
                      'your $n $noun.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.of(context)
                            .popUntil((route) => route.isFirst),
                        child: const Text('Back to my map'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: Builder(
                        builder: (btnCtx) => OutlinedButton(
                          onPressed: () => _shareOrder(btnCtx),
                          child: const Text('Share my order'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
