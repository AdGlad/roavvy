import 'dart:async';

import 'package:country_lookup/country_lookup.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_models/shared_models.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../core/globe_overlay.dart';
import '../../core/notification_service.dart';
import '../../core/providers.dart';
import '../../data/photo_gps_repository.dart';
import '../../core/theme/theme_mode_provider.dart';
import '../../data/firestore_sync_service.dart';
import '../xp/xp_event.dart';
import '../auth/apple_sign_in.dart' as apple;
import '../cards/card_type_picker_screen.dart';
import '../settings/privacy_account_screen.dart';
import '../sharing/travel_card_share.dart';
import '../memory/memory_pulse_card.dart';
import '../year_in_review/year_in_review_providers.dart';
import '../year_in_review/year_in_review_screen.dart';
import 'country_detail_sheet.dart';
import 'country_profile_screen.dart';
import 'country_polygon_layer.dart';
import 'space_background.dart';
import '../globe_replay/replay_entry_sheet.dart';
import 'country_centroids.dart';
import 'globe_map_widget.dart';
import 'globe_projection.dart';
import '../challenge/challenge_stats_screen.dart';
import '../challenge/daily_challenge_screen.dart';
import '../heritage/unesco_nearby_explorer_screen.dart';
import 'region_chips_marker_layer.dart';
import 'world_heritage_marker_layer.dart';
import 'map_photo_pin.dart';
import 'map_photo_strip.dart';
import 'photo_heatmap_layer.dart';
import 'region_progress_notifier.dart';
import 'rovy_bubble.dart';
import 'stats_strip.dart';
import 'target_country_layer.dart';
import 'timeline_scrubber_bar.dart';
import 'xp_level_bar.dart';

/// Displays all country polygons on an offline flutter_map canvas.
///
/// Polygon rendering is delegated to [CountryPolygonLayer] which applies
/// per-visual-state colours and animations (ADR-066). [MapScreen] retains
/// [_visitedByCode] solely for tap resolution.
///
/// [tapResolverOverride] is a test hook that bypasses [resolveCountry()].
/// [onNavigateToScan] is called when the user taps "Scan Photos" in the empty
/// state overlay — used by [MainShell] to switch to the Scan tab.
/// [signInWithAppleOverride] is a test hook that replaces the full Apple
/// sign-in flow (avoids platform channel in widget tests).
/// [syncService] overrides the default [FirestoreSyncService]; pass
/// [NoOpSyncService] in widget tests to prevent real Firestore calls (ADR-030).
class MapScreen extends ConsumerWidget {
  const MapScreen({
    super.key,
    this.tapResolverOverride,
    this.onNavigateToScan,
    this.onNavigateToScanFull,
    this.onNavigateToScanPartial,
    this.signInWithAppleOverride,
    this.syncService,
  });

  /// Test hook: if non-null, called instead of [resolveCountry()] on tap.
  final String? Function(double lat, double lng)? tapResolverOverride;

  /// Called when the user taps "Scan Photos" in the empty state overlay.
  final VoidCallback? onNavigateToScan;

  /// Called when the user taps "Full Scan" in the action bar.
  final VoidCallback? onNavigateToScanFull;

  /// Called when the user taps "New Photos" in the action bar.
  final VoidCallback? onNavigateToScanPartial;

  /// Test hook: if non-null, called instead of the real Apple sign-in flow.
  final Future<void> Function()? signInWithAppleOverride;

  /// Sync service used to flush dirty records after Apple sign-in.
  final SyncService? syncService;

  SyncService _syncService() => syncService ?? FirestoreSyncService();

