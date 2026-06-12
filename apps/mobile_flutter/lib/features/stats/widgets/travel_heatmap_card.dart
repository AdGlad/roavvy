import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_models/shared_models.dart';

import '../../../core/country_names.dart';

/// Continent → display colour.  Keys match [kCountryContinent].
const Map<String, Color> kContinentHeatmapColors = {
  'Africa':        Color(0xFFFF8C42),
  'Asia':          Color(0xFFE74C3C),
  'Europe':        Color(0xFF3498DB),
  'North America': Color(0xFF27AE60),
  'Oceania':       Color(0xFF16A085),
  'South America': Color(0xFF8E44AD),
};

/// For each (year, month) bucket, returns the list of country codes visited
/// that month (using [EffectiveVisitedCountry.firstSeen]).
///
/// Countries with no [firstSeen] date (manual adds without photo evidence)
/// are skipped.
///
/// Exported as a top-level function so it can be unit-tested without Flutter.
Map<(int, int), List<String>> buildHeatmapData(
  List<EffectiveVisitedCountry> visits,
) {
  final data = <(int, int), List<String>>{};
  for (final visit in visits) {
    if (visit.firstSeen == null) continue;
    final key = (visit.firstSeen!.year, visit.firstSeen!.month);
    data.putIfAbsent(key, () => []).add(visit.countryCode);
  }
  return data;
}

/// Returns the dominant continent for [codes]: most-visited wins; if tied,
/// alphabetically-first continent name wins (deterministic tiebreak).
String? dominantContinent(List<String> codes) {
  final counts = <String, int>{};
  for (final code in codes) {
    final c = kCountryContinent[code];
    if (c != null) counts[c] = (counts[c] ?? 0) + 1;
  }
  if (counts.isEmpty) return null;
  String? best;
  int bestCount = 0;
  for (final e in counts.entries) {
    if (e.value > bestCount ||
        (e.value == bestCount &&
            (best == null || e.key.compareTo(best) < 0))) {
      best = e.key;
      bestCount = e.value;
    }
  }
  return best;
}

// ── Card ──────────────────────────────────────────────────────────────────────

/// GitHub-style month × year heatmap of travel history (M149).
///
/// Rows = years (earliest visit → current year).
/// Cols = months (Jan → Dec).
/// Cell colour = dominant continent; empty cells use theme surface tint.
/// Tapping a non-empty cell shows a small callout with visited countries.
class TravelHeatmapCard extends StatefulWidget {
  const TravelHeatmapCard({super.key, required this.visits});

  final List<EffectiveVisitedCountry>? visits;

  @override
  State<TravelHeatmapCard> createState() => _TravelHeatmapCardState();
}

class _TravelHeatmapCardState extends State<TravelHeatmapCard> {
  (int, int)? _selected; // (year, month) of tapped cell

  static const _cellW = 22.0;
  static const _cellH = 18.0;
  static const _gap = 3.0;

  static const _months = [
    'J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D',
  ];

  // ── Data ───────────────────────────────────────────────────────────────────

  late Map<(int, int), List<String>> _data;
  late Map<(int, int), String?> _continentMap; // (y,m) → continent name
  late int _startYear;
  late int _endYear;
  late int _monthsWithTravel;

  void _rebuild() {
    final visits = widget.visits;
    if (visits == null || visits.isEmpty) {
      _data = {};
      _continentMap = {};
      _startYear = DateTime.now().year;
      _endYear = DateTime.now().year;
      _monthsWithTravel = 0;
      return;
    }
    _data = buildHeatmapData(visits);
    _continentMap = {
      for (final e in _data.entries) e.key: dominantContinent(e.value),
    };
    final years = _data.keys.map((k) => k.$1).toList();
    _startYear = years.reduce(math.min);
    _endYear = DateTime.now().year;
    _monthsWithTravel = _data.length;
  }

  @override
  void initState() {
    super.initState();
    _rebuild();
  }

  @override
  void didUpdateWidget(TravelHeatmapCard old) {
    super.didUpdateWidget(old);
    if (old.visits != widget.visits) _rebuild();
  }

  // ── Hit testing ────────────────────────────────────────────────────────────

  (int, int)? _hitTest(Offset local) {
    const stride = _cellW + _gap;
    const strideH = _cellH + _gap;
    final col = (local.dx / stride).floor();
    final row = (local.dy / strideH).floor();
    if (col < 0 || col > 11) return null;
    final year = _startYear + row;
    if (year > _endYear) return null;
    return (year, col + 1); // month is 1-based
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalYears = _endYear - _startYear + 1;
    final gridW = 12 * (_cellW + _gap) - _gap;
    final gridH = totalYears * (_cellH + _gap) - _gap;

    final emptyColor = theme.colorScheme.surfaceContainerHighest;

    Widget grid = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (d) {
        final cell = _hitTest(d.localPosition);
        setState(() {
          // Toggle off if same cell tapped again, or clear if empty cell.
          if (cell != null && _data.containsKey(cell)) {
            _selected = _selected == cell ? null : cell;
          } else {
            _selected = null;
          }
        });
      },
      child: SizedBox(
        width: gridW,
        height: gridH,
        child: CustomPaint(
          painter: _HeatmapPainter(
            data: _continentMap,
            startYear: _startYear,
            endYear: _endYear,
            emptyColor: emptyColor,
            selectedCell: _selected,
          ),
        ),
      ),
    );

