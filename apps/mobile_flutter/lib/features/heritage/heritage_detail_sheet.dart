import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:shared_models/shared_models.dart';

import '../../core/country_names.dart';

/// Shows a modal bottom sheet with details about a visited [VisitedHeritageSite].
///
/// Call [showHeritageDetailSheet] from a tap handler.
void showHeritageDetailSheet(BuildContext context, VisitedHeritageSite site) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _HeritageDetailSheet(site: site),
  );
}

class _HeritageDetailSheet extends StatelessWidget {
  const _HeritageDetailSheet({required this.site});

  final VisitedHeritageSite site;

  @override
  Widget build(BuildContext context) {
    final countryName = kCountryNames[site.countryCode] ?? site.countryCode;
    final flag = _flagEmoji(site.countryCode);
    final categoryLabel = _categoryLabel(site.category);
    final categoryColor = _categoryColor(site.category);

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.75),
            borderRadius: BorderRadius.circular(20),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // UNESCO badge
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'UNESCO World Heritage',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Category pill
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: categoryColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: categoryColor.withOpacity(0.6), width: 1),
                        ),
                        child: Text(
                          categoryLabel,
                          style: TextStyle(
                            color: categoryColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Site name
                  Text(
                    site.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Country + flag
                  Row(
                    children: [
                      Text(flag, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Text(
                        countryName,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Metadata row
                  Wrap(
                    spacing: 20,
                    runSpacing: 8,
                    children: [
                      _MetaItem(
                        label: 'UNESCO Listed',
                        value: site.inscriptionYear > 0
                            ? '${site.inscriptionYear}'
                            : '—',
                      ),
                      _MetaItem(
                        label: 'First Visited',
                        value: _formatDate(site.firstSeen),
                      ),
                      _MetaItem(
                        label: 'Photos',
                        value: '${site.photoCount}',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
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

  static String _categoryLabel(String category) => switch (category) {
        'natural' => 'Natural',
        'mixed' => 'Mixed',
        _ => 'Cultural',
      };

  static Color _categoryColor(String category) => switch (category) {
        'natural' => const Color(0xFF4CAF50),
        'mixed' => const Color(0xFF26C6DA),
        _ => const Color(0xFFD4A017),
      };

  static String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.year}';
  }
}

/// A small label + value metadata pair used in the detail sheet.
class _MetaItem extends StatelessWidget {
  const _MetaItem({required this.label, required this.value});

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
        const SizedBox(height: 2),
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
