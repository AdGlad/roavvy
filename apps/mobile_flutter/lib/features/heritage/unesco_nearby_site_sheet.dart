import 'package:flutter/material.dart';

import '../../core/country_names.dart';
import 'distance_utils.dart';
import 'native_maps_launcher.dart';
import 'unesco_nearby_service.dart';

// ── Palette (matches UnescoNearbySiteCard) ────────────────────────────────────

const _gold = Color(0xFFF2C94C);
const _mint = Color(0xFF2ED8B6);
const _coral = Color(0xFFFF6B6B);

Color _categoryColor(String cat) => switch (cat.toLowerCase()) {
      'natural' => _mint,
      'mixed' => _coral,
      _ => _gold,
    };

String _categoryLabel(String cat) => switch (cat.toLowerCase()) {
      'natural' => 'Natural',
      'mixed' => 'Mixed',
      _ => 'Cultural',
    };

String _flagEmoji(String code) {
  if (code.length != 2) return '';
  const base = 0x1F1E6;
  return String.fromCharCode(base + code.codeUnitAt(0) - 65) +
      String.fromCharCode(base + code.codeUnitAt(1) - 65);
}

// ── Entry point ───────────────────────────────────────────────────────────────

/// Shows a modal bottom sheet with full proximity details for [result].
void showUnescoNearbySiteSheet(BuildContext context, NearbySiteResult result) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _UnescoNearbySiteSheet(result: result),
  );
}

// ── Sheet widget ──────────────────────────────────────────────────────────────

class _UnescoNearbySiteSheet extends StatelessWidget {
  const _UnescoNearbySiteSheet({required this.result});

  final NearbySiteResult result;

