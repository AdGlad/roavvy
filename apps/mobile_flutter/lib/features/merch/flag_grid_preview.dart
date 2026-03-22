import 'package:flutter/material.dart';

/// Converts an ISO 3166-1 alpha-2 country code to its flag emoji.
///
/// Each letter maps to a Regional Indicator Symbol (U+1F1E6–U+1F1FF).
/// e.g. "GB" → 🇬🇧
String _codeToEmoji(String code) {
  const base = 0x1F1A5; // offset: 'A'.codeUnitAt(0) + base = Regional Indicator A
  return code.toUpperCase().split('').map((c) {
    return String.fromCharCode(c.codeUnitAt(0) + base);
  }).join();
}

/// Displays a responsive grid of country flag emojis for [selectedCodes].
///
/// - 5 columns on screens ≤390pt wide; 6 columns on wider screens.
/// - Maximum 24 flag cells. If [selectedCodes.length] > 24, the last visible
///   cell shows "+N more" instead of a flag.
/// - Collapses to zero height when [selectedCodes] is empty.
/// - All rendering is synchronous — no network calls, no async work.
class FlagGridPreview extends StatelessWidget {
  const FlagGridPreview({super.key, required this.selectedCodes});

  final List<String> selectedCodes;

  static const int _maxCells = 24;

  @override
  Widget build(BuildContext context) {
    if (selectedCodes.isEmpty) return const SizedBox.shrink();

    final screenWidth = MediaQuery.sizeOf(context).width;
    final columns = screenWidth <= 390 ? 5 : 6;

    final overflow = selectedCodes.length - _maxCells;
    // How many flag cells to show (leave room for overflow chip if needed)
    final showOverflow = overflow > 0;
    final flagCount = showOverflow ? _maxCells - 1 : selectedCodes.length;
    final displayCodes = selectedCodes.take(flagCount).toList();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        childAspectRatio: 1,
      ),
      itemCount: displayCodes.length + (showOverflow ? 1 : 0),
      itemBuilder: (context, index) {
        if (showOverflow && index == displayCodes.length) {
          return _OverflowCell(count: overflow + 1);
        }
        return _FlagCell(code: displayCodes[index]);
      },
    );
  }
}

class _FlagCell extends StatelessWidget {
  const _FlagCell({required this.code});
  final String code;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: FittedBox(
          child: Text(
            _codeToEmoji(code),
            style: const TextStyle(fontSize: 28),
          ),
        ),
      ),
    );
  }
}

class _OverflowCell extends StatelessWidget {
  const _OverflowCell({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '+$count',
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ),
    );
  }
}
