import 'package:design_studio/design_studio.dart';
import 'package:flutter/material.dart' hide Orientation;
import 'package:design_forge/design_forge.dart' show Orientation;

import '../commerce/garment_cart_request.dart';

/// **Review** workspace (M8) — the purchase-oriented final step. It consumes the
/// existing [StudioController]/GarmentDesign session (no new model) and presents
/// a calm, purchase-focused summary: BOTH real faces (Front/Back), the shirt
/// colour, the travel summary, and the chosen Direction / Detail / Vibe / title /
/// front configuration / artwork orientation & size — WITHOUT re-exposing any
/// Fine-Tune complexity.
///
/// It offers two actions:
///  * **Save design** → [StudioController.saveGarment] (idempotent; persists
///    both faces so the design reproduces deterministically later).
///  * **Add to cart** → renders the hero (back) face to a transparent print PNG,
///    builds a neutral [GarmentCartRequest], and hands it to the injected
///    [onAddToCart]. The host adapter maps that onto the EXISTING merch cart /
///    checkout / Printful flow — Studio V2 never touches commerce itself. The
///    persistent hero preview above stays the live shirt at all times.
///
/// Workflow Back (the app bar) returns to editing with the whole design state
/// intact — Review mutates nothing except via the shared controller.
class ReviewWorkspace extends StatefulWidget {
  const ReviewWorkspace({
    super.key,
    required this.controller,
    this.onAddToCart,
  });

  final StudioController controller;

  /// Injected by the host. Null in dev/test builds with no commerce wired — the
  /// Add-to-cart button then explains it is unavailable instead of failing.
  final AddToCartCallback? onAddToCart;

  @override
  State<ReviewWorkspace> createState() => _ReviewWorkspaceState();
}

class _ReviewWorkspaceState extends State<ReviewWorkspace> {
  StudioController get _c => widget.controller;
  bool _busy = false;
  bool _saved = false;

  // The V2 hero is the main artwork → it prints on the BACK; the front face is
  // the chest ribbon. Placement is expressed in the existing commerce vocabulary.
  String get _frontPosition => switch (_c.frontFit) {
        FrontFit.full => 'center',
        FrontFit.chest => _c.chestRight ? 'right_chest' : 'left_chest',
        FrontFit.none => 'none',
      };
  String get _backPosition => 'center';

  double get _aspectRatio => switch (_c.current.composition.orientation) {
        Orientation.portrait => 4 / 5,
        Orientation.landscape => 5 / 4,
        Orientation.square => 1.0,
      };

  Future<void> _save() async {
    _c.saveGarment();
    if (!mounted) return;
    setState(() => _saved = true);
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Design saved to your library')));
  }

  Future<void> _addToCart() async {
    final cb = widget.onAddToCart;
    if (cb == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Cart is not available in this build')));
      return;
    }
    setState(() => _busy = true);
    // The hero (back) face is the print file for the shirt back; render it
    // LAZILY (transparent, print-resolution PNG) so the host controls exactly
    // when the expensive rasterise runs.
    final hero = _c.hero;
    final service = _c.service;
    // The front (chest) face is the real V2 front artwork — render it lazily too
    // so it, not the V1 flag ribbon, becomes the front print. A blank front
    // (FrontFit.none) carries no front render, so the shirt front stays empty.
    final frontFace = _c.frontFace;
    final hasFrontPrint = _c.frontFit != FrontFit.none;
    final req = GarmentCartRequest(
      garment: _c.garment,
      renderBackArtwork: () async =>
          (await service.renderArtwork(hero)).pngBytes,
      renderFrontArtwork: hasFrontPrint
          ? () async => (await service.renderArtwork(frontFace)).pngBytes
          : null,
      garmentColourHex: _c.hero.palette?.garmentColour,
      garmentColourName: _c.garmentName,
      selectedCountryCodes: _c.selectedCountryCodes.toList(),
      trips: _c.context.trips,
      frontPosition: _frontPosition,
      backPosition: _backPosition,
      aspectRatio: _aspectRatio,
      title: _c.currentTitle.isEmpty ? null : _c.currentTitle,
    );
    try {
      await cb(context, req);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _c.currentTitle;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('REVIEW',
              style: TextStyle(
                  fontSize: 11, letterSpacing: 1.4, color: Colors.tealAccent)),
          const SizedBox(height: 4),
          const Text('Both sides, ready to order. Switch Front/Back to check '
              'each face, then save or add to cart.',
              style: TextStyle(fontSize: 13, color: Colors.white70)),
          const SizedBox(height: 12),

          // ── Front / Back review switch (both real rendered faces) ──
          Row(children: [
            _sideBtn('v2-review-side-back', 'Back', !_c.onFront,
                () => _c.setSide(false)),
            const SizedBox(width: 8),
            _sideBtn('v2-review-side-front', 'Front', _c.onFront,
                () => _c.setSide(true)),
            const Spacer(),
            Text(_c.onFront ? 'Front' : 'Back',
                style: const TextStyle(fontSize: 11, color: Colors.white38)),
          ]),
          const SizedBox(height: 14),

          // ── Purchase summary (reads real design state; no Fine-Tune knobs) ──
          if (title.trim().isNotEmpty) ...[
            _summaryRow('Title', title),
            const SizedBox(height: 8),
          ],
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final chip in _c.reviewSpec()) _specChip(chip),
            ],
          ),
          const SizedBox(height: 20),

          // ── Actions ──
          Row(children: [
            OutlinedButton.icon(
              key: const Key('v2-review-save'),
              onPressed: _busy ? null : _save,
              icon: Icon(_saved ? Icons.check : Icons.bookmark_border, size: 18),
              label: Text(_saved ? 'Saved' : 'Save design'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Color(0xFF3A3D44)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                key: const Key('v2-review-addtocart'),
                onPressed: _busy ? null : _addToCart,
                icon: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.shopping_bag_outlined, size: 18),
                label: const Text('Add to cart'),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          const Text('Shirt size and quantity are chosen at checkout.',
              style: TextStyle(fontSize: 11, color: Colors.white38)),
        ],
      ),
    );
  }

  Widget _sideBtn(String key, String label, bool selected, VoidCallback onTap) =>
      GestureDetector(
        key: Key(key),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: selected
                ? Colors.tealAccent.withValues(alpha: 0.2)
                : const Color(0xFF23262C),
            border: Border.all(
                color: selected ? Colors.tealAccent : const Color(0xFF3A3D44)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: selected ? Colors.tealAccent : Colors.white70)),
        ),
      );

  Widget _specChip(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF1B1E24),
          border: Border.all(color: const Color(0xFF2E3138)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(text,
            style: const TextStyle(fontSize: 12, color: Colors.white70)),
      );

  Widget _summaryRow(String label, String value) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 56,
            child: Text(label,
                style: const TextStyle(fontSize: 11, color: Colors.white38)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      );
}
