import 'package:flutter/material.dart';
import 'package:shared_models/shared_models.dart';

/// A self-contained travel stats card suitable for both on-screen display and
/// off-screen capture via [RepaintBoundary].
///
/// Pure [StatelessWidget] — no Riverpod dependency. Callers are responsible for
/// providing a [TravelSummary] from the appropriate provider.
class TravelCardWidget extends StatelessWidget {
  const TravelCardWidget(this.summary, {super.key});

  final TravelSummary summary;

  String get _yearRange {
    final earliest = summary.earliestVisit;
    final latest = summary.latestVisit;
    if (earliest == null || latest == null) return '—';
    if (earliest.year == latest.year) return '${earliest.year}';
    return '${earliest.year} – ${latest.year}';
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 3 / 2,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1B4332),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Brand
            const Text(
              'Roavvy',
              style: TextStyle(
                color: Color(0xFF95D5B2),
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
              ),
            ),
            const Spacer(),
            // Country count — large, prominent
            Text(
              '${summary.countryCount}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 72,
                fontWeight: FontWeight.bold,
                height: 1,
              ),
            ),
            const Text(
              'countries visited',
              style: TextStyle(
                color: Color(0xFF95D5B2),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            // Year range + achievement count
            Row(
              children: [
                Text(
                  _yearRange,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                Text(
                  '🏆 ${summary.achievementCount}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