  Future<void> _onDeleteHistory(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Delete all travel history?'),
            content: const Text(
              'This will remove all scanned and manually added countries.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
    if (confirmed != true) return;
    await ref.read(visitRepositoryProvider).clearAll();
    await ref.read(roavvyDatabaseProvider).resetOnboarding();
    ref.invalidate(effectiveVisitsProvider);
    ref.invalidate(travelSummaryProvider);
    ref.invalidate(tripListProvider); // ADR-081: refresh Journal tab
    ref.invalidate(regionCountProvider); // ADR-082: refresh Stats regions count
    ref.invalidate(countryTripCountsProvider);
    ref.invalidate(earliestVisitYearProvider);
    ref.invalidate(onboardingCompleteProvider);
  }

  Future<void> _onSignInWithApple(BuildContext context, WidgetRef ref) async {
    if (signInWithAppleOverride != null) {
      await signInWithAppleOverride!();
      return;
    }
    try {
      await apple.signInWithApple(
        repo: ref.read(visitRepositoryProvider),
        syncService: _syncService(),
        tripRepo: ref.read(tripRepositoryProvider),
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return;
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in failed. Try again.')),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in failed. Try again.')),
      );
    }
  }

  void _onMapTap(
    BuildContext context,
    WidgetRef ref,
    Map<String, EffectiveVisitedCountry> visitedByCode,
    TapPosition _,
    LatLng point,
  ) {
    // Google Photos behaviour: tapping a heat blob selects the nearest photo
    // (pin drops, grid scrolls to it). Falls through to the country sheet
    // when the tap isn't near any photo.
    if (_tryHeatTap(context, ref, point)) return;

    final resolver = tapResolverOverride ?? resolveCountry;
    final code = resolver(point.latitude, point.longitude);
    if (code == null) return;
    _showCountryDetail(context, ref, code, visitedByCode);
  }

  /// Selects the photo nearest to [point] if it is within roughly one heat
  /// blob radius on screen. Returns true when a photo was selected.
  ///
  /// Screen distance is approximated from the current viewport bounds
  /// (degrees-per-pixel), which is accurate enough for tap disambiguation.
  bool _tryHeatTap(BuildContext context, WidgetRef ref, LatLng point) {
    if (!ref.read(showPhotoThumbnailsProvider)) return false;
    final locations = ref.read(photoLocationsProvider).valueOrNull;
    final vp = ref.read(mapViewportProvider);
    if (locations == null || locations.isEmpty || vp == null) return false;

    final screenWidth = MediaQuery.of(context).size.width;
    final degPerPx = (vp.east - vp.west) / screenWidth;
    if (degPerPx <= 0) return false;
    const thresholdPx = 28.0;

    PhotoLocation? nearest;
    var nearestPx = thresholdPx;
    for (final loc in locations) {
      final dxPx = (loc.lng - point.longitude).abs() / degPerPx;
      if (dxPx > thresholdPx) continue;
      final dyPx = (loc.lat - point.latitude).abs() / degPerPx;
      if (dyPx > thresholdPx) continue;
      final dist = (Offset(dxPx, dyPx)).distance;
      if (dist < nearestPx) {
        nearestPx = dist;
        nearest = loc;
      }
    }
    if (nearest == null) return false;
    ref.read(selectedMapPhotoProvider.notifier).state = nearest;
    // Re-sort the gallery around the tapped area, nearest photo first
    // (Google Photos: "tap the heat mark to jump to photos in that area").
    ref.read(mapGallerySortAnchorProvider.notifier).state = nearest;
    // Reveal the grid so the tap visibly scrolls it to the selected photo.
    ref.read(mapPhotoPanelExpandedProvider.notifier).state = true;
    return true;
  }

  /// Shows [CountryDetailSheet] for a country tapped on the globe (ADR-116).
  void _onGlobeTap(
    BuildContext context,
    WidgetRef ref,
    String isoCode,
    Map<String, EffectiveVisitedCountry> visitedByCode,
  ) {
    _showCountryDetail(context, ref, isoCode, visitedByCode);
  }

  void _showCountryDetail(
    BuildContext context,
    WidgetRef ref,
    String code,
    Map<String, EffectiveVisitedCountry> visitedByCode,
  ) {
    final visit = visitedByCode[code];

    if (visit != null) {
      // Visited country → full-screen profile (ADR-009 revised).
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              CountryProfileScreen(isoCode: code, visit: visit),
        ),
      );
    } else {
      // Unvisited country → lightweight add sheet.
      showModalBottomSheet<bool>(
        context: context,
        builder: (_) => CountryDetailSheet(
          isoCode: code,
          visit: null,
          onAdd: () => ref.read(visitRepositoryProvider).saveAdded(
                UserAddedCountry(
                  countryCode: code,
                  addedAt: DateTime.now().toUtc(),
                ),
              ),
        ),
      ).then((added) {
        if (added == true) ref.invalidate(effectiveVisitsProvider);
      });
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Trigger the one-time background GPS fetch (M155). Non-blocking — the
    // provider caches its result so this only runs once per app session.
    ref.watch(photoGpsFetchProvider);

    final user = ref.watch(authStateProvider).valueOrNull;
    final isAnonymous = user == null || user.isAnonymous;
    final isDarkMode = ref.watch(themeModeProvider) == ThemeMode.dark;

    // Height of the photo grid panel shown below the flat map (2 tile rows).
    // Used to offset floating buttons so they sit above the grid.
    final screenWidth = MediaQuery.of(context).size.width;

    final yearFilter = ref.watch(yearFilterProvider);

    // Derive earliestVisitYear for the "Filter by year" menu item.
    final earliestYear = ref.watch(earliestVisitYearProvider).valueOrNull;
    final showFilterByYear =
        (earliestYear != null && earliestYear < DateTime.now().year) ||
        yearFilter != null;

    // Derive visitedByCode reactively — used for tap resolution and empty-state.
    final visitsAsync = ref.watch(effectiveVisitsProvider);
    final visitedByCode = {
      for (final v in visitsAsync.valueOrNull ?? <EffectiveVisitedCountry>[])
        v.countryCode: v,
    };
    final hasVisits = visitedByCode.isNotEmpty;

    // 30-day scan nudge banner (ADR-085).
    final lastScanAt = ref.watch(lastScanAtProvider).valueOrNull;
    final nudgeDismissed = ref.watch(scanNudgeDismissedProvider);
    final showNudge =
        hasVisits &&
        !nudgeDismissed &&
        lastScanAt != null &&
        DateTime.now().difference(lastScanAt) >= const Duration(days: 30);

    // Show loading indicator until effective visits first resolve.
    if (visitsAsync.isLoading && visitedByCode.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Fire region-1-away Rovy nudge whenever a region transitions to exactly
    // 1 country remaining and the user has at least one visit in that region.
    ref.listen<List<RegionProgressData>>(regionProgressProvider, (
      previous,
      next,
    ) {
      final prevOneAway =
          (previous ?? const <RegionProgressData>[])
              .where((r) => r.remaining == 1 && r.visitedCount > 0)
              .map((r) => r.region)
              .toSet();
      for (final data in next) {
        if (data.remaining == 1 &&
            data.visitedCount > 0 &&
            !prevOneAway.contains(data.region)) {
          ref.read(rovyMessageProvider.notifier).state = RovyMessage(
            text: 'Just 1 more country to complete ${data.region.displayName}!',
            trigger: RovyTrigger.regionOneAway,
            emoji: '🎯',
          );
          break; // one message at a time
        }
      }
    });

    final globeMode = ref.watch(globeModeProvider);
    final overlayMode = ref.watch(mapOverlayModeProvider);
    // The photo gallery panel shows in heatmap mode on EITHER view; heritage
    // mode shows the visited-flag strip instead — see the body Stack below.
    // Shared mode so switching between globe and flat map keeps your choice.
    final showPhotoGrid = overlayMode == MapOverlayMode.heatmap;
    final photoPanelExpanded = ref.watch(mapPhotoPanelExpandedProvider);
    final photoGridH = showPhotoGrid
        ? MapPhotoStrip.panelHeight(screenWidth, expanded: photoPanelExpanded)
        : 0.0;
    final filteredVisits =
        ref.watch(filteredEffectiveVisitsProvider).valueOrNull ??
        const <EffectiveVisitedCountry>[];
    // M134: hide map UI controls while replay/scan overlay is active so only
    // the globe and the replay HUD are visible.
    final overlayActive = ref.watch(globeOverlayProvider).isActive;
    final mapTheme = Theme.of(context);
    final mapIsDark = mapTheme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          mapIsDark ? const Color(0xFF030D1A) : mapTheme.colorScheme.surface,
      body: Stack(
        children: [
          // Deep-space starfield — visible in dark mode only.
          // For the flat map the FlutterMap background is transparent so stars
          // show through the ocean gaps between continents.
          // For globe mode the globe circle covers the centre; stars fill
          // the corners of the screen outside the disk.
          if (mapIsDark) const StarfieldBackground(),

          if (globeMode)
            _GlobeWithHeroPin(
              onCountryTap:
                  (code) => _onGlobeTap(context, ref, code, visitedByCode),
              showHeroPin: overlayMode == MapOverlayMode.heatmap,
            )
          else
            FlutterMap(
              options: MapOptions(
                initialCenter: const LatLng(20, 0),
                initialZoom: 2,
                // Flat map uses a solid ocean colour — no stars visible through
                // the ocean gaps. Globe mode uses transparent so stars fill the
                // corners outside the disk (handled by GlobeMapWidget instead).
                backgroundColor:
                    mapIsDark
                        ? const Color(0xFF0D2137) // dark ocean blue
                        : const Color(0xFFB8D4E8), // light ocean blue
                // Rotation left out deliberately — a two-finger twist gesture
                // could otherwise skew the map off the horizontal with no way
                // back to level short of restarting the gesture. Every other
                // default interaction (drag, pinch-zoom, fling, double-tap
                // zoom) is preserved.
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
                onTap:
                    (pos, latlng) =>
                        _onMapTap(context, ref, visitedByCode, pos, latlng),
                onPositionChanged: (camera, _) {
                  final b = camera.visibleBounds;
                  ref.read(mapViewportProvider.notifier).state = (
                    north: b.north,
                    south: b.south,
                    east: b.east,
                    west: b.west,
                  );
                },
              ),
              children: [
                const CountryPolygonLayer(),
                const TargetCountryLayer(),
                const RegionChipsMarkerLayer(),
                // Heritage markers and the photo heatmap compete for the same
                // visual space and tap targets — mutually exclusive, same as
                // the globe (see MapOverlayMode).
                if (overlayMode == MapOverlayMode.heritage)
                  const WorldHeritageMarkerLayer()
                else ...[
                  const PhotoHeatmapLayer(),
                  // Google Photos-style: no thumbnail clusters — a heatmap at
                  // every zoom plus anchor dots and a single photo pin.
                  const PhotoAnchorDotsLayer(),
                  const PhotoPinLayer(),
                ],
              ],
            ),

          // Aurora borealis / australis — slow gradient drift at the poles.
          // Sits above the map/globe, below all UI controls. Dark mode only.
          if (mapIsDark) const AuroraOverlay(),

          // All map UI is hidden while replay/scan overlay is active (M134).
          if (!overlayActive) ...[
            const Align(alignment: Alignment.topCenter, child: XpLevelBar()),
            const Align(
              alignment: Alignment.topCenter,
              child: _MemoryPulseSection(),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showNudge)
                    _ScanNudgeBanner(
                      onScan: onNavigateToScan,
                      onDismiss:
                          () =>
                              ref
                                  .read(scanNudgeDismissedProvider.notifier)
                                  .state = true,
                    ),
                  const _YearInReviewBanner(),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Center(
                      child: _GlobeActionBar(
                        onFullScan: onNavigateToScanFull,
                        onNewPhotos: onNavigateToScanPartial,
                        onReplay:
                            globeMode
                                ? () => showReplayEntrySheet(context)
                                : null,
                      ),
                    ),
                  ),
                  if (showPhotoGrid)
                    const MapPhotoStrip()
                  else if (visitedByCode.isNotEmpty)
                    _VisitedCountryFlagStrip(visits: filteredVisits),
                  const TimelineScrubberBar(),
                ],
              ),
            ),
            // Travel stats — top-left text overlay on the map (frees the
            // vertical space the old bottom stats bar occupied).
            Positioned(
              top: MediaQuery.of(context).padding.top + 96,
              left: 14,
              child: const StatsStrip(),
            ),
            // Action chips — top center, below the XP progress bar.
            Positioned(
              top: MediaQuery.of(context).padding.top + 48,
              left: 0,
              right: 0,
              child: const Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _DailyChallengeChip(),
                    SizedBox(width: 8),
                    _UnescoNearbyChip(),
                  ],
                ),
              ),
            ),
            if (!hasVisits)
              _EmptyStateOverlay(onNavigateToScan: onNavigateToScan),
            Positioned(
              bottom: photoGridH + 16,
              left: 0,
              right: 0,
              child: const Center(child: RovyBubble()),
            ),
            // Globe ↔ flat map toggle + rotation toggle — bottom-right.
            // Offsets are reduced in landscape where the screen is shorter.
            Builder(
              builder: (context) {
                final isLandscape =
                    MediaQuery.of(context).orientation == Orientation.landscape;
                final baseBottom = isLandscape ? 100.0 : photoGridH + 56;
                return Stack(
                  children: [
                    // Heatmap/heritage overlay toggle — available on both
                    // views (see MapOverlayMode). Top→bottom in globe mode:
                    // overlay toggle, view toggle, rotation.
                    Positioned(
                      bottom: globeMode ? baseBottom + 104 : baseBottom + 52,
                      right: 12,
                      child: const _MapOverlayModeToggle(),
                    ),
                    Positioned(
                      bottom: globeMode ? baseBottom + 52 : baseBottom,
                      right: 12,
                      child: _MapViewToggle(globeMode: globeMode),
                    ),
                    if (globeMode)
                      Positioned(
                        bottom: baseBottom,
                        right: 12,
                        child: const _GlobeRotationToggle(),
                      ),
                  ],
                );
              },
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 8,
              child: Material(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(20),
                child: PopupMenuButton<_MapMenuAction>(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  onSelected: (action) {
                    if (action == _MapMenuAction.signInWithApple) {
                      _onSignInWithApple(context, ref);
                    } else if (action == _MapMenuAction.deleteHistory) {
                      _onDeleteHistory(context, ref);
                    } else if (action == _MapMenuAction.shareMyMap) {
                      final s =
                          ref.read(travelSummaryProvider).valueOrNull ??
                          TravelSummary.fromVisits(
                            visitedByCode.values.toList(),
                          );
                      captureAndShare(context, s, 'My Roavvy travel map');
                      ref
                          .read(rovyMessageProvider.notifier)
                          .state = const RovyMessage(
                        text: 'Love it! Thanks for sharing your adventures!',
                        trigger: RovyTrigger.postShare,
                        emoji: '🙌',
                      );
                      final now = DateTime.now().toUtc();
                      unawaited(
                        ref
                            .read(xpNotifierProvider.notifier)
                            .award(
                              XpEvent(
                                id: '${now.microsecondsSinceEpoch}-share',
                                reason: XpReason.share,
                                amount: 30,
                                awardedAt: now,
                              ),
                            ),
                      );
                    } else if (action == _MapMenuAction.createCard) {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const CardTypePickerScreen(),
                        ),
                      );
                    } else if (action == _MapMenuAction.privacyAccount) {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const PrivacyAccountScreen(),
                        ),
                      );
                    } else if (action == _MapMenuAction.signOut) {
                      FirebaseAuth.instance.signOut();
                    } else if (action == _MapMenuAction.filterByYear) {
                      ref.read(yearFilterProvider.notifier).state =
                          yearFilter != null ? null : DateTime.now().year;
                    } else if (action == _MapMenuAction.toggleDarkMode) {
                      ref.read(themeModeProvider.notifier).toggle();
                    } else if (action == _MapMenuAction.debugMemoryPulse) {
                      final notifier = ref.read(
                        memoryPulseDebugOverrideProvider.notifier,
                      );
                      final turningOn = !notifier.state;
                      notifier.state = turningOn;
                      if (turningOn) {
                        // Clear session-dismissed set so previously-seen cards reappear.
                        ref.read(memoriesDismissedProvider.notifier).state = {};
                        // Clear the "shown today" pref so the post-scan tray
                        // can also re-trigger on demand.
                        unawaited(
                          ref
                              .read(memoryPulseServiceProvider)
                              .clearShownState(),
                        );
                      }
                      ref.invalidate(todaysMemoriesProvider);
                    }
                  },
                  itemBuilder:
                      (_) => [
                        if (isAnonymous)
                          const PopupMenuItem(
                            value: _MapMenuAction.signInWithApple,
                            child: ListTile(
                              leading: Icon(Icons.person_add_outlined),
                              title: Text('Sign in with Apple'),
                            ),
                          )
                        else
                          const PopupMenuItem(
                            enabled: false,
                            value: _MapMenuAction.signInWithApple,
                            child: ListTile(
                              leading: Icon(Icons.check_circle_outline),
                              title: Text('Signed in with Apple'),
                            ),
                          ),
                        if (hasVisits)
                          const PopupMenuItem(
                            value: _MapMenuAction.shareMyMap,
                            child: ListTile(
                              leading: Icon(Icons.share),
                              title: Text('Share travel card'),
                            ),
                          ),
                        if (hasVisits)
                          const PopupMenuItem(
                            value: _MapMenuAction.createCard,
                            child: ListTile(
                              leading: Icon(Icons.style_outlined),
                              title: Text('Create card'),
                            ),
                          ),
                        PopupMenuItem(
                          value: _MapMenuAction.deleteHistory,
                          child: ListTile(
                            leading: Icon(
                              Icons.delete_outline,
                              color: Colors.red.shade600,
                            ),
                            title: Text(
                              'Clear travel history',
                              style: TextStyle(color: Colors.red.shade600),
                            ),
                          ),
                        ),
                        const PopupMenuItem(
                          value: _MapMenuAction.privacyAccount,
                          child: ListTile(
                            leading: Icon(Icons.security),
                            title: Text('Privacy & account'),
                          ),
                        ),
                        PopupMenuItem(
                          value: _MapMenuAction.toggleDarkMode,
                          child: ListTile(
                            leading: Icon(
                              isDarkMode
                                  ? Icons.light_mode_outlined
                                  : Icons.dark_mode_outlined,
                            ),
                            title: Text(
                              isDarkMode ? 'Light mode' : 'Dark mode',
                            ),
                          ),
                        ),
                        const PopupMenuItem(
                          value: _MapMenuAction.signOut,
                          child: ListTile(
                            leading: Icon(Icons.logout),
                            title: Text('Sign out'),
                          ),
                        ),
                        if (showFilterByYear)
                          PopupMenuItem(
                            value: _MapMenuAction.filterByYear,
                            child: ListTile(
                              leading: const Icon(Icons.timeline),
                              title: Text(
                                yearFilter != null
                                    ? 'Clear year filter'
                                    : 'Filter by year',
                              ),
                            ),
                          ),
                        PopupMenuItem(
                          value: _MapMenuAction.debugMemoryPulse,
                          child: ListTile(
                            leading: const Icon(Icons.history_toggle_off),
                            title: Text(
                              ref.watch(memoryPulseDebugOverrideProvider)
                                  ? 'Hide memory pulse'
                                  : 'Show memory pulse',
                            ),
                          ),
                        ),
                      ],
                ),
              ),
            ),
            // App-open scan prompt gate (Task 150 — M43)
            _ScanPromptGate(onNavigateToScan: onNavigateToScan),
          ], // end !overlayActive
        ],
      ),
    );
  }
}

