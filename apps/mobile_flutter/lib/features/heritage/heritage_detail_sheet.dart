import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_models/shared_models.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/country_names.dart';
import 'world_heritage_lookup_service.dart';

/// Shows a modal bottom sheet with full details about a [VisitedHeritageSite].
void showHeritageDetailSheet(BuildContext context, VisitedHeritageSite site) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _HeritageDetailSheet(site: site),
  );
}

/// Shows the heritage detail sheet for any [WorldHeritageSite] — including
/// ones the user has not visited. Visit-specific stats (photos, dates) are
/// hidden when called from this overload.
void showHeritageDetailSheetForSite(BuildContext context, WorldHeritageSite whs) {
  // Construct a proxy VisitedHeritageSite with photoCount = 0 to signal
  // "not visited" — the sheet hides visit stats when photoCount == 0.
  final proxy = VisitedHeritageSite(
    siteId: whs.siteId,
    name: whs.name,
    countryCode: whs.countryCode,
    category: whs.category,
    latitude: whs.latitude,
    longitude: whs.longitude,
    inscriptionYear: whs.inscriptionYear,
    firstSeen: DateTime.utc(1970),
    lastSeen: DateTime.utc(1970),
    photoCount: 0,
    confidence: '',
    nearestDistanceKm: 0,
  );
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _HeritageDetailSheet(site: proxy),
  );
}

class _HeritageDetailSheet extends StatefulWidget {
  const _HeritageDetailSheet({required this.site});

  final VisitedHeritageSite site;

  @override
  State<_HeritageDetailSheet> createState() => _HeritageDetailSheetState();
}

class _HeritageDetailSheetState extends State<_HeritageDetailSheet> {
  /// Enriched static data from the bundled JSON asset.
  WorldHeritageSite? _enriched;

  /// Distance in kilometres from the user's current GPS position.
  /// null = not yet determined; -1 = permission denied / unavailable.
  double? _distanceKm;

  @override
  void initState() {
    super.initState();
    _enriched = WorldHeritageLookupService.findBySiteId(widget.site.siteId);
    _fetchDistance();
  }

