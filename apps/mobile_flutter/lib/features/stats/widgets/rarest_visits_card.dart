import 'package:flutter/material.dart';
import 'package:shared_models/shared_models.dart';

import '../../../core/country_names.dart';

/// Displays up to 3 of the user's rarest visited countries (M150).
///
/// Hidden when the user has no Uncommon-or-rarer countries.
class RarestVisitsCard extends StatelessWidget {
  const RarestVisitsCard({super.key, required this.visits});

  final List<EffectiveVisitedCountry>? visits;

  @override
  Widget build(BuildContext context) {
    final visitedCodes = (visits ?? []).map((v) => v.countryCode).toList();
    final rarest = rarestVisited(visitedCodes, limit: 3);

    if (rarest.isEmpty) return const SizedBox.shrink();

    final hasUltraRare = rarest.any((r) => r.tier == RarityTier.ultraRare);
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: theme.shadowColor.withValues(alpha: 0.1),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ───────────────────────────────────────────────────
            Row(
              children: [
                const Text('🗺️', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Off the Beaten Path',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Your rarest destinations',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // ── Country cards ─────────────────────────────────────────────
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (int i = 0; i < rarest.length; i++) ...[
                    if (i > 0) const SizedBox(width: 10),
                    _RarityCountryCard(entry: rarest[i]),
                  ],
                ],
              ),
            ),

            // ── Achievement nudge for 2+ ultra-rare ──────────────────────
            if (hasUltraRare && rarest.where((r) => r.tier == RarityTier.ultraRare).length >= 2) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF9B51E0).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFF9B51E0).withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    const Text('🧭', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'You\'re a true pioneer — very few travellers reach these places.',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: const Color(0xFF9B51E0),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Individual country card ───────────────────────────────────────────────────

class _RarityCountryCard extends StatelessWidget {
  const _RarityCountryCard({required this.entry});

  final ({String countryCode, double score, RarityTier tier}) entry;

  Color get _tierColor => switch (entry.tier) {
    RarityTier.ultraRare => const Color(0xFFE74C3C),
    RarityTier.rare => const Color(0xFFFF8C42),
    RarityTier.uncommon => const Color(0xFF3498DB),
  };

  String get _percentLabel {
    final pct = entry.score * 100;
    // Round to nearest 0.5
    final rounded = (pct * 2).round() / 2;
    return 'Only ~${rounded.toStringAsFixed(1)}% of travellers visit';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _tierColor;
    final name = kCountryNames[entry.countryCode] ?? entry.countryCode;
    final flag = _flagEmoji(entry.countryCode);

    return Container(
      width: 140,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(flag, style: const TextStyle(fontSize: 28)),
          const SizedBox(height: 6),
          Text(
            name,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          // Tier badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              entry.tier.label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _percentLabel,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

String _flagEmoji(String iso) {
  if (iso.length != 2) return '🏳️';
  const base = 0x1F1E6;
  return String.fromCharCode(base + iso.codeUnitAt(0) - 65) +
      String.fromCharCode(base + iso.codeUnitAt(1) - 65);
}
