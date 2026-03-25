import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_models/shared_models.dart';

import '../../core/providers.dart';
import '../merch/merch_product_browser_screen.dart';
import 'card_templates.dart';
import 'travel_card_service.dart';

/// Full-screen card generator: pick a template, preview it, and share.
///
/// Entry points: Stats screen "Create card" button + Map "⋮" menu item (ADR-092).
class CardGeneratorScreen extends ConsumerStatefulWidget {
  const CardGeneratorScreen({super.key});

  @override
  ConsumerState<CardGeneratorScreen> createState() =>
      _CardGeneratorScreenState();
}

class _CardGeneratorScreenState extends ConsumerState<CardGeneratorScreen> {
  CardTemplateType _selected = CardTemplateType.grid;
  final _previewKey = GlobalKey();
  bool _sharing = false;

  @override
  Widget build(BuildContext context) {
    final visitsAsync = ref.watch(effectiveVisitsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Create card')),
      body: visitsAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator.adaptive()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (visits) {
          if (visits.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Scan your photos to generate a card',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.white54),
                ),
              ),
            );
          }

          final codes = visits.map((v) => v.countryCode).toList()..sort();

          return Column(
            children: [
              const SizedBox(height: 16),
              _TemplatePicker(
                selected: _selected,
                onChanged: (t) => setState(() => _selected = t),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Center(
                    child: RepaintBoundary(
                      key: _previewKey,
                      child: _buildTemplate(codes),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _ActionBar(
                sharing: _sharing,
                onShare: () => _onShare(context, codes),
                onPrint: () => _onPrint(context, codes),
              ),
              SizedBox(height: MediaQuery.paddingOf(context).bottom + 16),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTemplate(List<String> codes) {
    switch (_selected) {
      case CardTemplateType.grid:
        return GridFlagsCard(countryCodes: codes);
      case CardTemplateType.heart:
        return HeartFlagsCard(countryCodes: codes);
      case CardTemplateType.passport:
        return PassportStampsCard(countryCodes: codes);
    }
  }

  Future<void> _onShare(BuildContext context, List<String> codes) async {
    if (_sharing) return;
    setState(() => _sharing = true);

    try {
      // Capture the visible RepaintBoundary.
      final boundary =
          _previewKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final bytes = byteData.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/roavvy_travel_card.png');
      await file.writeAsBytes(bytes);

      // Persist card to Firestore (fire-and-forget; ADR-092).
      final uid = ref.read(currentUidProvider);
      if (uid != null) {
        final card = TravelCard(
          cardId: 'card-${DateTime.now().microsecondsSinceEpoch}',
          userId: uid,
          templateType: _selected,
          countryCodes: codes,
          countryCount: codes.length,
          createdAt: DateTime.now().toUtc(),
        );
        unawaited(TravelCardService(FirebaseFirestore.instance).create(card));
      }

      if (!context.mounted) return;
      final size = MediaQuery.sizeOf(context);
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'My Roavvy travel card',
        sharePositionOrigin: Rect.fromLTWH(size.width / 2 - 22, size.height - 88, 44, 44),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  void _onPrint(BuildContext context, List<String> codes) {
    if (_sharing) return;

    // Persist card fire-and-forget so the order is traceable (ADR-093).
    final uid = ref.read(currentUidProvider);
    String? cardId;
    if (uid != null) {
      cardId = 'card-${DateTime.now().microsecondsSinceEpoch}';
      final card = TravelCard(
        cardId: cardId,
        userId: uid,
        templateType: _selected,
        countryCodes: codes,
        countryCount: codes.length,
        createdAt: DateTime.now().toUtc(),
      );
      unawaited(TravelCardService(FirebaseFirestore.instance).create(card));
    }

    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => MerchProductBrowserScreen(
        selectedCodes: codes,
        cardId: cardId,
      ),
    ));
  }
}

// ── Template picker ────────────────────────────────────────────────────────────

class _TemplatePicker extends StatelessWidget {
  const _TemplatePicker({required this.selected, required this.onChanged});

  final CardTemplateType selected;
  final ValueChanged<CardTemplateType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _Tile(
          label: 'Grid',
          type: CardTemplateType.grid,
          selected: selected == CardTemplateType.grid,
          onTap: () => onChanged(CardTemplateType.grid),
        ),
        const SizedBox(width: 12),
        _Tile(
          label: 'Heart',
          type: CardTemplateType.heart,
          selected: selected == CardTemplateType.heart,
          onTap: () => onChanged(CardTemplateType.heart),
        ),
        const SizedBox(width: 12),
        _Tile(
          label: 'Passport',
          type: CardTemplateType.passport,
          selected: selected == CardTemplateType.passport,
          onTap: () => onChanged(CardTemplateType.passport),
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.label,
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final CardTemplateType type;
  final bool selected;
  final VoidCallback onTap;

  static const _amber = Color(0xFFD4A017);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(
            color: selected ? _amber : Colors.white24,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: selected ? _amber.withValues(alpha: 0.12) : Colors.transparent,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? _amber : Colors.white70,
            fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

// ── Action bar ─────────────────────────────────────────────────────────────────

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.sharing,
    required this.onShare,
    required this.onPrint,
  });

  final bool sharing;
  final VoidCallback onShare;
  final VoidCallback onPrint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: sharing ? null : onShare,
              icon: sharing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                    )
                  : const Icon(Icons.share),
              label: const Text('Share'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: sharing ? null : onPrint,
              icon: const Icon(Icons.print_outlined),
              label: const Text('Print your card'),
            ),
          ),
        ],
      ),
    );
  }
}
