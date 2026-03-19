import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

/// Callback type for fetching a thumbnail for a given PHAsset local identifier.
///
/// Production callers use [_platformFetch]; tests inject a stub to avoid
/// calling the photo_manager platform channel (ADR-061).
typedef ThumbnailFetcher = Future<Uint8List?> Function(String assetId);

/// Loads a 150×150 thumbnail via photo_manager.
///
/// Never called in widget tests — tests supply their own [ThumbnailFetcher]
/// via [PhotoGalleryScreen.thumbnailFetcher].
Future<Uint8List?> _platformFetch(String assetId) async {
  final entity = await AssetEntity.fromId(assetId);
  return entity?.thumbnailDataWithSize(ThumbnailSize.square(150));
}

/// 3-column grid of photo thumbnails for a given list of PHAsset identifiers.
///
/// Empty state: displays a friendly message when [assetIds] is empty.
/// Each thumbnail shows a [CircularProgressIndicator] while loading.
/// Tapping a thumbnail pushes a full-screen [InteractiveViewer] (pinch-to-zoom).
///
/// Production callers omit [thumbnailFetcher]; tests inject a stub.
class PhotoGalleryScreen extends StatelessWidget {
  const PhotoGalleryScreen({
    super.key,
    required this.assetIds,
    this.thumbnailFetcher,
  });

  final List<String> assetIds;

  /// Override the default photo_manager fetcher. Primarily for widget tests.
  final ThumbnailFetcher? thumbnailFetcher;

  @override
  Widget build(BuildContext context) {
    if (assetIds.isEmpty) {
      return const Center(child: Text('No photos with location data'));
    }

    final fetcher = thumbnailFetcher ?? _platformFetch;

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: assetIds.length,
      itemBuilder: (context, i) => _ThumbnailCell(
        assetId: assetIds[i],
        fetcher: fetcher,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                _FullScreenPhoto(assetId: assetIds[i], fetcher: fetcher),
          ),
        ),
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _ThumbnailCell extends StatefulWidget {
  const _ThumbnailCell({
    required this.assetId,
    required this.fetcher,
    required this.onTap,
  });

  final String assetId;
  final ThumbnailFetcher fetcher;
  final VoidCallback onTap;

  @override
  State<_ThumbnailCell> createState() => _ThumbnailCellState();
}

class _ThumbnailCellState extends State<_ThumbnailCell> {
  late final Future<Uint8List?> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.fetcher(widget.assetId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data;
        if (data == null) {
          return const Center(child: Icon(Icons.broken_image_outlined));
        }
        return GestureDetector(
          onTap: widget.onTap,
          child: Image.memory(data, fit: BoxFit.cover),
        );
      },
    );
  }
}

// ── Full-screen viewer ────────────────────────────────────────────────────────

class _FullScreenPhoto extends StatefulWidget {
  const _FullScreenPhoto({required this.assetId, required this.fetcher});

  final String assetId;
  final ThumbnailFetcher fetcher;

  @override
  State<_FullScreenPhoto> createState() => _FullScreenPhotoState();
}

class _FullScreenPhotoState extends State<_FullScreenPhoto> {
  late final Future<Uint8List?> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.fetcher(widget.assetId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: FutureBuilder<Uint8List?>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data;
          if (data == null) {
            return const Center(
              child: Icon(Icons.broken_image_outlined, size: 64),
            );
          }
          return InteractiveViewer(
            child: Center(child: Image.memory(data)),
          );
        },
      ),
    );
  }
}