  Future<void> _fetchDistance() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        if (mounted) setState(() => _distanceKm = -1);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 8),
        ),
      );
      if (!mounted) return;
      final km = _haversineKm(
        pos.latitude, pos.longitude,
        widget.site.latitude, widget.site.longitude,
      );
      setState(() => _distanceKm = km);
    } catch (_) {
      if (mounted) setState(() => _distanceKm = -1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final site = widget.site;
    final enriched = _enriched;
    final countryName = kCountryNames[site.countryCode] ?? site.countryCode;
    final flag = _flagEmoji(site.countryCode);
    final categoryLabel = _categoryLabel(site.category);
    final categoryColor = _categoryColor(site.category);
    final imageUrl = enriched?.imageUrl ?? '';
    final description = enriched?.shortDescription ?? '';
    final hasImage = imageUrl.isNotEmpty;
    final hasDescription = description.isNotEmpty;

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0D2137),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        clipBehavior: Clip.hardEdge,
        child: CustomScrollView(
          controller: controller,
          slivers: [
            // ── Hero image (or gradient header) ──────────────────────────
            SliverToBoxAdapter(
              child: hasImage
                  ? _HeroImage(
                      url: imageUrl,
                      siteName: site.name,
                      categoryLabel: categoryLabel,
                      categoryColor: categoryColor,
                    )
                  : _HeaderNoImage(
                      siteName: site.name,
                      categoryLabel: categoryLabel,
                      categoryColor: categoryColor,
                    ),
            ),

            // ── Body content ──────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Country + region row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(flag, style: const TextStyle(fontSize: 22)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                countryName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (enriched?.region case final region?) ...[
                                const SizedBox(height: 2),
                                Text(
                                  region,
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        // Distance chip
                        _DistanceChip(distanceKm: _distanceKm),
                      ],
                    ),

                    const SizedBox(height: 20),
                    const Divider(color: Colors.white12, height: 1),
                    const SizedBox(height: 20),

                    // Description
                    if (hasDescription) ...[
                      Text(
                        description,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          height: 1.55,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Divider(color: Colors.white12, height: 1),
                      const SizedBox(height: 20),
                    ],

                    // Wikipedia link when no description available
                    if (!hasDescription) ...[
                      OutlinedButton.icon(
                        onPressed: () {
                          final query = Uri.encodeComponent(site.name);
                          launchUrl(
                            Uri.parse(
                              'https://en.wikipedia.org/w/index.php?search=$query+UNESCO',
                            ),
                            mode: LaunchMode.externalApplication,
                          );
                        },
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: const Text('Learn more on Wikipedia'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: const BorderSide(color: Colors.white24),
                          textStyle: const TextStyle(fontSize: 13),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Divider(color: Colors.white12, height: 1),
                      const SizedBox(height: 20),
                    ],

                    // Stats grid
                    Wrap(
                      spacing: 24,
                      runSpacing: 16,
                      children: [
                        _StatCell(
                          label: 'UNESCO Listed',
                          value: site.inscriptionYear > 0
                              ? '${site.inscriptionYear}'
                              : '—',
                        ),
                        if (site.photoCount > 0) ...[
                          _StatCell(
                            label: 'First Visited',
                            value: _fmtDate(site.firstSeen),
                          ),
                          _StatCell(
                            label: 'Last Visited',
                            value: _fmtDate(site.lastSeen),
                          ),
                          _StatCell(
                            label: 'Photos',
                            value: '${site.photoCount}',
                          ),
                        ],
                        _StatCell(
                          label: 'Coordinates',
                          value: '${site.latitude.toStringAsFixed(3)}°, '
                              '${site.longitude.toStringAsFixed(3)}°',
                        ),
                      ],
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

  static String _flagEmoji(String iso) {
    if (iso.length != 2) return '';
    const base = 0x1F1E6;
    return String.fromCharCode(base + iso.codeUnitAt(0) - 65) +
        String.fromCharCode(base + iso.codeUnitAt(1) - 65);
  }

  static String _categoryLabel(String c) => switch (c) {
        'natural' => 'Natural',
        'mixed'   => 'Mixed',
        _         => 'Cultural',
      };

  static Color _categoryColor(String c) => switch (c) {
        'natural' => const Color(0xFF4CAF50),
        'mixed'   => const Color(0xFF26C6DA),
        _         => const Color(0xFFD4A017),
      };

  static String _fmtDate(DateTime dt) {
    const m = ['Jan','Feb','Mar','Apr','May','Jun',
                'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${m[dt.month - 1]} ${dt.year}';
  }

  static double _haversineKm(
      double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
    final dLat = _rad(lat2 - lat1);
    final dLng = _rad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat1)) *
            math.cos(_rad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _rad(double deg) => deg * math.pi / 180;
}

// ── Hero image widget ──────────────────────────────────────────────────────────

class _HeroImage extends StatelessWidget {
  const _HeroImage({
    required this.url,
    required this.siteName,
    required this.categoryLabel,
    required this.categoryColor,
  });

  final String url;
  final String siteName;
  final String categoryLabel;
  final Color categoryColor;

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
            errorBuilder: (_, __, ___) => Container(
              color: const Color(0xFF1B3A5C),
              child: const Icon(Icons.landscape_outlined,
                  color: Colors.white24, size: 48),
            ),
          ),
          // Bottom gradient so name/badges are readable.
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
          // Drag handle at top.
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
          // Site name + category badge at bottom.
          Positioned(
            left: 16,
            right: 16,
            bottom: 14,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _CategoryBadge(label: categoryLabel, color: categoryColor),
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

// ── Header for sites without an image ─────────────────────────────────────────

class _HeaderNoImage extends StatelessWidget {
  const _HeaderNoImage({
    required this.siteName,
    required this.categoryLabel,
    required this.categoryColor,
  });

  final String siteName;
  final String categoryLabel;
  final Color categoryColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      color: const Color(0xFF1B3A5C),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.account_balance_outlined,
                  color: Colors.white38, size: 16),
              const SizedBox(width: 6),
              const Text(
                'UNESCO World Heritage',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(width: 8),
              _CategoryBadge(label: categoryLabel, color: categoryColor),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            siteName,
            style: const TextStyle(
              color: Colors.white,
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

// ── Distance chip ──────────────────────────────────────────────────────────────

class _DistanceChip extends StatelessWidget {
  const _DistanceChip({required this.distanceKm});

  final double? distanceKm;

  @override
  Widget build(BuildContext context) {
    final String label;
    final Color color;

    if (distanceKm == null) {
      label = '…';
      color = Colors.white24;
    } else if (distanceKm! < 0) {
      return const SizedBox.shrink();
    } else {
      final km = distanceKm!;
      if (km < 1) {
        label = '${(km * 1000).round()} m away';
      } else if (km < 10) {
        label = '${km.toStringAsFixed(1)} km away';
      } else {
        label = '${km.round()} km away';
      }
      color = Colors.amber;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── Category badge ─────────────────────────────────────────────────────────────

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.label, required this.color});

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

// ── Stat cell ──────────────────────────────────────────────────────────────────

class _StatCell extends StatelessWidget {
  const _StatCell({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
