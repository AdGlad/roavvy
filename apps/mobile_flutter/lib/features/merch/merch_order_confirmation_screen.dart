import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_models/shared_models.dart';
import 'package:url_launcher/url_launcher.dart';

import 'merch_variant_lookup.dart';
import 'shopify_pricing_repository.dart';

// Colour swatches — mirrors _kSwatchColours in local_mockup_preview_screen.dart.
const _swatchColours = <String, Color>{
  'Black': Color(0xFF1A1A1A),
  'White': Color(0xFFF5F5F5),
  'Blue': Color(0xFF1A2C5B),
  'Grey': Color(0xFFB0B0B0),
  'Red': Color(0xFFCC1717),
};

// ── Screen ────────────────────────────────────────────────────────────────────

/// Mandatory full-screen order review inserted between [_MockupState.ready] and
/// Shopify checkout (ADR-131 / M85, M168).
///
/// All order data is passed as immutable constructor params at push time — the
/// screen holds no references to the parent's mutable state. A swipe-to-confirm
/// gesture gates the "Proceed to Checkout" action (M168). Price is shown above
/// the swipe widget (M168).
class MerchOrderConfirmationScreen extends ConsumerStatefulWidget {
  const MerchOrderConfirmationScreen({
    super.key,
    this.frontMockupUrl,
    this.backMockupUrl,
    this.frontArtworkBytes,
    required this.artworkBytes,
    required this.size,
    required this.colour,
    required this.frontPosition,
    required this.backPosition,
    required this.templateType,
    required this.checkoutUrl,
    required this.isTshirt,
    this.onCheckoutLaunched,
  });

  /// Printful front mockup URL. May be null if still generating.
  final String? frontMockupUrl;

  /// Printful back mockup URL. May be null when back print is disabled.
  final String? backMockupUrl;

  /// Front ribbon artwork bytes (used when frontPosition != 'none').
  /// Falls back to [artworkBytes] when null.
  final Uint8List? frontArtworkBytes;

  /// Back/main design artwork bytes — always present.
  final Uint8List artworkBytes;

  /// Selected t-shirt or poster size (e.g. 'L', '12x18in').
  final String size;

  /// Selected colour name (e.g. 'Black').
  final String colour;

  /// Front print position: 'center' | 'left_chest' | 'right_chest' | 'none'.
  final String frontPosition;

  /// Back print position: 'center' | 'none'.
  final String backPosition;

  /// Design template type.
  final CardTemplateType templateType;

  /// Shopify checkout URL — launched on confirmation.
  final String checkoutUrl;

  /// True for t-shirt; false for poster (hides size/colour on poster).
  final bool isTshirt;

  /// Called after checkout URL is successfully launched, so the parent can
  /// set its `_checkoutLaunched` flag and trigger the post-purchase poll.
  final VoidCallback? onCheckoutLaunched;

  @override
  ConsumerState<MerchOrderConfirmationScreen> createState() =>
      _MerchOrderConfirmationScreenState();
}

