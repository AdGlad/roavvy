import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_models/shared_models.dart';

import '../../core/providers.dart';
import '../heritage/heritage_detail_sheet.dart';

/// Renders a [MarkerLayer] on the flat map for every visited UNESCO World
/// Heritage Site. (M119)
///
/// Markers are shown at all zoom levels. Tapping a marker opens
/// [HeritageDetailSheet] with the site's details.
///
/// Does NOT render on the globe — globe integration is deferred.
class WorldHeritageMarkerLayer extends ConsumerWidget {
  const WorldHeritageMarkerLayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sitesAsync = ref.watch(visitedHeritageProvider);
    return sitesAsync.when(
      data: (sites) => _buildLayer(context, sites),
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildLayer(BuildContext context, List<VisitedHeritageSite> sites) {
    if (sites.isEmpty) return const SizedBox.shrink();

    final markers = sites.map((site) {
      return Marker(
        point: LatLng(site.latitude, site.longitude),
        width: 28,
        height: 28,
        child: GestureDetector(
          onTap: () => showHeritageDetailSheet(context, site),
          child: _WhsMarkerIcon(category: site.category),
        ),
      );
    }).toList();

    return MarkerLayer(markers: markers);
  }
}

/// Small circular marker icon for a World Heritage Site.
///
/// Colour-coded by [category]:
/// - Cultural → amber (matches visited-country gold theme)
/// - Natural  → green
/// - Mixed    → teal
class _WhsMarkerIcon extends StatelessWidget {
  const _WhsMarkerIcon({required this.category});

  final String category;

  @override
  Widget build(BuildContext context) {
    final color = switch (category) {
      'natural' => const Color(0xFF2E7D32),
      'mixed' => const Color(0xFF00695C),
      _ => const Color(0xFFD4A017), // cultural — matches visited-country gold
    };

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 2, offset: Offset(0, 1)),
        ],
      ),
      child: const Icon(Icons.account_balance, color: Colors.white, size: 14),
    );
  }
}
