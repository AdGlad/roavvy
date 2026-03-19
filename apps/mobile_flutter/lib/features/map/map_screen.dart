import 'dart:async';

import 'package:country_lookup/country_lookup.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_models/shared_models.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../core/providers.dart';
import '../../data/firestore_sync_service.dart';
import '../auth/apple_sign_in.dart' as apple;
import '../settings/privacy_account_screen.dart';
import '../sharing/travel_card_share.dart';
import 'country_detail_sheet.dart';
import 'stats_strip.dart';

/// ISO codes suppressed from the world map.
const _kSuppressedCodes = {'AQ'};

const _kVisitedColor = Color(0xFF2D6A4F);
const _kUnvisitedColor = Color(0xFFD1D5DB);
const _kBorderColor = Color(0xFF9CA3AF);

/// Displays all country polygons on an offline flutter_map canvas.
///
/// Visited countries are highlighted in [_kVisitedColor]. Tapping a country
/// opens [CountryDetailSheet]. Antarctica (AQ) is suppressed.
///
/// Polygon data and visit state come from Riverpod providers.
/// [tapResolverOverride] is a test hook that bypasses [resolveCountry()].
/// [onNavigateToScan] is called when the user taps "Scan Photos" in the empty
/// state overlay — used by [MainShell] to switch to the Scan tab.
/// [signInWithAppleOverride] is a test hook that replaces the full Apple
/// sign-in flow (avoids platform channel in widget tests).
/// [syncService] overrides the default [FirestoreSyncService]; pass
/// [NoOpSyncService] in widget tests to prevent real Firestore calls (ADR-030).
class MapScreen extends ConsumerStatefulWidget {
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
  /// Defaults to [FirestoreSyncService] when null.
  final SyncService? syncService;

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  Map<String, EffectiveVisitedCountry> _visitedByCode = {};
  List<Polygon> _mapPolygons = const [];
  bool _loading = true;

  SyncService get _syncService => widget.syncService ?? FirestoreSyncService();

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final polygonData = ref.read(polygonsProvider);
    final effective = await ref.read(effectiveVisitsProvider.future);
    final visitedByCode = {for (final v in effective) v.countryCode: v};

    final polygons = <Polygon>[];
    for (final p in polygonData) {
      if (_kSuppressedCodes.contains(p.isoCode)) continue;
      polygons.add(
        Polygon(
          points: [for (final (lat, lng) in p.vertices) LatLng(lat, lng)],
          color: visitedByCode.containsKey(p.isoCode)
              ? _kVisitedColor
              : _kUnvisitedColor,
          borderColor: _kBorderColor,
          borderStrokeWidth: 0.5,
        ),
      );
    }

    if (!mounted) return;
    setState(() {
      _visitedByCode = visitedByCode;
      _mapPolygons = polygons;
      _loading = false;
    });
  }

  Future<void> _onDeleteHistory() async {
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
    if (confirmed != true || !mounted) return;
    await ref.read(visitRepositoryProvider).clearAll();
    ref.invalidate(effectiveVisitsProvider);
    ref.invalidate(travelSummaryProvider);
    _init();
  }

  Future<void> _onSignInWithApple() async {
    // Test hook: bypass platform channel in widget tests.
    if (widget.signInWithAppleOverride != null) {
      await widget.signInWithAppleOverride!();
      return;
    }

    try {
      await apple.signInWithApple(
        repo: ref.read(visitRepositoryProvider),
        syncService: _syncService,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return; // user cancelled — no UI
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in failed. Try again.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in failed. Try again.')),
      );
    }
  }

  void _onMapTap(TapPosition _, LatLng point) {
    final resolver = widget.tapResolverOverride ?? resolveCountry;
    final code = resolver(point.latitude, point.longitude);
    if (code == null) return;

    final visit = _visitedByCode[code];

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
      if (added == true && mounted) {
        ref.invalidate(effectiveVisitsProvider);
        _init();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final isAnonymous = user == null || user.isAnonymous;
    final hasVisits = _visitedByCode.isNotEmpty;

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: const LatLng(20, 0),
              initialZoom: 2,
              onTap: _onMapTap,
            ),
            children: [
              PolygonLayer(
                polygonCulling: true,
                polygons: _mapPolygons,
              ),
            ],
          ),
          const Align(
            alignment: Alignment.bottomCenter,
            child: StatsStrip(),
          ),
          if (_visitedByCode.isEmpty)
            _EmptyStateOverlay(onNavigateToScan: widget.onNavigateToScan),
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
                    _onSignInWithApple();
                  } else if (action == _MapMenuAction.deleteHistory) {
                    _onDeleteHistory();
                  } else if (action == _MapMenuAction.shareMyMap) {
                    final s = ref.read(travelSummaryProvider).valueOrNull ??
                        TravelSummary.fromVisits(_visitedByCode.values.toList());
                    captureAndShare(context, s, 'My Roavvy travel map');
                  } else if (action == _MapMenuAction.privacyAccount) {
                    Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => const PrivacyAccountScreen(),
                    ));
                  } else if (action == _MapMenuAction.signOut) {
                    FirebaseAuth.instance.signOut();
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Menu actions ───────────────────────────────────────────────────────────────

enum _MapMenuAction { signInWithApple, deleteHistory, shareMyMap, privacyAccount, signOut }

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
