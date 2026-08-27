import 'package:design_forge/design_forge.dart';
import 'package:design_studio/design_studio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/country_names.dart';

/// **Detail** workspace (M3) — only shown for the **Flags** Direction. Chooses
/// the *shape the flags fill*: Grid · Map · Animals · Plants · Landmarks · Heart
/// · Circle, driven by [StudioController.applyDetail]. The three silhouette
/// shapes open a bottom-sheet picker over the full bundled inventory
/// ([StudioController.allSilhouetteOptions] / [StudioController.silhouetteOptions]),
/// so a specific national silhouette can be chosen; the pick updates the live
/// shirt immediately and is preserved when returning. The shirt above stays the
/// hero — this strip only swaps the shape.
class DetailWorkspace extends StatelessWidget {
  const DetailWorkspace({super.key, required this.controller});

  final StudioController controller;

  static const _details = <(StudioDetail, String)>[
    (StudioDetail.grid, 'Grid'),
    (StudioDetail.map, 'Map'),
    (StudioDetail.animals, 'Animals'),
    (StudioDetail.plants, 'Plants'),
    (StudioDetail.landmarks, 'Landmarks'),
    (StudioDetail.heart, 'Heart'),
    (StudioDetail.circle, 'Circle'),
  ];

  static ClipShape? _silhouetteShapeFor(StudioDetail d) => switch (d) {
        StudioDetail.animals => ClipShape.animalSilhouette,
        StudioDetail.plants => ClipShape.plantSilhouette,
        StudioDetail.landmarks => ClipShape.landmarkSilhouette,
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final active = controller.detail;
    final silShape = _silhouetteShapeFor(active);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('DETAIL',
            style: TextStyle(
                fontSize: 11, letterSpacing: 1.4, color: Colors.tealAccent)),
        const SizedBox(height: 4),
        const Text('Choose the shape your flags fill.',
            style: TextStyle(fontSize: 13, color: Colors.white70)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (d, label) in _details)
              _chip('v2-detail-${d.name}', label, active == d,
                  () => controller.applyDetail(d)),
          ],
        ),
        if (silShape != null) ...[
          const SizedBox(height: 12),
          _silhouetteRow(context, silShape),
        ],
      ],
    );
  }

  Widget _silhouetteRow(BuildContext context, ClipShape shape) {
    final all = controller.allSilhouetteOptions().where((o) => o.$1 == shape);
    final currentSlug = controller.current.clip?.code;
    if (all.isEmpty) {
      return const Text('No bundled art for this shape yet.',
          style: TextStyle(fontSize: 12, color: Colors.white38));
    }
    final currentLabel = currentSlug == null
        ? 'Default'
        : controller.silhouetteLabel(shape, currentSlug);
    return Row(children: [
      Expanded(
        child: Text('Silhouette: $currentLabel',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: Colors.white70)),
      ),
      const SizedBox(width: 8),
      OutlinedButton.icon(
        key: const Key('v2-detail-silhouette-pick'),
        style: OutlinedButton.styleFrom(
            foregroundColor: Colors.tealAccent,
            side: const BorderSide(color: Color(0xFF3A3D44))),
        icon: const Icon(Icons.grid_view, size: 16),
        label: const Text('Choose'),
        onPressed: () => _openSheet(context, shape),
      ),
    ]);
  }

  void _openSheet(BuildContext context, ClipShape shape) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF121317),
      isScrollControlled: true,
      builder: (_) => _SilhouetteSheet(controller: controller, shape: shape),
    );
  }

  Widget _chip(String id, String label, bool selected, VoidCallback onTap) =>
      GestureDetector(
        key: Key(id),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? Colors.tealAccent.withValues(alpha: 0.16)
                : const Color(0xFF23262C),
            border: Border.all(
                color: selected ? Colors.tealAccent : const Color(0xFF3A3D44),
                width: selected ? 1.5 : 1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: selected ? Colors.tealAccent : Colors.white70)),
        ),
      );
}

/// The full-inventory silhouette picker. Defaults to the design's own countries
/// (["silhouetteOptions"]) but a toggle reveals the complete bundled inventory
/// (["allSilhouetteOptions"]) so nothing is out of reach. Thumbnails render the
/// bundled SVG directly (offline); the current pick is outlined.
class _SilhouetteSheet extends StatefulWidget {
  const _SilhouetteSheet({required this.controller, required this.shape});

  final StudioController controller;
  final ClipShape shape;

  @override
  State<_SilhouetteSheet> createState() => _SilhouetteSheetState();
}

class _SilhouetteSheetState extends State<_SilhouetteSheet> {
  bool _allCountries = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final source =
        _allCountries ? c.allSilhouetteOptions() : c.silhouetteOptions();
    final options = [
      for (final o in source)
        if (o.$1 == widget.shape) o.$2
    ]..sort();
    final currentSlug = c.current.clip?.code;

    // Group by country (slug = `<cc>_<name>`) for a scannable list.
    final byCountry = <String, List<String>>{};
    for (final slug in options) {
      byCountry.putIfAbsent(slug.split('_').first, () => []).add(slug);
    }
    final countries = byCountry.keys.toList()..sort();

    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: 0.8,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 4),
              child: Row(children: [
                const Expanded(
                  child: Text('Choose a silhouette',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white)),
                ),
                Row(children: [
                  const Text('All countries',
                      style: TextStyle(fontSize: 12, color: Colors.white70)),
                  Switch(
                    key: const Key('v2-silhouette-all-toggle'),
                    value: _allCountries,
                    activeThumbColor: Colors.tealAccent,
                    onChanged: (v) => setState(() => _allCountries = v),
                  ),
                ]),
              ]),
            ),
            if (options.isEmpty)
              const Expanded(
                child: Center(
                  child: Text('No bundled art for this shape.',
                      style: TextStyle(color: Colors.white38)),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                  itemCount: countries.length,
                  itemBuilder: (context, i) {
                    final cc = countries[i];
                    final slugs = byCountry[cc]!;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
                          child: Text(
                              kCountryNames[cc.toUpperCase()] ??
                                  cc.toUpperCase(),
                              style: const TextStyle(
                                  fontSize: 12,
                                  letterSpacing: 0.5,
                                  color: Colors.tealAccent)),
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final slug in slugs)
                              _thumb(slug, slug == currentSlug, () {
                                c.setClip(
                                    Clip.shape(widget.shape, code: slug));
                                Navigator.of(context).pop();
                              }),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _thumb(String slug, bool selected, VoidCallback onTap) {
    final name = slug.split('_').skip(1).join(' ');
    return GestureDetector(
      key: Key('v2-silhouette-$slug'),
      onTap: onTap,
      child: Container(
        width: 84,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: const Color(0xFF1B1E24),
          border: Border.all(
              color: selected ? Colors.tealAccent : const Color(0xFF3A3D44),
              width: selected ? 2 : 1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 44,
              child: SvgPicture.asset(
                'assets/silhouettes/$slug.svg',
                colorFilter: ColorFilter.mode(
                    selected ? Colors.tealAccent : Colors.white70,
                    BlendMode.srcIn),
                placeholderBuilder: (_) => const SizedBox.shrink(),
              ),
            ),
            const SizedBox(height: 4),
            Text(name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 10, color: Colors.white60)),
          ],
        ),
      ),
    );
  }
}
