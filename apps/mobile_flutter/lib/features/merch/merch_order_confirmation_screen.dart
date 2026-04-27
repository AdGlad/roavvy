import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:shared_models/shared_models.dart';
import 'package:url_launcher/url_launcher.dart';

// Colour swatches — mirrors _kSwatchColours in local_mockup_preview_screen.dart.
const _swatchColours = <String, Color>{
  'Black': Color(0xFF1A1A1A),
  'White': Color(0xFFF5F5F5),
  'Blue':  Color(0xFF1A2C5B),
  'Grey':  Color(0xFFB0B0B0),
  'Red':   Color(0xFFCC1717),
};

// ── Screen ────────────────────────────────────────────────────────────────────

/// Mandatory full-screen order review inserted between [_MockupState.ready] and
/// Shopify checkout (ADR-131 / M85).
///
/// All order data is passed as immutable constructor params at push time — the
/// screen holds no references to the parent's mutable state. A checkbox gates
/// the "Proceed to Checkout" button; Go Back returns to the mockup view.
class MerchOrderConfirmationScreen extends StatefulWidget {
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
  State<MerchOrderConfirmationScreen> createState() =>
      _MerchOrderConfirmationScreenState();
}

class _MerchOrderConfirmationScreenState
    extends State<MerchOrderConfirmationScreen> {
  bool _confirmed = false;

  Future<void> _launchCheckout() async {
    final uri = Uri.parse(widget.checkoutUrl);
    if (!await launchUrl(uri, mode: LaunchMode.inAppBrowserView)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open checkout')),
      );
      return;
    }
    widget.onCheckoutLaunched?.call();
  }

  @override
  Widget build(BuildContext context) {
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
                  const _WarningBox(),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    value: _confirmed,
                    onChanged: (v) => setState(() => _confirmed = v ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text(
                      'I confirm the size, colour, design, and print positions '
                      'shown above are correct.',
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          _ActionRow(
            confirmed: _confirmed,
            onGoBack: () => Navigator.of(context).pop(),
            onProceed: _launchCheckout,
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
                  color: _page == i
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

  List<Widget> _buildPages() {
    final pages = <Widget>[];

    if (widget.frontMockupUrl != null) {
      pages.add(Image.network(
        widget.frontMockupUrl!,
        fit: BoxFit.contain,
        loadingBuilder: (_, child, progress) => progress == null
            ? child
            : const Center(child: CircularProgressIndicator()),
        errorBuilder: (_, __, ___) => _localFallback(front: true),
      ));
    } else {
      pages.add(_localFallback(front: true));
    }

    if (widget.backMockupUrl != null) {
      pages.add(Image.network(
        widget.backMockupUrl!,
        fit: BoxFit.contain,
        loadingBuilder: (_, child, progress) => progress == null
            ? child
            : const Center(child: CircularProgressIndicator()),
        errorBuilder: (_, __, ___) => _localFallback(front: false),
      ));
    }

    return pages;
  }

  Widget _localFallback({required bool front}) {
    final bytes = front
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
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: child,
      ),
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
                        border: Border.all(
                          color: Colors.black26,
                          width: 0.5,
                        ),
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
        'center'      => 'Centre',
        'left_chest'  => 'Left Chest',
        'right_chest' => 'Right Chest',
        _             => 'None',
      };

  static String _templateLabel(CardTemplateType type) => switch (type) {
        CardTemplateType.passport    => 'Passport Stamps',
        CardTemplateType.grid        => 'Flag Grid',
        CardTemplateType.heart       => 'Heart Flags',
        CardTemplateType.timeline    => 'Travel Log',
        CardTemplateType.frontRibbon => 'Front Ribbon',
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
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
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

// ── Warning box ───────────────────────────────────────────────────────────────

class _WarningBox extends StatelessWidget {
  const _WarningBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        border: Border.all(color: Colors.amber.shade600),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: Colors.amber.shade800, size: 20),
              const SizedBox(width: 8),
              Text(
                'Custom-Made Product',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.amber.shade900,
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

// ── Action row ────────────────────────────────────────────────────────────────

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.confirmed,
    required this.onGoBack,
    required this.onProceed,
  });

  final bool confirmed;
  final VoidCallback onGoBack;
  final VoidCallback onProceed;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(
          children: [
            TextButton(
              onPressed: onGoBack,
              child: const Text('Go Back'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: confirmed ? onProceed : null,
                child: const Text('Proceed to Checkout'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
