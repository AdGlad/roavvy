import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../shared/thumbnail_channel.dart';
import 'year_in_review_service.dart';

// Regional Indicator Symbol base for flag emoji (same helper used across app).
String _flagEmoji(String isoCode) {
  if (isoCode.length != 2) return '';
  const base = 0x1F1E6;
  return String.fromCharCode(base + isoCode.codeUnitAt(0) - 65) +
      String.fromCharCode(base + isoCode.codeUnitAt(1) - 65);
}

const _kGold = Color(0xFFD4A017);
const _kDarkBg = Color(0xFF0D1117);

/// Scene label -> emoji mapping for highlight chips.
const Map<String, String> _kSceneEmoji = {
  'beach': '🏖',
  'mountain': '⛰',
  'city': '🏙',
  'forest': '🌲',
  'desert': '🏜',
  'snow': '🌨',
  'lake': '🌊',
  'coast': '🏖',
  'island': '🏝',
  'sunset': '🌅',
  'sunrise': '🌄',
  'golden_hour': '🌅',
  'night': '🌃',
  'boat': '⛵',
  'hiking': '🥾',
  'food': '🍽',
  'people': '👥',
};

/// The shareable 9:16 mosaic card for Year in Review (M94, ADR-139).
///
/// Requires pre-loaded [thumbs] from [YearInReviewCardLoader].
class YearInReviewCard extends StatelessWidget {
  const YearInReviewCard({super.key, required this.data, required this.thumbs});

  final YearInReviewData data;

  /// Thumbnail bytes keyed by assetId. Null value means still loading / unavailable.
  final Map<String, Uint8List?> thumbs;

  @override
  Widget build(BuildContext context) {
    // Collect up to 9 hero images for mosaic grid, in trip order.
    final heroSlots = <({String? assetId, String countryCode})>[];
    for (final trip in data.trips.take(9)) {
      final hero = data.heroByTripId[trip.id];
      heroSlots.add((assetId: hero?.assetId, countryCode: trip.countryCode));
    }
    // Pad to exactly 9 slots if fewer trips.
    while (heroSlots.length < 9) {
      heroSlots.add((assetId: null, countryCode: ''));
    }

    return AspectRatio(
      aspectRatio: 9 / 16,
      child: Container(
        color: _kDarkBg,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top section: year + subtitle
            const SizedBox(height: 8),
            Text(
              '${data.year}',
              style: const TextStyle(
                fontSize: 56,
                fontWeight: FontWeight.w900,
                color: _kGold,
                height: 1.0,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            const Text(
              'Your Year in Travel',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.white60,
                letterSpacing: 1.2,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // Mosaic grid
            Expanded(child: _MosaicGrid(slots: heroSlots, thumbs: thumbs)),

            const SizedBox(height: 12),

            // Stats row
            Text(
              '${data.countryCount} ${data.countryCount == 1 ? "country" : "countries"}'
              '  ·  ${data.tripCount} ${data.tripCount == 1 ? "trip" : "trips"}'
              '  ·  ${data.totalPhotos} photos',
              style: const TextStyle(
                fontSize: 13,
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),

            // Highlight chip
            if (data.topScene != null) ...[
              const SizedBox(height: 8),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _kGold.withValues(alpha: 0.15),
                    border: Border.all(color: _kGold.withValues(alpha: 0.4)),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_kSceneEmoji[data.topScene] ?? ''} ${_capitalise(data.topScene!.replaceAll('_', ' '))}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: _kGold,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 8),

            // Branding
            const Text(
              'made with Roavvy',
              style: TextStyle(fontSize: 10, color: Colors.white24),
              textAlign: TextAlign.right,
            ),
          ],
        ),
      ),
    );
  }

  static String _capitalise(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}

class _MosaicGrid extends StatelessWidget {
  const _MosaicGrid({required this.slots, required this.thumbs});

  final List<({String? assetId, String countryCode})> slots;
  final Map<String, Uint8List?> thumbs;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      crossAxisSpacing: 3,
      mainAxisSpacing: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: List.generate(9, (i) {
        final slot = slots[i];
        final bytes = slot.assetId != null ? thumbs[slot.assetId] : null;
        if (bytes != null) {
          return Image.memory(bytes, fit: BoxFit.cover);
        }
        // Fallback tile: flag emoji or dark placeholder.
        return Container(
          color: const Color(0xFF1A2233),
          alignment: Alignment.center,
          child:
              slot.countryCode.isNotEmpty
                  ? Text(
                    _flagEmoji(slot.countryCode),
                    style: const TextStyle(fontSize: 28),
                  )
                  : const SizedBox.shrink(),
        );
      }),
    );
  }
}

/// Loads thumbnail bytes for all heroes in [data], then builds [YearInReviewCard].
///
/// Notifies [onThumbsReady] when all bytes are loaded (or unavailable).
/// Used as both the preview inside [YearInReviewScreen] and the Offstage
/// widget captured for sharing.
class YearInReviewCardLoader extends StatefulWidget {
  const YearInReviewCardLoader({
    super.key,
    required this.data,
    required this.onThumbsReady,
  });

  final YearInReviewData data;
  final VoidCallback onThumbsReady;

  @override
  State<YearInReviewCardLoader> createState() => _YearInReviewCardLoaderState();
}

class _YearInReviewCardLoaderState extends State<YearInReviewCardLoader> {
  static const _thumb = ThumbnailChannel();
  final Map<String, Uint8List?> _thumbs = {};
  bool _notified = false;

  @override
  void initState() {
    super.initState();
    _loadThumbs();
  }

  @override
  void didUpdateWidget(YearInReviewCardLoader old) {
    super.didUpdateWidget(old);
    if (old.data != widget.data) {
      _thumbs.clear();
      _notified = false;
      _loadThumbs();
    }
  }

  Future<void> _loadThumbs() async {
    // Collect unique assetIds for the top-9 trips.
    final assetIds = <String>[];
    for (final trip in widget.data.trips.take(9)) {
      final hero = widget.data.heroByTripId[trip.id];
      if (hero != null) assetIds.add(hero.assetId);
    }

    if (assetIds.isEmpty) {
      _maybeNotify();
      return;
    }

    await Future.wait(
      assetIds.map((id) async {
        final bytes = await _thumb.getThumbnail(id, size: 300);
        if (mounted) setState(() => _thumbs[id] = bytes);
      }),
    );

    _maybeNotify();
  }

  void _maybeNotify() {
    if (!_notified && mounted) {
      _notified = true;
      widget.onThumbsReady();
    }
  }

  @override
  Widget build(BuildContext context) {
    return YearInReviewCard(data: widget.data, thumbs: _thumbs);
  }
}
