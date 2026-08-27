import 'package:design_studio/design_studio.dart';
import 'package:flutter/material.dart';

import '../../../core/country_names.dart';
import '../../map/globe_map_widget.dart';

/// **Choose Your Travels** (M2) — the Travels-stage workspace. The live shirt
/// stays visible above this; everything here writes the ONE shared selection on
/// the [StudioController], so Map and List can never disagree.
///
///  * **Source** Countries | Trips — Trips (+ the year range) appear only when
///    dated trip history exists.
///  * **View** Map | List — two front-ends onto the same selection set. Map reuses
///    the existing Roavvy globe ([GlobeMapWidget]); List is the precise selector.
class TravelsWorkspace extends StatefulWidget {
  const TravelsWorkspace({super.key, required this.controller});

  final StudioController controller;

  @override
  State<TravelsWorkspace> createState() => _TravelsWorkspaceState();
}

class _TravelsWorkspaceState extends State<TravelsWorkspace> {
  StudioController get _c => widget.controller;

  /// View sub-tab is pure presentation (not design state) → local.
  bool _mapView = false;

  @override
  Widget build(BuildContext context) {
    final dated = _c.hasTrips;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          if (dated) ...[
            _segment(
              children: [
                _seg('travels-source-countries', 'Countries', !_c.sourceTrips,
                    () => _c.setSource(false)),
                _seg('travels-source-trips', 'Trips', _c.sourceTrips,
                    () => _c.setSource(true)),
              ],
            ),
            const SizedBox(width: 10),
          ],
          _segment(children: [
            _seg('travels-view-list', 'List', !_mapView,
                () => setState(() => _mapView = false)),
            _seg('travels-view-map', 'Map', _mapView,
                () => setState(() => _mapView = true)),
          ]),
        ]),
        if (dated) _yearRange(),
        const SizedBox(height: 8),
        Row(children: [
          Text('${_c.selectedCountryCodes.length} selected',
              style: const TextStyle(fontSize: 12, color: Colors.white60)),
          const Spacer(),
          _textButton('travels-select-all', 'Select all', _c.selectAllCountries),
          const SizedBox(width: 4),
          _textButton('travels-clear', 'Clear', _c.clearCountries),
        ]),
        const SizedBox(height: 6),
        Expanded(child: _mapView ? _map() : _list()),
      ],
    );
  }

  // ── Year range (dated trips only) ───────────────────────────────────────────
  Widget _yearRange() {
    final span = _c.span;
    if (span == null) return const SizedBox.shrink();
    final minY = span.start!.year;
    final maxY = span.end!.year;
    if (maxY <= minY) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text('Trips from $minY',
            style: const TextStyle(fontSize: 12, color: Colors.white60)),
      );
    }
    final lo = _c.yearLo.clamp(minY, maxY).toDouble();
    final hi = _c.yearHi.clamp(minY, maxY).toDouble();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Years  ${_c.yearLo}–${_c.yearHi}',
              style: const TextStyle(fontSize: 12, color: Colors.white70)),
          RangeSlider(
            key: const Key('v2-travels-year'),
            min: minY.toDouble(),
            max: maxY.toDouble(),
            divisions: maxY - minY,
            labels: RangeLabels('${lo.round()}', '${hi.round()}'),
            values: RangeValues(lo, hi),
            // Cheap label update during the drag…
            onChanged: (v) =>
                _c.previewYear(v.start.round(), v.end.round()),
            // …commit (regenerate) only on release → debounces the render.
            onChangeEnd: (v) =>
                _c.setYearRange(v.start.round(), v.end.round()),
          ),
        ],
      ),
    );
  }

  // ── List selector (the precise selector; same state as the Map) ─────────────
  Widget _list() {
    final codes = _c.availableCountryCodes;
    return ListView.builder(
      key: const Key('v2-travels-list'),
      itemCount: codes.length,
      itemBuilder: (context, i) {
        final cc = codes[i];
        final selected = _c.isSelected(cc);
        final name = kCountryNames[cc.toUpperCase()] ?? cc.toUpperCase();
        return ListTile(
          key: Key('v2-travels-country-$cc'),
          dense: true,
          leading: Text(_flagEmoji(cc), style: const TextStyle(fontSize: 22)),
          title: Text(name,
              style: const TextStyle(fontSize: 14, color: Colors.white)),
          trailing: Icon(
            selected ? Icons.check_circle : Icons.circle_outlined,
            color: selected ? Colors.tealAccent : Colors.white30,
            size: 20,
          ),
          onTap: () => _c.toggleCountry(cc),
        );
      },
    );
  }

  // ── Map selector — reuses the existing Roavvy globe (no new renderer) ────────
  Widget _map() {
    final visited = _c.availableCountryCodes.toSet();
    return Container(
      key: const Key('v2-travels-map'),
      decoration: BoxDecoration(
        color: const Color(0xFF0B0C0F),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: GlobeMapWidget(
        // Only visited countries are selectable; taps toggle the shared set.
        onCountryTap: (iso) {
          final cc = iso.toLowerCase();
          if (visited.contains(cc)) _c.toggleCountry(cc);
        },
      ),
    );
  }

  // ── Bits ────────────────────────────────────────────────────────────────────
  Widget _segment({required List<Widget> children}) => Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: const Color(0xFF23262C),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: children),
      );

  Widget _seg(String id, String label, bool on, VoidCallback onTap) =>
      GestureDetector(
        key: Key('v2-$id'),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: on ? Colors.tealAccent.withValues(alpha: 0.2) : null,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: on ? Colors.tealAccent : Colors.white60)),
        ),
      );

  Widget _textButton(String id, String label, VoidCallback onTap) =>
      TextButton(
        key: Key('v2-$id'),
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: Colors.tealAccent,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          minimumSize: const Size(0, 32),
        ),
        child: Text(label, style: const TextStyle(fontSize: 12)),
      );

  /// ISO alpha-2 → flag emoji (regional-indicator pair). Pure, no assets.
  String _flagEmoji(String iso) {
    final code = iso.toUpperCase();
    if (code.length != 2) return '🏳️';
    return String.fromCharCodes(
        [for (final u in code.codeUnits) 0x1F1E6 + (u - 0x41)]);
  }
}