class _MerchOrderConfirmationScreenState
    extends ConsumerState<MerchOrderConfirmationScreen> {
  Future<void> _launchCheckout() async {
    if (!mounted) return;
    // Notify parent immediately (starts polling / marks cart started), then
    // replace this route with a non-poppable processing screen so the review
    // page is removed from the stack — the user cannot return here and
    // accidentally trigger a second checkout.
    widget.onCheckoutLaunched?.call();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => _CheckoutProcessingScreen(checkoutUrl: widget.checkoutUrl),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prices = ref.watch(shopifyPricingProvider);
    final priceStr = prices.whenOrNull(data: (p) => p.tshirtFromPrice) ??
        MerchProduct.tshirt.fromPrice;

    return Scaffold(
      appBar: AppBar(title: const Text('Review Your Order')),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _MockupSection(
                    frontMockupUrl: widget.frontMockupUrl,
                    backMockupUrl: widget.backMockupUrl,
                    frontArtworkBytes: widget.frontArtworkBytes,
                    artworkBytes: widget.artworkBytes,
                  ),
                  const SizedBox(height: 20),
                  _OrderSummaryCard(
                    colour: widget.colour,
                    size: widget.size,
                    frontPosition: widget.frontPosition,
                    backPosition: widget.backPosition,
                    templateType: widget.templateType,
                    isTshirt: widget.isTshirt,
                  ),
                  const SizedBox(height: 16),
                  const MerchCustomProductWarning(),
                  const SizedBox(height: 24),
                  // Price display (M168)
                  Center(
                    child: Text(
                      'from $priceStr',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Swipe-to-confirm gesture (M168)
                  _SwipeToConfirm(
                    label: 'Swipe to confirm order',
                    onComplete: _launchCheckout,
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Go Back'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Mockup section ────────────────────────────────────────────────────────────

class _MockupSection extends StatefulWidget {
  const _MockupSection({
    required this.frontMockupUrl,
    required this.backMockupUrl,
    required this.frontArtworkBytes,
    required this.artworkBytes,
  });

  final String? frontMockupUrl;
  final String? backMockupUrl;
  final Uint8List? frontArtworkBytes;
  final Uint8List artworkBytes;

  @override
  State<_MockupSection> createState() => _MockupSectionState();
}

class _MockupSectionState extends State<_MockupSection> {
  final PageController _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = _buildPages();

    if (pages.length == 1) {
      return _MockupFrame(child: pages.first);
    }

    return Column(
      children: [
        _MockupFrame(
          child: PageView(
            controller: _controller,
            onPageChanged: (i) => setState(() => _page = i),
            children: pages,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (int i = 0; i < pages.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: _page == i ? 20 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color:
                      _page == i
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            _page == 0 ? 'Front' : 'Back',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
      ],
    );
  }

  Widget _zoomable(Widget child) => InteractiveViewer(
    panEnabled: false,
    minScale: 1.0,
    maxScale: 4.0,
    child: child,
  );

  List<Widget> _buildPages() {
    final pages = <Widget>[];

    if (widget.frontMockupUrl != null) {
      pages.add(
        _zoomable(Image.network(
          widget.frontMockupUrl!,
          fit: BoxFit.contain,
          loadingBuilder:
              (_, child, progress) =>
                  progress == null
                      ? child
                      : const Center(child: CircularProgressIndicator()),
          errorBuilder: (_, __, ___) => _localFallback(front: true),
        )),
      );
    } else {
      pages.add(_zoomable(_localFallback(front: true)));
    }

    if (widget.backMockupUrl != null) {
      pages.add(
        _zoomable(Image.network(
          widget.backMockupUrl!,
          fit: BoxFit.contain,
          loadingBuilder:
              (_, child, progress) =>
                  progress == null
                      ? child
                      : const Center(child: CircularProgressIndicator()),
          errorBuilder: (_, __, ___) => _localFallback(front: false),
        )),
      );
    }

    return pages;
  }

  Widget _localFallback({required bool front}) {
    final bytes =
        front
            ? (widget.frontArtworkBytes ?? widget.artworkBytes)
            : widget.artworkBytes;
    return Image.memory(bytes, fit: BoxFit.contain);
  }
}

class _MockupFrame extends StatelessWidget {
  const _MockupFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(aspectRatio: 3 / 4, child: child),
    );
  }
}

// ── Order summary card ────────────────────────────────────────────────────────

class _OrderSummaryCard extends StatelessWidget {
  const _OrderSummaryCard({
    required this.colour,
    required this.size,
    required this.frontPosition,
    required this.backPosition,
    required this.templateType,
    required this.isTshirt,
  });

  final String colour;
  final String size;
  final String frontPosition;
  final String backPosition;
  final CardTemplateType templateType;
  final bool isTshirt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Order Details', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            if (isTshirt) ...[
              _SummaryRow(
                label: 'Colour',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: _swatchColours[colour] ?? Colors.grey,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black26, width: 0.5),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(colour),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              _SummaryRow(label: 'Size', value: size),
              const SizedBox(height: 8),
              _SummaryRow(
                label: 'Front print',
                value: _positionLabel(frontPosition),
              ),
              const SizedBox(height: 8),
              _SummaryRow(
                label: 'Back print',
                value: _positionLabel(backPosition),
              ),
            ] else ...[
              _SummaryRow(label: 'Size', value: size),
            ],
            const SizedBox(height: 8),
            _SummaryRow(label: 'Design', value: _templateLabel(templateType)),
          ],
        ),
      ),
    );
  }

  static String _positionLabel(String position) => switch (position) {
    'center' => 'Centre',
    'left_chest' => 'Left Chest',
    'right_chest' => 'Right Chest',
    _ => 'None',
  };

  static String _templateLabel(CardTemplateType type) => switch (type) {
    CardTemplateType.passport => 'Passport Stamps',
    CardTemplateType.grid => 'Flag Grid',
    CardTemplateType.heart => 'Heart Flags',
    CardTemplateType.timeline => 'Travel Log',
    CardTemplateType.frontRibbon => 'Front Ribbon',
    CardTemplateType.typography => 'Typography',
    CardTemplateType.badge => 'Explorer Badge',
    CardTemplateType.wordCloud => 'Word Cloud',
    CardTemplateType.landmark => 'Landmark',
  };
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, this.value, this.trailing});

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
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
      ],
    );
  }
}

