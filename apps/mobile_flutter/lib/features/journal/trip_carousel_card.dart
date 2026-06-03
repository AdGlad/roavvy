import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_models/shared_models.dart';

import 'package:photo_manager/photo_manager.dart';

import '../../core/country_names.dart';
import '../scan/hero_providers.dart';
import '../shared/hero_image_view.dart';
import '../shared/hero_override_picker.dart';

/// Full-bleed photographic card for the 3D Journal Carousel.
///
/// Displays a high-quality trip hero image with dual-gradient overlays
/// and premium typography for trip metadata.
class TripCarouselCard extends ConsumerWidget {
  const TripCarouselCard({super.key, required this.trip, this.onTap});

  final TripRecord trip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final mq = MediaQuery.of(context);
    // Request the image at the card's physical pixel width so PHImageManager
    // decodes at exactly the right resolution — no upscaling, no waste.
    final cardPx = (mq.size.width * mq.devicePixelRatio).ceil();
    final countryName = kCountryNames[trip.countryCode] ?? trip.countryCode;
    final flag = _flagEmoji(trip.countryCode);
    final dateRange = _dateRange(trip.startedOn, trip.endedOn);
    final days = _tripDays(trip.startedOn, trip.endedOn);
    final dayWord = days == 1 ? 'day' : 'days';

    final heroAsync = ref.watch(heroForTripProvider(trip.id));
    final hero = heroAsync.valueOrNull;
    final fallbackColor = _continentFallbackColor(
      kCountryContinent[trip.countryCode],
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Full-bleed background hero image
          HeroImageView(
            assetId: hero?.assetId,
            fallbackColor: fallbackColor,
            height: double.infinity,
            thumbnailSize: ThumbnailSize.square(cardPx),
          ),

          // 2. Dual Gradients (Legibility layers)
          // Top gradient for status/flag
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.center,
                  colors: [Colors.black54, Colors.transparent],
                  stops: [0.0, 0.4],
                ),
              ),
            ),
          ),
          // Bottom gradient for title/metadata
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.center,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black87],
                  stops: [0.4, 1.0],
                ),
              ),
            ),
          ),

          // 3. Trip Content Overlay
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top: Country & Flag
                Row(
                  children: [
                    Text(flag, style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        countryName.toUpperCase(),
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: Colors.white,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (trip.isManual)
                      const Icon(
                        Icons.edit_location_alt_rounded,
                        color: Colors.white70,
                        size: 16,
                      ),
                  ],
                ),

                const Spacer(),

                // Bottom: Title & Dates
                Text(
                  'Trip to $countryName',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        dateRange,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white70,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$days $dayWord · ${trip.photoCount} 📷',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 4. Tap Target (covers the full card below the edit button)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              splashColor: Colors.white10,
              highlightColor: Colors.white10,
            ),
          ),

          // 5. Edit button — last so it sits above the InkWell in hit-test order.
          Positioned(
            top: 14,
            right: 14,
            child: GestureDetector(
              onTap:
                  () => showHeroOverridePicker(
                    context,
                    trip.id,
                    fallbackColor: fallbackColor,
                  ),
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.edit, color: Colors.white, size: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helpers (Copied from JournalScreen for now) ────────────────────────────────

String _flagEmoji(String isoCode) {
  if (isoCode.length != 2) return '';
  const base = 0x1F1E6;
  return String.fromCharCode(base + isoCode.codeUnitAt(0) - 65) +
      String.fromCharCode(base + isoCode.codeUnitAt(1) - 65);
}

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _fmtDate(DateTime dt, {bool showYear = true}) {
  final m = _months[dt.month - 1];
  return showYear ? '${dt.day} $m ${dt.year}' : '${dt.day} $m';
}

String _dateRange(DateTime start, DateTime end) {
  if (start.year == end.year) {
    return '${_fmtDate(start, showYear: false)} – ${_fmtDate(end)}';
  }
  return '${_fmtDate(start)} – ${_fmtDate(end)}';
}

int _tripDays(DateTime start, DateTime end) => end.difference(start).inDays + 1;

Color _continentFallbackColor(String? continent) {
  switch (continent) {
    case 'Europe':
      return const Color(0xFF2563EB);
    case 'Asia':
      return const Color(0xFF7C3AED);
    case 'North America':
      return const Color(0xFF059669);
    case 'South America':
      return const Color(0xFFD97706);
    case 'Africa':
      return const Color(0xFFDC2626);
    case 'Oceania':
      return const Color(0xFF0891B2);
    default:
      return const Color(0xFF374151);
  }
}
