import 'package:design_studio/design_studio.dart';
import 'package:flutter/material.dart';

import '../../../core/country_names.dart';
import '../../map/globe_map_widget.dart';
import '../studio_v2_theme.dart';

/// Choose the travels represented by the shirt. Map and List are two views onto
/// the same controller selection; the globe is the primary Roavvy experience.
class TravelsWorkspace extends StatefulWidget {
  const TravelsWorkspace({super.key, required this.controller});

  final StudioController controller;

  @override
  State<TravelsWorkspace> createState() => _TravelsWorkspaceState();
}

class _TravelsWorkspaceState extends State<TravelsWorkspace> {
  StudioController get _c => widget.controller;

  bool _mapView = true;

  @override
  Widget build(BuildContext context) {
    final dated = _c.hasTrips;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Choose your travels',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                  SizedBox(height: 3),
                  Text('Tap the places you want represented on your shirt.',
                      style: TextStyle(fontSize: 12, color: Colors.white54)),
                ],
              ),
            ),
            _viewButton(),
          ],
        ),
        if (dated) ...[
          const SizedBox(height: 10),
          Row(children: [
            _segment(
              children: [
                _seg('travels-source-countries', 'Countries', !_c.sourceTrips,
                    () => _c.setSource(false)),
                _seg('travels-source-trips', 'Trips', _c.sourceTrips,
                    () => _c.setSource(true)),
              ],
            ),
            const Spacer(),
            Text('${_c.selectedCountryCodes.length} selected',
                style: const TextStyle(fontSize: 12, color: Colors.white60)),
          ]),
          _yearRange(),
        ] else ...[
          const SizedBox(height: 10),
          Row(children: [
            Text('${_c.selectedCountryCodes.length} countries selected',
                style: const TextStyle(fontSize: 12, color: Colors.white60)),
            const Spacer(),
            _textButton('travels-select-all', 'All', _c.selectAllCountries),
            _textButton('travels-clear', 'Clear', _c.clearCountries),
          ]),
        ],
        if (dated)
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            _textButton('travels-select-all', 'Select all', _c.selectAllCountries),
            _textButton('travels-clear', 'Clear', _c.clearCountries),
          ]),
        const SizedBox(height: 6),
        Expanded(child: _mapView ? _map() : _list()),
      ],
    );
  }

  Widget _viewButton() => TextButton.icon(
        key: const Key('v2-travels-view-toggle'),
        onPressed: () => setState(() => _mapView = !_mapView),
        icon: Icon(_mapView ? Icons.list_rounded : Icons.public, size: 17),
        label: Text(_mapView ? 'List' : 'Map'),
        style: TextButton.styleFrom(foregroundColor: StudioV2Theme.accent),
      );

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
          Text('${_c.yearLo} – ${_c.yearHi}',
              style: const TextStyle(fontSize: 12, color: Colors.white70)),
          RangeSlider(
            key: const Key('v2-travels-year'),
            min: minY.toDouble(),
            max: maxY.toDouble(),
            divisions: maxY - minY,
            labels: RangeLabels('${lo.round()}', '${hi.round()}'),
            values: RangeValues(lo, hi),
            onChanged: (v) => _c.previewYear(v.start.round(), v.end.round()),
            onChangeEnd: (v) => _c.setYearRange(v.start.round(), v.end.round()),
          ),
        ],
      ),
    );
  }

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
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          leading: Text(_flagEmoji(cc), style: const TextStyle(fontSize: 22)),
          title: Text(name,
              style: const TextStyle(fontSize: 14, color: Colors.white)),
          trailing: Icon(
            selected ? Icons.check_circle : Icons.circle_outlined,
            color: selected ? StudioV2Theme.accent : Colors.white30,
            size: 20,
          ),
          onTap: () => _c.toggleCountry(cc),
        );
      },
    );
  }

  Widget _map() {
    final visited = _c.availableCountryCodes.toSet();
    return Container(
      key: const Key('v2-travels-map'),
      decoration: BoxDecoration(
        color: const Color(0xFF0B0C0F),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: GlobeMapWidget(
        onCountryTap: (iso) {
          final cc = iso.toLowerCase();
          if (visited.contains(cc)) _c.toggleCountry(cc);
        },
      ),
    );
  }

  Widget _segment({required List<Widget> children}) => Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: StudioV2Theme.control,
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
            color: on ? StudioV2Theme.accent.withValues(alpha: 0.16) : null,
            border: Border.all(
              color: on ? StudioV2Theme.accent : Colors.transparent,
            ),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: on ? StudioV2Theme.accent : Colors.white60)),
        ),
      );

  Widget _textButton(String id, String label, VoidCallback onTap) => TextButton(
        key: Key('v2-$id'),
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: StudioV2Theme.accent,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          minimumSize: const Size(0, 30),
        ),
        child: Text(label, style: const TextStyle(fontSize: 12)),
      );

  String _flagEmoji(String iso) {
    final code = iso.toUpperCase();
    if (code.length != 2) return '🏳️';
    return String.fromCharCodes(
        [for (final u in code.codeUnits) 0x1F1E6 + (u - 0x41)]);
  }
}
