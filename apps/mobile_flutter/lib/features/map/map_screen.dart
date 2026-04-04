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

import '../../core/providers.dart';
import '../../data/firestore_sync_service.dart';
import '../xp/xp_event.dart';
import '../auth/apple_sign_in.dart' as apple;
import '../cards/card_generator_screen.dart';
import '../merch/merch_country_selection_screen.dart';
import '../settings/privacy_account_screen.dart';
import '../sharing/travel_card_share.dart';
import 'country_detail_sheet.dart';
import 'country_polygon_layer.dart';
import 'globe_map_widget.dart';
import 'region_chips_marker_layer.dart';
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
    this.signInWithAppleOverride,
    this.syncService,
  });

  /// Test hook: if non-null, called instead of [resolveCountry()] on tap.
  final String? Function(double lat, double lng)? tapResolverOverride;

  /// Called when the user taps "Scan Photos" in the empty state overlay.
  final VoidCallback? onNavigateToScan;

  /// Test hook: if non-null, called instead of the real Apple sign-in flow.
  final Future<void> Function()? signInWithAppleOverride;

  /// Sync service used to flush dirty records after Apple sign-in.
  final SyncService? syncService;

  SyncService _syncService() => syncService ?? FirestoreSyncService();

  Future<void> _onDeleteHistory(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
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
    ref.invalidate(effectiveVisitsProvider);
    ref.invalidate(travelSummaryProvider);
    ref.invalidate(tripListProvider);        // ADR-081: refresh Journal tab
    ref.invalidate(regionCountProvider);    // ADR-082: refresh Stats regions count
    ref.invalidate(countryTripCountsProvider);
    ref.invalidate(earliestVisitYearProvider);
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
    final resolver = tapResolverOverride ?? resolveCountry;
    final code = resolver(point.latitude, point.longitude);
    if (code == null) return;
    _showCountryDetail(context, ref, code, visitedByCode);
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
    showModalBottomSheet<bool>(
      context: context,
      builder: (_) => CountryDetailSheet(
        isoCode: code,
        visit: visit,
        onAdd: visit == null
            ? () => ref.read(visitRepositoryProvider).saveAdded(
                  UserAddedCountry(
                    countryCode: code,
                    addedAt: DateTime.now().toUtc(),
                  ),
                )
            : null,
      ),
    ).then((added) {
      if (added == true) {
        ref.invalidate(effectiveVisitsProvider);
      }
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final isAnonymous = user == null || user.isAnonymous;

    // Derive earliestVisitYear for the "Filter by year" menu item.
    final earliestYear =
        ref.watch(earliestVisitYearProvider).valueOrNull;
    final showFilterByYear =
        earliestYear != null && earliestYear < DateTime.now().year;

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
    final showNudge = hasVisits &&
        !nudgeDismissed &&
        lastScanAt != null &&
        DateTime.now().difference(lastScanAt) >= const Duration(days: 30);

    // Show loading indicator until effective visits first resolve.
    if (visitsAsync.isLoading && visitedByCode.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Fire region-1-away Rovy nudge whenever a region transitions to exactly
    // 1 country remaining and the user has at least one visit in that region.
    ref.listen<List<RegionProgressData>>(regionProgressProvider,
        (previous, next) {
      final prevOneAway = (previous ?? const <RegionProgressData>[])
          .where((r) => r.remaining == 1 && r.visitedCount > 0)
          .map((r) => r.region)
          .toSet();
      for (final data in next) {
        if (data.remaining == 1 &&
            data.visitedCount > 0 &&
            !prevOneAway.contains(data.region)) {
          ref.read(rovyMessageProvider.notifier).state = RovyMessage(
            text:
                'Just 1 more country to complete ${data.region.displayName}!',
            trigger: RovyTrigger.regionOneAway,
            emoji: '🎯',
          );
          break; // one message at a time
        }
      }
    });

    final globeMode = ref.watch(globeModeProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0D2137), // dark navy ocean (ADR-080)
      body: Stack(
        children: [
          if (globeMode)
            GlobeMapWidget(
              onCountryTap: (code) =>
                  _onGlobeTap(context, ref, code, visitedByCode),
            )
          else
            FlutterMap(
              options: MapOptions(
                initialCenter: const LatLng(20, 0),
                initialZoom: 2,
                backgroundColor: const Color(0xFF0D2137),
                onTap: (pos, latlng) =>
                    _onMapTap(context, ref, visitedByCode, pos, latlng),
              ),
              children: const [
                CountryPolygonLayer(),
                TargetCountryLayer(),
                RegionChipsMarkerLayer(),
              ],
            ),
          const Align(
            alignment: Alignment.topCenter,
            child: XpLevelBar(),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showNudge)
                  _ScanNudgeBanner(
                    onScan: onNavigateToScan,
                    onDismiss: () =>
                        ref.read(scanNudgeDismissedProvider.notifier).state =
                            true,
                  ),
                const TimelineScrubberBar(),
                const StatsStrip(),
              ],
            ),
          ),
          if (!hasVisits)
            _EmptyStateOverlay(onNavigateToScan: onNavigateToScan),
          const Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.only(bottom: 80),
              child: RovyBubble(),
            ),
          ),
          // Globe / flat toggle (ADR-116).
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            child: Material(
              color: Colors.black45,
              borderRadius: BorderRadius.circular(20),
              child: IconButton(
                icon: Icon(
                  globeMode ? Icons.language : Icons.public,
                  color: Colors.white,
                ),
                tooltip: globeMode ? 'Switch to flat map' : 'Switch to globe',
                onPressed: () => ref.read(globeModeProvider.notifier).state =
                    !ref.read(globeModeProvider),
              ),
            ),
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
                    final s = ref.read(travelSummaryProvider).valueOrNull ??
                        TravelSummary.fromVisits(visitedByCode.values.toList());
                    captureAndShare(context, s, 'My Roavvy travel map');
                    ref.read(rovyMessageProvider.notifier).state =
                        const RovyMessage(
                      text: 'Love it! Thanks for sharing your adventures!',
                      trigger: RovyTrigger.postShare,
                      emoji: '🙌',
                    );
                    final now = DateTime.now().toUtc();
                    unawaited(ref.read(xpNotifierProvider.notifier).award(XpEvent(
                      id: '${now.microsecondsSinceEpoch}-share',
                      reason: XpReason.share,
                      amount: 30,
                      awardedAt: now,
                    )));
                  } else if (action == _MapMenuAction.createCard) {
                    Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => const CardGeneratorScreen(),
                    ));
                  } else if (action == _MapMenuAction.shop) {
                    Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => const MerchCountrySelectionScreen(),
                    ));
                  } else if (action == _MapMenuAction.privacyAccount) {
                    Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => const PrivacyAccountScreen(),
                    ));
                  } else if (action == _MapMenuAction.signOut) {
                    FirebaseAuth.instance.signOut();
                  } else if (action == _MapMenuAction.filterByYear) {
                    ref.read(yearFilterProvider.notifier).state =
                        DateTime.now().year;
                  }
                },
                itemBuilder: (_) => [
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
                  if (hasVisits)
                    const PopupMenuItem(
                      value: _MapMenuAction.shop,
                      child: ListTile(
                        leading: Icon(Icons.shopping_bag_outlined),
                        title: Text('Create a poster'),
                      ),
                    ),
                  PopupMenuItem(
                    value: _MapMenuAction.deleteHistory,
                    child: ListTile(
                      leading: Icon(Icons.delete_outline, color: Colors.red.shade600),
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
                  const PopupMenuItem(
                    value: _MapMenuAction.signOut,
                    child: ListTile(
                      leading: Icon(Icons.logout),
                      title: Text('Sign out'),
                    ),
                  ),
                  if (showFilterByYear)
                    const PopupMenuItem(
                      value: _MapMenuAction.filterByYear,
                      child: ListTile(
                        leading: Icon(Icons.timeline),
                        title: Text('Filter by year'),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // App-open scan prompt gate (Task 150 — M43)
          _ScanPromptGate(onNavigateToScan: onNavigateToScan),
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
  shop,
  privacyAccount,
  signOut,
  filterByYear,
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

    final onboardingDone =
        await ref.read(onboardingCompleteProvider.future).catchError((_) => false);
    if (!onboardingDone || !mounted) return;

    final lastScan = await ref.read(lastScanAtProvider.future).catchError((_) => null);
    final now = DateTime.now();
    final needsScan = lastScan == null ||
        now.difference(lastScan).inDays > 7;
    if (!needsScan || !mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final dismissedAt = prefs.getString(_prefKey);
    if (dismissedAt != null) {
      final dismissed = DateTime.tryParse(dismissedAt);
      if (dismissed != null &&
          DateUtils.isSameDay(dismissed, now)) {
        return;
      }
    }

    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isDismissible: true,
      builder: (_) => DiscoverNewCountriesSheet(
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
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
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
            FilledButton(
              onPressed: onScanNow,
              child: const Text('Scan now'),
            ),
            TextButton(
              onPressed: onLater,
              child: const Text('Later'),
            ),
          ],
        ),
      ),
    );
  }
}
