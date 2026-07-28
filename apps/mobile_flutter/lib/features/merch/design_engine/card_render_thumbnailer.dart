import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_models/shared_models.dart';

import '../../cards/card_image_renderer.dart';
import 'design_engine_contracts.dart';
import 'design_params.dart';

/// Thrown when a thumbnail render fails. The optimisation loop already tolerates
/// this — it catches renderer errors and falls back to an analytic-only score
/// for that candidate (see `optimization_loop.dart`).
class ThumbnailRenderException implements Exception {
  ThumbnailRenderException(this.params, this.cause);

  final DesignParams params;
  final Object cause;

  @override
  String toString() =>
      'ThumbnailRenderException(${params.contentHash}): $cause';
}

/// M200 — the concrete [DesignRenderer] (§8). Maps a design genome onto
/// [CardImageRenderer.render] args and rasterises a low-resolution, transparent
/// thumbnail for the pixel scorers and the gallery.
///
/// [CardImageRenderer] rasterises a widget via a `RepaintBoundary`, so it **must
/// run on the UI thread** with a live [BuildContext] — it cannot run in a Dart
/// isolate. This class therefore:
///
///  * serialises renders through a **concurrency-1 queue**, yielding a frame
///    (`SchedulerBinding.endOfFrame`) between renders so the UI stays responsive;
///  * caches results in a bounded **LRU byte cache** keyed by
///    [DesignParams.contentHash], so re-rendering the same genome is free.
class CardRenderThumbnailer implements DesignRenderer {
  /// [contextProvider] yields a live [BuildContext] at render time (re-read on
  /// every render so a stale context is never captured).
  ///
  /// [pixelRatio] is deliberately low (scoring thumbnails, not the HD print).
  /// [cacheCapacity] bounds the LRU byte cache. [assetsTimeout] caps how long a
  /// render waits for SVG assets (flags / stamps) to load. [frameYield] is
  /// injectable so tests can substitute a cheap microtask yield for the real
  /// end-of-frame wait.
  CardRenderThumbnailer(
    this.contextProvider, {
    this.pixelRatio = 2.0,
    int cacheCapacity = 64,
    this.assetsTimeout = const Duration(seconds: 10),
    Future<void> Function()? frameYield,
  })  : _cache = _LruByteCache(cacheCapacity),
        _frameYield =
            frameYield ?? (() => SchedulerBinding.instance.endOfFrame);

  /// Convenience constructor when the context is stable for the renderer's life.
  factory CardRenderThumbnailer.forContext(
    BuildContext context, {
    double pixelRatio = 2.0,
    int cacheCapacity = 64,
    Duration assetsTimeout = const Duration(seconds: 10),
    Future<void> Function()? frameYield,
  }) =>
      CardRenderThumbnailer(
        () => context,
        pixelRatio: pixelRatio,
        cacheCapacity: cacheCapacity,
        assetsTimeout: assetsTimeout,
        frameYield: frameYield,
      );

  final BuildContext Function() contextProvider;
  final double pixelRatio;
  final Duration assetsTimeout;
  final Future<void> Function() _frameYield;
  final _LruByteCache _cache;

  // Concurrency-1 queue: every render chains onto this tail so only one runs at
  // a time.
  Future<void> _queueTail = Future<void>.value();

  // Test hook: how many times a genome was actually rasterised (cache misses).
  int _renderCount = 0;

  /// Number of real rasterisations performed (cache hits do not increment).
  int get renderCount => _renderCount;

  /// Current number of cached genomes.
  int get cacheSize => _cache.length;

  @override
  Future<Uint8List> renderThumbnail(
    DesignParams params,
    List<TripRecord> trips,
  ) {
    final key = params.contentHash;
    final cached = _cache.get(key);
    if (cached != null) return Future<Uint8List>.value(cached);
    return _enqueue(params, trips, key);
  }

  Future<Uint8List> _enqueue(
    DesignParams params,
    List<TripRecord> trips,
    String key,
  ) {
    final completer = Completer<Uint8List>();
    _queueTail = _queueTail.then((_) async {
      // A duplicate request may have been rendered while this one was queued.
      final cached = _cache.get(key);
      if (cached != null) {
        completer.complete(cached);
        return;
      }
      try {
        // Yield a frame so a burst of renders doesn't jank the UI thread.
        await _frameYield();
        final bytes = await _renderOne(params, trips);
        _cache.put(key, bytes);
        completer.complete(bytes);
      } catch (e, st) {
        completer.completeError(ThumbnailRenderException(params, e), st);
      }
    });
    return completer.future;
  }

  Future<Uint8List> _renderOne(
    DesignParams params,
    List<TripRecord> trips,
  ) async {
    _renderCount++;
    final context = contextProvider();
    final preset = params.toPresetConfig();

    // Only pass trips for the countries being designed — prevents stamps from
    // unrelated countries appearing (mirrors _generateFromPreset).
    final codeSet = params.countryCodes.toSet();
    final scopedTrips =
        trips.where((t) => codeSet.contains(t.countryCode)).toList();

    // Sync, cheap aspect choice — deliberately NOT the async clip-aspect path.
    final aspect = params.isPortrait ? 4.0 / 5.0 : 5.0 / 4.0;

    final result = await CardImageRenderer.render(
      context,
      params.template,
      codes: params.countryCodes,
      trips: scopedTrips,
      pixelRatio: pixelRatio,
      transparentBackground: true,
      cardAspectRatio: aspect,
      textColor: _inkColorFor(params.shirtColour),
      // Stamp genes via the preset (matches MerchPresetConfig getters).
      entryOnly: preset.entryOnly,
      stampSizeMultiplier: preset.stampSizeMultiplier,
      stampJitterFactor: preset.jitter,
      // Flag-grid genes.
      gridLayoutMode: params.gridLayoutMode,
      clipShape: params.clipShape,
      clipCode: params.clipCode,
      rowCount: params.rowCount,
      stampSeed: params.seed,
      assetsTimeout: assetsTimeout,
    );
    return result.bytes;
  }

  /// Adaptive ink colour — light ink on dark garments, dark ink on light ones
  /// (mirrors M193 / `merchDefaultTextColor` and `_suggestGridTextColor`), so
  /// the artwork always contrasts against the shirt.
  static Color _inkColorFor(String shirtColour) => switch (shirtColour) {
        'White' => const Color(0xFF000000),
        'Grey' => const Color(0xFF000000),
        'Heather Grey' => const Color(0xFF000000),
        _ => const Color(0xFFFFFFFF), // Black, Blue, Navy, Red → light ink
      };
}

/// A tiny bounded LRU cache of PNG byte buffers keyed by content hash.
class _LruByteCache {
  _LruByteCache(this.capacity);

  final int capacity;
  final LinkedHashMap<String, Uint8List> _map =
      LinkedHashMap<String, Uint8List>();

  int get length => _map.length;

  Uint8List? get(String key) {
    final value = _map.remove(key);
    if (value == null) return null;
    _map[key] = value; // re-insert → most-recently-used.
    return value;
  }

  void put(String key, Uint8List value) {
    _map.remove(key);
    _map[key] = value;
    while (_map.length > capacity) {
      _map.remove(_map.keys.first); // evict least-recently-used.
    }
  }
}
