// lib/features/world_leap/presentation/widgets/world_leap_share_card.dart

import 'package:flutter/material.dart';

import '../../domain/models/world_leap_run.dart';

/// Returns the ordered list of country codes in the run trail.
List<String> runTrail(WorldLeapRun run) => [
      run.startCountryCode,
      ...run.launches.map((l) => l.toCountryCode),
    ];

/// A self-contained widget designed to be screenshot-able.
/// Fixed 400x300 logical pixels with a dark green gradient and Roavvy branding.
class WorldLeapShareCard extends StatelessWidget {
  final WorldLeapRun run;

  const WorldLeapShareCard({super.key, required this.run});

  @override
  Widget build(BuildContext context) {
    final trail = runTrail(run);
    final trailText = trail.join(' → ');

    return SizedBox(
      width: 400,
      height: 300,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0D1F0D),
              Color(0xFF1A3A1A),
              Color(0xFF0A2A1A),
            ],
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top row: title + date ──────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '🌍 World Leap',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  run.date,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Stats row ──────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _CardStat(label: 'Score', value: run.totalScore.toString()),
                _CardStat(
                    label: 'Countries', value: run.countryCount.toString()),
                _CardStat(
                  label: 'Longest',
                  value: run.longestLaunchKm > 0
                      ? '${run.longestLaunchKm.toStringAsFixed(0)} km'
                      : '—',
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Country trail ──────────────────────────────────────────────
            if (trailText.isNotEmpty)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  trailText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

            const Spacer(),

            // ── Branding ───────────────────────────────────────────────────
            Text(
              '🦘 Roavvy',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardStat extends StatelessWidget {
  final String label;
  final String value;

  const _CardStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.55),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