  @override
  Widget build(BuildContext context) {
    final site = result.site;
    final cs = Theme.of(context).colorScheme;
    final catColor = _categoryColor(site.category);
    final catLabel = _categoryLabel(site.category);
    final country = kCountryNames[site.countryCode] ?? site.countryCode;
    final flag = _flagEmoji(site.countryCode);
    final imageUrl = site.imageUrl ?? '';
    final hasImage = imageUrl.isNotEmpty;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        clipBehavior: Clip.hardEdge,
        child: CustomScrollView(
          controller: controller,
          slivers: [
            // ── Hero / header ───────────────────────────────────────────────
            SliverToBoxAdapter(
              child: hasImage
                  ? _HeroImage(
                      url: imageUrl,
                      siteName: site.name,
                      catLabel: catLabel,
                      catColor: catColor,
                    )
                  : _HeaderNoImage(
                      siteName: site.name,
                      catLabel: catLabel,
                      catColor: catColor,
                    ),
            ),

            // ── Body ────────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Country row + visited badge
                    Row(
                      children: [
                        Text(flag, style: const TextStyle(fontSize: 22)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            country,
                            style: TextStyle(
                              color: cs.onSurface,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (result.isVisited)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: Colors.green.withValues(alpha: 0.5)),
                            ),
                            child: const Text(
                              '✅ Visited',
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Distance + bearing strip
                    _DistanceBearingStrip(result: result, catColor: catColor),

                    const SizedBox(height: 16),
                    Divider(
                        color: cs.onSurface.withValues(alpha: 0.12), height: 1),
                    const SizedBox(height: 16),

                    // Travel time row
                    _TravelTimeSection(result: result),

                    const SizedBox(height: 16),
                    Divider(
                        color: cs.onSurface.withValues(alpha: 0.12), height: 1),
                    const SizedBox(height: 16),

                    // Short description
                    if (site.shortDescription != null &&
                        site.shortDescription!.isNotEmpty) ...[
                      Text(
                        site.shortDescription!,
                        style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.70),
                          fontSize: 14,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Divider(
                          color: cs.onSurface.withValues(alpha: 0.12),
                          height: 1),
                      const SizedBox(height: 16),
                    ],

                    // Stats
                    Wrap(
                      spacing: 24,
                      runSpacing: 14,
                      children: [
                        if (site.inscriptionYear > 0)
                          _StatCell(
                            label: 'UNESCO Listed',
                            value: '${site.inscriptionYear}',
                          ),
                        _StatCell(
                          label: 'Coordinates',
                          value:
                              '${site.latitude.toStringAsFixed(3)}°, '
                              '${site.longitude.toStringAsFixed(3)}°',
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),

                    // Get Directions button
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => NativeMapsLauncher.open(
                          site.latitude,
                          site.longitude,
                          site.name,
                        ),
                        icon: const Icon(Icons.directions, size: 18),
                        label: const Text('Get Directions'),
                        style: FilledButton.styleFrom(
                          backgroundColor: catColor,
                          foregroundColor: Colors.black87,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          textStyle: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
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

// ── Distance + bearing strip ─────────────────────────────────────────────────

class _DistanceBearingStrip extends StatelessWidget {
  const _DistanceBearingStrip({required this.result, required this.catColor});

  final NearbySiteResult result;
  final Color catColor;

  @override
  Widget build(BuildContext context) {
    final distStr = result.distanceKm < 1
        ? '${(result.distanceKm * 1000).round()} m'
        : '${result.distanceKm.toStringAsFixed(1)} km';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: catColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: catColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.navigation, size: 18, color: catColor),
          const SizedBox(width: 8),
          Text(
            '$distStr away',
            style: TextStyle(
              color: catColor,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '· ${result.bearingLabel}',
            style: TextStyle(
              color: catColor.withValues(alpha: 0.8),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Travel time section ──────────────────────────────────────────────────────

class _TravelTimeSection extends StatelessWidget {
  const _TravelTimeSection({required this.result});

  final NearbySiteResult result;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ESTIMATED TRAVEL',
          style: TextStyle(
            color: cs.onSurface.withValues(alpha: 0.38),
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _TravelTile(
                icon: '🚶', label: 'Walking', time: result.walkTime),
            const SizedBox(width: 12),
            _TravelTile(
                icon: '🚲', label: 'Cycling', time: result.cycleTime),
            const SizedBox(width: 12),
            _TravelTile(
                icon: '🚗', label: 'Driving', time: result.driveTime),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Straight-line estimates at ${DistanceUtils.walkingKmh.round()} / '
          '${DistanceUtils.cyclingKmh.round()} / '
          '${DistanceUtils.drivingKmh.round()} km/h',
          style: TextStyle(
            color: cs.onSurface.withValues(alpha: 0.35),
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

class _TravelTile extends StatelessWidget {
  const _TravelTile({
    required this.icon,
    required this.label,
    required this.time,
  });

  final String icon;
  final String label;
  final String time;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: cs.surfaceContainer,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 4),
            Text(
              time,
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              label,
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.45),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Hero image ────────────────────────────────────────────────────────────────

class _HeroImage extends StatelessWidget {
  const _HeroImage({
    required this.url,
    required this.siteName,
    required this.catLabel,
    required this.catColor,
  });

  final String url;
  final String siteName;
  final String catLabel;
  final Color catColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (ctx, __, ___) => Container(
              color: Theme.of(ctx).colorScheme.surfaceContainer,
              child: Icon(
                Icons.landscape_outlined,
                color: Theme.of(ctx)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.24),
                size: 48,
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7),
                  ],
                  stops: const [0.4, 1.0],
                ),
              ),
            ),
          ),
          // Drag handle
          Positioned(
            top: 10,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white38,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          // Site name + badge at bottom
          Positioned(
            left: 16,
            right: 16,
            bottom: 14,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _SmallBadge(label: catLabel, color: catColor),
                const SizedBox(height: 6),
                Text(
                  siteName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    shadows: [Shadow(blurRadius: 8, color: Colors.black87)],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Header without image ──────────────────────────────────────────────────────

class _HeaderNoImage extends StatelessWidget {
  const _HeaderNoImage({
    required this.siteName,
    required this.catLabel,
    required this.catColor,
  });

  final String siteName;
  final String catLabel;
  final Color catColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      color: cs.surfaceContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.24),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(
                Icons.account_balance_outlined,
                color: cs.onSurface.withValues(alpha: 0.38),
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                'UNESCO World Heritage',
                style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.54), fontSize: 12),
              ),
              const SizedBox(width: 8),
              _SmallBadge(label: catLabel, color: catColor),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            siteName,
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Small category badge ──────────────────────────────────────────────────────

class _SmallBadge extends StatelessWidget {
  const _SmallBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ── Stat cell ─────────────────────────────────────────────────────────────────

class _StatCell extends StatelessWidget {
  const _StatCell({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: cs.onSurface.withValues(alpha: 0.38),
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            color: cs.onSurface,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