// ── Scan nudge banner ──────────────────────────────────────────────────────────

/// Dismissible amber banner shown when the user hasn't scanned in 30+ days.
/// Dismissed per-session via [scanNudgeDismissedProvider]. (ADR-085)
class _ScanNudgeBanner extends StatelessWidget {
  const _ScanNudgeBanner({this.onScan, required this.onDismiss});

  final VoidCallback? onScan;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFB300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              "It's been a while — time for a new scan",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          TextButton(
            onPressed: onScan,
            child: const Text(
              'Scan now',
              style: TextStyle(color: Colors.white),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 18),
            onPressed: onDismiss,
            tooltip: 'Dismiss',
          ),
        ],
      ),
    );
  }
}

// ── Menu actions ───────────────────────────────────────────────────────────────

enum _MapMenuAction {
  signInWithApple,
  deleteHistory,
  shareMyMap,
  createCard,
  privacyAccount,
  signOut,
  filterByYear,
  toggleDarkMode,
  debugMemoryPulse,
}

// ── Visited country flag strip ─────────────────────────────────────────────────

/// Horizontal scrollable strip of emoji flags for visited countries (M86).
///
/// Shown above the timeline scrubber when the globe is active. Tapping a flag
/// writes the country's centroid to [globeTargetProvider], which [GlobeMapWidget]
/// animates to over 900 ms.
class _VisitedCountryFlagStrip extends ConsumerWidget {
  const _VisitedCountryFlagStrip({required this.visits});

