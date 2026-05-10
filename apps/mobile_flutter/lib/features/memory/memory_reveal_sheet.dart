import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_models/shared_models.dart';

import '../../core/country_names.dart';
import '../../core/providers.dart';
import '../journal/trip_detail_screen.dart';
import '../merch/pulse_merch_option_screen.dart';
import '../shared/hero_image_view.dart';
import 'memory_pulse_service.dart';
import 'memory_share_service.dart';

/// Full-screen modal bottom sheet with a two-phase memory reveal (M95).
///
/// Phase 1 (question): large centred question, hint text, amber "Reveal" button.
/// Phase 2 (revealed): hero image animates in (350ms FadeTransition +
/// SlideTransition), overlaid with flag, country, date, label chips, share
/// button, and "View trip" link.
///
/// Drag-to-dismiss is provided by [showModalBottomSheet] default behaviour.
class MemoryRevealSheet extends ConsumerStatefulWidget {
  const MemoryRevealSheet({
    super.key,
    required this.hero,
    required this.yearsAgo,
    required this.question,
    required this.service,
  });

  final HeroImage hero;
  final int yearsAgo;
  final String question;
  final MemoryPulseService service;

  /// Convenience factory: builds the question and shows the bottom sheet.
  static Future<void> show(
    BuildContext context, {
    required HeroImage hero,
    required int yearsAgo,
    required MemoryPulseService service,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFF0D1B2A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => MemoryRevealSheet(
        hero: hero,
        yearsAgo: yearsAgo,
        question: service.buildQuestion(hero, yearsAgo),
        service: service,
      ),
    );
  }

  @override
  ConsumerState<MemoryRevealSheet> createState() => _MemoryRevealSheetState();
}

class _MemoryRevealSheetState extends ConsumerState<MemoryRevealSheet>
    with SingleTickerProviderStateMixin {
  bool _revealed = false;
  late final AnimationController _controller;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _reveal() {
    setState(() => _revealed = true);
    _controller.forward();
    widget.service.markRevealed(widget.hero.tripId, DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollController) => SingleChildScrollView(
        controller: scrollController,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 32),

              // Question text (always visible)
              Text(
                widget.question,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  height: 1.35,
                ),
              ),

              if (!_revealed) ...[
                const SizedBox(height: 16),
                const Text(
                  'Tap to reveal your memory',
                  style: TextStyle(color: Colors.white38, fontSize: 14),
                ),
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: _reveal,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 14,
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  child: const Text('Reveal'),
                ),
              ],

              if (_revealed) ...[
                const SizedBox(height: 24),
                FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: _RevealedContent(
                      hero: widget.hero,
                      yearsAgo: widget.yearsAgo,
                      screenWidth: screenWidth,
                      service: widget.service,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Revealed content ──────────────────────────────────────────────────────────

class _RevealedContent extends ConsumerWidget {
  const _RevealedContent({
    required this.hero,
    required this.yearsAgo,
    required this.screenWidth,
    required this.service,
  });

  final HeroImage hero;
  final int yearsAgo;
  final double screenWidth;
  final MemoryPulseService service;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countryName = kCountryNames[hero.countryCode] ?? hero.countryCode;
    final flagEmoji = _flagEmoji(hero.countryCode);
    final dateStr = _formatDate(hero.capturedAt, yearsAgo);
    final topLabels = [
      if (hero.primaryScene != null) hero.primaryScene!,
      ...hero.mood.take(1),
    ].take(2).toList();

    final physicalWidth = (screenWidth * MediaQuery.devicePixelRatioOf(context)).toInt();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Hero image with gradient overlay
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 260,
            child: Stack(
              fit: StackFit.expand,
              children: [
                HeroImageView(
                  assetId: hero.assetId,
                  fallbackColor: const Color(0xFF2D4A5F),
                  height: 260,
                  thumbnailSize: ThumbnailSize(physicalWidth, physicalWidth * 2),
                ),
                // Bottom gradient
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 120,
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Color(0xCC000000), Colors.transparent],
                      ),
                    ),
                  ),
                ),
                // Flag + country
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 36,
                  child: Text(
                    '$flagEmoji  $countryName',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Date string
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: Text(
                    dateStr,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Label chips
        if (topLabels.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: topLabels
                .map(
                  (l) => Chip(
                    label: Text(
                      l.replaceAll('_', ' '),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    backgroundColor: Colors.white12,
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                )
                .toList(),
          ),
        ],

        const SizedBox(height: 24),

        // Share button
        FilledButton.icon(
          onPressed: () => MemoryShareService.generateAndShare(context, hero),
          icon: const Icon(Icons.share_outlined),
          label: const Text('Share memory'),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.amber,
            foregroundColor: Colors.black87,
          ),
        ),

        const SizedBox(height: 8),

        // Print merch CTA
        _PrintMerchButton(hero: hero),

        const SizedBox(height: 8),

        // View trip
        _ViewTripButton(tripId: hero.tripId),
      ],
    );
  }

  static String _flagEmoji(String code) {
    const base = 0x1F1E6 - 0x41;
    return String.fromCharCode(base + code.codeUnitAt(0)) +
        String.fromCharCode(base + code.codeUnitAt(1));
  }

  static String _formatDate(DateTime dt, int yearsAgo) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    final yearsWord = yearsAgo == 1 ? '1 year ago' : '$yearsAgo years ago';
    return '${dt.day} ${months[dt.month - 1]} ${dt.year} · $yearsWord';
  }
}

// ── Print merch button ────────────────────────────────────────────────────────

class _PrintMerchButton extends ConsumerWidget {
  const _PrintMerchButton({required this.hero});

  final HeroImage hero;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trips = ref.watch(tripListProvider).valueOrNull ?? const [];
    final allVisits =
        ref.watch(effectiveVisitsProvider).valueOrNull ?? const [];

    return OutlinedButton.icon(
      onPressed: () {
        Navigator.of(context).pop();
        Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => PulseMerchOptionScreen(
            hero: hero,
            allTrips: trips,
            allVisits: allVisits,
          ),
        ));
      },
      icon: const Icon(Icons.checkroom_outlined),
      label: const Text('Print on a t-shirt'),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white70,
        side: const BorderSide(color: Colors.white24),
      ),
    );
  }
}

// ── View trip button ──────────────────────────────────────────────────────────

class _ViewTripButton extends ConsumerWidget {
  const _ViewTripButton({required this.tripId});

  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripsAsync = ref.watch(tripListProvider);

    return TextButton(
      onPressed: tripsAsync.valueOrNull == null
          ? null
          : () {
              final trip = tripsAsync.value!
                  .where((t) => t.id == tripId)
                  .firstOrNull;
              if (trip == null || !context.mounted) return;
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => TripDetailScreen(trip: trip),
                ),
              );
            },
      child: const Text(
        'View trip',
        style: TextStyle(color: Colors.white54),
      ),
    );
  }
}
