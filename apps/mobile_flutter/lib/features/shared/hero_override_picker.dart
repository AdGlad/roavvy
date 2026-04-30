import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_models/shared_models.dart';

import '../../core/providers.dart';
import '../scan/hero_image_repository.dart';
import '../scan/hero_providers.dart';
import 'hero_image_view.dart';

/// Shows a bottom sheet that lets the user pick their hero image for [tripId].
///
/// Loads ALL photos for the trip's date range so the user is not limited to
/// the 3 pre-ranked candidates. Ranked candidates are labelled with their rank.
///
/// "Use this photo" calls [HeroImageRepository.upsertUserSelected];
/// "Reset to auto" calls [HeroImageRepository.clearUserSelected].
///
/// ADR-135: selection persists in Drift; isUserSelected guard (ADR-134) then
/// protects the chosen row from re-scan replacement.
Future<void> showHeroOverridePicker(
  BuildContext context,
  String tripId, {
  Color fallbackColor = const Color(0xFF374151),
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _HeroOverridePicker(
      tripId: tripId,
      fallbackColor: fallbackColor,
    ),
  );
}

class _HeroOverridePicker extends ConsumerStatefulWidget {
  const _HeroOverridePicker({
    required this.tripId,
    required this.fallbackColor,
  });

  final String tripId;
  final Color fallbackColor;

  @override
  ConsumerState<_HeroOverridePicker> createState() =>
      _HeroOverridePickerState();
}

/// Holds all data needed to render the picker.
class _PickerData {
  const _PickerData({
    required this.photos,
    required this.candidates,
    required this.trip,
  });

  /// All photos for the trip's date range, ordered by capturedAt.
  final List<PhotoDateRecord> photos;

  /// Existing ranked hero candidates (rank 1-3), keyed by assetId.
  final Map<String, HeroImage> candidates;

  /// The trip record (needed to get countryCode + capturedAt for upsert).
  final TripRecord trip;
}

class _HeroOverridePickerState extends ConsumerState<_HeroOverridePicker> {
  String? _selectedAssetId;
  bool _saving = false;

  Future<_PickerData> _load() async {
    final tripRepo = ref.read(tripRepositoryProvider);
    final visitRepo = ref.read(visitRepositoryProvider);
    final heroRepo = ref.read(heroImageRepositoryProvider);

    final trip = await tripRepo.loadById(widget.tripId);
    if (trip == null) {
      final epoch = DateTime.utc(1970);
      return _PickerData(
        photos: [],
        candidates: {},
        trip: TripRecord(
          id: '',
          countryCode: '',
          startedOn: epoch,
          endedOn: epoch,
          photoCount: 0,
          isManual: false,
        ),
      );
    }

    final photos = await visitRepo.loadPhotoRecordsByDateRange(
      trip.countryCode,
      trip.startedOn,
      trip.endedOn,
    );
    final candidateList = await heroRepo.getCandidatesForTrip(widget.tripId);
    final candidates = {for (final c in candidateList) c.assetId: c};

    return _PickerData(photos: photos, candidates: candidates, trip: trip);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final heroRepo = ref.read(heroImageRepositoryProvider);

    return FutureBuilder<_PickerData>(
      future: _load(),
      builder: (context, snapshot) {
        final data = snapshot.data;
        final photos = data?.photos ?? [];
        final candidates = data?.candidates ?? {};

        // Default selection: user-selected candidate → rank-1 candidate → first photo.
        if (_selectedAssetId == null && data != null) {
          _selectedAssetId = candidates.values
                  .where((c) => c.isUserSelected)
                  .map((c) => c.assetId)
                  .firstOrNull ??
              candidates.values
                  .where((c) => c.rank == 1)
                  .map((c) => c.assetId)
                  .firstOrNull ??
              (photos.isNotEmpty ? photos.first.assetId : null);
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Choose your hero image',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (photos.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'No photos found for this trip. Try scanning again.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                else ...[
                  Text(
                    '${photos.length} photo${photos.length == 1 ? '' : 's'}'
                    '${candidates.isNotEmpty ? ' · ${candidates.length} analysed' : ''}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 120,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: photos.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, index) {
                        final photo = photos[index];
                        final assetId = photo.assetId!;
                        final candidate = candidates[assetId];
                        final isSelected = _selectedAssetId == assetId;
                        return GestureDetector(
                          onTap: () =>
                              setState(() => _selectedAssetId = assetId),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: SizedBox(
                                  width: 120,
                                  height: 120,
                                  child: HeroImageView(
                                    assetId: assetId,
                                    fallbackColor: widget.fallbackColor,
                                    height: 120,
                                    thumbnailSize: 300,
                                  ),
                                ),
                              ),
                              if (isSelected)
                                Positioned(
                                  top: 6,
                                  right: 6,
                                  child: Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.star,
                                      size: 14,
                                      color: Colors.amber,
                                    ),
                                  ),
                                ),
                              if (candidate != null)
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius:
                                          const BorderRadius.vertical(
                                        bottom: Radius.circular(8),
                                      ),
                                      color: Colors.black.withValues(alpha: 0.45),
                                    ),
                                    child: Text(
                                      '#${candidate.rank}',
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(color: Colors.white),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving
                            ? null
                            : () async {
                                setState(() => _saving = true);
                                await heroRepo
                                    .clearUserSelected(widget.tripId);
                                if (context.mounted) Navigator.pop(context);
                              },
                        child: const Text('Reset to auto'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: (_saving ||
                                _selectedAssetId == null ||
                                data == null ||
                                data.trip.id.isEmpty)
                            ? null
                            : () async {
                                setState(() => _saving = true);
                                final photo = data.photos.firstWhere(
                                  (p) => p.assetId == _selectedAssetId,
                                );
                                await heroRepo.upsertUserSelected(
                                  assetId: _selectedAssetId!,
                                  tripId: widget.tripId,
                                  countryCode: data.trip.countryCode,
                                  capturedAt: photo.capturedAt,
                                );
                                if (context.mounted) Navigator.pop(context);
                              },
                        child: const Text('Use this photo'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