  /// All effective visits; sorted here by [firstSeen] ascending (earliest first).
  final List<EffectiveVisitedCountry> visits;

  static String _flag(String iso) {
    if (iso.length != 2) return '';
    const base = 0x1F1E6;
    return String.fromCharCode(base + iso.codeUnitAt(0) - 65) +
        String.fromCharCode(base + iso.codeUnitAt(1) - 65);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Sort by firstSeen ascending; null dates (manually added) go to the end.
    final sorted = [...visits]..sort((a, b) {
      final fa = a.firstSeen;
      final fb = b.firstSeen;
      if (fa == null && fb == null) return 0;
      if (fa == null) return 1;
      if (fb == null) return -1;
      return fa.compareTo(fb);
    });

    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: sorted.length,
        itemBuilder: (context, index) {
          final code = sorted[index].countryCode;
          final centroid = kCountryCentroids[code];
          return Tooltip(
            message: code,
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap:
                  centroid == null
                      ? null
                      : () =>
                          ref.read(globeTargetProvider.notifier).state = (
                            centroid.$1,
                            centroid.$2,
                          ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Text(_flag(code), style: const TextStyle(fontSize: 22)),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────────────

/// Shown over the map when the user has no visited countries yet.
class _EmptyStateOverlay extends StatelessWidget {
  const _EmptyStateOverlay({this.onNavigateToScan});

  final VoidCallback? onNavigateToScan;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 32),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Scan your photos to see where you've been",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onNavigateToScan,
                child: const Text('Scan Photos'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── App-open scan prompt ───────────────────────────────────────────────────────

/// Invisible gate widget that shows [DiscoverNewCountriesSheet] once per day
/// when onboarding is complete and the last scan was > 7 days ago. (ADR-095)
class _ScanPromptGate extends ConsumerStatefulWidget {
  const _ScanPromptGate({this.onNavigateToScan});
  final VoidCallback? onNavigateToScan;

  @override
  ConsumerState<_ScanPromptGate> createState() => _ScanPromptGateState();
}

class _ScanPromptGateState extends ConsumerState<_ScanPromptGate> {
  static const _prefKey = 'scan_prompt_dismissed_at';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShow());
  }

  Future<void> _maybeShow() async {
    if (!mounted) return;

    final onboardingDone = await ref
        .read(onboardingCompleteProvider.future)
        .catchError((_) => false);
    if (!onboardingDone || !mounted) return;

    final lastScan = await ref
        .read(lastScanAtProvider.future)
        .catchError((_) => null);
    final now = DateTime.now();

    // On reinstall: data is restored from Firestore (lastScanAt = null because
    // scan history is not stored in Firestore) but the user already has their
    // map populated. Don't prompt them to scan — they haven't lost anything.
    // Only show the prompt when lastScan is null AND there are no visits yet
    // (genuine new user), or when the last scan was more than 7 days ago.
    if (lastScan == null) {
      final visits = await ref
          .read(effectiveVisitsProvider.future)
          .catchError((_) => <EffectiveVisitedCountry>[]);
      if (visits.isNotEmpty || !mounted) return;
    } else if (now.difference(lastScan).inDays <= 7) {
      return;
    }
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final dismissedAt = prefs.getString(_prefKey);
    if (dismissedAt != null) {
      final dismissed = DateTime.tryParse(dismissedAt);
      if (dismissed != null && DateUtils.isSameDay(dismissed, now)) {
        return;
      }
    }

    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isDismissible: true,
      builder:
          (_) => DiscoverNewCountriesSheet(
            onScanNow: () {
              Navigator.of(context).pop();
              widget.onNavigateToScan?.call();
            },
            onLater: () => Navigator.of(context).pop(),
          ),
    );

    // Record dismiss date regardless of which button was tapped.
    await prefs.setString(_prefKey, now.toIso8601String());
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// Bottom sheet shown when the user hasn't scanned in 7+ days. (ADR-095)
class DiscoverNewCountriesSheet extends StatelessWidget {
  const DiscoverNewCountriesSheet({
    super.key,
    required this.onScanNow,
    required this.onLater,
  });

  final VoidCallback onScanNow;
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.photo_camera_outlined,
              size: 48,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'New countries may be waiting',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              "You haven't scanned in a while. Scan your photo library to discover new countries.",
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: onScanNow, child: const Text('Scan now')),
            TextButton(onPressed: onLater, child: const Text('Later')),
          ],
        ),
      ),
    );
  }
}

