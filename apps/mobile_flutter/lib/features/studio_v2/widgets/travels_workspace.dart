import 'package:design_studio/design_studio.dart';
import 'package:flutter/material.dart';

import '../../../core/country_names.dart';
import '../../map/globe_map_widget.dart';
import '../studio_v2_theme.dart';

/// **Travels** — which journeys this shirt represents.
///
/// Countries, and only countries: a map to pick them on, a year range to bound
/// them by, and the list itself. Map and list are two views onto the ONE
/// selection the controller holds, so neither can disagree with the other.
///
/// This supplies control content only. The compact garment above it, the drag
/// between compact and full-height, and the snap are the shell's
/// ([StudioWorkspaceShell]) — every later step inherits them the same way.
class TravelsWorkspace extends StatelessWidget {
  const TravelsWorkspace({super.key, required this.controller});

  final StudioController controller;

  StudioController get _c => controller;

  @override
  Widget build(BuildContext context) {
    final codes = _c.availableCountryCodes;
    final selected = _c.selectedCountryCodes;
    // The map is a heavy widget with its own gesture arena. Building it in a
    // const-keyed slot keeps it out of the list's recycling, so scrolling the
    // countries never rebuilds the globe.
    return _TravelsScope(
      controller: _c,
      child: CustomScrollView(
        key: const Key('v2-travels-scroll'),
        slivers: [
          SliverToBoxAdapter(child: _question()),
          const SliverToBoxAdapter(child: _MapCard()),
          SliverToBoxAdapter(child: _yearRange(context)),
          SliverToBoxAdapter(child: _countriesHeader(selected.length)),
          SliverList.builder(
            itemCount: codes.length,
            itemBuilder:
                (context, i) => _CountryRow(
                  key: Key('v2-travels-country-${codes[i]}'),
                  code: codes[i],
                  selected: _c.isSelected(codes[i]),
                  onTap: () => _c.toggleCountry(codes[i]),
                ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  Widget _question() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: StudioV2Theme.accent,
                shape: BoxShape.circle,
              ),
              child: const Text(
                '1',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Travels',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const Text(
          'Which travels should this shirt represent?',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 14),
      ],
    ),
  );

  /// The years the trips span, when there are dated trips to span them.
  Widget _yearRange(BuildContext context) {
    final span = _c.span;
    if (span == null) return const SizedBox.shrink();
    final minY = span.start!.year;
    final maxY = span.end!.year;
    // A single year is not a range — showing a slider that cannot move is
    // worse than showing nothing.
    if (maxY <= minY) return const SizedBox.shrink();
    final lo = _c.yearLo.clamp(minY, maxY).toDouble();
    final hi = _c.yearHi.clamp(minY, maxY).toDouble();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Year range',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Text(
                '${lo.round()}',
                style: const TextStyle(fontSize: 14, color: Colors.white70),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: StudioV2Theme.accent,
                    inactiveTrackColor: Colors.white12,
                    thumbColor: Colors.white,
                    overlayColor: StudioV2Theme.accent.withValues(alpha: 0.14),
                    trackHeight: 3,
                    rangeThumbShape: const RoundRangeSliderThumbShape(
                      enabledThumbRadius: 11,
                    ),
                    showValueIndicator: ShowValueIndicator.never,
                  ),
                  child: RangeSlider(
                    key: const Key('v2-travels-year'),
                    min: minY.toDouble(),
                    max: maxY.toDouble(),
                    divisions: maxY - minY,
                    values: RangeValues(lo, hi),
                    // Cheap during the drag: labels move, nothing regenerates.
                    onChanged:
                        (v) => _c.previewYear(v.start.round(), v.end.round()),
                    // The design is re-cut once, when the thumb is let go.
                    onChangeEnd:
                        (v) => _c.setYearRange(v.start.round(), v.end.round()),
                  ),
                ),
              ),
              Text(
                '${hi.round()}',
                style: const TextStyle(fontSize: 14, color: Colors.white70),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _countriesHeader(int count) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 18, 12, 6),
    child: Row(
      children: [
        Flexible(
          child: RichText(
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              children: [
                const TextSpan(
                  text: 'Countries ',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                TextSpan(
                  text: '($count selected)',
                  style: const TextStyle(fontSize: 14, color: Colors.white54),
                ),
              ],
            ),
          ),
        ),
        const Spacer(),
        _action('v2-travels-select-all', 'Select all', _c.selectAllCountries),
        _action('v2-travels-clear', 'Clear', _c.clearCountries),
      ],
    ),
  );

  Widget _action(String key, String label, VoidCallback onTap) => TextButton(
    key: Key(key),
    onPressed: onTap,
    style: TextButton.styleFrom(
      foregroundColor: StudioV2Theme.accent,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      minimumSize: const Size(0, 34),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
    child: Text(
      label,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    ),
  );
}

/// The globe, in its own widget so the country list rebuilding never rebuilds
/// it. Selection is read from the controller it finds above it.
class _MapCard extends StatelessWidget {
  const _MapCard();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Container(
      key: const Key('v2-travels-map'),
      height: 210,
      decoration: BoxDecoration(
        color: const Color(0xFF0B0C0F),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: StudioV2Theme.subtleBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: _MapBody(),
    ),
  );
}

class _MapBody extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = _TravelsScope.of(context);
    final visited = c.availableCountryCodes.toSet();
    return GlobeMapWidget(
      onCountryTap: (iso) {
        final cc = iso.toLowerCase();
        // Only somewhere they have actually been can be put on the shirt.
        if (visited.contains(cc)) c.toggleCountry(cc);
      },
    );
  }
}

/// One country: flag, name, and whether it is on the shirt.
class _CountryRow extends StatelessWidget {
  const _CountryRow({
    super.key,
    required this.code,
    required this.selected,
    required this.onTap,
  });

  final String code;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: StudioV2Theme.subtleBorder, width: 0.6),
        ),
      ),
      child: Row(
        children: [
          Text(_flagEmoji(code), style: const TextStyle(fontSize: 26)),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              kCountryNames[code.toUpperCase()] ?? code.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, color: Colors.white),
            ),
          ),
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: selected ? StudioV2Theme.accent : Colors.transparent,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(
                color: selected ? StudioV2Theme.accent : Colors.white24,
                width: 1.6,
              ),
            ),
            child:
                selected
                    ? const Icon(Icons.check, size: 18, color: Colors.white)
                    : null,
          ),
        ],
      ),
    ),
  );

  static String _flagEmoji(String iso) {
    final code = iso.toUpperCase();
    if (code.length != 2) return '🏳️';
    return String.fromCharCodes([
      0x1F1E6 + code.codeUnitAt(0) - 65,
      0x1F1E6 + code.codeUnitAt(1) - 65,
    ]);
  }
}

/// Hands the controller down to the map without threading it through every
/// intermediate widget, so the map can stay `const` and out of rebuilds.
class _TravelsScope extends InheritedWidget {
  const _TravelsScope({required this.controller, required super.child});

  final StudioController controller;

  static StudioController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_TravelsScope>()!.controller;

  @override
  bool updateShouldNotify(_TravelsScope old) =>
      !identical(old.controller, controller);
}