// ── Warning box ───────────────────────────────────────────────────────────────

/// Amber warning box shown before checkout reminding users this is a
/// custom-made, non-refundable product. Shared between confirmation flows.
class MerchCustomProductWarning extends StatelessWidget {
  const MerchCustomProductWarning({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.amber.shade900.withValues(alpha: 0.20)
            : Colors.amber.shade50,
        border: Border.all(
          color: isDark
              ? Colors.amber.shade700.withValues(alpha: 0.60)
              : Colors.amber.shade600,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: isDark ? Colors.amber.shade300 : Colors.amber.shade800,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Custom-Made Product',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Please review every detail above carefully before continuing.\n\n'
            'This item is made to order — once payment is completed, '
            'we cannot offer refunds or exchanges for change of mind.\n\n'
            'You can still cancel during checkout.',
          ),
        ],
      ),
    );
  }
}

// ── Checkout processing screen ─────────────────────────────────────────────

/// Non-poppable screen shown immediately after "Proceed to Checkout" is tapped.
///
/// With [LaunchMode.inAppBrowserView] (SFSafariViewController), [launchUrl]
/// returns as soon as the in-app browser is presented — not when the user
/// closes it. Two states are shown:
///
/// - [_launching]: brief spinner while the browser is being opened.
/// - [_returned]: shown when the user closes the in-app browser; provides a
///   clear "View my orders" forward path so they are not left stranded on a
///   processing screen with no way to proceed.
class _CheckoutProcessingScreen extends StatefulWidget {
  const _CheckoutProcessingScreen({required this.checkoutUrl});
  final String checkoutUrl;

  @override
  State<_CheckoutProcessingScreen> createState() =>
      _CheckoutProcessingScreenState();
}

enum _CheckoutState { launching, returned, failed }

class _CheckoutProcessingScreenState extends State<_CheckoutProcessingScreen> {
  _CheckoutState _state = _CheckoutState.launching;

  @override
  void initState() {
    super.initState();
    Future.microtask(_openBrowser);
  }