// ── Year in Review Banner ─────────────────────────────────────────────────────

/// Dismissible bottom banner shown in December (current year preview) and
/// January (prior year summary), inviting the user to view Year in Review.
/// (M94, ADR-139)
class _YearInReviewBanner extends ConsumerStatefulWidget {
  const _YearInReviewBanner();

  @override
  ConsumerState<_YearInReviewBanner> createState() =>
      _YearInReviewBannerState();
}

class _YearInReviewBannerState extends ConsumerState<_YearInReviewBanner> {
  static const _prefDismissedPrefix = 'yirDismissed:';
  static const _prefScheduledPrefix = 'yirScheduled:';

  bool _dismissed = false;
  bool _prefLoaded = false;

  late int _reviewYear;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _reviewYear = now.month == 12 ? now.year : now.year - 1;
    _loadPref();

    // Handle cold-start from YIR notification.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final year = NotificationService.instance.pendingYearInReviewYear.value;
      if (year != null && mounted) {
        NotificationService.instance.pendingYearInReviewYear.value = null;
        _openScreen(year);
      }
    });

    NotificationService.instance.pendingYearInReviewYear.addListener(
      _onPendingYearInReview,
    );
  }

  void _onPendingYearInReview() {
    final year = NotificationService.instance.pendingYearInReviewYear.value;
    if (year != null && mounted) {
      NotificationService.instance.pendingYearInReviewYear.value = null;
      _openScreen(year);
    }
  }

  Future<void> _loadPref() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final dismissed =
        prefs.getBool('$_prefDismissedPrefix$_reviewYear') ?? false;
    setState(() {
      _dismissed = dismissed;
      _prefLoaded = true;
    });
    // Schedule next notification once per year (guard prevents duplicate scheduling).
    final nextYear = DateTime.now().year + 1;
    final alreadyScheduled =
        prefs.getBool('$_prefScheduledPrefix$nextYear') ?? false;
    if (!alreadyScheduled) {
      await NotificationService.instance.scheduleYearInReview(
        forYear: nextYear,
      );
      await prefs.setBool('$_prefScheduledPrefix$nextYear', true);
    }
  }

  Future<void> _dismiss() async {
    setState(() => _dismissed = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_prefDismissedPrefix$_reviewYear', true);
  }

  void _openScreen(int year) {
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => YearInReviewScreen(year: year)),
    );
  }

  @override
  void dispose() {
    NotificationService.instance.pendingYearInReviewYear.removeListener(
      _onPendingYearInReview,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    // Only show in December or January.
    if (now.month != 12 && now.month != 1) return const SizedBox.shrink();
    if (!_prefLoaded || _dismissed) return const SizedBox.shrink();

    // Only show if there is data for the review year.
    final dataAsync = ref.watch(yearInReviewDataProvider(_reviewYear));
    if (!dataAsync.hasValue || dataAsync.valueOrNull == null) {
      return const SizedBox.shrink();
    }

    final yirTheme = Theme.of(context);
    final yirOnSurface = yirTheme.colorScheme.onSurface;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      decoration: BoxDecoration(
        color: yirTheme.colorScheme.surfaceContainer,
        border: Border.all(
          color: const Color(0xFFD4A017).withValues(alpha: 0.5),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          const Text('🌍', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$_reviewYear in Review — see your year in travel',
              style: TextStyle(
                color: yirOnSurface,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          TextButton(
            onPressed: () => _openScreen(_reviewYear),
            child: const Text(
              'View',
              style: TextStyle(color: Color(0xFFD4A017)),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: yirOnSurface.withValues(alpha: 0.54), size: 18),
            onPressed: _dismiss,
            tooltip: 'Dismiss',
          ),
        ],
      ),
    );
  }
}

// ── Memory Pulse Section ──────────────────────────────────────────────────────

/// Surfaces today's travel anniversary cards above the globe (M91, ADR-136).
///
/// Owns the slide-in animation and cold-start ValueNotifier listener.
/// Stays as a separate [ConsumerStatefulWidget] so [MapScreen] itself
/// remains a [ConsumerWidget] (ADR-136).
class _MemoryPulseSection extends ConsumerStatefulWidget {
  const _MemoryPulseSection();

  @override
  ConsumerState<_MemoryPulseSection> createState() =>
      _MemoryPulseSectionState();
}

class _MemoryPulseSectionState extends ConsumerState<_MemoryPulseSection>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fade = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final memoriesAsync = ref.watch(todaysMemoriesProvider);
    final dismissed = ref.watch(memoriesDismissedProvider);
    final service = ref.read(memoryPulseServiceProvider);

    final memories = memoriesAsync.valueOrNull ?? const [];
    final visible =
        memories.where((m) => !dismissed.contains(m.assetId)).toList();

    if (visible.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller.isCompleted) _controller.reverse();
      });
      return const SizedBox.shrink();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_controller.isCompleted && !_controller.isAnimating) {
        _controller.forward();
      }
    });

    // Schedule the next notification once memories are known (fire-and-forget).
    ref.listen(todaysMemoriesProvider, (_, next) {
      if (next.hasValue) {
        service.scheduleAnniversaryNotifications(DateTime.now());
      }
    });

    return Padding(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 52, // below XpLevelBar
      ),
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: MemoryPulseCard(
            memories: visible,
            service: service,
            onViewTrip: (tripId) {
              NotificationService.instance.pendingMemoryTripId.value = tripId;
            },
          ),
        ),
      ),
    );
  }
}

