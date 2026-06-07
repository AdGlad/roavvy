import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_models/shared_models.dart';

import '../../../core/theme/roavvy_colours.dart';
import '../countries_list_screen.dart';

/// Animated, colour-coded 2×2 stats grid (M147).
///
/// Each card shows a gradient background, icon, and an animated counter
/// that runs 0 → actual value on first render.
/// Colours: Countries=Blue, Continents=Green, Trips=Purple, UNESCO=Gold.
class StatsGrid extends StatelessWidget {
  const StatsGrid({
    super.key,
    required this.countryCount,
    required this.continentCount,
    required this.tripCount,
    required this.heritageCount,
    this.visits,
  });

  final int countryCount;
  final int continentCount;
  final int tripCount;
  final int heritageCount;
  final List<EffectiveVisitedCountry>? visits;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 1.7,
        children: [
          _AnimatedStatCard(
            value: countryCount,
            total: 195,
            label: 'Countries',
            icon: Icons.public_outlined,
            gradient: const LinearGradient(
              colors: [Color(0xFF1565C0), Color(0xFF2F80ED)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            onTap: (visits != null && visits!.isNotEmpty)
                ? () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => CountriesListScreen(visits: visits!),
                      ),
                    )
                : null,
          ),
          _AnimatedStatCard(
            value: continentCount,
            total: 6,
            label: 'Continents',
            icon: Icons.travel_explore_outlined,
            gradient: const LinearGradient(
              colors: [Color(0xFF1B5E20), Color(0xFF27AE60)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          _AnimatedStatCard(
            value: tripCount,
            label: 'Trips',
            icon: Icons.flight_takeoff_outlined,
            gradient: const LinearGradient(
              colors: [Color(0xFF4A148C), Color(0xFF9B51E0)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          _AnimatedStatCard(
            value: heritageCount,
            label: 'UNESCO Sites',
            icon: Icons.account_balance_outlined,
            gradient: const LinearGradient(
              colors: [Color(0xFFF57F17), RoavvyColours.roavvyGold],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedStatCard extends StatelessWidget {
  const _AnimatedStatCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.gradient,
    this.total,
    this.onTap,
  });

  final int value;
  final String label;
  final IconData icon;
  final LinearGradient gradient;
  final int? total;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: gradient.colors.last.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 17, color: Colors.white70),
              const Spacer(),
              if (total != null)
                Text(
                  '/ $total',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
            ],
          ),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value.toDouble()),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOut,
            builder: (_, v, __) => Text(
              '${v.round()}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
                height: 1.1,
              ),
            ),
          ),
          Row(
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (onTap != null)
                const Icon(Icons.chevron_right, size: 13, color: Colors.white54),
            ],
          ),
        ],
      ),
    );

    if (onTap == null) return card;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap!();
      },
      child: card,
    );
  }
}
