import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_models/shared_models.dart';

import '../../core/providers.dart';
import 'card_editor_screen.dart';
import 'card_templates.dart';
import 'front_ribbon_card.dart';
import 'timeline_card.dart';

/// First screen in the Create Card flow.
///
/// Shows a horizontal carousel of card-type tiles, each with a live scaled-down
/// preview of that type using the user's actual travel data. Tapping a tile
/// pushes [CardEditorScreen] with that type pre-selected (ADR-119).
class CardTypePickerScreen extends ConsumerWidget {
  const CardTypePickerScreen({super.key});

  static const _types = [
    CardTemplateType.grid,
    CardTemplateType.heart,
    CardTemplateType.passport,
    CardTemplateType.timeline,
  ];

  static const _labels = {
    CardTemplateType.grid: 'Flag Grid',
    CardTemplateType.heart: 'Heart',
    CardTemplateType.passport: 'Passport',
    CardTemplateType.timeline: 'Timeline',
  };

  static const _taglines = {
    CardTemplateType.grid: 'All your flags, side by side',
    CardTemplateType.heart: 'Your travels, made with love',
    CardTemplateType.passport: 'Authentic stamp collection',
    CardTemplateType.timeline: 'Your journey through time',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visitsAsync = ref.watch(effectiveVisitsProvider);
    final tripsAsync = ref.watch(tripListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Create Card')),
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

          final allCodes =
              visits.map((v) => v.countryCode).toList()..sort();
          final allTrips = tripsAsync.valueOrNull
                  ?.where((t) => allCodes.contains(t.countryCode))
                  .toList() ??
              [];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Choose a style',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  '${allCodes.length} '
                  '${allCodes.length == 1 ? 'country' : 'countries'} ready',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white54,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  itemCount: _types.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 16),
                  itemBuilder: (context, index) {
                    final type = _types[index];
                    return _CardTypeTile(
                      type: type,
                      label: _labels[type]!,
                      tagline: _taglines[type]!,
                      countryCodes: allCodes,
                      trips: allTrips,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              CardEditorScreen(templateType: type),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// A single tile in the card-type carousel.
class _CardTypeTile extends StatelessWidget {
  const _CardTypeTile({
    required this.type,
    required this.label,
    required this.tagline,
    required this.countryCodes,
    required this.trips,
    required this.onTap,
  });

  final CardTemplateType type;
  final String label;
  final String tagline;
  final List<String> countryCodes;
  final List<TripRecord> trips;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final tileWidth = math.min(screenWidth * 0.72, 280.0);

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: tileWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Card preview — scaled to fill tile
                    FittedBox(
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        width: 300,
                        child: _buildPreview(),
                      ),
                    ),
                    // Bottom gradient overlay
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 72,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.65),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Forward arrow
                    Positioned(
                      right: 14,
                      bottom: 14,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_forward,
                          size: 15,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              tagline,
              style: const TextStyle(fontSize: 12, color: Colors.white54),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    const aspectRatio = 2.0 / 3.0;
    switch (type) {
      case CardTemplateType.grid:
        return GridFlagsCard(
          countryCodes: countryCodes,
          aspectRatio: aspectRatio,
          dateLabel: '',
        );
      case CardTemplateType.heart:
        return HeartFlagsCard(
          countryCodes: countryCodes,
          trips: trips,
          aspectRatio: aspectRatio,
          dateLabel: '',
        );
      case CardTemplateType.passport:
        return PassportStampsCard(
          countryCodes: countryCodes,
          trips: trips,
          forPrint: false,
          aspectRatio: aspectRatio,
          dateLabel: '',
        );
      case CardTemplateType.timeline:
        return ColoredBox(
          color: Colors.white,
          child: TimelineCard(
            trips: trips,
            countryCodes: countryCodes,
            aspectRatio: aspectRatio,
            dateLabel: '',
            transparentBackground: true,
          ),
        );
      case CardTemplateType.frontRibbon:
        return FrontRibbonCard(
          countryCodes: countryCodes,
          travelerLevel: 'Explorer',
        );
    }
  }
}