// ── Globe action bar ──────────────────────────────────────────────────────────

/// Compact horizontal bar with Full Scan, New Photos, and Replay actions.
///
/// Shown at the top of [MapScreen] (M134) — replaces the separate replay FAB
/// and scan camera icon button.
class _GlobeActionBar extends StatelessWidget {
  const _GlobeActionBar({this.onFullScan, this.onNewPhotos, this.onReplay});

  final VoidCallback? onFullScan;
  final VoidCallback? onNewPhotos;
  final VoidCallback? onReplay;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black45,
      borderRadius: BorderRadius.circular(20),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ActionBtn(
            icon: Icons.photo_library_outlined,
            label: 'Full Scan',
            onPressed: onFullScan,
          ),
          Container(width: 1, height: 24, color: Colors.white24),
          _ActionBtn(
            icon: Icons.add_photo_alternate_outlined,
            label: 'New Photos',
            onPressed: onNewPhotos,
          ),
          Container(width: 1, height: 24, color: Colors.white24),
          _ActionBtn(
            icon: Icons.play_circle_outline,
            label: 'Replay',
            onPressed: onReplay,
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({required this.icon, required this.label, this.onPressed});

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Daily Challenge chip ───────────────────────────────────────────────────────

// ── Globe + hero pin wrapper ─────────────────────────────────────────────────

/// How often the globe's hero pin is re-evaluated against whatever photo is
/// currently nearest the screen centre. Chosen as a "slideshow" pace —
/// long enough to actually register each photo, short enough that the globe
/// feels like it's continuously surfacing new ones as it turns (not every
/// candidate under the centre needs a turn; this samples periodically
/// rather than tracking every frame).
const _kHeroCycleInterval = Duration(seconds: 3);

/// Hosts [GlobeMapWidget] plus [GlobeHeroPin] (the globe's equivalent of the
/// flat map's [PhotoPinLayer]), fed by the globe's per-frame projection via
/// `onProjectionUpdated`. Kept in a small stateful wrapper — rather than
/// setState-ing the whole (stateless) MapScreen every frame — so only the
/// pin itself rebuilds as the globe rotates/zooms.
///
/// Also cycles the hero pin to whatever photo is nearest the screen centre
/// every [_kHeroCycleInterval] while the globe is turning — a periodic
/// sample rather than a per-frame check, since "nearest to centre" only
/// needs to update a few times a minute to read as a continuous flow, and
/// recomputing it 60x/sec would be pure waste.
class _GlobeWithHeroPin extends ConsumerStatefulWidget {
  const _GlobeWithHeroPin({
    required this.onCountryTap,
    required this.showHeroPin,
  });

  final void Function(String isoCode) onCountryTap;
  final bool showHeroPin;

  @override
  ConsumerState<_GlobeWithHeroPin> createState() => _GlobeWithHeroPinState();
}

class _GlobeWithHeroPinState extends ConsumerState<_GlobeWithHeroPin> {
  final _projectionNotifier = ValueNotifier<(GlobeProjection, Size)>(
    (const GlobeProjection(), Size.zero),
  );
  Timer? _heroCycleTimer;

  @override
  void initState() {
    super.initState();
    _heroCycleTimer = Timer.periodic(
      _kHeroCycleInterval,
      (_) => _maybeCycleHero(),
    );
  }

  @override
  void dispose() {
    _heroCycleTimer?.cancel();
    _projectionNotifier.dispose();
    super.dispose();
  }

  /// Re-picks the hero photo from whatever is nearest the screen centre
  /// right now. No-ops while heritage mode is showing (no pin to move) or
  /// while rotation is explicitly paused — nothing is "turning" for the pin
  /// to follow, so leave it on the photo the user was already looking at.
  void _maybeCycleHero() {
    if (!mounted || !widget.showHeroPin) return;
    if (ref.read(globeRotationPausedProvider)) return;
    final locations = ref.read(photoLocationsProvider).valueOrNull;
    if (locations == null || locations.isEmpty) return;
    final (projection, canvasSize) = _projectionNotifier.value;
    final next = findCenterMostPhoto(
      locations: locations,
      projection: projection,
      canvasSize: canvasSize,
    );
    if (next == null) return;
    if (ref.read(selectedMapPhotoProvider)?.assetId == next.assetId) return;
    ref.read(selectedMapPhotoProvider.notifier).state = next;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GlobeMapWidget(
          onCountryTap: widget.onCountryTap,
          onProjectionUpdated: (projection, canvasSize) {
            _projectionNotifier.value = (projection, canvasSize);
          },
        ),
        if (widget.showHeroPin)
          ValueListenableBuilder<(GlobeProjection, Size)>(
            valueListenable: _projectionNotifier,
            builder: (context, value, _) =>
                GlobeHeroPin(projection: value.$1, canvasSize: value.$2),
          ),
      ],
    );
  }
}

