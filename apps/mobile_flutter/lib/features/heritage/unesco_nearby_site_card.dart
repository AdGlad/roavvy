import 'package:flutter/material.dart';

import '../../core/country_names.dart';
import 'unesco_nearby_service.dart';

// ── Category styling (matches CountryProfileScreen palette) ──────────────────

const _gold = Color(0xFFF2C94C);
const _mint = Color(0xFF2ED8B6);
const _coral = Color(0xFFFF6B6B);

Color _categoryColor(String cat) => switch (cat.toLowerCase()) {
      'natural' => _mint,
      'mixed' => _coral,
      _ => _gold,
    };

String _categoryIcon(String cat) => switch (cat.toLowerCase()) {
      'natural' => '🌿',
      'mixed' => '✨',
      _ => '🏛',
    };

String _flagEmoji(String code) {
  if (code.length != 2) return '';
  const base = 0x1F1E6;
  return String.fromCharCode(base + code.codeUnitAt(0) - 65) +
      String.fromCharCode(base + code.codeUnitAt(1) - 65);
}

// ── UnescoNearbySiteCard ──────────────────────────────────────────────────────

/// Engaging list card for a UNESCO site in the Nearby Explorer.
///
/// Shows a hero image (or category fallback), site name, country + category
/// badge, distance / bearing, approximate travel times, and a visited stamp
/// when the user has already been to the site.
class UnescoNearbySiteCard extends StatelessWidget {
  const UnescoNearbySiteCard({
    super.key,
    required this.result,
    required this.onTap,
  });

  final NearbySiteResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final site = result.site;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final country = kCountryNames[site.countryCode] ?? site.countryCode;
    final flag = _flagEmoji(site.countryCode);
    final catColor = _categoryColor(site.category);
    final catIcon = _categoryIcon(site.category);
    final distStr = result.distanceKm < 1
        ? '${(result.distanceKm * 1000).round()} m'
        : '${result.distanceKm.toStringAsFixed(1)} km';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Thumbnail / fallback ────────────────────────────────────────
            _Thumbnail(
              imageUrl: site.imageUrl,
              category: site.category,
              catColor: catColor,
              catIcon: catIcon,
            ),
            // ── Content ─────────────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Site name + visited badge
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            site.name,
                            style: tt.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (result.isVisited)
                          const Padding(
                            padding: EdgeInsets.only(left: 6),
                            child: Text('✅', style: TextStyle(fontSize: 14)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Country + category badge
                    Row(
                      children: [
                        Text(
                          '$flag $country',
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _CategoryBadge(
                          label: _capitalize(site.category),
                          color: catColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Distance + bearing
                    Row(
                      children: [
                        Icon(
                          Icons.navigation,
                          size: 14,
                          color: catColor,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '$distStr · ${result.bearingLabel}',
                          style: tt.bodySmall?.copyWith(
                            color: catColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Short description teaser
                    if (site.shortDescription != null &&
                        site.shortDescription!.isNotEmpty)
                      Text(
                        site.shortDescription!,
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.55),
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 6),
                    // Travel time estimates
                    _TravelTimeRow(result: result),
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

String _capitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({
    required this.imageUrl,
    required this.category,
    required this.catColor,
    required this.catIcon,
  });

  final String? imageUrl;
  final String category;
  final Color catColor;
  final String catIcon;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    return SizedBox(
      width: 110,
      height: 110,
      child: url != null && url.isNotEmpty
          ? Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _fallback(),
            )
          : _fallback(),
    );
  }

  Widget _fallback() => Container(
        color: catColor.withValues(alpha: 0.15),
        child: Center(
          child: Text(catIcon, style: const TextStyle(fontSize: 36)),
        ),
      );
}

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _TravelTimeRow extends StatelessWidget {
  const _TravelTimeRow({required this.result});

  final NearbySiteResult result;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final color =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45);

    return Row(
      children: [
        _TimeChip(icon: '🚶', label: result.walkTime, style: tt, color: color),
        const SizedBox(width: 8),
        _TimeChip(icon: '🚲', label: result.cycleTime, style: tt, color: color),
        const SizedBox(width: 8),
        _TimeChip(icon: '🚗', label: result.driveTime, style: tt, color: color),
      ],
    );
  }
}

class _TimeChip extends StatelessWidget {
  const _TimeChip({
    required this.icon,
    required this.label,
    required this.style,
    required this.color,
  });

  final String icon;
  final String label;
  final TextTheme style;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(icon, style: const TextStyle(fontSize: 11)),
        const SizedBox(width: 2),
        Text(
          label,
          style: style.labelSmall?.copyWith(color: color, fontSize: 10),
        ),
      ],
    );
  }
}
