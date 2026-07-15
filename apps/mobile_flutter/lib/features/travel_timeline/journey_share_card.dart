import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_models/shared_models.dart';

import 'country_scene_icons.dart';

/// Off-screen share card for the Journey Share feature (M153).
///
/// Logical size: 360×640. Rendered at pixelRatio: 3 → 1080×1920 PNG.
class JourneyShareCard extends StatelessWidget {
  const JourneyShareCard({
    super.key,
    required this.countryCount,
    required this.continentCount,
    required this.sinceYear,
    required this.trips,
  });

  final int countryCount;
  final int continentCount;
  final int sinceYear;
  final List<TripRecord> trips;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 360,
      height: 640,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0D1117), Color(0xFF1A2340)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Wordmark
              const Text(
                'roavvy',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),

              const Spacer(),

              // Flag parade
              _FlagParade(trips: trips),

              const SizedBox(height: 28),

              // Stats block
              Center(
                child: Text(
                  '$countryCount ${countryCount == 1 ? 'country' : 'countries'}'
                  '  ·  '
                  '$continentCount ${continentCount == 1 ? 'continent' : 'continents'}'
                  '  ·  '
                  'Since $sinceYear',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ),

              const Spacer(),

              // Footer
              Center(
                child: Text(
                  'Track your travels at roavvy.com',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Flag parade ───────────────────────────────────────────────────────────────

class _FlagParade extends StatelessWidget {
  const _FlagParade({required this.trips});

  final List<TripRecord> trips;

  static const _kFlagW = 28.0;
  static const _kFlagH = 20.0;
  static const _kOverlap = 8.0;

  @override
  Widget build(BuildContext context) {
    // Deduplicate by country code, preserve chronological order (earliest first).
    final sorted = [...trips]..sort((a, b) => a.startedOn.compareTo(b.startedOn));
    final seen = <String>{};
    final uniqueCountryCodes = <String>[];
    for (final t in sorted) {
      final cc = t.countryCode.toUpperCase();
      if (seen.add(cc)) uniqueCountryCodes.add(cc);
    }

    final displayCodes = uniqueCountryCodes.take(20).toList();
    final count = displayCodes.length;
    if (count == 0) return const SizedBox.shrink();

    // Total width of the parade stack.
    final totalW = _kFlagW + (count - 1) * (_kFlagW - _kOverlap);

    return Center(
      child: SizedBox(
        width: totalW,
        height: _kFlagH + 4,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (int i = 0; i < count; i++)
              Positioned(
                left: i * (_kFlagW - _kOverlap),
                top: 0,
                child: _FlagChip(cc: displayCodes[i]),
              ),
          ],
        ),
      ),
    );
  }
}

class _FlagChip extends StatelessWidget {
  const _FlagChip({required this.cc});

  final String cc;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 20,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      clipBehavior: Clip.hardEdge,
      child: SvgPicture.asset(
        'assets/flags/svg/${cc.toLowerCase()}.svg',
        width: 28,
        height: 20,
        fit: BoxFit.cover,
        placeholderBuilder: (_) => SizedBox(
          width: 28,
          height: 20,
          child: Center(
            child: Text(
              flagEmoji(cc),
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ),
      ),
    );
  }
}