// ── Globe rotation toggle ─────────────────────────────────────────────────────

/// Small pause / play button in the top-left corner of the globe.
/// Pausing stops auto-spin so the user can inspect heritage site dots and
/// tap any site to view its details.
class _GlobeRotationToggle extends ConsumerWidget {
  const _GlobeRotationToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paused = ref.watch(globeRotationPausedProvider);
    return Material(
      color: Colors.black45,
      shape: const CircleBorder(),
      child: IconButton(
        icon: Icon(paused ? Icons.play_arrow_rounded : Icons.pause_rounded),
        color: Colors.white,
        iconSize: 22,
        tooltip: paused ? 'Resume rotation' : 'Pause rotation',
        onPressed:
            () =>
                ref.read(globeRotationPausedProvider.notifier).state = !paused,
      ),
    );
  }
}

/// Cycles the map's optional overlay between the Google Photos-style photo
/// heatmap and UNESCO heritage site markers (mutually exclusive — see
/// [MapOverlayMode]). Shared between the globe and the flat map, so
/// switching views keeps the same choice. Gold when the heatmap is active.
class _MapOverlayModeToggle extends ConsumerWidget {
  const _MapOverlayModeToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(mapOverlayModeProvider);
    final isHeatmap = mode == MapOverlayMode.heatmap;
    return Material(
      color: Colors.black45,
      shape: const CircleBorder(),
      child: IconButton(
        icon: Icon(
          isHeatmap ? Icons.blur_on_rounded : Icons.account_balance_rounded,
        ),
        color: isHeatmap ? const Color(0xFFF2C94C) : Colors.white,
        iconSize: 22,
        tooltip: isHeatmap
            ? 'Showing photo heatmap — tap for UNESCO sites'
            : 'Showing UNESCO sites — tap for photo heatmap',
        onPressed: () => ref.read(mapOverlayModeProvider.notifier).state =
            isHeatmap ? MapOverlayMode.heritage : MapOverlayMode.heatmap,
      ),
    );
  }
}

