import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_models/shared_models.dart';

import '../scan/hero_image_repository.dart';
import '../scan/hero_providers.dart';
import 'hero_image_view.dart';

/// Shows a bottom sheet that lets the user pick their hero image for [tripId].
///
/// Displays rank-1/2/3 candidate thumbnails. "Use this photo" calls
/// [HeroImageRepository.setUserSelected]; "Reset to auto" calls
/// [HeroImageRepository.clearUserSelected].
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

class _HeroOverridePickerState extends ConsumerState<_HeroOverridePicker> {
  String? _selectedAssetId;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final repo = ref.read(heroImageRepositoryProvider);

    return FutureBuilder<List<HeroImage>>(
      future: repo.getCandidatesForTrip(widget.tripId),
      builder: (context, snapshot) {
        final candidates = snapshot.data ?? [];
        _selectedAssetId ??= candidates
            .where((c) => c.isUserSelected)
            .map((c) => c.assetId)
            .firstOrNull;

        // If no user selection, default to rank-1 candidate.
        if (_selectedAssetId == null && candidates.isNotEmpty) {
          _selectedAssetId = candidates
              .where((c) => c.rank == 1)
              .map((c) => c.assetId)
              .firstOrNull ??
              candidates.first.assetId;
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
                else if (candidates.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'No hero images available yet. Try scanning again.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                else ...[
                  if (candidates.length == 1)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'This is your only candidate.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  SizedBox(
                    height: 120,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: candidates.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, index) {
                        final candidate = candidates[index];
                        final isSelected =
                            _selectedAssetId == candidate.assetId;
                        return GestureDetector(
                          onTap: () => setState(
                            () => _selectedAssetId = candidate.assetId,
                          ),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: SizedBox(
                                  width: 120,
                                  height: 120,
                                  child: HeroImageView(
                                    assetId: candidate.assetId,
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
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: const BorderRadius.vertical(
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
                                await repo.clearUserSelected(widget.tripId);
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
                                candidates.isEmpty)
                            ? null
                            : () async {
                                setState(() => _saving = true);
                                await repo.setUserSelected(
                                  _selectedAssetId!,
                                  widget.tripId,
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