    // Horizontal scroll if > 6 years
    if (totalYears > 6) {
      grid = SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: grid,
      );
    }

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
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────
            Row(
              children: [
                Text(
                  'Travel History',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (_monthsWithTravel > 0)
                  Text(
                    '$_monthsWithTravel month${_monthsWithTravel == 1 ? '' : 's'} '
                    'of travel since $_startYear',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // ── Month labels ─────────────────────────────────────────────
            Row(
              children: [
                for (int i = 0; i < 12; i++) ...[
                  if (i > 0) const SizedBox(width: _gap),
                  SizedBox(
                    width: _cellW,
                    child: Text(
                      _months[i],
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 9,
                      ),
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 4),

            // ── Grid + year labels ────────────────────────────────────────
            if (_data.isEmpty && widget.visits != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Add travel dates to see your history',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Year labels
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (int y = _startYear; y <= _endYear; y++) ...[
                        if (y > _startYear) const SizedBox(height: _gap),
                        SizedBox(
                          height: _cellH,
                          child: Text(
                            '$y',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 9,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(width: 6),

                  // Heatmap grid
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      grid,
                      // Callout for selected cell
                      if (_selected != null && _data.containsKey(_selected!))
                        _CellCallout(
                          cell: _selected!,
                          codes: _data[_selected!]!,
                          startYear: _startYear,
                          cellW: _cellW,
                          cellH: _cellH,
                          gap: _gap,
                        ),
                    ],
                  ),
                ],
              ),

            const SizedBox(height: 10),

            // ── Legend ───────────────────────────────────────────────────
            Wrap(
              spacing: 10,
              runSpacing: 4,
              children: [
                for (final e in kContinentHeatmapColors.entries)
                  _LegendDot(label: _shortContinent(e.key), color: e.value),
                _LegendDot(label: 'No travel', color: emptyColor),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _shortContinent(String name) => switch (name) {
  'North America' => 'N. America',
  'South America' => 'S. America',
  _ => name,
};

// ── Painter ───────────────────────────────────────────────────────────────────

class _HeatmapPainter extends CustomPainter {
  const _HeatmapPainter({
    required this.data,
    required this.startYear,
    required this.endYear,
    required this.emptyColor,
    this.selectedCell,
  });

  final Map<(int, int), String?> data;
  final int startYear;
  final int endYear;
  final Color emptyColor;
  final (int, int)? selectedCell;

  static const _cellW = 22.0;
  static const _cellH = 18.0;
  static const _gap = 3.0;
  static const _r = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    for (int y = startYear; y <= endYear; y++) {
      final row = y - startYear;
      final top = row * (_cellH + _gap);
      for (int m = 1; m <= 12; m++) {
        final col = m - 1;
        final left = col * (_cellW + _gap);
        final rect = RRect.fromLTRBR(
          left, top, left + _cellW, top + _cellH,
          const Radius.circular(_r),
        );
        final key = (y, m);
        final continent = data[key];
        final color = continent != null
            ? (kContinentHeatmapColors[continent] ?? emptyColor)
            : emptyColor;
        final isSelected = selectedCell == key;
        canvas.drawRRect(
          rect,
          Paint()..color = isSelected ? color : color.withValues(alpha: 0.85),
        );
        if (isSelected) {
          canvas.drawRRect(
            rect,
            Paint()
              ..color = color
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_HeatmapPainter old) =>
      old.data != data ||
      old.startYear != startYear ||
      old.endYear != endYear ||
      old.selectedCell != selectedCell;
}

// ── Cell callout ──────────────────────────────────────────────────────────────

class _CellCallout extends StatelessWidget {
  const _CellCallout({
    required this.cell,
    required this.codes,
    required this.startYear,
    required this.cellW,
    required this.cellH,
    required this.gap,
  });

  final (int, int) cell;
  final List<String> codes;
  final int startYear;
  final double cellW;
  final double cellH;
  final double gap;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    final (year, month) = cell;
    final row = year - startYear;
    final col = month - 1;
    final left = col * (cellW + gap);
    final top = row * (cellH + gap) - 6; // shift callout upward

    final theme = Theme.of(context);
    final names = codes
        .map((c) => kCountryNames[c] ?? c)
        .toList()
      ..sort();

    return Positioned(
      left: left.clamp(0, double.infinity),
      bottom: -(top + cellH + 8), // position above the cell
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.inverseSurface,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${_months[month - 1]} $year',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onInverseSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              ...names.take(5).map(
                (n) => Text(
                  n,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onInverseSurface.withValues(alpha: 0.85),
                  ),
                ),
              ),
              if (names.length > 5)
                Text(
                  '+${names.length - 5} more',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onInverseSurface.withValues(alpha: 0.6),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Legend dot ────────────────────────────────────────────────────────────────

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