// ── Globe ↔ flat map toggle ───────────────────────────────────────────────────

class _MapViewToggle extends ConsumerWidget {
  const _MapViewToggle({required this.globeMode});

  final bool globeMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: Colors.black45,
      shape: const CircleBorder(),
      child: IconButton(
        icon: Icon(globeMode ? Icons.map_outlined : Icons.language_rounded),
        color: Colors.white,
        iconSize: 22,
        tooltip: globeMode ? 'Switch to flat map' : 'Switch to globe',
        onPressed: () =>
            ref.read(globeModeProvider.notifier).state = !globeMode,
      ),
    );
  }
}

// ── Daily challenge chip ──────────────────────────────────────────────────────

/// Pill-shaped chip shown below the action bar. Tapping opens [DailyChallengeScreen].
/// Long-pressing opens [ChallengeStatsScreen].
/// Shows a streak badge (🔥N) when streak≥2, otherwise a green dot when unsolved.
class _DailyChallengeChip extends ConsumerWidget {
  const _DailyChallengeChip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(dailyChallengeProgressProvider);
    final solved = progressAsync.valueOrNull?.solved ?? false;
    final streak =
        ref.watch(challengeAggregateProvider).valueOrNull?.currentStreak ?? 0;

    return GestureDetector(
      onTap:
          () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const DailyChallengeScreen(),
            ),
          ),
      onLongPress:
          () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const ChallengeStatsScreen(),
            ),
          ),
      child: Material(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.emoji_events_outlined,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 6),
              const Text(
                'Daily Challenge',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
              if (streak >= 2) ...[
                const SizedBox(width: 6),
                Text('🔥$streak', style: const TextStyle(fontSize: 12)),
              ] else if (!solved) ...[
                const SizedBox(width: 6),
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Color(0xFF4CAF50),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── UNESCO Nearby chip ────────────────────────────────────────────────────────

class _UnescoNearbyChip extends StatelessWidget {
  const _UnescoNearbyChip();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const UnescoNearbyExplorerScreen(),
        ),
      ),
      child: Material(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(20),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.account_balance_outlined,
                  color: Colors.white, size: 16),
              SizedBox(width: 6),
              Text(
                'UNESCO Nearby',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