  Future<void> _openBrowser() async {
    // Append return_to so Shopify's "Return to shopping" button sends the user
    // back via the roavvy:// scheme, which iOS handles by closing SFSafariViewController
    // and opening the app (navigating to the map via the app_links listener).
    final base = Uri.parse(widget.checkoutUrl);
    final uri = base.replace(
      queryParameters: {...base.queryParameters, 'return_to': 'roavvy://return'},
    );
    if (!mounted) return;
    final launched = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    if (!mounted) return;
    // launchUrl returns once SFSafariViewController is presented. Switch to
    // _returned so that when the user closes the in-app browser they see a
    // clear "View my orders" CTA rather than a spinner.
    setState(() => _state = launched ? _CheckoutState.returned : _CheckoutState.failed);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: switch (_state) {
                _CheckoutState.launching => Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 28),
                    Text(
                      'Opening checkout…',
                      style: theme.textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
                _CheckoutState.returned => Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle_outline_rounded, size: 56, color: Color(0xFFFFD700)),
                    const SizedBox(height: 20),
                    Text(
                      'Order placed!',
                      style: theme.textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Your custom t-shirt is being made. '
                      'We\'ll email you when it ships.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    FilledButton(
                      onPressed: () {
                        // Pop back to root (past the confirmation flow).
                        Navigator.of(context).popUntil((route) => route.isFirst);
                      },
                      child: const Text('Back to Roavvy'),
                    ),
                  ],
                ),
                _CheckoutState.failed => Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline_rounded, size: 48, color: theme.colorScheme.error),
                    const SizedBox(height: 20),
                    Text('Could not open checkout', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => setState(() {
                        _state = _CheckoutState.launching;
                        Future.microtask(_openBrowser);
                      }),
                      child: const Text('Try again'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                      child: const Text('Back to Roavvy'),
                    ),
                  ],
                ),
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ── Swipe-to-confirm widget (M168) ────────────────────────────────────────────

/// Horizontal swipe gesture that triggers [onComplete] at 85% drag distance.
/// Provides haptic feedback on completion.
class _SwipeToConfirm extends StatefulWidget {
  const _SwipeToConfirm({required this.label, required this.onComplete});

  final String label;
  final VoidCallback onComplete;

  @override
  State<_SwipeToConfirm> createState() => _SwipeToConfirmState();
}

class _SwipeToConfirmState extends State<_SwipeToConfirm> {
  double _dragFraction = 0.0;
  bool _completed = false;

  static const _thumbSize = 56.0;
  static const _trackHeight = 56.0;

  void _onDragUpdate(DragUpdateDetails details, double trackWidth) {
    if (_completed) return;
    final maxDrag = trackWidth - _thumbSize;
    if (maxDrag <= 0) return;
    final newOffset = (_dragFraction * maxDrag + details.delta.dx)
        .clamp(0.0, maxDrag);
    final newFraction = newOffset / maxDrag;
    setState(() => _dragFraction = newFraction);
    if (newFraction >= 0.85) _complete();
  }

  void _onDragEnd(DragEndDetails _) {
    if (_completed) return;
    setState(() => _dragFraction = 0.0);
  }

  void _complete() {
    if (_completed) return;
    setState(() {
      _completed = true;
      _dragFraction = 1.0;
    });
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 300), widget.onComplete);
  }

  @override
  Widget build(BuildContext context) {
    const kGold = Color(0xFFFFD700);
    final cs = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final trackWidth = constraints.maxWidth;
        final thumbOffset = _dragFraction * (trackWidth - _thumbSize);

        return GestureDetector(
          onHorizontalDragUpdate: (d) => _onDragUpdate(d, trackWidth),
          onHorizontalDragEnd: _onDragEnd,
          child: Container(
            height: _trackHeight,
            decoration: BoxDecoration(
              color: cs.surfaceContainer,
              borderRadius: BorderRadius.circular(_trackHeight / 2),
            ),
            child: Stack(
              children: [
                // Gold fill behind thumb
                AnimatedContainer(
                  duration: const Duration(milliseconds: 80),
                  width: thumbOffset + _thumbSize,
                  decoration: BoxDecoration(
                    color: kGold.withValues(alpha: (_dragFraction * 0.25).clamp(0, 0.25)),
                    borderRadius: BorderRadius.circular(_trackHeight / 2),
                  ),
                ),
                // Label — fades out as thumb moves right
                Center(
                  child: Opacity(
                    opacity: (1.0 - _dragFraction * 2.5).clamp(0.0, 1.0),
                    child: Text(
                      widget.label,
                      style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.54),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                // Draggable thumb
                Positioned(
                  left: thumbOffset,
                  top: 0,
                  bottom: 0,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 80),
                    width: _thumbSize,
                    decoration: BoxDecoration(
                      color: _completed ? kGold : kGold.withValues(alpha: 0.85),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _completed
                          ? Icons.check_rounded
                          : Icons.arrow_forward_rounded,
                      color: Colors.black87,
                      size: 24,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
